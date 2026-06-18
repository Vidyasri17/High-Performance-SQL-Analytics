WITH calendar AS (
    SELECT generate_series(
        CURRENT_DATE - 90,
        CURRENT_DATE,
        '1 day'::interval
    )::date AS day
),
daily_revenue AS (
    SELECT
        o.created_at::date AS day,
        SUM(o.amount) AS daily_revenue
    FROM orders o
    WHERE o.status = 'completed'
    GROUP BY o.created_at::date
),
filled_daily AS (
    SELECT
        c.day,
        COALESCE(dr.daily_revenue, 0) AS daily_revenue
    FROM calendar c
    LEFT JOIN daily_revenue dr ON c.day = dr.day
)
SELECT
    fd.day,
    fd.daily_revenue,
    AVG(fd.daily_revenue) OVER (
        ORDER BY fd.day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_avg
FROM filled_daily fd
ORDER BY fd.day;
