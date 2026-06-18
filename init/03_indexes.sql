-- Index for orders join and window partitioning
CREATE INDEX IF NOT EXISTS idx_orders_user_created
    ON orders (user_id, created_at);

-- Index for cohort analysis
CREATE INDEX IF NOT EXISTS idx_users_cohort
    ON users (cohort_month);

-- Index for order status filtering (commonly used in queries)
CREATE INDEX IF NOT EXISTS idx_orders_status
    ON orders (status);

-- Index for date-range filtering on orders
CREATE INDEX IF NOT EXISTS idx_orders_created
    ON orders (created_at);

ANALYZE users;
ANALYZE orders;
