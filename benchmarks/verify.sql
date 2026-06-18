-- Verification Script
-- Run: psql -U analyst -d analytics -f /benchmarks/verify.sql

-- 1. Verify table existence and structure
SELECT '=== 1. Table Structure ===' AS step;
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name IN ('users', 'orders')
ORDER BY table_name, ordinal_position;

-- 2. Verify foreign keys
SELECT '=== 2. Foreign Keys ===' AS step;
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY';

-- 3. Verify row counts
SELECT '=== 3. Row Counts ===' AS step;
SELECT 'users' AS table_name, count(*) AS row_count FROM users
UNION ALL
SELECT 'orders', count(*) FROM orders;

-- 4. Verify Q1 window vs CTE produce same results
SELECT '=== 4. Q1: Window vs CTE ===' AS step;
WITH window_result AS (
    SELECT day, daily_revenue, ROUND(rolling_7d_avg::numeric, 2) AS rolling_7d_avg
    FROM (
        WITH calendar AS (
            SELECT generate_series(CURRENT_DATE - 90, CURRENT_DATE, '1 day'::interval)::date AS day
        ),
        daily_revenue AS (
            SELECT o.created_at::date AS day, SUM(o.amount) AS daily_revenue
            FROM orders o WHERE o.status = 'completed'
            GROUP BY o.created_at::date
        ),
        filled_daily AS (
            SELECT c.day, COALESCE(dr.daily_revenue, 0) AS daily_revenue
            FROM calendar c LEFT JOIN daily_revenue dr ON c.day = dr.day
        )
        SELECT fd.day, fd.daily_revenue,
               AVG(fd.daily_revenue) OVER (ORDER BY fd.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_avg
        FROM filled_daily fd ORDER BY fd.day
    ) sub
),
cte_result AS (
    SELECT day, daily_revenue, ROUND(rolling_7d_avg::numeric, 2) AS rolling_7d_avg
    FROM (
        WITH calendar AS (
            SELECT generate_series(CURRENT_DATE - 90, CURRENT_DATE, '1 day'::interval)::date AS day
        ),
        daily_revenue AS (
            SELECT o.created_at::date AS day, SUM(o.amount) AS daily_revenue
            FROM orders o WHERE o.status = 'completed'
            GROUP BY o.created_at::date
        ),
        filled_daily AS (
            SELECT c.day, COALESCE(dr.daily_revenue, 0) AS daily_revenue
            FROM calendar c LEFT JOIN daily_revenue dr ON c.day = dr.day
        )
        SELECT fd1.day, fd1.daily_revenue,
               AVG(fd2.daily_revenue) AS rolling_7d_avg
        FROM filled_daily fd1
        JOIN filled_daily fd2 ON fd2.day BETWEEN fd1.day - 6 AND fd1.day
        GROUP BY fd1.day, fd1.daily_revenue ORDER BY fd1.day
    ) sub
)
SELECT 'Q1 results match' AS verification
WHERE (SELECT count(*) FROM window_result) = (SELECT count(*) FROM cte_result)
  AND NOT EXISTS (
    SELECT 1 FROM window_result w
    FULL JOIN cte_result c USING (day)
    WHERE w.daily_revenue IS DISTINCT FROM c.daily_revenue
       OR w.rolling_7d_avg IS DISTINCT FROM c.rolling_7d_avg
  );

-- 5. Verify Q2: Top 10 per cohort
SELECT '=== 5. Q2: Cohort Rankings ===' AS step;
SELECT cohort_month, COUNT(*) AS users_returned, MAX(rank_in_cohort) AS max_rank
FROM (
    WITH user_spend AS (
        SELECT u.user_id, u.cohort_month, COALESCE(SUM(o.amount), 0) AS total_spend,
               RANK() OVER (PARTITION BY u.cohort_month ORDER BY SUM(o.amount) DESC) AS rank_in_cohort
        FROM users u LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = 'completed'
        GROUP BY u.user_id, u.cohort_month
    )
    SELECT cohort_month, user_id, total_spend, rank_in_cohort
    FROM user_spend WHERE rank_in_cohort <= 10
    ORDER BY cohort_month, rank_in_cohort
) sub
GROUP BY cohort_month
ORDER BY cohort_month;

-- 6. Verify Q3: one row per user, no self-joins
SELECT '=== 6. Q3: First/Last Order ===' AS step;
WITH ordered_orders AS (
    SELECT o.user_id, o.created_at, o.amount,
           FIRST_VALUE(o.created_at) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_order_date,
           LAST_VALUE(o.created_at) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_date,
           FIRST_VALUE(o.amount) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_order_amount,
           LAST_VALUE(o.amount) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_amount,
           ROW_NUMBER() OVER (PARTITION BY o.user_id ORDER BY o.created_at) AS rn
    FROM orders o WHERE o.status = 'completed'
)
SELECT 'Q3: ' || count(*) || ' users, unique users: ' || count(DISTINCT user_id) AS verification
FROM ordered_orders WHERE rn = 1;

-- 7. Verify Q4: at-risk users
SELECT '=== 7. Q4: Churn Risk ===' AS step;
SELECT count(*) AS at_risk_users FROM (
    WITH user_period_orders AS (
        SELECT user_id,
               CASE WHEN created_at >= CURRENT_DATE - 30 THEN 'last_30'
                    WHEN created_at >= CURRENT_DATE - 60 THEN 'prev_30'
               END AS period,
               COUNT(*) AS cnt
        FROM orders WHERE status = 'completed' AND created_at >= CURRENT_DATE - 60
        GROUP BY user_id,
            CASE WHEN created_at >= CURRENT_DATE - 30 THEN 'last_30'
                 WHEN created_at >= CURRENT_DATE - 60 THEN 'prev_30' END
    ),
    with_lag AS (
        SELECT user_id, period, cnt,
               LAG(cnt) OVER (PARTITION BY user_id ORDER BY period) AS prev_cnt
        FROM user_period_orders
    )
    SELECT user_id, cnt AS orders_last_30d, prev_cnt AS orders_prev_30d
    FROM with_lag WHERE period = 'last_30' AND cnt < prev_cnt
) sub;

-- 8. Verify Q5: lifetime share sums to ~100 per user
SELECT '=== 8. Q5: Revenue Contribution ===' AS step;
SELECT COUNT(*) AS users_with_valid_total FROM (
    SELECT user_id, ROUND(SUM(lifetime_share_pct), 2) AS total_pct
    FROM (
        SELECT o.order_id, o.user_id, o.amount,
               ROUND((o.amount / SUM(o.amount) OVER (PARTITION BY o.user_id)) * 100, 2) AS lifetime_share_pct
        FROM orders o WHERE o.status = 'completed'
    ) sub
    GROUP BY user_id
    HAVING ABS(SUM(lifetime_share_pct) - 100) > 0.01
) bad;

-- 9. Verify Materialized View
SELECT '=== 9. Materialized View ===' AS step;
SELECT count(*) AS mv_exists FROM pg_matviews WHERE matviewname = 'daily_revenue_stats';

-- 10. Verify indexes
SELECT '=== 10. Indexes ===' AS step;
SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('users', 'orders') ORDER BY tablename, indexname;
