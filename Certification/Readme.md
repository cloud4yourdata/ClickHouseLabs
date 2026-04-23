# Clickhouse Certification
---
## Modeling data
- **Create a new database**
- **Create a new table that satisfies a given criteria or - matches a given file format**
- **Choose efficient data types for columns when appropriate**
- **Define an efficient primary key given a specific criteria of the types of queries that will be executed on a MergeTree table**
- **Define and query a Dictionary**
---

---
## Inserting data
- **Insert a local file into a table**
- **Insert a file from cloud storage into a table**
- **Insert a Parquet, CSV, or TSV file into a table**
- **Provide minor transformations to columns as they are being inserted**
- **Insert data from one table into another**
---
## Analyzing data
---
- **Write a query that satisfies a given criteria**
- **Write a query that uses regular functions. For example:**
    - searches for substrings within a String column
    - [converts a timestamp to the beginning of a time interval](Timestamp.md)
- **Write a query that uses aggregate functions. For example, find the max/min/sum/avg of a column, or the number of unique values, or a given quantile**
- **Use a GROUP BY to compute buckets of aggregated values given a specified timeframe or grouping criteria**
---
 ## Optimizing query performance
---
- **Define a materialized view that stores the result of a non-aggregation query**
- **Define a materialized view that stores the result of an aggregate function using the AggregatingMergeTree or SummingMergeTree table engines**
- **Define a projection on a table**
- **Define a set or minmax skipping index on a table**
---
 ## Deduplication and mutations
---
- **Perform a lightweight delete operation on a table**
- **Implement an efficient upsert strategy using the ReplacingMergeTree table engine**
- **Implement an efficient strategy for performing frequent updates using the CollapsingMergeTree table engine**
---

### Docs
- [Basic time-series operations](https://clickhouse.com/docs/use-cases/time-series/basic-operations#time-series-aggregating-time-bucket)
- [String Searching](https://clickhouse.com/docs/sql-reference/functions/string-search-functions)

