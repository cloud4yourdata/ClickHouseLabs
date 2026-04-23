CREATE DATABASE IF NOT EXISTS eniges_samples;
USE eniges_samples;

DROP TABLE IF EXISTS mergetree_table;
CREATE TABLE mergetree_table
(
    `id` UInt32,
    `value` UInt64
)
ENGINE = MergeTree
ORDER BY id;

INSERT INTO mergetree_table VALUES (1, 100), (2, 200), (3, 300);

SELECT *
FROM mergetree_table;

INSERT INTO mergetree_table VALUES (1, 100), (20, 200), (30, 300);

SELECT *
FROM mergetree_table;

----
DROP TABLE IF EXISTS replacing_mergetree_table;
CREATE TABLE replacing_mergetree_table
(
    id UInt32,
    value UInt64
)   
ENGINE = ReplacingMergeTree()
ORDER BY id;

INSERT INTO replacing_mergetree_table VALUES (1, 100), (2, 200), (3, 300);

select *
from replacing_mergetree_table;

INSERT INTO replacing_mergetree_table VALUES (1, 1000), (20, 200), (30, 300);
-----

DROP TABLE IF EXISTS collapsing_mergetree_table
CREATE TABLE collapsing_mergetree_table
(
    `id` UInt32,
    `value` UInt64,
    `sign` Int8
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY id;

INSERT INTO collapsing_mergetree_table VALUES (1, 100, 1), (2, 200, 1), (3, 300, 1);

SELECT *
FROM collapsing_mergetree_table;


INSERT INTO collapsing_mergetree_table(id,sign) VALUES (2,-1);

SELECT *
FROM collapsing_mergetree_table;

SELECT *
FROM collapsing_mergetree_table
FINAL;
---------------------------
DROP TABLE IF EXISTS coalescing_mergetree_table
CREATE TABLE coalescing_mergetree_table
(
    `id` UInt32,
    `value1` Nullable(UInt64),
    `value2` Nullable(UInt64),
    `value3` Nullable(UInt64)
)
ENGINE = CoalescingMergeTree
ORDER BY id

insert into coalescing_mergetree_table values (1,NULL,200,NULL),(2,100,NULL,300),(3,NULL,NULL,400);

SELECT *
FROM coalescing_mergetree_table;

insert into coalescing_mergetree_table values (3,200,500,NULL);

SELECT *
FROM coalescing_mergetree_table FINAL;

------
DROP TABLE IF EXISTS summing_mergetree_table;
CREATE TABLE summing_mergetree_table
(
    `id` UInt32,
    `value` UInt64
)
engine = SummingMergeTree() 
order by id;
----
insert into summing_mergetree_table values (1,100),(2,200),(3,300);
----
insert into summing_mergetree_table values (1,100),(2,200),(3,300);

select *
from summing_mergetree_table;

---------------------------
DROP TABLE IF EXISTS aggregating_mergetree_source_table;
CREATE TABLE aggregating_mergetree_source_table
(
    `id` UInt32,
    `value` UInt64
)
ENGINE = MergeTree
ORDER BY id;
---
DROP TABLE IF EXISTS aggregating_mergetree_table;
CREATE TABLE aggregating_mergetree_table
(
    `id` UInt32,
    avg_value AggregateFunction(avg, UInt64)
)
ENGINE = AggregatingMergeTree()
ORDER BY id;

DROP VIEW IF EXISTS aggregating_mergetree_mv;

CREATE MATERIALIZED VIEW aggregating_mergetree_mv
TO aggregating_mergetree_table AS
SELECT
    id,
    avgState(value) AS avg_value
FROM aggregating_mergetree_source_table
GROUP BY id;
---
CREATE TABLE aggregating_mergetree_source_table_sink
(
    `id` UInt32,
    `value` UInt64
)
ENGINE = MergeTree()
ORDER BY id;

DROP VIEW IF EXISTS aggregating_mergetree_sink_mv;

CREATE MATERIALIZED VIEW aggregating_mergetree_sink_mv
TO aggregating_mergetree_source_table_sink AS
SELECT
    id,
    value   
FROM aggregating_mergetree_source_table;

------------------
INSERT INTO aggregating_mergetree_source_table VALUES (1,100),(2,200),(3,300),(1,400),(2,500);
----
SELECT * FROM aggregating_mergetree_source_table;

SELECT * FROM aggregating_mergetree_source_table_sink;

SELECT * FROM aggregating_mergetree_table;

SELECT id, avgMerge(avg_value) AS average_value
FROM aggregating_mergetree_table
GROUP BY id;
-------------------

DROP TABLE IF EXISTS replacing_mergetree_table_mw_agg;
CREATE TABLE replacing_mergetree_table_mw_agg
(
    id UInt32,
    batch_id UInt32,
    value UInt64
)   
ENGINE = ReplacingMergeTree()
ORDER BY id;

DROP TABLE IF EXISTS replacing_mergetree_table_mw_agg_sink;
CREATE TABLE replacing_mergetree_table_mw_agg_sink
(
    id UInt32,
    batch_id UInt32,
    value UInt64
)
engine = MergeTree() 
order by id;

DROP VIEW IF EXISTS replacing_mergetree_mw_agg_mv_mergetree;

CREATE MATERIALIZED VIEW replacing_mergetree_mw_agg_mv_mergetree
TO replacing_mergetree_table_mw_agg_sink AS     
SELECT
    id,
    batch_id,
    value
FROM replacing_mergetree_table_mw_agg;

--
DROP TABLE IF EXISTS replacing_mergetree_table_mw_agg_mergetree;

CREATE TABLE replacing_mergetree_table_mw_agg_mergetree
(
    id UInt32,
    max_batch_id  SimpleAggregateFunction(max,UInt32),
    avg_value AggregateFunction(avg,UInt64)
)
engine = AggregatingMergeTree()
order by id;


DROP VIEW IF EXISTS replacing_mergetree_mw_agg_mv_agg;
CREATE MATERIALIZED VIEW replacing_mergetree_mw_agg_mv_agg
TO replacing_mergetree_table_mw_agg_mergetree AS    
SELECT
    id,
    maxSimpleState(batch_id) AS max_batch_id,
    avgState(value) AS avg_value
FROM replacing_mergetree_table_mw_agg
GROUP BY id;

insert into replacing_mergetree_table_mw_agg values (1,1,100),(2,1,200),(3,1,300)

insert into replacing_mergetree_table_mw_agg values (1,2,1000),(2,2,200),(3,2,3000)


SELECT
    detectTonality('Good dog'),
    detectTonality('Bad dog'),
    detectTonality('Do nothing')
;

CREATE TABLE UAct
(
    UserID UInt64,
    PageViews UInt8,
    Duration UInt8,
    Sign Int8,
    Version UInt8
)
ENGINE = VersionedCollapsingMergeTree(Sign, Version)
ORDER BY UserID