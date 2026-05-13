# SQLDay2026  Utils

--------------------------------
Dictionary status


```sql
SELECT 
    name, 
    status, 
    last_exception, 
    loading_start_time, 
    last_successful_update_time 
FROM system.dictionaries 
WHERE name = 'ppe_ami_dict';
```

```sql
SYSTEM RELOAD DICTIONARY ppe_ami_dict;
```
Column info
```sql
SELECT
    name,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS ratio
FROM system.columns
WHERE `table` = 'ami_silver'
GROUP BY name
```
Mutation status
```sql
SELECT
    `table`,
    mutation_id,
    command,
    is_done,
    parts_to_do,
    parts_in_progress_names
FROM system.mutations
WHERE (`table` = 'ami_silver') AND (command LIKE '%MATERIALIZE PROJECTION%')
ORDER BY create_time DESC
```
AGG Functions
```sql
SELECT name 
FROM system.functions 
WHERE is_aggregate = 1 
ORDER BY name;
```