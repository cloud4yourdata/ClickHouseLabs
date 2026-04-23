create database if not exists SQLDay2026;
use SQLDay2026;

CREATE TABLE IF NOT EXISTS ami_ingest
(
    `ts` DateTime64(3) DEFAULT now64(),
    `msg` JSON
)
ENGINE = Null;

CREATE TABLE IF NOT EXISTS ami_bronze
(
    `ts` DateTime64(3) DEFAULT now64(),
    `msg` JSON
)
ENGINE = MergeTree
ORDER BY toDate(ts)
PARTITION BY toYYYYMM(ts)
TTL ts + INTERVAL 3 MINUTE;

CREATE TABLE IF NOT EXISTS ami_bronze_ttl_demo
(
    `ts` DateTime64(3) DEFAULT now64(),
    `msg` JSON
)
ENGINE = MergeTree
ORDER BY toDate(ts)
PARTITION BY toYYYYMM(ts)
TTL ts + INTERVAL 3 MONTH;

CREATE MATERIALIZED VIEW IF NOT EXISTS ami_ingest_to_bronze_mv
TO ami_bronze AS
SELECT * FROM ami_ingest;


CREATE TABLE IF NOT EXISTS ami_silver_tmp
(
    `message_id` String,
    `measurement_time` DateTime64(3),
    `device_id` String,
    `energy_active_total` Float64,
    `energy_active_l1` Float64,
    `energy_active_l2` Float64,
    `energy_active_l3` Float64
)
ENGINE = MergeTree
ORDER BY (device_id, toDate(measurement_time));

------
CREATE TABLE IF NOT EXISTS ami_silver
(
    `message_id` String,
    `measurement_time` DateTime64(3),
    `device_id` String,
    `energy_active_total` Float64,
    `energy_active_l1` Float64,
    `energy_active_l2` Float64,
    `energy_active_l3` Float64
)
ENGINE = MergeTree
ORDER BY (device_id, toDate(measurement_time));


CREATE MATERIALIZED VIEW IF NOT EXISTS ami_bronze_to_silver_mv
TO ami_silver AS
SELECT
    CAST(msg.message_header.message_id, 'String') AS message_id,
    parseDateTimeBestEffort(CAST(msg.message_header.timestamp, 'String')) AS measurement_time,
    CAST(msg.device_details.device_id, 'String') AS device_id,
    maxIf(toFloat64(r.value), r.obis_code = '1.8.0') AS energy_active_total,
    maxIf(toFloat64(r.value), r.obis_code = '21.7.0') AS energy_active_l1,
    maxIf(toFloat64(r.value), r.obis_code = '41.7.0') AS energy_active_l2,
    maxIf(toFloat64(r.value), r.obis_code = '61.7.0') AS energy_active_l3
FROM ami_bronze
ARRAY JOIN CAST(msg.readings, 'Array(JSON)') AS r
GROUP BY
    message_id,
    measurement_time,
    device_id;

CREATE DICTIONARY IF NOT EXISTS ppe_ami_dict
(
    ppe String,
    ami String,
    trafo_nr String
)
PRIMARY KEY ppe, ami
SOURCE(POSTGRESQL(PORT 5432 HOST '127.0.0.1' USER 'postgres' PASSWORD 'Monday12' DB 'sqlday2026-ami' TABLE 'ppe_ami' SCHEMA 'public'))
LIFETIME(MIN 0 MAX 300)
LAYOUT(COMPLEX_KEY_HASHED());


CREATE TABLE IF NOT EXISTS ppe_usage_gold
(
    ppe String,
    year UInt32,
    month UInt8,
    energy_usage Float64
)
ENGINE = ReplacingMergeTree()
ORDER BY (ppe, year, month);


CREATE MATERIALIZED VIEW IF NOT EXISTS ami_ppe_usage_silver_to_gold_mv
TO ppe_usage_gold AS
SELECT
    d.ppe,
    year(toDate(measurement_time)) AS year,
    month(toDate(measurement_time)) AS month,
    energy_active_total AS  energy_usage
FROM ami_silver as s
JOIN ppe_ami_dict AS d ON s.device_id = d.ami;

/*existing data insert*/
INSERT INTO ppe_usage_gold
SELECT
    d.ppe,
    year(toDate(measurement_time)) AS year,
    month(toDate(measurement_time)) AS month,
    max(energy_active_total) AS  energy_usage
FROM ami_silver as s
JOIN ppe_ami_dict AS d ON s.device_id = d.ami
GROUP BY
    d.ppe,
    year(toDate(measurement_time)),
    month(toDate(measurement_time));

