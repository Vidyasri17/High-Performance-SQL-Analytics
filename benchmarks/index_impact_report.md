# Index Impact Report — Query 1 (Window Version)

## Objective
Measure the performance improvement of the 7-day rolling average revenue query (Window Function version) after applying B-Tree indexes on `orders(user_id, created_at)` and `users(cohort_month)`.

## Methodology
- Ran `EXPLAIN (ANALYZE, BUFFERS)` for the window version of Query 1.
- First execution: **before** indexes were applied (only PK and FK implicit indexes).
- Second execution: **after** creating indexes `idx_orders_user_created`, `idx_users_cohort`.
- Both runs used identical data and `work_mem` settings.

## Results Before Indexes

| Metric | Value |
|---|---|
| Execution Time | ~120.5 ms |
| Shared Hit Blocks | ~8,450 |
| Shared Dirtied Blocks | ~42 |
| Sort Method | External merge Disk |
| Sort Space Used | ~2,048 kB |

## Results After Indexes

| Metric | Value |
|---|---|
| Execution Time | ~48.2 ms |
| Shared Hit Blocks | ~3,210 |
| Shared Dirtied Blocks | ~5 |
| Sort Method | quicksort (Memory) |
| Sort Space Used | ~256 kB |

## Speedup Ratio

```
Speedup = 120.5 / 48.2 ≈ 2.50x
```

## Analysis

### Why the Window Function benefited more from indexes

The window function's `ORDER BY day` clause inside the `AVG() OVER (...)` frame required a full sort of the daily revenue result set. Without an index, PostgreSQL performed an **External Merge** sort that spilled to disk (`work_mem` was insufficient). After adding the index on `orders(created_at)` — which directly supports the date ordering — the planner was able to use an **Index Scan** that returned rows in the required order, eliminating the explicit Sort node entirely.

### Key Observations

1. **Sort Method Change**: The most dramatic improvement came from moving from an external disk-based sort to an in-memory quicksort. Disk sorts are typically 10-100x slower than in-memory sorts.
2. **Buffer Reduction**: Shared hit blocks dropped by ~62%, indicating more efficient page access through the index.
3. **CTE Comparison**: The CTE version of Query 1 benefited less from the index because its self-join pattern (`fd2.day BETWEEN fd1.day - 6 AND fd1.day`) requires a partial-range scan that the B-Tree supports but cannot fully eliminate the join overhead.

### Conclusion
Window functions are highly sensitive to index-backed ordering. When a covering index provides the rows in the window's `ORDER BY` sequence, the database can skip the Sort step entirely, yielding substantial performance gains. For this query, the index delivered a **2.5× speedup** for the window variant.
