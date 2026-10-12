-- FINAL CLEANING PIPELINE (based on the author's corrected transaction).
-- Run after importing the original CSV into public.raw_superstore_orders.
-- The original first version used NUMERIC(14,3) for profit and was later
-- replaced to preserve up to five decimal places. Only the final version is
-- retained here as the reproducible build.
-- IMPORTANT: Running this script replaces public.clean_superstore_orders.
-- Do not run against a production database or a table with dependencies.
BEGIN;

CREATE TABLE public.clean_superstore_orders_new AS
SELECT
    TRIM(order_id) AS order_id,
    CASE WHEN TRIM(order_date) LIKE '%-%'
        THEN TO_DATE(TRIM(order_date), 'DD-MM-YYYY')
        ELSE TO_DATE(TRIM(order_date), 'DD/MM/YYYY') END AS order_date,
    CASE WHEN TRIM(ship_date) LIKE '%-%'
        THEN TO_DATE(TRIM(ship_date), 'DD-MM-YYYY')
        ELSE TO_DATE(TRIM(ship_date), 'DD/MM/YYYY') END AS ship_date,
    TRIM(ship_mode) AS ship_mode,
    TRIM(customer_name) AS customer_name,
    TRIM(segment) AS segment,
    TRIM(state) AS state,
    TRIM(country) AS country,
    TRIM(market) AS market,
    TRIM(region) AS region,
    TRIM(product_id) AS product_id,
    TRIM(category) AS category,
    TRIM(sub_category) AS sub_category,
    TRIM(product_name) AS product_name,
    REPLACE(TRIM(sales), ',', '')::NUMERIC(18,3) AS sales,
    TRIM(quantity)::INTEGER AS quantity,
    TRIM(discount)::NUMERIC(5,3) AS discount,
    TRIM(profit)::NUMERIC(18,5) AS profit,
    REPLACE(TRIM(shipping_cost), ',', '')::NUMERIC(18,3) AS shipping_cost,
    TRIM(order_priority) AS order_priority,
    TRIM(year)::INTEGER AS year,
    (
        CASE WHEN TRIM(ship_date) LIKE '%-%'
            THEN TO_DATE(TRIM(ship_date), 'DD-MM-YYYY')
            ELSE TO_DATE(TRIM(ship_date), 'DD/MM/YYYY') END
        -
        CASE WHEN TRIM(order_date) LIKE '%-%'
            THEN TO_DATE(TRIM(order_date), 'DD-MM-YYYY')
            ELSE TO_DATE(TRIM(order_date), 'DD/MM/YYYY') END
    ) AS shipping_days
FROM public.raw_superstore_orders;

DO $$
DECLARE
    raw_count BIGINT;
    clean_count BIGINT;
    invalid_shipping BIGINT;
BEGIN
    SELECT COUNT(*) INTO raw_count FROM public.raw_superstore_orders;
    SELECT COUNT(*) INTO clean_count FROM public.clean_superstore_orders_new;
    SELECT COUNT(*) INTO invalid_shipping
    FROM public.clean_superstore_orders_new WHERE shipping_days < 0;
    IF raw_count <> clean_count THEN
        RAISE EXCEPTION 'Nombre de lignes different : raw=%, clean=%', raw_count, clean_count;
    END IF;
    IF invalid_shipping > 0 THEN
        RAISE EXCEPTION '% dates d expedition anterieures aux commandes', invalid_shipping;
    END IF;
END $$;

DROP TABLE IF EXISTS public.clean_superstore_orders;
ALTER TABLE public.clean_superstore_orders_new RENAME TO clean_superstore_orders;
COMMIT;

-- Post-cleaning validation
SELECT
    (SELECT COUNT(*) FROM public.raw_superstore_orders) AS raw_rows,
    (SELECT COUNT(*) FROM public.clean_superstore_orders) AS clean_rows;

SELECT order_id, order_date, ship_date, customer_name, sales,
       quantity, discount, profit, shipping_days
FROM public.clean_superstore_orders LIMIT 10;

SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS total_orders,
       ROUND(SUM(sales), 2) AS total_sales,
       ROUND(SUM(profit), 5) AS total_profit,
       SUM(quantity) AS total_quantity,
       ROUND(AVG(shipping_days), 2) AS avg_shipping_days
FROM public.clean_superstore_orders;

WITH raw_totals AS (
    SELECT SUM(REPLACE(TRIM(sales), ',', '')::NUMERIC) AS total_sales,
           SUM(TRIM(profit)::NUMERIC) AS total_profit,
           SUM(TRIM(quantity)::INTEGER) AS total_quantity
    FROM public.raw_superstore_orders
), clean_totals AS (
    SELECT SUM(sales) AS total_sales, SUM(profit) AS total_profit,
           SUM(quantity) AS total_quantity
    FROM public.clean_superstore_orders
)
SELECT ROUND(r.total_sales-c.total_sales,3) AS sales_difference,
       ROUND(r.total_profit-c.total_profit,3) AS profit_difference,
       r.total_quantity-c.total_quantity AS quantity_difference
FROM raw_totals r CROSS JOIN clean_totals c;

-- Example precision check. A join on (order_id, product_id) can return
-- multiple matches; it is illustrative, not a unique row-by-row validation.
SELECT r.profit AS raw_profit, c.profit AS clean_profit
FROM public.raw_superstore_orders r
JOIN public.clean_superstore_orders c
  ON r.order_id = c.order_id AND r.product_id = c.product_id
WHERE TRIM(r.profit) = '72.31944'
LIMIT 10;