CREATE TABLE IF NOT EXISTS ppe_billing
(
    ppe String,
    year UInt32,
    month UInt8,
    energy_usage Float64
)ENGINE = ReplacingMergeTree()
ORDER BY (ppe, year, month);

CREATE MATERIALIZED VIEW IF NOT EXISTS ppe_usage_gold_to_billing_mv
REFRESH EVERY 5 MINUTE TO ppe_billing AS
SELECT
    ppe,
    year,
    month,
    energy_usage - lagInFrame(energy_usage) OVER (
        PARTITION BY ppe
        ORDER BY year ASC, month ASC
    ) AS energy_usage 
FROM ppe_usage_gold FINAL
WHERE makeDate(year, month, 1) >= toStartOfMonth(makeDate(2025, 1, 1)) - INTERVAL 2 MONTH;



CREATE TABLE IF NOT EXISTS ppe_stats_gold
(
    ppe String,
    year UInt32,
    month UInt8,
    energy_usage AggregateFunction(max, Float64),
    last_measurement_time AggregateFunction(max, DateTime64(3)),
    avg_energy_usage_l1 AggregateFunction(avg, Float64),
    avg_energy_usage_l2 AggregateFunction(avg, Float64),
    avg_energy_usage_l3 AggregateFunction(avg, Float64),
    min_energy_usage_l1 AggregateFunction(min, Float64),
    min_energy_usage_l2 AggregateFunction(min, Float64),
    min_energy_usage_l3 AggregateFunction(min, Float64),
    min_ts_energy_usage_l1 AggregateFunction(argMin, DateTime64(3), Float64),
    min_ts_energy_usage_l2 AggregateFunction(argMin, DateTime64(3), Float64),
    min_ts_energy_usage_l3 AggregateFunction(argMin, DateTime64(3), Float64),
    max_energy_usage_l1 AggregateFunction(max, Float64),
    max_energy_usage_l2 AggregateFunction(max, Float64),
    max_energy_usage_l3 AggregateFunction(max, Float64),
    max_ts_energy_usage_l1 AggregateFunction(argMax, DateTime64(3), Float64),
    max_ts_energy_usage_l2 AggregateFunction(argMax, DateTime64(3), Float64),
    max_ts_energy_usage_l3 AggregateFunction(argMax, DateTime64(3), Float64)
)
ENGINE = AggregatingMergeTree()
ORDER BY (ppe, year, month);
---
CREATE MATERIALIZED VIEW IF NOT EXISTS ami_ppe_stats_silver_to_gold_mv
TO ppe_stats_gold AS
SELECT
    ppe.ppe,
    toYear(ami.measurement_time) AS year,
    toMonth(ami.measurement_time) AS month,
    maxState(ami.energy_active_total) AS energy_usage,
    maxState(ami.measurement_time) AS last_measurement_time,
    -- Averages
    avgState(ami.energy_active_l1) AS avg_energy_usage_l1,
    avgState(ami.energy_active_l2) AS avg_energy_usage_l2,
    avgState(ami.energy_active_l3) AS avg_energy_usage_l3,
    -- Minimums
    minState(ami.energy_active_l1) AS min_energy_usage_l1,
    minState(ami.energy_active_l2) AS min_energy_usage_l2,
    minState(ami.energy_active_l3) AS min_energy_usage_l3,
    -- Timestamps of Minimums (Using argMinState)
    argMinState(ami.measurement_time, ami.energy_active_l1) AS min_ts_energy_usage_l1,
    argMinState(ami.measurement_time, ami.energy_active_l2) AS min_ts_energy_usage_l2,
    argMinState(ami.measurement_time, ami.energy_active_l3) AS min_ts_energy_usage_l3,
    -- Maximums
    maxState(ami.energy_active_l1) AS max_energy_usage_l1,
    maxState(ami.energy_active_l2) AS max_energy_usage_l2,
    maxState(ami.energy_active_l3) AS max_energy_usage_l3,
    -- Timestamps of Maximums (Using argMaxState)
    argMaxState(ami.measurement_time, ami.energy_active_l1) AS max_ts_energy_usage_l1,
    argMaxState(ami.measurement_time, ami.energy_active_l2) AS max_ts_energy_usage_l2,
    argMaxState(ami.measurement_time, ami.energy_active_l3) AS max_ts_energy_usage_l3
FROM ami_silver AS ami
JOIN ppe_ami_dict AS ppe ON ami.device_id = ppe.ami
GROUP BY 
    ppe, 
    year, 
    month;

