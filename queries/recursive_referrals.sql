WITH RECURSIVE top_users AS (
    SELECT user_id
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
    ORDER BY COUNT(*) DESC
    LIMIT 100
),
referral_chain AS (
    SELECT user_id AS original_user, referred_by, user_id AS current_user, 0 AS depth
    FROM users
    WHERE user_id IN (SELECT user_id FROM top_users)
    UNION ALL
    SELECT rc.original_user, u.referred_by, u.user_id, rc.depth + 1
    FROM users u
    JOIN referral_chain rc ON u.user_id = rc.referred_by
)
SELECT
    original_user AS user_id,
    MAX(depth) AS chain_depth
FROM referral_chain
GROUP BY original_user
ORDER BY chain_depth DESC, original_user;
