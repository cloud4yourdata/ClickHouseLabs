
SELECT
    format(
        '{{
          "message_header": {{
            "message_id": "MSG-{0}-{1}",
            "timestamp": "{2}",
            "source": "{3}"
          }},
          "device_details": {{
            "device_id": "{3}",
            "meter_type": "Electricity_3Phase",
            "firmware_version": "v2.4.1"
          }},
          "readings": [
            {{ "obis_code": "1.8.0", "value": {4} }},
            {{ "obis_code": "21.7.0", "value": {5} }},
            {{ "obis_code": "41.7.0", "value": {6} }},
            {{ "obis_code": "61.7.0", "value": {7} }}
          ]
        }}',
        -- {0} Date string for Message ID
        formatDateTime(now(), '%Y%m%d'),
        -- {1} Padded sequence for Message ID
        lpad(toString(number), 6, '0'),
        -- {2} ISO Timestamp
        formatDateTime(now(), '%Y-%m-%dT%H:%M:%SZ'),
        -- {3} AMI ID (Matching your PostgreSQL pattern)
        concat('AMI-PL-20', lpad(toString(number + 1), 10, '0')),
        -- {4} 1.8.0: Total Active Energy (Random starting point + small increment)
        toString(round(10000 + (rand() % 5000) + (rand() / 4294967295), 2)),
        -- {5,6,7} 21.7.0, 41.7.0, 61.7.0: Instantaneous Power L1, L2, L3 (0.0 to 3.0 kW)
        toString(round((rand(1) % 300) / 100.0, 2)),
        toString(round((rand(2) % 200) / 100.0, 2)),
        toString(round((rand(3) % 400) / 100.0, 2))
    )
FROM numbers(10);


SELECT
    -- Unikalny ID wiadomości
    generateUUIDv4() AS message_id,
    -- Czas co 15 minut dla każdego urządzenia
    timestamp AS measurement_time,
    -- Identyfikator urządzenia (meter_001, meter_002, itd.)
    format('meter_{:03d}', device_idx) AS device_id,
    -- Energy Total: narastająco (bazowa wartość + przyrost wynikający z czasu)
    (1000 + (step_idx * 0.5) + (randCanonical(device_idx) * 10)) AS energy_active_total,
    -- Chwilowe zużycie na fazach (wartości losowe z zakresu 0.1 - 1.5)
    (randCanonical(device_idx + 1) * 1.5) AS energy_active_l1,
    (randCanonical(device_idx + 2) * 1.5) AS energy_active_l2,
    (randCanonical(device_idx + 3) * 1.5) AS energy_active_l3
FROM (
    SELECT
        -- 100 liczników
        number % 100 AS device_idx,
        -- Indeks kroku czasowego (potrzebny do narastania energii)
        intDiv(number, 100) AS step_idx,
        -- Startujemy tydzień temu, co 15 minut (900 sekund)
        now() - INTERVAL 7 DAY + (step_idx * INTERVAL 15 MINUTE) AS timestamp
    FROM numbers(100 * 96 * 7) -- 100 liczników * 96 odczytów/dobę * 7 dni
);

SELECT
     concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS msg_id,
    toDateTime(intDiv(toUInt64(now()), 900) * 900) AS measurement_time,
    ami,
    -- Energy Total: przykładowa wartość bazowa (np. 1500.50)
    1500.50 +energy_active_l1+energy_active_l2+energy_active_l3 AS energy_active_total,
    -- Chwilowe zużycie na fazach (losowe wartości dla urealnienia danych)
    round((rand(1) % 300) / 100.0, 2) AS energy_active_l1,
    round((rand(2) % 300) / 100.0, 2) AS energy_active_l2,
    round((rand(3) % 300) / 100.0, 2) AS energy_active_l3
FROM ppe_ami_dict as ami
------------------------------------------------------------------------------
---NEW DATA
INSERT INTO ami_silver_tmp(
    message_id,
    measurement_time,
    device_id,
    energy_active_total,
    energy_active_l1,
    energy_active_l2,
    energy_active_l3
)
WITH
last_data AS
    (
        SELECT
            ppe,
            energy_usage_total,
            last_measurement_time
        FROM vw_ppe_stats
        QUALIFY row_number() OVER (PARTITION BY ppe, year, month ORDER BY last_measurement_time DESC) = 1
    )