--INITIAL DATA
INSERT INTO ppe_stats_gold
SELECT
    ppe.ppe,
    toYear(ami.measurement_time) AS year,
    toMonth(ami.measurement_time) AS month,
    maxState(ami.energy_active_total) AS energy_usage,
    maxState(ami.measurement_time) AS last_measurement_time,
    -- Averages
    avgState(ami.energy_active_l1) AS avg_energy_usage_l1,
    avgState(ami.energy_active_l2) AS avg_energy_usage_l2,
    avgState(ami.energy_active_l3) AS avg_energy_usage_l3,
    -- Minimums
    minState(ami.energy_active_l1) AS min_energy_usage_l1,
    minState(ami.energy_active_l2) AS min_energy_usage_l2,
    minState(ami.energy_active_l3) AS min_energy_usage_l3,
    -- Timestamps of Minimums (Using argMinState)
    argMinState(ami.measurement_time, ami.energy_active_l1) AS min_ts_energy_usage_l1,
    argMinState(ami.measurement_time, ami.energy_active_l2) AS min_ts_energy_usage_l2,
    argMinState(ami.measurement_time, ami.energy_active_l3) AS min_ts_energy_usage_l3,
    -- Maximums
    maxState(ami.energy_active_l1) AS max_energy_usage_l1,
    maxState(ami.energy_active_l2) AS max_energy_usage_l2,
    maxState(ami.energy_active_l3) AS max_energy_usage_l3,
    -- Timestamps of Maximums (Using argMaxState)
    argMaxState(ami.measurement_time, ami.energy_active_l1) AS max_ts_energy_usage_l1,
    argMaxState(ami.measurement_time, ami.energy_active_l2) AS max_ts_energy_usage_l2,
    argMaxState(ami.measurement_time, ami.energy_active_l3) AS max_ts_energy_usage_l3
FROM ami_silver AS ami
JOIN ppe_ami_dict AS ppe ON ami.device_id = ppe.ami
GROUP BY 
    ppe, 
    year, 
    month;


---
CREATE VIEW IF NOT EXISTS vw_ppe_stats AS
SELECT
    ppe,
    year,
    month,
    maxMerge(energy_usage) AS energy_usage_total,
    maxMerge(last_measurement_time) AS last_measurement_time,

    avgMerge(avg_energy_usage_l1) AS avg_l1,
    avgMerge(avg_energy_usage_l2) AS avg_l2,
    avgMerge(avg_energy_usage_l3) AS avg_l3,
    minMerge(min_energy_usage_l1) AS min_l1,
    argMinMerge(min_ts_energy_usage_l1) AS min_l1_time,
    maxMerge(max_energy_usage_l1) AS max_l1,
    argMaxMerge(max_ts_energy_usage_l1) AS max_l1_time,

    minMerge(min_energy_usage_l2) AS min_l2,
    argMinMerge(min_ts_energy_usage_l2) AS min_l2_time,
    maxMerge(max_energy_usage_l2) AS max_l2,
    argMaxMerge(max_ts_energy_usage_l2) AS max_l2_time,

    minMerge(min_energy_usage_l3) AS min_l3,
    argMinMerge(min_ts_energy_usage_l3) AS min_l3_time,
    maxMerge(max_energy_usage_l3) AS max_l3,
    argMaxMerge(max_ts_energy_usage_l3) AS max_l3_time

FROM ppe_stats_gold
GROUP BY
    ppe,
    year,
    month
ORDER BY
    year DESC,
    month DESC;

select 
 d.transformer_station,
 pu.year,
 pu.month,
 sum(pu.energy_usage) as total_energy_usage
 from ppe_usage_gold as pu final 
 join ppe_ami_dict as d on pu.ppe = d.ppe
 where makeDate(year, month, 1) >= toStartOfMonth(today() - INTERVAL 2 MONTH)
group by transformer_station, pu.year, pu.month

---------------------
INSERT INTO ami_ingest (msg) VALUES 
('{
  "message_header": {
    "message_id": "MSG-20260320-99811",
    "timestamp": "2026-03-20T18:00:00Z",
    "source": "AMI-PL-200000001598"
  },
  "device_details": {
    "device_id": "AMI-PL-200000001598",
    "meter_type": "Electricity_3Phase",
    "firmware_version": "v2.4.1"
  },
  "readings": [
    { "obis_code": "1.8.0", "value": 10523.50 },
    { "obis_code": "21.7.0", "value": 0.15 },
    { "obis_code": "41.7.0", "value": 1.5 },
    { "obis_code": "61.7.0", "value": 0.05 }
  ]
}');
INSERT INTO ami_ingest (msg) VALUES 
('{
  "message_header": {
    "message_id": "MSG-20260320-99812",
    "timestamp": "2026-03-20T19:00:00Z",
    "source": "AMI-PL-2012345678"
  },
  "device_details": {
    "device_id": "AMI-PL-2012345678",
    "meter_type": "Electricity_3Phase",
    "firmware_version": "v2.4.1"
  },
  "readings": [
    { "obis_code": "1.8.0", "value": 12453.75 },
    { "obis_code": "21.7.0", "value": 0.18 },
    { "obis_code": "41.7.0", "value": 1.9 },
    { "obis_code": "61.7.0", "value": 0.1 }
  ]
}');

