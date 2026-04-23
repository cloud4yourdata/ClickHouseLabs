# SQLDay2026 Demo Extra
```sql
SYSTEM DROP QUERY CONDITION CACHE;
SYSTEM DROP QUERY CACHE;
```
Query - ami_silver  4.03 billions avg_energy_active_l1
```sql
SELECT avg(energy_active_l1) AS avg_energy_active_l1
FROM ami_silver
```
Query - ami_silver  4.03 billions avg_energy_active_l2
```sql
SELECT avg(energy_active_l2) AS avg_energy_active_l2
FROM ami_silver
SETTINGS use_query_cache = false;
```
**Why such a big difference in execution time?**
Explain avg_energy_active_l1
```sql
EXPLAIN indexes=1 
SELECT avg(energy_active_l1) AS avg_energy_active_l1
FROM ami_silver
```
Explain avg_energy_active_l1
```sql
EXPLAIN indexes=1 
SELECT avg(energy_active_l2) AS avg_energy_active_l2
FROM ami_silver
```

## How to fix it?
### Projections
```sql
SELECT
    *
FROM system.projections
WHERE database = 'SQLDay2026'
  AND table = 'ami_silver';
```
New Projection for avg(energy_active_l2) AS avg_energy_active_l2
```sql
ALTER TABLE ami_silver
    (ADD PROJECTION IF NOT EXISTS avg_energy_active_l2_proj
    (
        SELECT
        avg(energy_active_l2) AS avg_energy_active_l2
    ))
```
Materialize projection
```sql
ALTER TABLE ami_silver MATERIALIZE PROJECTION avg_energy_active_l2_proj
```
Checking if materialization has finished?
```sql
SELECT *
FROM system.mutations
WHERE database = 'SQLDay2026' 
AND table ='ami_silver' 
AND is_done = 0
FORMAT Vertical
```
Query - ami_silver  4.03 billions avg_energy_active_l2
```sql
SELECT avg(energy_active_l2) AS avg_energy_active_l2
FROM ami_silver
SETTINGS use_query_cache = false;
```
