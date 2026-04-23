use SQLDayLite2025;

--NYC Taxi Demo Data S3
select count() from s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi/clickhouse-academy/nyc_taxi_2009-2010.parquet');
---Local NYC Taxi Demo Data
select count()  from file('nyc_taxi_2009-2010.parquet');
--Sample NYC Taxi Data
select * from file('nyc_taxi_2009-2010.parquet') limit 5 format Vertical;

---CREATE raw empty table
create table if not exists nyc_taxi_raw
order by () Empty
as select * from file('nyc_taxi_2009-2010.parquet');

--SHOW CREATE TABLE nyc_taxi_raw;
show create table nyc_taxi_raw;

---INSERT DATA from local file
insert into nyc_taxi_raw select * from file('nyc_taxi_2009-2010.parquet');

---SHOW sample data
select * from nyc_taxi_raw limit 5 format Vertical;

--Create a new table with a better schema
create table if not exists nyc_taxi_key
(
    vendor_id UInt8,
    pickup_datetime DateTime,
    dropoff_datetime DateTime,
    passenger_count UInt8,
    trip_distance Decimal32(2),
    ratecode_id LowCardinality(String),
    pickup_location_id UInt16,
    dropoff_location_id UInt16,
    payment_type UInt8,
    fare_amount Decimal32(2),
    extra Decimal32(2),
    mta_tax Decimal32(2),
    tip_amount Decimal32(2),
    tolls_amount Decimal32(2),
    total_amount Decimal32(2)
)
primary key (payment_type, passenger_count, pickup_datetime)
order by (payment_type, passenger_count, pickup_datetime, dropoff_datetime);
--SHOW CREATE TABLE nyc_taxi_key;
show create table nyc_taxi_key;

---INSERT DATA from local file
insert into nyc_taxi_key select * from file('nyc_taxi_2009-2010.parquet');


-----------------------------------------------------------------
-----------------------------------------------------------------
--DEMO
-----------------------------------------------------------------
-----------------------------------------------------------------

  {# ALTER TABLE nyc_taxi_key
    (DROP PROJECTION IF EXISTS nyc_taxi_stats_proj); #}

show create table nyc_taxi_raw;
show create table nyc_taxi_key;

----------------------------------------------
--Columns Info
select
    name,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS ratio
from system.columns
where table = 'nyc_taxi_raw'
group BY name;

select
    name,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS ratio
from system.columns
where table = 'nyc_taxi_key'
group BY name;
---TABLE SIZE
select table,
    formatReadableSize(total_bytes) AS total_bytes_f,
    formatReadableSize(total_bytes_uncompressed) AS total_bytes_uncompressed_f,
    total_bytes_uncompressed / total_bytes as ratio
from system.tables
where table in ('nyc_taxi_key', 'nyc_taxi_raw')
and database = 'SQLDayLite2025';
select table,
    formatReadableSize(total_bytes) AS total_bytes_f,
    formatReadableSize(total_bytes_uncompressed) AS total_bytes_uncompressed_f,
    total_bytes_uncompressed / total_bytes as ratio
from system.tables
where table in ('nyc_taxi_key', 'nyc_taxi_raw')
and database = 'SQLDayLite2025';

SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;
----Query Performance 
SELECT sum(total_amount)
FROM nyc_taxi_raw
WHERE passenger_count = 8
FORMAT Vertical
SETTINGS use_query_cache = false;

SELECT sum(total_amount)
FROM nyc_taxi_key
WHERE passenger_count = 8
FORMAT Vertical
SETTINGS use_query_cache = false;

----Query Performance raw


SELECT toDate(pickup_datetime) as day, sum(passenger_count) as total_passengers
FROM nyc_taxi_raw
WHERE toDate(pickup_datetime) >= '2009-02-01' 
AND toDate(pickup_datetime) <= '2009-02-28' 
GROUP BY toDate(pickup_datetime)
SETTINGS use_query_cache = false;

----Query Performance key
SELECT toDate(pickup_datetime) as day, sum(passenger_count) as total_passengers
FROM nyc_taxi_key
WHERE toDate(pickup_datetime) >= '2009-02-01' 
AND toDate(pickup_datetime) <= '2009-02-28' 
GROUP BY toDate(pickup_datetime)
SETTINGS use_query_cache = false;

--EXPLAIN
explain indexes=1
SELECT toDate(pickup_datetime) as day, sum(passenger_count) as total_passengers
FROM nyc_taxi_raw
WHERE toDate(pickup_datetime) >= '2009-02-01' 
AND toDate(pickup_datetime) <= '2009-02-28' 
GROUP BY toDate(pickup_datetime)
SETTINGS use_query_cache = false;

explain indexes=1
SELECT toDate(pickup_datetime) as day, sum(passenger_count) as total_passengers
FROM nyc_taxi_key
WHERE toDate(pickup_datetime) >= '2009-02-01' 
AND toDate(pickup_datetime) <= '2009-02-28' 
GROUP BY toDate(pickup_datetime)
SETTINGS use_query_cache = false;

--AGG



select payment_type,sum(total_amount) as total_amount from nyc_taxi_key 
group by payment_type
order by total_amount desc

SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    count() AS number_of_tracks,
    avg(total_amount) AS avg_amount,
    sum(total_amount) AS sum_amount
FROM nyc_taxi_key
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime))
ORDER BY avg_amount DESC
----
drop table if exists nyc_taxi_stats;
create table nyc_taxi_stats (
    year UInt32,
    month UInt8,
    number_of_tracks AggregateFunction(count, UInt64),
    avg_amount AggregateFunction(avg, Decimal32(2)),
    sum_amount SimpleAggregateFunction(sum,  Decimal(38,2))
)
ENGINE = AggregatingMergeTree() ORDER BY (year,month);

