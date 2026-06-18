-- Seed: 200,000 users with referral chains (DAG, no cycles)
INSERT INTO users (user_id, email, cohort_month, referred_by)
SELECT
    i,
    'user_' || i || '@example.com',
    date_trunc('month', CURRENT_DATE - (random() * 730 || ' days')::interval)::date,
    CASE
        WHEN i > 1 AND random() < 0.35 THEN floor(random() * (i - 1) + 1)::int
        ELSE NULL
    END
FROM generate_series(1, 200000) AS s(i);

ANALYZE users;

-- Seed: 1,000,000 orders with power-law distribution (user_id ∝ random()^3)
INSERT INTO orders (order_id, user_id, product_id, amount, status, created_at, updated_at)
SELECT
    gen_random_uuid(),
    1 + floor(200000 * random() ^ 3)::int,
    1 + floor(random() * 100)::int,
    (random() * 500 + 5)::numeric(10,2),
    CASE
        WHEN random() < 0.70 THEN 'completed'
        WHEN random() < 0.85 THEN 'pending'
        ELSE 'cancelled'
    END,
    NOW() - (random() * 365 || ' days')::interval,
    NOW() - (random() * 365 || ' days')::interval
FROM generate_series(1, 1000000);

ANALYZE orders;

-- Verify row counts
DO $$
BEGIN
    RAISE NOTICE 'Users count: %', (SELECT count(*) FROM users);
    RAISE NOTICE 'Orders count: %', (SELECT count(*) FROM orders);
END $$;