SELECT

    concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS message_id,
    case when toUnixTimestamp(ld.last_measurement_time)::int = 0 then toDateTime('2024-01-01 00:00:00') 
      else ld.last_measurement_time end + toIntervalMinute(step * 15)  AS measurement_time,
    ami.ami as device_id,
    (coalesce(ld.energy_usage_total, 0.) + (step * 0.75) + (randCanonical(1) * 0.1)) AS energy_active_total,
    round((rand(1) % 250) / 100., 2) AS energy_active_l1,
    round((rand(2) % 250) / 100., 2) AS energy_active_l2,
    round((rand(3) % 250) / 100., 2) AS energy_active_l3
FROM ppe_ami_dict AS ami
ARRAY JOIN range(0, (SELECT total_steps FROM params)::int) as step
LEFT JOIN last_data AS ld ON ami.ppe = ld.ppe
SETTINGS max_insert_block_size = 100_000, max_threads = 8;

---
WITH
params AS (
    SELECT 
        toDateTime('2024-01-01 00:00:00') AS global_start,
         toDateTime('2025-01-01 00:00:00') AS global_end,
        dateDiff('minute', global_start, global_end) / 15 AS total_steps
),
 last_data AS
    (
        SELECT
            ppe,
            energy_usage_total,
            last_measurement_time
        FROM vw_ppe_stats
        QUALIFY row_number() OVER (PARTITION BY ppe, year, month ORDER BY last_measurement_time DESC) = 1
    )
SELECT
    concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS msg_id,
    multiIf(toUnixTimestamp(ld.last_measurement_time) = 0, toDateTime('2024-01-01 00:00:00'), ld.last_measurement_time + toIntervalMinute(15)) AS measurement_time,
    ami,
    ((coalesce(ld.energy_usage_total, 0.) + energy_active_l1) + energy_active_l2) + energy_active_l3 AS energy_active_total,
    round((rand(1) % 300) / 100., 2) AS energy_active_l1,
    round((rand(2) % 300) / 100., 2) AS energy_active_l2,
    round((rand(3) % 300) / 100., 2) AS energy_active_l3
FROM ppe_ami_dict AS ami
CROSS JOIN numbers(((SELECT total_steps FROM params)))) as n
LEFT JOIN last_data AS ld ON ami.ppe = ld.ppe
AND ami.ami='AMI-PL-200000004488'
LIMIT 5

30*24*4



---NEW DATA
INSERT INTO ami_silver_tmp(
    message_id,
    measurement_time,
    device_id,
    energy_active_total,
    energy_active_l1,
    energy_active_l2,
    energy_active_l3
)
WITH
last_data AS
    (
      select device_id,
       max(energy_active_total) as energy_active_total,
       max( measurement_time) AS last_measurement_time
       from ami_silver_tmp group by all
    )
SELECT
    concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS message_id,
    case when year(ld.last_measurement_time) = 1970 then toDateTime('2024-01-01 00:00:00') 
      else ld.last_measurement_time end + toIntervalMinute(step * 15)  AS measurement_time,
    ami.ami as device_id,
    (coalesce(ld.energy_active_total, 0.) + (step * 0.75) + (randCanonical(1) * 0.1)) AS energy_active_total,
    round((rand(1) % 250) / 100., 2) AS energy_active_l1,
    round((rand(2) % 250) / 100., 2) AS energy_active_l2,
    round((rand(3) % 250) / 100., 2) AS energy_active_l3
FROM ppe_ami_dict AS ami
ARRAY JOIN range(0, 2880) as step
LEFT JOIN last_data AS ld ON ami.ami = ld.device_id
SETTINGS max_insert_block_size = 100_000, max_threads = 8;



SELECT
            device_id,
            energy_active_total,
            measurement_time as last_measurement_time
        FROM silver_ami_tmp
        QUALIFY row_number() OVER (PARTITION BY device_id ORDER BY measurement_time DESC) = 1


