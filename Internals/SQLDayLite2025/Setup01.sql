
CREATE TABLE IF NOT EXISTS dim_date
(
    `date_key` UInt32,
    `date` Date,
    `full_date_string` String,
    `day_of_week` UInt8,
    `day_name` LowCardinality(String),
    `day_of_month` UInt8,
    `day_of_year` UInt16,
    `week_of_year` UInt8,
    `month` UInt8,
    `month_name` LowCardinality(String),
    `year` UInt16,
    `quarter` UInt8,
    `year_quarter` LowCardinality(String),
    `is_weekend` UInt8
)
ENGINE = MergeTree()
ORDER BY date_key;

--

INSERT INTO dim_date WITH
    toDate('2000-01-01') AS start_date,  -- Start date of your range
    toDate('2032-12-31') AS end_date,    -- End date of your range
    dateDiff('day', start_date, end_date) + 1 AS date_range_days
SELECT
    -- Date Key (YYYYMMDD)
    toInt32(formatDateTime(d, '%Y%m%d')) AS date_key,
    
    -- Date Fields
    d AS date,
    formatDateTime(d, '%Y-%m-%d') AS full_date_string,
    
    -- Day Fields
    toDayOfWeek(d, 1) AS day_of_week, -- 1=Monday, 7=Sunday
    
    -- Correctly calculating Day Name using multiIf()
    multiIf(
        toDayOfWeek(d, 1) = 1, 'Monday',
        toDayOfWeek(d, 1) = 2, 'Tuesday',
        toDayOfWeek(d, 1) = 3, 'Wednesday',
        toDayOfWeek(d, 1) = 4, 'Thursday',
        toDayOfWeek(d, 1) = 5, 'Friday',
        toDayOfWeek(d, 1) = 6, 'Saturday',
        'Sunday'
    ) AS day_name,
    
    toDayOfMonth(d) AS day_of_month,
    toDayOfYear(d) AS day_of_year,
    
    -- Week Fields
    toISOWeek(d) AS week_of_year,
    
    -- Month Fields
    toMonth(d) AS month,
    
    -- Correctly calculating Month Name using multiIf()
    multiIf(
        toMonth(d) = 1, 'January',
        toMonth(d) = 2, 'February',
        toMonth(d) = 3, 'March',
        toMonth(d) = 4, 'April',
        toMonth(d) = 5, 'May',
        toMonth(d) = 6, 'June',
        toMonth(d) = 7, 'July',
        toMonth(d) = 8, 'August',
        toMonth(d) = 9, 'September',
        toMonth(d) = 10, 'October',
        toMonth(d) = 11, 'November',
        'December'
    ) AS month_name,
    
    -- Year and Quarter Fields
    toYear(d) AS year,
    toQuarter(d) AS quarter,
    
    -- Note: %Q is usually safe, but keeping it simple with concat
    concat(toString(toYear(d)), '-Q', toString(toQuarter(d))) AS year_quarter,
    
    -- Flags
    multiIf(toDayOfWeek(d, 1) IN (6, 7), 1, 0) AS is_weekend -- 6=Saturday, 7=Sunday
FROM
(
    -- Generate a sequence of dates
    SELECT addDays(start_date, number) AS d
    FROM numbers(date_range_days)
);


CREATE DICTIONARY date_dim_dict
(
    -- Key (The column you will look up by)
    `date_key` UInt32,
    -- Attributes (The data you want to retrieve)
    `date` Date,
    `day_name` String,
    `month_name` String,
    `year` UInt16,
    `quarter` UInt8,
    `is_weekend` UInt8
)
PRIMARY KEY date_key
SOURCE(
    -- Specify the source table and database
    CLICKHOUSE(
        host 'localhost'
        port 9000
        user 'default'
        password 'Monday12'
        db 'SQLDayLite2025'
        table 'dim_date'
    )
)
LIFETIME(MIN 300 MAX 3600) -- Refresh interval in seconds (5 minutes to 1 hour)
LAYOUT(HASHED()) -- Use the HASH layout for fast key lookups
SETTINGS(
    -- Maximum amount of memory the dictionary can take
    max_structure_size = 104857600 -- 100 MB
);