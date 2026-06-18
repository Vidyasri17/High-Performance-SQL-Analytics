SELECT
    o.order_id,
    o.user_id,
    o.amount,
    ROUND(
        (o.amount / SUM(o.amount) OVER (PARTITION BY o.user_id)) * 100,
        2
    ) AS lifetime_share_pct
FROM orders o
WHERE o.status = 'completed'
ORDER BY o.order_id;
