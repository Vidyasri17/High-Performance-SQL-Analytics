WITH relevant_users AS (
    SELECT DISTINCT user_id
    FROM orders
    WHERE status = 'completed' AND created_at >= CURRENT_DATE - 60
),
period_labels AS (
    SELECT 'prev_30' AS period UNION ALL SELECT 'last_30' AS period
),
all_user_periods AS (
    SELECT ru.user_id, pl.period
    FROM relevant_users ru
    CROSS JOIN period_labels pl
),
user_period_orders AS (
    SELECT
        user_id,
        CASE
            WHEN created_at >= CURRENT_DATE - 30 THEN 'last_30'
            ELSE 'prev_30'
        END AS period,
        COUNT(*) AS cnt
    FROM orders
    WHERE status = 'completed'
      AND created_at >= CURRENT_DATE - 60
    GROUP BY user_id,
        CASE
            WHEN created_at >= CURRENT_DATE - 30 THEN 'last_30'
            ELSE 'prev_30'
        END
),
filled_periods AS (
    SELECT
        aup.user_id,
        aup.period,
        COALESCE(upo.cnt, 0) AS cnt
    FROM all_user_periods aup
    LEFT JOIN user_period_orders upo
        ON aup.user_id = upo.user_id AND aup.period = upo.period
),
with_lag AS (
    SELECT
        user_id,
        period,
        cnt,
        LAG(cnt) OVER (PARTITION BY user_id ORDER BY period) AS prev_cnt
    FROM filled_periods
)
SELECT
    user_id,
    cnt AS orders_last_30d,
    prev_cnt AS orders_prev_30d
FROM with_lag
WHERE period = 'last_30'
  AND cnt < prev_cnt
ORDER BY user_id;
