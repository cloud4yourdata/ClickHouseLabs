CREATE DATABASE IF NOT EXISTS internals;
USE internals;

DROP TABLE IF EXISTS skip_table;
CREATE TABLE skip_table
(
    id UInt64,
    val UInt64
)
engine = MergeTree()
ORDER BY id;

---Generate data
INSERT INTO skip_table SELECT number, intDiv(number,4096) FROM numbers(100000000);

-- Sample Query 
SELECT * FROM skip_table WHERE val IN (125, 700);


ALTER TABLE skip_table ADD INDEX vix val TYPE set(100) GRANULARITY 2;


ALTER TABLE skip_table MATERIALIZE INDEX vix;

EXPLAIN indexes=1
SELECT * FROM skip_table WHERE val IN (125, 700);


Matrix!(&()!#)