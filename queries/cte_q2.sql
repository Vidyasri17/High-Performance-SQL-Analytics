WITH user_spend AS (
    SELECT
        u.user_id,
        u.cohort_month,
        COALESCE(SUM(o.amount), 0) AS total_spend
    FROM users u
    LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = 'completed'
    GROUP BY u.user_id, u.cohort_month
),
cohort_ranking AS (
    SELECT
        us.cohort_month,
        us.user_id,
        us.total_spend,
        (
            SELECT COUNT(*) + 1
            FROM user_spend us2
            WHERE us2.cohort_month = us.cohort_month
              AND us2.total_spend > us.total_spend
        ) AS rank_in_cohort
    FROM user_spend us
)
SELECT
    cohort_month,
    user_id,
    total_spend,
    rank_in_cohort
FROM cohort_ranking
WHERE rank_in_cohort <= 10
ORDER BY cohort_month, rank_in_cohort;
