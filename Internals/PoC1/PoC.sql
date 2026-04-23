--SETUP
CREATE DATABASE IF NOT EXISTS PoC1;

USE PoC1;

CREATE TABLE IF NOT EXISTS mevents
(
    `sensorid` UInt32,
    `eventtime` DateTime,
    `value` Float32
)
ENGINE = MergeTree
ORDER BY (sensorid, eventtime);
--INSERT
INSERT INTO mevents VALUES (1, '2025-01-01 00:00:00', 100.0),
                           (1, '2025-01-01 01:00:00', 200.0),
                           (2, '2025-01-01 00:30:00', 50.0),
                           (2, '2025-01-01 01:30:00', 150.0);

--QUERY
SELECT *
FROM mevents;

CREATE TABLE IF NOT EXISTS sensor_measures
(
    `sensorid` UInt32,
    `eventtime` DateTime,
    `value` Float32
)
ENGINE = ReplacingMergeTree
ORDER BY (sensorid, eventtime)

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_sensor_measures TO sensor_measures
AS SELECT
    sensorid,
    eventtime,
    value
FROM mevents;

--INSERT INITAL DATA
INSERT INTO sensor_measures SELECT
    sensorid,
    eventtime,
    value
FROM mevents;
--SELECT DATA
SELECT * FROM sensor_measures;

 INSERT INTO mevents VALUES (1, '2025-01-01 01:00:00', 150.0);

 --SELECT MERGED DATA
 SELECT * FROM sensor_measures FINAL;

 CREATE TABLE IF NOT EXISTS sensor_measures_agg
 (
     `sensorid` UInt32,
     `date` Date,
     `min_value` AggregateFunction(min,Float32),
     `max_value` AggregateFunction(max,Float32),
     `avg_value` AggregateFunction(avg,Float32),
     `count_value` AggregateFunction(count,UInt64)
 )
    ENGINE = AggregatingMergeTree
    ORDER BY (sensorid, date);

    CREATE MATERIALIZED VIEW IF NOT EXISTS mv_sensor_measures_agg TO sensor_measures_agg
    AS SELECT
        sensorid,
        toDate(eventtime) AS date,
        minState(value) AS min_value,
        maxState(value) AS max_value,
        avgState(value) AS avg_value,
        countState() AS count_value
        FROM sensor_measures FINAL
        GROUP BY sensorid, toDate(eventtime);

--INSERT INITAL DATA
INSERT INTO sensor_measures_agg 
SELECT
    sensorid,
    toDate(eventtime) AS date,
    minState(value) AS min_value,
    maxState(value) AS max_value,
    avgState(value) AS avg_value,
    countState() AS count_value
FROM sensor_measures
GROUP BY
    sensorid,
    toDate(eventtime);


SELECT
    sensorid,
    date,
    minMerge(min_value) AS min,
    maxMerge(max_value) AS max,
    avgMerge(avg_value) AS avg,
    countMerge(count_value) AS count
FROM sensor_measures_agg
GROUP BY
    sensorid,
    date;

---POTENCIAL SOLUTION

CREATE TABLE IF NOT EXISTS sensor_measures_agg_v2
(
    `sensorid` UInt32,
    `date` Date,
    `min_value` Float32,
    `max_value` Float32,
    `avg_value` Float32,
    `count_value` UInt64
)
   ENGINE = ReplacingMergeTree
   ORDER BY (sensorid, date);

   CREATE MATERIALIZED VIEW IF NOT EXISTS mv_sensor_measures_agg_v2 
   REFRESH EVERY 30 SECOND APPEND TO sensor_measures_agg_v2
   AS SELECT
       sensorid,
       toDate(eventtime) AS date,
       min(value) AS min_value,
       max(value) AS max_value,
       avg(value) AS avg_value,
       count() AS count_value
       FROM sensor_measures FINAL
       WHERE eventtime >= now() - INTERVAL 8 DAY
       GROUP BY sensorid, toDate(eventtime);

       --INSERT INITAL DATA
INSERT INTO sensor_measures_agg_v2 
SELECT
       sensorid,
       toDate(eventtime) AS date,
       min(value) AS min_value,
       max(value) AS max_value,
       avg(value) AS avg_value,
       count() AS count_value
       FROM sensor_measures FINAL
       GROUP BY sensorid, toDate(eventtime);
       
    