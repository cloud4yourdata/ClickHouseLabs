use examples;

SELECT *
FROM loop(numbers(3))
LIMIT 10
FORMAT PrettyCompact;

select *, sleep(2) as _ from loop(view(SELECT
    team,
    sum(salary) AS s,
    now() AS ts
FROM salaries
GROUP BY ALL
LIMIT 5))
FORMAT PrettyCompact;

SELECT
    *,
    sleep(1)
FROM loop(view(
    SELECT
        toStartOfInterval(time, toIntervalHour(4)) AS hour,
        sum(hits) AS hits,
        now() AS ts
    FROM wikistat
    WHERE CAST(time, 'date') = '2015-07-01'
    GROUP BY ALL
    ORDER BY hour ASC
    LIMIT 5
))
LIMIT 1;

CREATE TABLE IF NOT EXISTS device_telemetry (
    event_time         DateTime64(3),  -- High-precision timestamp
    device_id          String,         -- Identifier for the device
    location_id        UInt8,          -- Grouping for the device (e.g., location, factory line)
    temperature_c      Float32,        -- Metric 1: Temperature in Celsius
    pressure_pa        UInt32,         -- Metric 2: Pressure in Pascals
    status_code        Enum8('online' = 1, 'offline' = 0), -- Device status
    battery_level      UInt8           -- Metric 3: Battery percentage
)
ENGINE = MergeTree()
ORDER BY (device_id, event_time)
PARTITION BY toYYYYMM(event_time);
INSERT INTO device_telemetry
SELECT * EXCEPT _
FROM
(
    SELECT
        *,
        sleep(1) AS _
    FROM loop(view(
        SELECT
            toDateTime64((now() - toIntervalDay(7)) + (number * (((7 * 24) * 3600) / 100000)), 3) AS event_time,
            concat('device_', toString(rand() % 10)) AS device_id,
            (rand() % 5) + 1 AS location_id,
            15. + ((rand() / 4294967295.) * 20.) AS temperature_c,
            100000 + (rand() % 10000) AS pressure_pa,
            if((rand() % 100) < 95, 'online', 'offline') AS status_code,
            10 + (rand() % 91) AS battery_level
        FROM numbers(100000)
    ))
)

