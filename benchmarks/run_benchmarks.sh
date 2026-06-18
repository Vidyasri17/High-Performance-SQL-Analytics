#!/bin/bash
# Comprehensive Benchmark Runner for Window Functions vs CTEs
# Runs EXPLAIN (ANALYZE, BUFFERS) for all 10 query variants
# Usage: bash /benchmarks/run_benchmarks.sh
# Or:    docker exec analytics_benchmark bash /benchmarks/run_benchmarks.sh

set -e

DB_DSN="postgresql://analyst:benchmark_pass@localhost:5432/analytics"
PGUSER="analyst"
PGDB="analytics"
export PGPASSWORD="benchmark_pass"

RESULTS_FILE="/results/benchmark_timings.txt"

echo "============================================" > $RESULTS_FILE
echo "Window Functions vs CTEs - EXPLAIN ANALYZE" >> $RESULTS_FILE
echo "============================================" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

run_explain() {
    local label="$1"
    local sql_file="$2"

    echo "=== $label ===" >> $RESULTS_FILE
    echo "File: $sql_file" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE

    psql -h localhost -U "$PGUSER" -d "$PGDB" -c "EXPLAIN (ANALYZE, BUFFERS) $(cat $sql_file)" 2>&1 >> $RESULTS_FILE

    echo "" >> $RESULTS_FILE
    echo "---" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
}

echo "Phase 1: Baseline (no explicit indexes)" >> $RESULTS_FILE
echo "==========================================" >> $RESULTS_FILE

# Drop indexes for baseline
psql -h localhost -U "$PGUSER" -d "$PGDB" -c "
DROP INDEX IF EXISTS idx_orders_user_created;
DROP INDEX IF EXISTS idx_users_cohort;
DROP INDEX IF EXISTS idx_orders_status;
DROP INDEX IF EXISTS idx_orders_created;
"

run_explain "Q1 - Window (baseline)" "/queries/window_q1.sql"
run_explain "Q1 - CTE (baseline)" "/queries/cte_q1.sql"
run_explain "Q2 - Window (baseline)" "/queries/window_q2.sql"
run_explain "Q2 - CTE (baseline)" "/queries/cte_q2.sql"
run_explain "Q3 - Window (baseline)" "/queries/window_q3.sql"
run_explain "Q3 - CTE (baseline)" "/queries/cte_q3.sql"
run_explain "Q4 - Window (baseline)" "/queries/window_q4.sql"
run_explain "Q4 - CTE (baseline)" "/queries/cte_q4.sql"
run_explain "Q5 - Window (baseline)" "/queries/window_q5.sql"
run_explain "Q5 - CTE (baseline)" "/queries/cte_q5.sql"

echo "Phase 2: With Indexes" >> $RESULTS_FILE
echo "==========================================" >> $RESULTS_FILE

# Create indexes
psql -h localhost -U "$PGUSER" -d "$PGDB" -f /init/03_indexes.sql

run_explain "Q1 - Window (indexed)" "/queries/window_q1.sql"
run_explain "Q1 - CTE (indexed)" "/queries/cte_q1.sql"
run_explain "Q2 - Window (indexed)" "/queries/window_q2.sql"
run_explain "Q2 - CTE (indexed)" "/queries/cte_q2.sql"

echo "" >> $RESULTS_FILE
echo "=== BENCHMARK COMPLETE ===" >> $RESULTS_FILE

echo "Benchmark results written to $RESULTS_FILE"
cat $RESULTS_FILE | grep -E "(Execution Time|===|File:)"