--Info

SELECT
    formatReadableSize(total_bytes),
    formatReadableSize(total_bytes_uncompressed),
    formatReadableQuantity(total_rows)
FROM system.tables
WHERE name = 'ami_silver_tmp'
FORMAT vertical




WITH
last_data AS
    (
      select device_id,
       max(energy_active_total) as energy_active_total,
       max( measurement_time) AS last_measurement_time
       from ami_silver_tmp group by all
    )
SELECT
    concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS message_id,
    case when year(ld.last_measurement_time) = 1970 then toDateTime('2024-01-01 00:00:00') 
      else ld.last_measurement_time end + toIntervalMinute(step * 15)  AS measurement_time,
    ami.ami as device_id,
    (coalesce(ld.energy_active_total, 0.) + (step * 0.75) + (randCanonical(1) * 0.1)) AS energy_active_total,
    round((rand(1) % 250) / 100., 2) AS energy_active_l1,
    round((rand(2) % 250) / 100., 2) AS energy_active_l2,
    round((rand(3) % 250) / 100., 2) AS energy_active_l3
FROM ppe_ami_dict AS ami
ARRAY JOIN range(0, 2880) as step
LEFT JOIN last_data AS ld ON ami.ami = ld.device_id
SETTINGS max_insert_block_size = 100_000, max_threads = 8;


-----INSERT MESSAGES
INSERT INTO ami_ingest(msg)
WITH last_data AS
    (
      SELECT
          ppe,
          max(energy_usage_total) AS energy_active_total,
          max(last_measurement_time) AS last_measurement_time
      FROM vw_ppe_stats
      GROUP BY ALL
    ), reads 
    AS
    (
SELECT
    concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS message_id,
    case when year(ld.last_measurement_time) = 1970 then toDateTime('2024-01-01 00:00:00') 
      else ld.last_measurement_time end + toIntervalMinute(step * 15)  AS measurement_time,
    ami.ami as device_id,
    (coalesce(ld.energy_active_total, 0.) + (step * 0.75) + (randCanonical(1) * 0.1)) AS energy_active_total,
    round((rand(1) % 250) / 100., 2) AS energy_active_l1,
    round((rand(2) % 250) / 100., 2) AS energy_active_l2,
    round((rand(3) % 250) / 100., 2) AS energy_active_l3
FROM ppe_ami_dict AS ami
ARRAY JOIN range(0, 2880) as step
LEFT JOIN last_data AS ld ON ami.ppe = ld.ppe
WHERE ami.trafo_nr='TRAFO-171'
    )
SELECT 
format(
        '{{
          "message_header": {{
            "message_id": "{0}",
            "timestamp": "{1}",
            "source": "{2}"
          }},
          "device_details": {{
            "device_id": "{2}",
            "meter_type": "Electricity_3Phase",
            "firmware_version": "v2.4.1"
          }},
          "readings": [
            {{ "obis_code": "1.8.0", "value": {3} }},
            {{ "obis_code": "21.7.0", "value": {4} }},
            {{ "obis_code": "41.7.0", "value": {5} }},
            {{ "obis_code": "61.7.0", "value": {6} }}
          ]
        }}',
        message_id,
        measurement_time,
        device_id,
        energy_active_total,
        energy_active_l1,
        energy_active_l2,
        energy_active_l3
        )
FROM reads
---PPE065221
------------------------------------------------------------------
-----------------------------------------------------------------
--INGEST
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_ingest;

--DICT
SELECT * FROM ppe_ami_dict WHERE trafo_nr='TRAFO-171';
--AMI=AMI-PL-200000065221 PPE=PPE065221 trafo=TRAFO-171
SELECT * FROM ppe_ami_dict WHERE trafo_nr='TRAFO-171' AND ami='AMI-PL-200000065221';
--INGEST
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_ingest;
--BRONZE
TRUNCATE TABLE ami_bronze;
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_bronze;
--SILVER
SELECT device_id AS ami,
 energy_active_total,
 measurement_time
FROM ami_silver
WHERE device_id = 'AMI-PL-200000065221'
ORDER BY
    measurement_time DESC
