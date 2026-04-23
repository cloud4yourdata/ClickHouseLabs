use SQLDayLite2025;
--
SELECT formatReadableQuantity(count()) as total,count() as total_no FROM nyc_taxi_key;
--
SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;

SELECT toDate(pickup_datetime) as day, sum(total_amount) as total_amount
FROM nyc_taxi_key
WHERE toDate(pickup_datetime) >= '2009-03-01' 
AND toDate(pickup_datetime) <= '2009-03-28' 
AND passenger_count > 4
GROUP BY toDate(pickup_datetime);
--
SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;
SELECT *
FROM nyc_taxi_key
WHERE toDate(pickup_datetime) = '2009-02-06' 
AND passenger_count = 4
ORDER BY total_amount DESC
LIMIT 5 FORMAT Vertical;
--
SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;
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
ORDER BY
    year DESC,
    month DESC;
--------------------

SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;
SELECT
    year(toDate(pickup_datetime)) AS year,
    month(toDate(pickup_datetime)) AS month,
    count() AS number_of_tracks,
    avg(total_amount) AS avg_amount,
    sum(total_amount) AS sum_amount
FROM nyc_taxi_key
WHERE year(toDate(pickup_datetime)) = 2009
GROUP BY
    year(toDate(pickup_datetime)),
    month(toDate(pickup_datetime))
ORDER BY
    year DESC,
    month DESC;
-------------------
SELECT count() AS total_records
FROM nyc_taxi_key
WHERE (year(toDate(pickup_datetime)) = 2009) AND (month(toDate(pickup_datetime)) = 2)
---
with cte as 
(
SELECT dictGetString('date_dim_dict', 'day_name',formatDateTime(toDate(pickup_datetime),'%Y%m%d')) as day_name,  sum(total_amount) as total_amount
FROM nyc_taxi_key
WHERE toDate(pickup_datetime) >= '2009-02-01' 
AND toDate(pickup_datetime) <= '2009-02-28' 
GROUP BY  toDate(pickup_datetime)
)
SELECT day_name, sum(total_amount) as total_amount from cte group by day_name order by total_amount desc;