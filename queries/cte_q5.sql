WITH user_total AS (
    SELECT user_id, SUM(amount) AS total_spend
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
)
SELECT
    o.order_id,
    o.user_id,
    o.amount,
    ROUND((o.amount / ut.total_spend) * 100, 2) AS lifetime_share_pct
FROM orders o
JOIN user_total ut ON o.user_id = ut.user_id
WHERE o.status = 'completed'
ORDER BY o.order_id;
