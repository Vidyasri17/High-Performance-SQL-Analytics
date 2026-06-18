WITH ordered_orders AS (
    SELECT
        o.user_id,
        o.created_at,
        o.amount,
        FIRST_VALUE(o.created_at) OVER (
            PARTITION BY o.user_id
            ORDER BY o.created_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS first_order_date,
        LAST_VALUE(o.created_at) OVER (
            PARTITION BY o.user_id
            ORDER BY o.created_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_order_date,
        FIRST_VALUE(o.amount) OVER (
            PARTITION BY o.user_id
            ORDER BY o.created_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS first_order_amount,
        LAST_VALUE(o.amount) OVER (
            PARTITION BY o.user_id
            ORDER BY o.created_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_order_amount,
        ROW_NUMBER() OVER (
            PARTITION BY o.user_id
            ORDER BY o.created_at
        ) AS rn
    FROM orders o
    WHERE o.status = 'completed'
)
SELECT
    user_id,
    first_order_date,
    last_order_date,
    first_order_amount,
    last_order_amount
FROM ordered_orders
WHERE rn = 1
ORDER BY user_id;
