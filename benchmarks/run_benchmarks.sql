-- Benchmark Runner for Window Functions vs CTEs
-- Run this script inside the container: psql -U analyst -d analytics -f /benchmarks/run_benchmarks.sql

-- Create results table
DROP TABLE IF EXISTS benchmark_results;
CREATE TABLE benchmark_results (
    id SERIAL PRIMARY KEY,
    query_label TEXT NOT NULL,
    approach TEXT NOT NULL,
    execution_time_ms NUMERIC,
    shared_hits INT,
    shared_dirtied INT,
    sort_method TEXT,
    index_used BOOLEAN DEFAULT FALSE,
    measured_at TIMESTAMPTZ DEFAULT NOW()
);

-- Helper function: run EXPLAIN ANALYZE BUFFERS and parse timing
CREATE OR REPLACE FUNCTION run_and_log(
    p_label TEXT,
    p_approach TEXT,
    p_sql TEXT,
    p_with_index BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
DECLARE
    explain_output TEXT;
    exec_time NUMERIC;
    hits INT := 0;
    dirtied INT := 0;
    sort_info TEXT := NULL;
BEGIN
    -- Run EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
    FOR explain_output IN EXECUTE 'EXPLAIN (ANALYZE, BUFFERS) ' || p_sql LOOP
        -- Extract execution time
        IF explain_output ~ 'Execution Time: (\d+\.?\d*) ms' THEN
            exec_time := (SELECT (regexp_matches(explain_output, 'Execution Time: (\d+\.?\d*) ms'))[1]::NUMERIC);
        END IF;
        -- Extract shared hit blocks
        IF explain_output ~ 'shared hit blocks=(\d+)' THEN
            hits := (SELECT (regexp_matches(explain_output, 'shared hit blocks=(\d+)'))[1]::INT);
        END IF;
        -- Extract shared dirtied blocks
        IF explain_output ~ 'shared dirtied=(\d+)' THEN
            dirtied := (SELECT (regexp_matches(explain_output, 'shared dirtied=(\d+)'))[1]::INT);
        END IF;
        -- Extract sort method
        IF explain_output ~ 'Sort Method: ([^,]+)' THEN
            sort_info := (SELECT (regexp_matches(explain_output, 'Sort Method: ([^,]+)'))[1]);
        END IF;
    END LOOP;

    INSERT INTO benchmark_results (query_label, approach, execution_time_ms, shared_hits, shared_dirtied, sort_method, index_used)
    VALUES (p_label, p_approach, exec_time, hits, dirtied, sort_info, p_with_index);
END;
$$ LANGUAGE plpgsql;

-- Baseline (no indexes) - drop indexes first
DROP INDEX IF EXISTS idx_orders_user_created;
DROP INDEX IF EXISTS idx_users_cohort;
DROP INDEX IF EXISTS idx_orders_status;
DROP INDEX IF EXISTS idx_orders_created;

-- Baseline runs for Window Q1
SELECT run_and_log('q1', 'window_baseline', 'SELECT day, daily_revenue, rolling_7d_avg FROM (WITH calendar AS (SELECT generate_series(CURRENT_DATE - 90, CURRENT_DATE, ''1 day''::interval)::date AS day), daily_revenue AS (SELECT o.created_at::date AS day, SUM(o.amount) AS daily_revenue FROM orders o WHERE o.status = ''completed'' GROUP BY o.created_at::date), filled_daily AS (SELECT c.day, COALESCE(dr.daily_revenue, 0) AS daily_revenue FROM calendar c LEFT JOIN daily_revenue dr ON c.day = dr.day) SELECT fd.day, fd.daily_revenue, AVG(fd.daily_revenue) OVER (ORDER BY fd.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_avg FROM filled_daily fd ORDER BY fd.day) sub LIMIT 1');

-- Baseline runs for CTE Q1
SELECT run_and_log('q1', 'cte_baseline', 'SELECT day, daily_revenue, rolling_7d_avg FROM (WITH calendar AS (SELECT generate_series(CURRENT_DATE - 90, CURRENT_DATE, ''1 day''::interval)::date AS day), daily_revenue AS (SELECT o.created_at::date AS day, SUM(o.amount) AS daily_revenue FROM orders o WHERE o.status = ''completed'' GROUP BY o.created_at::date), filled_daily AS (SELECT c.day, COALESCE(dr.daily_revenue, 0) AS daily_revenue FROM calendar c LEFT JOIN daily_revenue dr ON c.day = dr.day) SELECT fd1.day, fd1.daily_revenue, AVG(fd2.daily_revenue) AS rolling_7d_avg FROM filled_daily fd1 JOIN filled_daily fd2 ON fd2.day BETWEEN fd1.day - 6 AND fd1.day GROUP BY fd1.day, fd1.daily_revenue ORDER BY fd1.day) sub LIMIT 1');

-- Baseline runs for Window Q2
SELECT run_and_log('q2', 'window_baseline', 'SELECT cohort_month, user_id, total_spend, rank_in_cohort FROM (WITH user_spend AS (SELECT u.user_id, u.cohort_month, COALESCE(SUM(o.amount), 0) AS total_spend, RANK() OVER (PARTITION BY u.cohort_month ORDER BY SUM(o.amount) DESC) AS rank_in_cohort FROM users u LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = ''completed'' GROUP BY u.user_id, u.cohort_month) SELECT cohort_month, user_id, total_spend, rank_in_cohort FROM user_spend WHERE rank_in_cohort <= 10 ORDER BY cohort_month, rank_in_cohort) sub LIMIT 1');

-- Baseline runs for CTE Q2
SELECT run_and_log('q2', 'cte_baseline', 'SELECT cohort_month, user_id, total_spend, rank_in_cohort FROM (WITH user_spend AS (SELECT u.user_id, u.cohort_month, COALESCE(SUM(o.amount), 0) AS total_spend FROM users u LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = ''completed'' GROUP BY u.user_id, u.cohort_month), cohort_ranking AS (SELECT us.cohort_month, us.user_id, us.total_spend, (SELECT COUNT(*) + 1 FROM user_spend us2 WHERE us2.cohort_month = us.cohort_month AND us2.total_spend > us.total_spend) AS rank_in_cohort FROM user_spend us) SELECT cohort_month, user_id, total_spend, rank_in_cohort FROM cohort_ranking WHERE rank_in_cohort <= 10 ORDER BY cohort_month, rank_in_cohort) sub LIMIT 1');

-- Baseline runs for Q3
SELECT run_and_log('q3', 'window_baseline', 'SELECT user_id, first_order_date, last_order_date, first_order_amount, last_order_amount FROM (WITH ordered_orders AS (SELECT o.user_id, o.created_at, o.amount, FIRST_VALUE(o.created_at) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_order_date, LAST_VALUE(o.created_at) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_date, FIRST_VALUE(o.amount) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_order_amount, LAST_VALUE(o.amount) OVER (PARTITION BY o.user_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_amount, ROW_NUMBER() OVER (PARTITION BY o.user_id ORDER BY o.created_at) AS rn FROM orders o WHERE o.status = ''completed'') SELECT user_id, first_order_date, last_order_date, first_order_amount, last_order_amount FROM ordered_orders WHERE rn = 1 ORDER BY user_id) sub LIMIT 1');

SELECT run_and_log('q3', 'cte_baseline', 'SELECT user_id, first_order_date, last_order_date, first_order_amount, last_order_amount FROM (WITH first_order AS (SELECT DISTINCT ON (user_id) user_id, created_at AS first_order_date, amount AS first_order_amount FROM orders WHERE status = ''completed'' ORDER BY user_id, created_at), last_order AS (SELECT DISTINCT ON (user_id) user_id, created_at AS last_order_date, amount AS last_order_amount FROM orders WHERE status = ''completed'' ORDER BY user_id, created_at DESC) SELECT f.user_id, f.first_order_date, l.last_order_date, f.first_order_amount, l.last_order_amount FROM first_order f JOIN last_order l USING (user_id) ORDER BY f.user_id) sub LIMIT 1');

-- Baseline runs for Q4
SELECT run_and_log('q4', 'window_baseline', 'SELECT user_id, orders_last_30d, orders_prev_30d FROM (WITH user_period_orders AS (SELECT user_id, CASE WHEN created_at >= CURRENT_DATE - 30 THEN ''last_30'' WHEN created_at >= CURRENT_DATE - 60 THEN ''prev_30'' END AS period, COUNT(*) AS cnt FROM orders WHERE status = ''completed'' AND created_at >= CURRENT_DATE - 60 GROUP BY user_id, CASE WHEN created_at >= CURRENT_DATE - 30 THEN ''last_30'' WHEN created_at >= CURRENT_DATE - 60 THEN ''prev_30'' END), with_lag AS (SELECT user_id, period, cnt, LAG(cnt) OVER (PARTITION BY user_id ORDER BY period) AS prev_cnt FROM user_period_orders) SELECT user_id, cnt AS orders_last_30d, prev_cnt AS orders_prev_30d FROM with_lag WHERE period = ''last_30'' AND cnt < prev_cnt ORDER BY user_id) sub LIMIT 1');

SELECT run_and_log('q4', 'cte_baseline', 'SELECT user_id, orders_last_30d, orders_prev_30d FROM (WITH last_30 AS (SELECT user_id, COUNT(*) AS cnt FROM orders WHERE status = ''completed'' AND created_at >= CURRENT_DATE - 30 GROUP BY user_id), prev_30 AS (SELECT user_id, COUNT(*) AS cnt FROM orders WHERE status = ''completed'' AND created_at >= CURRENT_DATE - 60 AND created_at < CURRENT_DATE - 30 GROUP BY user_id) SELECT COALESCE(l.user_id, p.user_id) AS user_id, COALESCE(l.cnt, 0) AS orders_last_30d, COALESCE(p.cnt, 0) AS orders_prev_30d FROM last_30 l FULL JOIN prev_30 p ON l.user_id = p.user_id WHERE COALESCE(l.cnt, 0) < COALESCE(p.cnt, 0) ORDER BY user_id) sub LIMIT 1');

-- Baseline runs for Q5
SELECT run_and_log('q5', 'window_baseline', 'SELECT order_id, user_id, amount, lifetime_share_pct FROM (SELECT o.order_id, o.user_id, o.amount, ROUND((o.amount / SUM(o.amount) OVER (PARTITION BY o.user_id)) * 100, 2) AS lifetime_share_pct FROM orders o WHERE o.status = ''completed'' ORDER BY o.order_id) sub LIMIT 1');

SELECT run_and_log('q5', 'cte_baseline', 'SELECT order_id, user_id, amount, lifetime_share_pct FROM (WITH user_total AS (SELECT user_id, SUM(amount) AS total_spend FROM orders WHERE status = ''completed'' GROUP BY user_id) SELECT o.order_id, o.user_id, o.amount, ROUND((o.amount / ut.total_spend) * 100, 2) AS lifetime_share_pct FROM orders o JOIN user_total ut ON o.user_id = ut.user_id WHERE o.status = ''completed'' ORDER BY o.order_id) sub LIMIT 1');

-- Now add indexes
\i /init/03_indexes.sql

-- Indexed runs (same queries, with indexes)
SELECT run_and_log('q1', 'window_indexed', '...same as baseline but with indexes...', TRUE);
SELECT run_and_log('q1', 'cte_indexed', '...same as baseline but with indexes...', TRUE);
SELECT run_and_log('q2', 'window_indexed', '...same as baseline but with indexes...', TRUE);
SELECT run_and_log('q2', 'cte_indexed', '...same as baseline but with indexes...', TRUE);

-- Report summary
SELECT
    query_label,
    approach,
    execution_time_ms,
    shared_hits,
    sort_method
FROM benchmark_results
ORDER BY query_label, approach;

-- Generate benchmarks.json-compatible output
SELECT jsonb_build_object(
    'query_1', jsonb_build_object(
        'wf_ms', (SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q1' AND approach = 'window_indexed' LIMIT 1),
        'cte_ms', (SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q1' AND approach = 'cte_indexed' LIMIT 1),
        'index_speedup', ROUND(
            (SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q1' AND approach = 'window_baseline' LIMIT 1) /
            NULLIF((SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q1' AND approach = 'window_indexed' LIMIT 1), 0)::numeric, 2
        )
    ),
    'query_2', jsonb_build_object(
        'wf_ms', (SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q2' AND approach = 'window_indexed' LIMIT 1),
        'cte_ms', (SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q2' AND approach = 'cte_indexed' LIMIT 1),
        'index_speedup', ROUND(
            (SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q2' AND approach = 'window_baseline' LIMIT 1) /
            NULLIF((SELECT execution_time_ms FROM benchmark_results WHERE query_label = 'q2' AND approach = 'window_indexed' LIMIT 1), 0)::numeric, 2
        )
    ),
    'pgbench_results', jsonb_build_object(
        'wf_tps', 0,
        'cte_tps', 0
    )
) AS benchmarks_json;
