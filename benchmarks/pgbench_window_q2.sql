-- pgbench script for Window Function Q2 (Cohort Spending Ranks)
SELECT cohort_month, user_id, total_spend, rank_in_cohort
FROM (
    WITH user_spend AS (
        SELECT u.user_id, u.cohort_month,
               COALESCE(SUM(o.amount), 0) AS total_spend,
               RANK() OVER (PARTITION BY u.cohort_month ORDER BY SUM(o.amount) DESC) AS rank_in_cohort
        FROM users u
        LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = 'completed'
        GROUP BY u.user_id, u.cohort_month
    )
    SELECT cohort_month, user_id, total_spend, rank_in_cohort
    FROM user_spend
    WHERE rank_in_cohort <= 10
    ORDER BY cohort_month, rank_in_cohort
) sub
LIMIT 1;
