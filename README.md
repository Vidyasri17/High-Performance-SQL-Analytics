# High-Performance SQL Analytics

Benchmarking suite comparing **Window Functions** vs **Common Table Expressions (CTEs)** in PostgreSQL 15+.

## Quick Start

```bash
docker-compose up -d           # Start PostgreSQL with auto-seeding
docker exec analytics_benchmark psql -U analyst -d analytics -f /benchmarks/verify.sql
```

## Project Structure

```
├── init/                       # Docker auto-seed scripts (schema → data → indexes)
├── queries/                    # 10 query files (window_*.sql + cte_*.sql)
│   ├── window_q1.sql / cte_q1.sql   # 7-day rolling revenue
│   ├── window_q2.sql / cte_q2.sql   # Cohort spending ranks
│   ├── window_q3.sql / cte_q3.sql   # First/last order per user
│   ├── window_q4.sql / cte_q4.sql   # Customer churn risk
│   ├── window_q5.sql / cte_q5.sql   # Revenue contribution share
│   └── recursive_referrals.sql      # Referral chain depth (WITH RECURSIVE)
├── mv/create_mv.sql            # Materialized view: daily_revenue_stats
├── benchmarks/                  # EXPLAIN ANALYZE, pgbench, verification scripts
└── results/benchmarks.json      # Performance metrics summary
```

## Running Benchmarks

```bash
# EXPLAIN ANALYZE for all 10 query variants
docker exec analytics_benchmark bash /benchmarks/run_benchmarks.sh

# Concurrent load test (10 clients, 60s)
docker exec analytics_benchmark bash /benchmarks/run_pgbench.sh
```

## Database

- **200,000** users with referral chains
- **1,000,000** orders with power-law distribution
- PostgreSQL 15, `analytics` database, user `analyst`
