WITH first_order AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        created_at AS first_order_date,
        amount AS first_order_amount
    FROM orders
    WHERE status = 'completed'
    ORDER BY user_id, created_at
),
last_order AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        created_at AS last_order_date,
        amount AS last_order_amount
    FROM orders
    WHERE status = 'completed'
    ORDER BY user_id, created_at DESC
)
SELECT
    f.user_id,
    f.first_order_date,
    l.last_order_date,
    f.first_order_amount,
    l.last_order_amount
FROM first_order f
JOIN last_order l USING (user_id)
ORDER BY f.user_id;
