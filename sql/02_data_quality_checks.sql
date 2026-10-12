-- Original exploratory and quality-check queries supplied by project author.
-- Exact repeated queries have been consolidated.
-- Note: regex tests do not count NULL values unless explicitly handled.

-- Row and order counts
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS total_orders
FROM public.raw_superstore_orders;

-- Raw sample
SELECT order_id, order_date, customer_name, category, product_name, sales, quantity, profit
FROM public.raw_superstore_orders LIMIT 10;

-- Missing required values
SELECT COUNT(*) AS total_rows,
 COUNT(*) FILTER (WHERE order_id IS NULL OR TRIM(order_id) = '') AS missing_order_id,
 COUNT(*) FILTER (WHERE order_date IS NULL OR TRIM(order_date) = '') AS missing_order_date,
 COUNT(*) FILTER (WHERE product_id IS NULL OR TRIM(product_id) = '') AS missing_product_id,
 COUNT(*) FILTER (WHERE sales IS NULL OR TRIM(sales) = '') AS missing_sales,
 COUNT(*) FILTER (WHERE profit IS NULL OR TRIM(profit) = '') AS missing_profit
FROM public.raw_superstore_orders;

-- Exact-row duplication check
SELECT COUNT(*) AS total_rows,
 COUNT(DISTINCT ROW(order_id, order_date, ship_date, ship_mode,
 customer_name, segment, state, country, market, region, product_id,
 category, sub_category, product_name, sales, quantity, discount,
 profit, shipping_cost, order_priority, year)) AS distinct_rows
FROM public.raw_superstore_orders;

-- Non-standard numeric text (NULLs excluded by original regex logic)
SELECT
 COUNT(*) FILTER (WHERE TRIM(sales) !~ '^-?[0-9]+(\.[0-9]+)?$') AS sales_non_standard,
 COUNT(*) FILTER (WHERE TRIM(profit) !~ '^-?[0-9]+(\.[0-9]+)?$') AS profit_non_standard,
 COUNT(*) FILTER (WHERE TRIM(quantity) !~ '^[0-9]+$') AS quantity_non_standard
FROM public.raw_superstore_orders;

-- Examine non-standard sales strings
SELECT sales, COUNT(*) AS occurrences
FROM public.raw_superstore_orders
WHERE TRIM(sales) !~ '^-?[0-9]+(\.[0-9]+)?$'
GROUP BY sales ORDER BY occurrences DESC LIMIT 20;

