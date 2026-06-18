WITH last_30 AS (
    SELECT user_id, COUNT(*) AS cnt
    FROM orders
    WHERE status = 'completed'
      AND created_at >= CURRENT_DATE - 30
    GROUP BY user_id
),
prev_30 AS (
    SELECT user_id, COUNT(*) AS cnt
    FROM orders
    WHERE status = 'completed'
      AND created_at >= CURRENT_DATE - 60
      AND created_at < CURRENT_DATE - 30
    GROUP BY user_id
)
SELECT
    COALESCE(l.user_id, p.user_id) AS user_id,
    COALESCE(l.cnt, 0) AS orders_last_30d,
    COALESCE(p.cnt, 0) AS orders_prev_30d
FROM last_30 l
FULL JOIN prev_30 p ON l.user_id = p.user_id
WHERE COALESCE(l.cnt, 0) < COALESCE(p.cnt, 0)
ORDER BY user_id;
