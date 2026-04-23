use examples;
CREATE TABLE IF NOT EXISTS ami_raw (
    event_time         DateTime64(3),  -- High-precision timestamp
    device_id          String,         -- Identifier for the device)
    value Float32
)
ENGINE = MergeTree()
ORDER BY (device_id, event_time)
PARTITION BY toYYYYMM(event_time);



INSERT INTO ami_raw
SELECT * EXCEPT _
FROM
(
    SELECT
        *,
        sleep(15) AS _
    FROM loop(view(
WITH last_value AS (
    SELECT
        device_id,
        MAX(value) AS max_value
    FROM ami_raw
    GROUP BY device_id
)
SELECT
now64(3) AS event_time,
concat('AMI', toString(number)) AS device_id,
coalesce(l.max_value, 1000+(rand() % 1000)) + round(randUniform(0.05, 0.75), 4) AS value
FROM numbers(100000) as m 
LEFT JOIN last_value AS l ON l.device_id = concat('AMI', toString(m.number))
    )))

---
INSERT INTO ami_raw(event_time, device_id, value)
SELECT * EXCEPT _
FROM
(
    SELECT
        *
    FROM loop(view(
WITH last_value AS (
    SELECT
        device_id,
        MAX(value) AS max_value
    FROM ami_raw
    GROUP BY device_id
)
SELECT
now64(3) AS event_time,
concat('AMI', toString(number)) AS device_id,
 1000.0 + round(randUniform(0.05, 0.75), 4) AS value,
 sleep(1) AS _
 FROM numbers(1) as m 
)))

SET param_devices = 100;         -- Liczba urządzeń
SET param_interval_s = 900;          -- Interwał w sekundach
SET param_days = 365;               -- Ile dni generujemy
SET param_start_date = '2025-01-01 00:00:00';

SET param_devices = 100;         -- Liczba urządzeń
SET param_interval_s = 900;          -- Interwał w sekundach
SET param_days = 365;               -- Ile dni generujemy
SET param_start_date = '2025-01-01 00:00:00';

INSERT INTO ami_raw(event_time, device_id, value)
SELECT
    toDateTime64('2025-01-01 00:00:00', 3) 
        + interval (number % intervals_per_device * 900) second AS event_time,
    concat('AMI', toString(intDiv(number, intervals_per_device))) AS device_id,
    rand() % 1000
        + ((number % intervals_per_device) * 0.02) 
        + (randCanonical(number) * 0.01) AS value
FROM (
    SELECT 
        number,
        ( 365 * 24 * 3600 ) / 900 AS intervals_per_device
    FROM numbers( 
        100 * (( 365 * 24 * 3600 ) / 900) 
    )
)
---
INSERT INTO ami_raw(event_time, device_id, value)
with devices as 
(
SELECT concat('AMI', toString(number)) AS device_id,
number,
rand() % 1000 AS init_value
FROM numbers(100000)
),times as 
(
 SELECT 
    arrayJoin(
        range(
            toUInt32( toDateTime('2025-01-01 00:00:00')),      
            toUInt32(toDateTime(today() + 1)),  
            15 * 60                             
        )
    ) AS ts_raw,
    toDateTime(ts_raw) AS event_time   
)
select t.event_time,
d.device_id,
d.init_value + (randCanonical(number) * 0.02) AS value
 from devices as d
CROSS JOIN times as t

---

INSERT INTO ami_raw (event_time, device_id, value)
WITH 
    toDateTime('2025-01-01 00:00:00') AS start_date,
    15 * 60 AS interval_seconds,
    devices AS (
        SELECT 
            concat('AMI', toString(number)) AS device_id,
            (rand() % 1000) AS init_value
        FROM numbers(1000)
    ),
    times AS (
        SELECT 
            toDateTime(ts_raw) AS event_time,
            intDiv(ts_raw - toUInt32(start_date), interval_seconds) AS interval_index
        FROM (
            SELECT arrayJoin(
                range(
                    toUInt32(start_date),
                    toUInt32(toDateTime(today() + 1)),
                    interval_seconds
                )
            ) AS ts_raw
        )
    )
SELECT 
    t.event_time,
    d.device_id,
    d.init_value + (t.interval_index * 0.15) + (randCanonical(t.interval_index) * 0.01) AS value
FROM devices AS d
CROSS JOIN times AS t where d.device_id = 'AMI0'