/*
 21.7.0: Instantaneous active power consumed on Phase L1
 41.7.0: Instantaneous active power consumed on Phase L2
 61.7.0: Instantaneous active power consumed on Phase L3
*/
---
SELECT
    CAST(msg.message_header.message_id, 'String') AS message_id,
    parseDateTimeBestEffort(CAST(msg.message_header.timestamp, 'String')) AS event_time,
    CAST(msg.device_details.device_id, 'String') AS device_id,
    maxIf(toFloat64(r.value), r.obis_code = '1.8.0') AS energy_active_total,
    maxIf(toFloat64(r.value), r.obis_code = '21.7.0') AS energy_active_l1,
    maxIf(toFloat64(r.value), r.obis_code = '41.7.0') AS energy_active_l2,
    maxIf(toFloat64(r.value), r.obis_code = '61.7.0') AS energy_active_l3
FROM ami_ingest
ARRAY JOIN CAST(msg.readings, 'Array(JSON)') AS r
GROUP BY
    message_id,
    event_time,
    device_id

---
CREATE MATERIALIZED VIEW IF NOT EXISTS ami_bronze_mv
TO ami_bronze AS
SELECT * FROM ami_ingest;

CREATE MATERIALIZED VIEW IF NOT EXISTS ami_silver_mv
TO ami_silver AS
SELECT
    CAST(msg.message_header.message_id, 'String') AS message_id,
    parseDateTimeBestEffort(CAST(msg.message_header.timestamp, 'String')) AS measurement_time,
    CAST(msg.device_details.device_id, 'String') AS device_id,
    maxIf(toFloat64(r.value), r.obis_code = '1.8.0') AS energy_active_total,
    maxIf(toFloat64(r.value), r.obis_code = '32.7.0') AS voltage_l1,
    maxIf(toFloat64(r.value), r.obis_code = '52.7.0') AS voltage_l2,
    maxIf(toFloat64(r.value), r.obis_code = '72.7.0') AS voltage_l3
FROM ami_bronze
ARRAY JOIN CAST(msg.readings, 'Array(JSON)') AS r
GROUP BY
    message_id,
    measurement_time,
    device_id
-----------------------------
---GOLD
--------------------------
CREATE TABLE IF NOT EXISTS ami_usage_gold_old
(
    ppe String,
    year UInt32,
    month UInt8,
    energy_usage SimpleAggregateFunction(max, UInt64)
)
ENGINE = AggregatingMergeTree()
ORDER BY (ppe, year, month);


CREATE DICTIONARY IF NOT EXISTS ppe_ami_dict
(
    ppe String,
    ami String,
    transformer_station String
)
PRIMARY KEY ppe, ami
SOURCE(POSTGRESQL(PORT 5432 HOST '127.0.0.1' USER 'postgres' PASSWORD 'Monday12' DB 'sqlday2026-ami' TABLE 'ppe_ami' SCHEMA 'public'))
LIFETIME(MIN 0 MAX 300)
LAYOUT(COMPLEX_KEY_HASHED());


SYSTEM RELOAD DICTIONARY ppe_ami_dict;

SELECT 
    name, 
    status, 
    last_exception, 
    loading_start_time, 
    last_successful_update_time 
FROM system.dictionaries 
WHERE name = 'ppe_ami_dict';

CREATE TABLE IF NOT EXISTS ami_usage_gold
(
    ppe String,
    year UInt32,
    month UInt8,
    energy_usage FloFloat64
)
ENGINE = AggregatingMergeTree()
ORDER BY (ppe, year, month);


---MATERIALIZED VIEW
CREATE MATERIALIZED VIEW IF NOT EXISTS ami_usage_gold_mv
TO ami_usage_gold AS
SELECT
    d.ppe,
    year(toDate(measurement_time)) AS year,
    month(toDate(measurement_time)) AS month,
    maxSimpleState(energy_active_total) AS  energy_usage
