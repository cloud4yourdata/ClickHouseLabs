# SQLDay2026 Demo
---
### Prerequisites
- Run WSL Terminal (VS Code)
- Login as a root 
    - ```sudo -i```
- Run clichouse server
    - ```sudo clickhouse start```
- Close root session
    - ```exit```
- Connect to clickhouse
    - ```sudo clickhouse start```
---
### Demo 1
```sql
USE SQLDay2026;
```
```sql
SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;
```
Table info
```sql
SELECT
    formatReadableSize(total_bytes) AS compressed_size,
    formatReadableSize(total_bytes_uncompressed) AS uncompressed_size,
    formatReadableQuantity(total_rows) AS total_rows
FROM system.tables
WHERE name = 'ami_silver'
FORMAT vertical
```
Sample Data
```sql
SELECT *
FROM ami_silver
LIMIT 3
FORMAT Vertical
```
Query 1
```sql
SELECT *
FROM ami_silver
WHERE (device_id = 'AMI-PL-200000000231') AND (toDate(measurement_time) = '2024-05-12')
ORDER BY measurement_time DESC
LIMIT 5
SETTINGS use_query_cache = false;
```
```sql
EXPLAIN indexes = 1 SELECT *
FROM ami_silver
WHERE (device_id = 'AMI-PL-200000000231') AND (toDate(measurement_time) = '2024-05-12')
ORDER BY measurement_time DESC
LIMIT 5
SETTINGS use_query_cache = false;
```

```sql
EXPLAIN indexes = 1
SELECT argMax(measurement_time, energy_active_l1)
FROM ami_silver
WHERE device_id = 'AMI-PL-200000090231'
GROUP BY ALL
 ```
---
### Demo 2
Ingest table
```sql
SHOW CREATE TABLE ami_ingest
```
Ingest table msg count
```sql
SELECT formatReadableQuantity(COUNT()) AS total_msg
FROM ami_ingest
```
Dictionry PostgreSQL
```sql
SHOW CREATE DICTIONARY ppe_ami_dict
```
Meters on trafo TRAFO-171 
```sql
SELECT *
FROM ppe_ami_dict
WHERE trafo_nr = 'TRAFO-171'
```
Sample AMI device
```sql
SELECT * FROM ppe_ami_dict WHERE trafo_nr='TRAFO-171' AND ami='AMI-PL-200000065221';
```
Clean bronze
```sql
TRUNCATE TABLE ami_bronze;
```
Bronze table
```sql
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_bronze;
```
Silver table

```sql
SELECT
    device_id AS ami,
    energy_active_total,
    measurement_time
FROM ami_silver
WHERE device_id = 'AMI-PL-200000065221'
ORDER BY measurement_time DESC
LIMIT 3
```
GOLD STATS PPE065221->AMI-PL-200000065221
```sql
SELECT ppe,year,month, energy_usage_total, last_measurement_time
FROM vw_ppe_stats
WHERE ppe = 'PPE065221'
ORDER BY
    year DESC,
    month DESC
LIMIT 3;
```
INGEST DATA
```sql
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
```
INGEST TABLE
```sql
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_ingest;
```
BRONZE
```sql
SELECT formatReadableQuantity(COUNT()) AS total_msg FROM ami_bronze;
```
BRONZE MSG
```sql
SELECT * FROM ami_bronze LIMIT 2 FORMAT vertical;
```
SILVER
```sql
SELECT
    device_id AS ami,
    energy_active_total,
    measurement_time
FROM ami_silver
WHERE device_id = 'AMI-PL-200000065221'
ORDER BY measurement_time DESC
LIMIT 3
```
GOLD STATS
```sql
SELECT ppe,year,month, energy_usage_total, last_measurement_time
FROM vw_ppe_stats
WHERE ppe = 'PPE065221'
ORDER BY
    year DESC,
    month DESC
LIMIT 3;
```
BILLING
```sql
SELECT *
FROM ppe_billing
WHERE ppe = 'PPE065221'
ORDER BY
    year DESC,
    month DESC
LIMIT 3
```