use examples;
CREATE OR REPLACE TABLE dbpedia
(
    `id` String,
    `title` String,
    `text` String,
    `vector` Array(Float32) CODEC(NONE),
    INDEX vector_idx vector TYPE vector_similarity('hnsw', 'L2Distance', 1536) GRANULARITY 100000000
)
ENGINE = MergeTree
ORDER BY id