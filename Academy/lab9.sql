 with cte AS
    (
        SELECT
            toStartOfMonth(p.date) AS month,
            count() AS count,
            any(r.variable) AS variable
        FROM uk_price_paid AS p
        INNER JOIN uk_mortgage_rates AS r ON toStartOfMonth(r.date) = toStartOfMonth(p.date)
        GROUP BY month
    )
select corr(toFloat32(count), toFloat32(variable)) from cte