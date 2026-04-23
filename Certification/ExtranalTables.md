# External Tables
---
[docs](https://clickhouse.com/docs/engines/table-engines#integration-engines)

- s3 [docs](https://clickhouse.com/docs/sql-reference/table-functions/s3)
```sql
SELECT *
FROM s3(
   'https://datasets-documentation.s3.eu-west-3.amazonaws.com/aapl_stock.csv',
   'CSVWithNames'
)
LIMIT 5;
```