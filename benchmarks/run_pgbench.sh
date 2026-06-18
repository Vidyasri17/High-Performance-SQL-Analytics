#!/bin/bash
# Concurrent Load Testing with pgbench
# Usage: bash /benchmarks/run_pgbench.sh
# Runs inside the container or via docker exec

set -e

DB_DSN="postgresql://analyst:benchmark_pass@localhost:5432/analytics"
PGUSER="analyst"
PGDB="analytics"

echo "=== pgbench: Window Function Q1 ==="
pgbench -h localhost -U "$PGUSER" -d "$PGDB" \
  -f /benchmarks/pgbench_window_q1.sql \
  -c 10 -T 60 -P 5 2>&1 | tee /results/pgbench_window_q1.txt

echo ""
echo "=== pgbench: CTE Q1 ==="
pgbench -h localhost -U "$PGUSER" -d "$PGDB" \
  -f /benchmarks/pgbench_cte_q1.sql \
  -c 10 -T 60 -P 5 2>&1 | tee /results/pgbench_cte_q1.txt

echo ""
echo "=== pgbench: Window Function Q2 ==="
pgbench -h localhost -U "$PGUSER" -d "$PGDB" \
  -f /benchmarks/pgbench_window_q2.sql \
  -c 10 -T 60 -P 5 2>&1 | tee /results/pgbench_window_q2.txt

echo ""
echo "=== pgbench: CTE Q2 ==="
pgbench -h localhost -U "$PGUSER" -d "$PGDB" \
  -f /benchmarks/pgbench_cte_q2.sql \
  -c 10 -T 60 -P 5 2>&1 | tee /results/pgbench_cte_q2.txt

echo ""
echo "Done. Results saved to /results/pgbench_*.txt"