----
drop view if exists nyc_taxi_stats_mv;

CREATE MATERIALIZED VIEW IF NOT EXISTS nyc_taxi_stats_mv 
 TO nyc_taxi_stats
AS SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    countState() AS number_of_tracks,
    avgState(total_amount) AS avg_amount,
    sumSimpleState(total_amount) AS sum_amount
FROM nyc_taxi_key
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime));
--INSERT INITAL DATA
INSERT INTO nyc_taxi_stats SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    countState() AS number_of_tracks,
    avgState(total_amount) AS avg_amount,
    sumSimpleState(total_amount) AS sum_amount
FROM nyc_taxi_key
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime));

--SELECT DATA
SELECT *
FROM nyc_taxi_stats;
--SELECT MERGED DATA
SELECT
    year,
    month,
    countMerge(number_of_tracks) AS number_of_tracks,
    avgMerge(avg_amount) AS avg_amount,
    sum(sum_amount) AS sum_amount  
FROM nyc_taxi_stats
GROUP BY (year, month);


    ----
    SELECT
    vendor_id,
    pickup_datetime + toIntervalYear(1) AS pickup_datetime_new,
    dropoff_datetime + toIntervalYear(1) AS dropoff_datetime_new,
    passenger_count,
    trip_distance,
    ratecode_id,
    pickup_location_id,
    dropoff_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    total_amount
FROM nyc_taxi_key
WHERE (year(toDate(pickup_datetime)) = 2010) AND (month(toDate(pickup_datetime)) < 6)
limit 5 format Vertical;

-----------------------------------
---On demo add 15 year
insert into nyc_taxi_key
    SELECT
    vendor_id,
    pickup_datetime + toIntervalYear(15) AS pickup_datetime_new,
    dropoff_datetime + toIntervalYear(15) AS dropoff_datetime_new,
    passenger_count,
    trip_distance,
    ratecode_id,
    pickup_location_id,
    dropoff_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    total_amount
FROM nyc_taxi_key
WHERE (year(toDate(pickup_datetime)) = 2010));



----Projection
SELECT
    name,
    type,
    sorting_key,
    query
FROM system.projections
WHERE database = 'SQLDayLite2025'
  AND table = 'nyc_taxi_key';

  ---
  ALTER TABLE nyc_taxi_key
    (ADD PROJECTION IF NOT EXISTS nyc_taxi_stats_proj
    (
        SELECT
            year(toDate(pickup_datetime)) AS year,
            month(toDate(pickup_datetime)) AS month,
            count() AS number_of_tracks,
            avg(total_amount) AS avg_amount,
            sum(total_amount) AS sum_amount
        GROUP BY
            year(toDate(pickup_datetime)),
            month(toDate(pickup_datetime))
    ))
  ---
ALTER TABLE nyc_taxi_key MATERIALIZE PROJECTION nyc_taxi_stats_proj;

--SAMPLE PROJECTION QUERY
SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    count() AS number_of_tracks,
    avg(total_amount) AS avg_amount,
    sum(total_amount) AS sum_amount
FROM nyc_taxi_key
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime));
--EXPLAIN
EXPLAIN indexes = 1
SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    count() AS number_of_tracks,
    avg(total_amount) AS avg_amount,
    sum(total_amount) AS sum_amount
FROM nyc_taxi_key
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime)) 
order by year desc, month desc

----------------------------------------------
insert into nyc_taxi_key
    SELECT
    vendor_id,
    pickup_datetime + toIntervalYear(8) AS pickup_datetime_new,
    dropoff_datetime + toIntervalYear(8) AS dropoff_datetime_new,
    passenger_count,
    trip_distance,
    ratecode_id,
    pickup_location_id,
    dropoff_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    total_amount
FROM nyc_taxi_key
WHERE (year(toDate(pickup_datetime)) = 2010) ;


CREATE TABLE agg  
   (                                
       `year` UInt16,               
       `month` UInt8,               
       `number_of_tracks` UInt64,   
       `avg_amount` Float64,        
       `sum_amount` Decimal(38, 2)  
   )                                
   ENGINE = ReplacingMergeTree             
   ORDER BY (year, month)           
   SETTINGS index_granularity = 8192


   CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg
   REFRESH EVERY 30 SECOND APPEND TO agg
   AS 
SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    count() AS number_of_tracks,
    avg(total_amount) AS avg_amount,
    sum(total_amount) AS sum_amount
FROM nyc_taxi_key
--WHERE toDate(pickup_datetime) >= now() - INTERVAL 8 DAY
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime))