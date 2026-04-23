create database if not exists examples;
use examples;

create table images 
engine = MergeTree()
order by (size,height,width)
as
select * except(content,url) from 
file('midjourney-messages/*.parquet','Parquet') 
SETTINGS schema_inference_make_columns_nullable=0;

from images
select count() filter (where width>2000) as bigCount,
countIf(width >2000) as bigCount;


select 

 countIf(width >2000) as bigCount,
 countif(width < 340) as smallCount,
 bigCount+smallCount as totalCount
 
 from images;

SELECT
    countDistinct(width),
    countDistinct(height)
FROM images

 FROM images
SELECT countDistinct(width),
       countDistinct(height),
       countDistinctIf(width, channel_id = '989268300473192561') AS widthChannel,
       countDistinctIf(height, channel_id = '989268300473192561') AS heightChannel;

SET schema_inference_make_columns_nullable = 0, describe_compact_output = 1;

CREATE OR REPLACE VIEW salaries
AS SELECT
    * EXCEPT weeklySalary,
    weeklySalary AS salary
FROM file('salaries.csv');

SELECT
    *,
    row_number() OVER () AS rowNum
FROM salaries
LIMIT 10


SELECT
    *,
    rank() OVER (ORDER BY salary ASC) AS rank,
    rank() OVER (PARTITION BY team ORDER BY salary DESC) AS teamRank,
    rank() OVER (PARTITION BY position ORDER BY salary DESC) AS posRank
FROM salaries
LIMIT 10


WITH windowedSalaries AS
    (
        SELECT
            *,
            rank() OVER (ORDER BY salary DESC) AS rank,
            rank() OVER (PARTITION BY team ORDER BY salary DESC) AS teamRank,
            rank() OVER (PARTITION BY position ORDER BY salary DESC) AS posRank
        FROM salaries
        ORDER BY salary DESC
    )
SELECT
    player,
    position,
    salary,
    bar(salary, 0, (
        SELECT max(salary)
        FROM windowedSalaries
        LIMIT 1
    ), 10) AS plot,
    teamRank,
    posRank,
    rank
FROM windowedSalaries
WHERE team LIKE '%Claireberg Vikings%'
LIMIT 15;

SELECT
    player,
    salary,
    bar(salary, 0, (
        SELECT max(salary)
        FROM salaries
        WHERE team LIKE '%Claireberg Vikings%'
    ), 10) AS bar
FROM salaries
WHERE team LIKE '%Claireberg Vikings%'
ORDER BY salary DESC


SELECT
    player,
    team,
    position AS pos,
    salary,
    max(salary) OVER (PARTITION BY position) AS max,
    salary - max AS diff
FROM salaries
ORDER BY diff ASC
LIMIT 10

SELECT
    player,
    team,
    salary,
    round(avg(salary) OVER (PARTITION BY team), 0) AS avg,
    round(salary - avg) AS avgDiff,
    round(median(salary) OVER (PARTITION BY team), 0) AS med,
    round(salary - med) AS medDiff
FROM salaries
ORDER BY avgDiff ASC
LIMIT 10


SELECT
    player,
    team,
    salary,
    round(avg(salary) OVER teamPartition , 0) AS avg,
    round(salary - avg) AS avgDiff,
    round(median(salary) OVER teamPartition, 0) AS med,
    round(salary - med) AS medDiff
FROM salaries
WINDOW teamPartition AS (PARTITION BY team)
ORDER BY avgDiff ASC
LIMIT 10

with salaryDist as 
(
    SELECT
        player,team,position,salary,
        groupArray(salary) OVER (PARTITION BY team,position) as distribution
    FROM salaries
    order by team,position,salary desc
)
select * except(team) replace(arraySort(distribution) as distribution) from salaryDist
where team  LIKE '%Claireberg Vikings%' AND position = 'M'
FORMAT Vertical;

SELECT map('ClickHouse', 1, 'ClickBench', 2)


WITH values AS
    (
        SELECT map('ClickHouse', 3) AS value
        UNION ALL
        SELECT map('ClickBench', 3, 'ClickHouse', 2)
    )
SELECT avgMap(value)
FROM values


CREATE TABLE wikistat
(
    `time` DateTime,
    `project` String,
    `subproject` String,
    `path` String,
    `hits` UInt64
)
ENGINE = MergeTree
ORDER BY (time);

INSERT INTO wikistat 
SELECT *
FROM s3('https://ClickHouse-public-datasets.s3.amazonaws.com/wikistat/partitioned/wikistat*.native.zst') 
LIMIT 1e9;

/**Time functions**/
SELECT
    toDate(time) AS date,
    sum(hits) AS hits
FROM wikistat
GROUP BY ALL
ORDER BY date ASC
LIMIT 5;

SELECT
    toDate(time) AS date,
    sum(hits) AS hits
FROM wikistat
WHERE date(time) = '2015-07-01'
GROUP BY ALL
ORDER BY date ASC
LIMIT 5;

SELECT
    toStartOfHour(time) AS hour,
    sum(hits) AS hits
FROM wikistat
WHERE CAST(time, 'date') = '2015-07-01'
GROUP BY ALL
ORDER BY hour ASC
LIMIT 5;

SELECT
    toStartOfInterval(time, toIntervalHour(4)) AS hour,
    sum(hits) AS hits
FROM wikistat
WHERE CAST(time, 'date') = '2015-07-01'
GROUP BY ALL
ORDER BY hour ASC
LIMIT 5

SELECT
    toStartOfHour(time) AS hour,
    sum(hits) AS hits
FROM wikistat
WHERE (CAST(time, 'date') = '2015-07-02') AND (project = 'ast') AND (subproject = 'm')
GROUP BY ALL
ORDER BY hour ASC;

SELECT
    toStartOfHour(time) AS hour,
    sum(hits) AS hits
FROM wikistat
WHERE (CAST(time, 'date') = '2015-07-02') AND (project = 'ast') AND (subproject = 'm')
GROUP BY ALL
ORDER BY hour ASC WITH FILL STEP toIntervalHour(1)

SELECT
    dateDiff('day', toDateTime('2015-05-01 18:00:00'), time) AS day,
    sum(hits) AS hits
FROM wikistat
GROUP BY ALL
ORDER BY day ASC
LIMIT 5

SELECT
    toDate(time) AS day,
    sum(hits) AS h,
    lagInFrame(h) OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS p,
    h - p AS trend
FROM wikistat
WHERE path = '"Weird_Al"_Yankovic'
GROUP BY ALL
LIMIT 10

SELECT
    toDate(time) AS day,
    sum(hits) AS h,
    sum(h) OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND 0 FOLLOWING) AS c,
    bar(c, 0, 50000, 25) AS b
FROM wikistat
WHERE path = '"Weird_Al"_Yankovic'
GROUP BY ALL
ORDER BY day ASC
LIMIT 10

SELECT
    toStartOfHour(time) AS time,
    sum(hits) AS hits,
    round(hits / (60 * 60), 2) AS rate,
    bar(rate * 10, 0, max(rate * 10) OVER (), 25) AS b
FROM wikistat
WHERE path = '"Weird_Al"_Yankovic'
GROUP BY time
LIMIT 10;

WITH histogram(10)(hits) AS hist
SELECT
    round(arrayJoin(hist).1) AS lowerBound,
    round(arrayJoin(hist).2) AS upperBound,
    arrayJoin(hist).3 AS count,
    bar(count, 0, max(count) OVER (), 20) AS b
FROM
(
    SELECT
        path,
        sum(hits) AS hits
    FROM wikistat
    WHERE date(time) = '2015-06-15'
    GROUP BY path
    HAVING hits > 10000
);