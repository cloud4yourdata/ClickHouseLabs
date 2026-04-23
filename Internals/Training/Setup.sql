CREATE DATABASE IF NOT EXISTS training;
USE training;

SET schema_inference_make_columns_nullable = 0, describe_compact_output = 1;

DESCRIBE TABLE s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/pypi/2023/pypi_0_7_34.snappy.parquet')

SELECT *
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/pypi/2023/pypi_0_7_34.snappy.parquet')
LIMIT 10

CREATE TABLE IF NOT EXISTS pypi
(
    `TIMESTAMP` DateTime,
    `COUNTRY_CODE` String,
    `URL` String,
    `PROJECT` String
)
ENGINE = MergeTree
PRIMARY KEY TIMESTAMP;

INSERT INTO pypi
    SELECT TIMESTAMP, COUNTRY_CODE, URL, PROJECT
    FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/pypi/2023/pypi_0_7_34.snappy.parquet');

SELECT
    PROJECT,
    count(*) AS c
FROM pypi
GROUP BY PROJECT
ORDER BY c DESC
LIMIT 100


CREATE TABLE crypto_prices (
   trade_date Date,
   crypto_name LowCardinality(String),
   volume Float32,
   price Float32,
   market_cap Float32,
   change_1_day Float32
)
ENGINE = MergeTree
PRIMARY KEY (crypto_name, trade_date);