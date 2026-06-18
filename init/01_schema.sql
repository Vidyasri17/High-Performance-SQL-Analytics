CREATE TABLE IF NOT EXISTS users (
    user_id INT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    cohort_month DATE NOT NULL,
    referred_by INT REFERENCES users(user_id)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id UUID PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id),
    product_id INT NOT NULL,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
