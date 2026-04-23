SET allow_experimental_database_unity_catalog = 1;
--https://dbc-b9b4b97b-d0dc.cloud.databricks.com/
CREATE DATABASE IF NOT EXISTS `sqldaylite2025-dbr`
ENGINE = DataLakeCatalog('https://dbc-b9b4b97b-d0dc.cloud.databricks.com/api/2.1/unity-catalog')
SETTINGS warehouse = 'labs', catalog_credential = '*****', catalog_type = 'unity'

--
172.22.64.1 -IP
172.22.76.56

ALTER USER postgres WITH PASSWORD 'Monday12';

SELECT name FROM postgresql(`localhost:5432`, 'labs', 'test', 'postgres', 'Monday12');

SELECT * FROM postgresql(`localhost:5432`, 'sqlday2026-ami', 'ppe_ami', 'postgres', 'Monday12');