LIMIT 3;

--GOLD STATS
SELECT ppe,year,month, energy_usage_total, last_measurement_time
FROM vw_ppe_stats
WHERE ppe = 'PPE065221'
ORDER BY
    year DESC,
    month DESC
LIMIT 3;
----INGEST DATA
INSERT INTO ami_ingest(msg)
WITH last_data AS
    (
      SELECT
          ppe,
          max(energy_usage_total) AS energy_active_total,
          max(last_measurement_time) AS last_measurement_time
      FROM vw_ppe_stats
      GROUP BY ALL
    ), reads 
    AS
    (
SELECT
    concat('MSG-', toString(toUnixTimestamp(current_timestamp())), toString(rowNumberInAllBlocks())) AS message_id,
    case when year(ld.last_measurement_time) = 1970 then toDateTime('2024-01-01 00:00:00') 
      else ld.last_measurement_time end + toIntervalMinute(step * 15)  AS measurement_time,
    ami.ami as device_id,
    (coalesce(ld.energy_active_total, 0.) + (step * 0.75) + (randCanonical(1) * 0.1)) AS energy_active_total,
    round((rand(1) % 250) / 100., 2) AS energy_active_l1,
    round((rand(2) % 250) / 100., 2) AS energy_active_l2,
    round((rand(3) % 250) / 100., 2) AS energy_active_l3
FROM ppe_ami_dict AS ami
ARRAY JOIN range(0, 3072) as step
LEFT JOIN last_data AS ld ON ami.ppe = ld.ppe
WHERE ami.trafo_nr='TRAFO-171'
    )
SELECT 
format(
        '{{
          "message_header": {{
            "message_id": "{0}",
            "timestamp": "{1}",
            "source": "{2}"
          }},
          "device_details": {{
            "device_id": "{2}",
            "meter_type": "Electricity_3Phase",
            "firmware_version": "v2.4.1"
          }},
          "readings": [
            {{ "obis_code": "1.8.0", "value": {3} }},
            {{ "obis_code": "21.7.0", "value": {4} }},
            {{ "obis_code": "41.7.0", "value": {5} }},
            {{ "obis_code": "61.7.0", "value": {6} }}
          ]
        }}',
        message_id,
        measurement_time,
        device_id,
        energy_active_total,
        energy_active_l1,
        energy_active_l2,
        energy_active_l3
        )
FROM reads;

--INGEST
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_ingest;

--BRONZE
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_bronze;
--BRONZE MSG
SELECT * FROM ami_bronze LIMIT 2 FORMAT vertical;

--SILVER
SELECT device_id AS ami,
 energy_active_total,
 measurement_time
FROM ami_silver
WHERE device_id = 'AMI-PL-200000065221'
ORDER BY
    measurement_time DESC
LIMIT 3;

--GOLD STATS
SELECT ppe,year,month, energy_usage_total, last_measurement_time
FROM vw_ppe_stats
WHERE ppe = 'PPE065221'
ORDER BY
    year DESC,
    month DESC
LIMIT 3;

---
with last_read as (
SELECT
    ppe,
    toLastDayOfMonth(max(makeDate(year, month, 1))) - interval 2 MONTH AS last_measurement_month
FROM ppe_usage_gold FINAL
GROUP BY ppe
), monthly_total_usage AS (
SELECT usage.* from ppe_usage_gold as usage FINAL
join last_read using (ppe)
WHERE makeDate(year, month, 1) >= last_measurement_month
and ppe = 'PPE065221'
)
SELECT * from monthly_total_usage
ORDER BY year, month;


SELECT
    ppe,
    year,
    month,
    energy_usage,
    -- Added the column name 'energy_diff' after AS
    energy_usage - lagInFrame(energy_usage) OVER (
        PARTITION BY ppe
        ORDER BY year ASC, month ASC
    ) AS energy_diff 
FROM ppe_usage_gold FINAL
WHERE makeDate(year, month, 1) >= toStartOfMonth(makeDate(2025, 5, 1)) - INTERVAL 2 MONTH
ORDER BY ppe, year, month;