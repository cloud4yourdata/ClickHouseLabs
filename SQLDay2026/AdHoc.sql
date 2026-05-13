CREATE TABLE IF NOT EXISTS ppe_daily
(
    trafo_nr LowCardinality(String),
    ppe String,
    date Date,
    energy_active_total Float64,
)
ENGINE = ReplacingMergeTree
ORDER BY (trafo_nr,date, ppe)

INSERT INTO ppe_daily
SELECT ppe.trafo_nr, ppe.ppe, toDate(ami.measurement_time) AS date, MAX(ami.energy_active_total) AS energy_active_total
FROM ami_silver AS ami
JOIN ppe_ami_dict AS ppe ON ami.device_id = ppe.ami
GROUP BY ppe.trafo_nr, ppe.ppe,date;

CREATE MATERIALIZED VIEW IF NOT EXISTS  ppe_daily_mv
TO ppe_daily AS
SELECT ppe.trafo_nr, ppe.ppe, toDate(ami.measurement_time) AS date, MAX(ami.energy_active_total) AS energy_active_total
FROM ami_silver AS ami
JOIN ppe_ami_dict AS ppe ON ami.device_id = ppe.ami
GROUP BY ppe.trafo_nr, ppe.ppe,date;