FROM ami_silver as s
JOIN ppe_ami_dict AS d ON s.device_id = d.ami
GROUP BY
    d.ppe,
    year(toDate(measurement_time)),
    month(toDate(measurement_time));



INSERT INTO ami_usage_gold
SELECT
    d.ppe,
    year(toDate(measurement_time)) AS year,
    month(toDate(measurement_time)) AS month,
    maxSimpleState(energy_active_total) AS  energy_usage
FROM ami_silver as s
JOIN ppe_ami_dict AS d ON s.device_id = d.ami
GROUP BY
    d.ppe,
    year(toDate(measurement_time)),
    month(toDate(measurement_time));
---
CREATE VIEW IF NOT EXISTS vw_ami_usage AS
SELECT 
    ppe, 
    year, 
    month, 
    max(energy_usage) AS energy_usage, 
    avgMerge(avg_voltage_l1) AS avg_voltage_l1, 
    avgMerge(avg_voltage_l2) AS avg_voltage_l2, 
    avgMerge(avg_voltage_l3) AS avg_voltage_l3
FROM ami_usage_gold
GROUP BY
    (ppe, 
    year, 
    month)


---
INSERT INTO ppe_stats_gold
SELECT
    ppe,
    year,
    month,
    maxMerge(energy_usage) AS energy_usage_total,
    maxMerge(last_measurement_time) AS last_measurement_time,

    avgMerge(avg_energy_usage_l1) AS avg_l1,
    avgMerge(avg_energy_usage_l2) AS avg_l2,
    avgMerge(avg_energy_usage_l3) AS avg_l3,
    minMerge(min_energy_usage_l1) AS min_l1,
    argMinMerge(min_ts_energy_usage_l1) AS min_l1_time,
    maxMerge(max_energy_usage_l1) AS max_l1,
    argMaxMerge(max_ts_energy_usage_l1) AS max_l1_time,

    minMerge(min_energy_usage_l2) AS min_l2,
    argMinMerge(min_ts_energy_usage_l2) AS min_l2_time,
    maxMerge(max_energy_usage_l2) AS max_l2,
    argMaxMerge(max_ts_energy_usage_l2) AS max_l2_time,

    minMerge(min_energy_usage_l3) AS min_l3,
    argMinMerge(min_ts_energy_usage_l3) AS min_l3_time,
    maxMerge(max_energy_usage_l3) AS max_l3,
    argMaxMerge(max_ts_energy_usage_l3) AS max_l3_time

FROM ppe_stats_gold
GROUP BY
    ppe,
    year,
    month
ORDER BY
    year DESC,
    month DESC;


    transformer_station

  with cte as 
  (
    select 
    device_id,
    year(toDate(measurement_time)) AS year,
    month(toDate(measurement_time)) AS month,
    max(energy_active_total) AS max_energy_active_total
    from ami_silver group by year,month,device_id
  )
  select d.transformer_station,cte.year,cte.month,max_energy_active_total  from cte 
  join ppe_ami_dict as d on cte.device_id = d.ami


select 
 d.transformer_station,
 pu.year,
 pu.month,
 sum(pu.energy_usage) as total_energy_usage
 from ppe_usage_gold as pu final 
 join ppe_ami_dict as d on pu.ppe = d.ppe
 where makeDate(year, month, 1) >= toStartOfMonth(today() - INTERVAL 2 MONTH)
group by transformer_station, pu.year, pu.month


SELECT
    measurement_time,
    energy_active_total,
    energy_active_l1,
    energy_active_l2,
    energy_active_l3
FROM ami_silver_tmp
WHERE (device_id = 'AMI-PL-200000004598') AND (toDate(measurement_time) = '2024-05-12')
ORDER BY measurement_time ASC
LIMIT 5
FORMAT vertical

SELECT *
FROM ami_silver_tmp
WHERE (device_id = 'AMI-PL-200000001598') AND (measurement_time = '2024-10-01 12:00:00.000')


------------------

SELECT makeDate(year, month, 1) from vw_ppe_usage


  ALTER TABLE ami_silver
    (ADD PROJECTION IF NOT EXISTS ami_silver_max_energy
    (
        SELECT
           max(energy_active_l1) AS max_energy_l1,
           argMax(measurement_time, energy_active_l1) AS max_energy_l1_timstamp,
           max(energy_active_l2) AS max_energy_l2,
           argMax(measurement_time, energy_active_l2) AS max_energy_l2_timstamp,
           max(energy_active_l3) AS max_energy_l3
           argMax(measurement_time, energy_active_l3) AS max_energy_l3_timstamp,

        GROUP BY device_id
        ORDER BY device_id, toDate(measurement_time)
    ))