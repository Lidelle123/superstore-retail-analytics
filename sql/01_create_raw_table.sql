-- Original table definition supplied by project author.
-- Database environment inspection
SELECT current_database() AS database_name, current_user AS connected_user, version() AS postgresql_version;

-- Run only once on a new database.
CREATE TABLE public.raw_superstore_orders (
    order_id TEXT, order_date TEXT, ship_date TEXT, ship_mode TEXT,
    customer_name TEXT, segment TEXT, state TEXT, country TEXT,
    market TEXT, region TEXT, product_id TEXT, category TEXT,
    sub_category TEXT, product_name TEXT, sales TEXT, quantity TEXT,
    discount TEXT, profit TEXT, shipping_cost TEXT,
    order_priority TEXT, year TEXT
);
