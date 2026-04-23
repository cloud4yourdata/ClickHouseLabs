CREATE DATABASE IF NOT EXISTS PoC2;
USE PoC2;

CREATE TABLE IF NOT EXISTS bronze_table
(
     key UInt32,
     val UInt32
)
ENGINE = MergeTree
ORDER BY (key);

CREATE TABLE IF NOT EXISTS silver_table
(
     key UInt32,
     val UInt32
)
ENGINE = ReplacingMergeTree
ORDER BY (key);


 CREATE MATERIALIZED VIEW IF NOT EXISTS bronze_to_silver TO silver_table
    AS SELECT
        key,
        val
    FROM bronze_table;

--INSERT INITAL DATA
INSERT INTO bronze_table VALUES (1, 100), (2, 200), (3, 300);

--SELECT DATA
SELECT * FROM silver_table;

INSERT INTO bronze_table VALUES (1, 150), (2, 250);


CREATE TABLE IF NOT EXISTS gold_table
(
     key UInt32,
     val UInt32
)
ENGINE = MergeTree
ORDER BY (key);

CREATE MATERIALIZED VIEW IF NOT EXISTS silver_to_gold TO gold_table
    AS SELECT
        key,
        val
    FROM silver_table FINAL;