-- Identify thousand separators
SELECT COUNT(*) AS total_rows,
 COUNT(*) FILTER (WHERE TRIM(sales) ~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$') AS sales_with_thousands_separator,
 COUNT(*) FILTER (WHERE TRIM(sales) !~ '^-?[0-9]+(\.[0-9]+)?$'
 AND TRIM(sales) !~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$') AS sales_other_formats
FROM public.raw_superstore_orders;

-- Inspect date text and year
SELECT LEFT(TRIM(order_date), 4) AS order_date_example,
 LEFT(TRIM(ship_date), 4) AS ship_date_example, year, COUNT(*) AS occurrences
FROM public.raw_superstore_orders GROUP BY 1,2,3
ORDER BY occurrences DESC LIMIT 15;

-- Date format audit (original query expects slash-separated dates)
SELECT COUNT(*) AS total_rows,
 COUNT(*) FILTER (WHERE TRIM(order_date) !~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$') AS invalid_order_date_format,
 COUNT(*) FILTER (WHERE TRIM(ship_date) !~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$') AS invalid_ship_date_format
FROM public.raw_superstore_orders;

-- Discount bounds; requires discount strings to be castable to NUMERIC
SELECT MIN(discount::NUMERIC) AS min_discount,
 MAX(discount::NUMERIC) AS max_discount,
 COUNT(*) FILTER (WHERE discount::NUMERIC < 0 OR discount::NUMERIC > 1) AS invalid_discount_count
FROM public.raw_superstore_orders;

-- Classify date patterns. Labels are author's original assumptions,
-- not independent proof of day/month order.
SELECT CASE
 WHEN TRIM(order_date) ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 'Slash format: DD/MM/YYYY'
 WHEN TRIM(order_date) ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$' THEN 'Dash format: DD-MM-YYYY'
 WHEN TRIM(order_date) ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$' THEN 'ISO format: YYYY-MM-DD'
 ELSE 'Other format' END AS date_format, COUNT(*) AS total_rows
FROM public.raw_superstore_orders GROUP BY 1 ORDER BY total_rows DESC;

-- Additional date quality checks supplied in the second batch.
-- Original pasted SQL had two SELECT statements concatenated and a LIMIT
-- after a semicolon; these are separated here into valid statements.
SELECT DISTINCT order_date, ship_date, year
FROM public.raw_superstore_orders
WHERE TRIM(order_date) !~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
LIMIT 20;

SELECT CASE WHEN TRIM(order_date) ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 'Slash'
            WHEN TRIM(order_date) ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$' THEN 'Dash'
            ELSE 'Other' END AS order_date_format,
       CASE WHEN TRIM(ship_date) ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 'Slash'
            WHEN TRIM(ship_date) ~ '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$' THEN 'Dash'
            ELSE 'Other' END AS ship_date_format,
       COUNT(*) AS total_rows
FROM public.raw_superstore_orders
GROUP BY 1,2 ORDER BY total_rows DESC;

SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE RIGHT(TRIM(order_date),4)<>TRIM(year)) AS year_mismatch
FROM public.raw_superstore_orders;

WITH date_parts AS (
    SELECT SPLIT_PART(REPLACE(TRIM(order_date),'-','/'),'/',1)::INTEGER AS order_day,
           SPLIT_PART(REPLACE(TRIM(order_date),'-','/'),'/',2)::INTEGER AS order_month,
           SPLIT_PART(REPLACE(TRIM(ship_date),'-','/'),'/',1)::INTEGER AS ship_day,
           SPLIT_PART(REPLACE(TRIM(ship_date),'-','/'),'/',2)::INTEGER AS ship_month
    FROM public.raw_superstore_orders
)
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE order_day NOT BETWEEN 1 AND 31 OR order_month NOT BETWEEN 1 AND 12) AS invalid_order_components,
       COUNT(*) FILTER (WHERE ship_day NOT BETWEEN 1 AND 31 OR ship_month NOT BETWEEN 1 AND 12) AS invalid_ship_components,
       COUNT(*) FILTER (WHERE order_day>12) AS order_day_above_12,
       COUNT(*) FILTER (WHERE ship_day>12) AS ship_day_above_12
FROM date_parts;

WITH normalized AS (
    SELECT REPLACE(TRIM(order_date),'-','/') AS order_text,
           REPLACE(TRIM(ship_date),'-','/') AS ship_text
    FROM public.raw_superstore_orders
), parsed AS (
    SELECT order_text, ship_text,
           TO_DATE(order_text,'DD/MM/YYYY') AS parsed_order_date,
           TO_DATE(ship_text,'DD/MM/YYYY') AS parsed_ship_date
    FROM normalized
)
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE TO_CHAR(parsed_order_date,'FMDD/FMMM/YYYY') <>
         (SPLIT_PART(order_text,'/',1)::INTEGER || '/' || SPLIT_PART(order_text,'/',2)::INTEGER || '/' || SPLIT_PART(order_text,'/',3))) AS invalid_order_dates,
       COUNT(*) FILTER (WHERE TO_CHAR(parsed_ship_date,'FMDD/FMMM/YYYY') <>
         (SPLIT_PART(ship_text,'/',1)::INTEGER || '/' || SPLIT_PART(ship_text,'/',2)::INTEGER || '/' || SPLIT_PART(ship_text,'/',3))) AS invalid_ship_dates
FROM parsed;

WITH parsed_dates AS (
    SELECT TO_DATE(REPLACE(TRIM(order_date),'-','/'),'DD/MM/YYYY') AS order_date_clean,
           TO_DATE(REPLACE(TRIM(ship_date),'-','/'),'DD/MM/YYYY') AS ship_date_clean
    FROM public.raw_superstore_orders
)
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE ship_date_clean<order_date_clean) AS deliveries_before_orders,
       MIN(ship_date_clean-order_date_clean) AS min_delivery_days,
       MAX(ship_date_clean-order_date_clean) AS max_delivery_days,
       ROUND(AVG(ship_date_clean-order_date_clean),2) AS avg_delivery_days
FROM parsed_dates;

-- Check raw profit precision (the motivation for the final NUMERIC(18,5) type).
SELECT profit, LENGTH(SPLIT_PART(TRIM(profit),'.',2)) AS decimal_places
FROM public.raw_superstore_orders
WHERE TRIM(profit) LIKE '%.%'
ORDER BY decimal_places DESC LIMIT 20;

SELECT MAX(LENGTH(SPLIT_PART(TRIM(profit),'.',2))) AS max_decimal_places
FROM public.raw_superstore_orders;
