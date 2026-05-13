USE use eniges_samples;

CREATE TABLE IF NOT EXISTS errors_table
(
    `id` UInt32,
    `value` UInt64
)
ENGINE = Memory;

CREATE TABLE IF NOT EXISTS errors_final
(
    `value` UInt64
)
ENGINE = Memory;

CREATE MATERIALIZED VIEW IF NOT EXISTS errors_mv
TO errors_final AS
SELECT value/value AS value
FROM errors_table
