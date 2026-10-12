-- Business analysis queries actually supplied by the project author.
-- Execute independently after 03_create_clean_table.sql.

-- 1. Sales and profit by category
SELECT category, COUNT(*) AS sales_lines,
       COUNT(DISTINCT order_id) AS total_orders,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct,
       SUM(quantity) AS total_quantity
FROM public.clean_superstore_orders
GROUP BY category ORDER BY total_sales DESC;

-- 2. Furniture sub-category performance
SELECT sub_category, COUNT(*) AS sales_lines,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct
FROM public.clean_superstore_orders
WHERE category = 'Furniture'
GROUP BY sub_category ORDER BY total_profit ASC;

-- 3. Table profitability by discount band
SELECT CASE
         WHEN discount=0 THEN '0% - No discount'
         WHEN discount<=0.10 THEN '1-10%'
         WHEN discount<=0.20 THEN '11-20%'
         WHEN discount<=0.30 THEN '21-30%'
         WHEN discount<=0.50 THEN '31-50%'
         ELSE 'Above 50%' END AS discount_band,
       COUNT(*) AS sales_lines,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct
FROM public.clean_superstore_orders
WHERE category='Furniture' AND sub_category='Tables'
GROUP BY 1 ORDER BY MIN(discount);

-- 4. Tables by market
SELECT market, COUNT(*) AS sales_lines,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct
FROM public.clean_superstore_orders
WHERE category='Furniture' AND sub_category='Tables'
GROUP BY market ORDER BY total_profit ASC;

-- 5. Most loss-making table products
SELECT product_id, product_name,
       COUNT(*) AS sales_lines, COUNT(DISTINCT order_id) AS total_orders,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct
FROM public.clean_superstore_orders
WHERE category='Furniture' AND sub_category='Tables'
GROUP BY product_id, product_name
ORDER BY total_profit ASC LIMIT 15;

-- 6. Loss-making table products by market
SELECT market, product_id, product_name,
       COUNT(*) AS sales_lines,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct
FROM public.clean_superstore_orders
WHERE category='Furniture' AND sub_category='Tables'
GROUP BY market, product_id, product_name
HAVING SUM(profit)<0
ORDER BY total_profit ASC LIMIT 20;

-- 7. Profitability status of individual Tables sales lines
SELECT CASE WHEN profit<0 THEN 'Loss-making'
            WHEN profit=0 THEN 'Break-even' ELSE 'Profitable' END AS profitability_status,
       COUNT(*) AS sales_lines,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct
FROM public.clean_superstore_orders
WHERE category='Furniture' AND sub_category='Tables'
GROUP BY CASE WHEN profit<0 THEN 'Loss-making'
              WHEN profit=0 THEN 'Break-even' ELSE 'Profitable' END
ORDER BY total_profit ASC;

-- 8. Discount analysis across all product categories
WITH discount_analysis AS (
    SELECT category,
           CASE WHEN discount=0 THEN '0% - No discount'
                WHEN discount<=0.10 THEN '1-10%'
                WHEN discount<=0.20 THEN '11-20%'
                WHEN discount<=0.30 THEN '21-30%'
                WHEN discount<=0.50 THEN '31-50%'
                ELSE 'Above 50%' END AS discount_band,
           CASE WHEN discount=0 THEN 1 WHEN discount<=0.10 THEN 2
                WHEN discount<=0.20 THEN 3 WHEN discount<=0.30 THEN 4
                WHEN discount<=0.50 THEN 5 ELSE 6 END AS discount_order,
           sales, profit, discount
    FROM public.clean_superstore_orders
)
SELECT category, discount_band, COUNT(*) AS sales_lines,
       ROUND(SUM(sales),2) AS total_sales,
       ROUND(SUM(profit),2) AS total_profit,
       ROUND(100.0*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct,
       ROUND(AVG(discount)*100,2) AS avg_discount_pct
FROM discount_analysis
GROUP BY category, discount_band, discount_order
ORDER BY category, discount_order;
