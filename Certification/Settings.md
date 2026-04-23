# Timestamp
---
```sql
SET schema_inference_make_columns_nullable = 0, describe_compact_output = 1;
```
**schema_inference_make_columns_nullable** : Controls making inferred types Nullable in schema inference. Possible values:0-3 [docs](https://clickhouse.com/docs/operations/settings/formats#schema_inference_make_columns_nullable)
**asterisk_include_materialized_columns** Include MATERIALIZED columns for wildcard query (SELECT *). [docs](https://clickhouse.com/docs/operations/settings/settings#asterisk_include_materialized_columns)