-- pgbench script for CTE Q1 (7-day rolling revenue)
SELECT day, daily_revenue, rolling_7d_avg
FROM (
    WITH calendar AS (
        SELECT generate_series(CURRENT_DATE - 90, CURRENT_DATE, '1 day'::interval)::date AS day
    ),
    daily_revenue AS (
        SELECT o.created_at::date AS day, SUM(o.amount) AS daily_revenue
        FROM orders o
        WHERE o.status = 'completed'
        GROUP BY o.created_at::date
    ),
    filled_daily AS (
        SELECT c.day, COALESCE(dr.daily_revenue, 0) AS daily_revenue
        FROM calendar c
        LEFT JOIN daily_revenue dr ON c.day = dr.day
    )
    SELECT
        fd1.day,
        fd1.daily_revenue,
        AVG(fd2.daily_revenue) AS rolling_7d_avg
    FROM filled_daily fd1
    JOIN filled_daily fd2 ON fd2.day BETWEEN fd1.day - 6 AND fd1.day
    GROUP BY fd1.day, fd1.daily_revenue
    ORDER BY fd1.day
) sub
LIMIT 1;
