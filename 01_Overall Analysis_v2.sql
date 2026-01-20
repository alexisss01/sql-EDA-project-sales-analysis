-- Overall Analysis (v2)
-- Purpose: Business overview EDA using existing Gold layer tables/views.

-----------------------------------------------------------------------
-- 0) Quick sanity checks
-----------------------------------------------------------------------
SELECT
    COUNT(*) AS row_count_fact_sales,
    COUNT(DISTINCT order_number) AS order_count,
    COUNT(DISTINCT customer_key) AS transacting_customers,
    COUNT(DISTINCT product_key) AS transacting_products,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM gold.fact_sales
WHERE order_date IS NOT NULL;

-----------------------------------------------------------------------
-- 1) Executive KPI snapshot
-----------------------------------------------------------------------
;WITH base AS (
    SELECT
        f.order_number,
        f.customer_key,
        f.product_key,
        f.order_date,
        CAST(f.sales_amount AS decimal(18,2)) AS sales_amount,
        CAST(f.quantity AS decimal(18,2)) AS quantity,
        CAST(f.price AS decimal(18,2)) AS price
    FROM gold.fact_sales f
    WHERE f.order_date IS NOT NULL
)
SELECT measure_name, measure_value
FROM (
    SELECT 'Total Sales' AS measure_name, CAST(SUM(sales_amount) AS decimal(18,2)) AS measure_value FROM base
    UNION ALL
    SELECT 'Total Quantity', CAST(SUM(quantity) AS decimal(18,2)) FROM base
    UNION ALL
    SELECT 'Average Selling Price', CAST(AVG(NULLIF(price,0)) AS decimal(18,2)) FROM base
    UNION ALL
    SELECT 'Total Orders', CAST(COUNT(DISTINCT order_number) AS decimal(18,2)) FROM base
    UNION ALL
    SELECT 'Transacting Customers', CAST(COUNT(DISTINCT customer_key) AS decimal(18,2)) FROM base
    UNION ALL
    SELECT 'Transacting Products', CAST(COUNT(DISTINCT product_key) AS decimal(18,2)) FROM base
) kpis
ORDER BY measure_name;

-----------------------------------------------------------------------
-- 2) Sales trend (monthly)
-----------------------------------------------------------------------
SELECT
    EOMONTH(f.order_date) AS month_end,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales,
    CAST(SUM(CAST(f.quantity AS decimal(18,2))) AS decimal(18,2)) AS total_quantity,
    COUNT(DISTINCT f.order_number) AS total_orders,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) / NULLIF(COUNT(DISTINCT f.order_number),0) AS decimal(18,2)) AS avg_order_value
FROM gold.fact_sales f
WHERE f.order_date IS NOT NULL
GROUP BY EOMONTH(f.order_date)
ORDER BY month_end;

-----------------------------------------------------------------------
-- 3) Category / Subcategory contribution
-----------------------------------------------------------------------
SELECT
    p.category,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales,
    CAST(100.0 * SUM(CAST(f.sales_amount AS decimal(18,2)))
         / NULLIF((SELECT SUM(CAST(sales_amount AS decimal(18,2))) FROM gold.fact_sales WHERE order_date IS NOT NULL),0) AS decimal(6,2)) AS pct_of_total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
GROUP BY p.category
ORDER BY total_sales DESC;

SELECT
    p.category,
    p.subcategory,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
GROUP BY p.category, p.subcategory
ORDER BY total_sales DESC;

-----------------------------------------------------------------------
-- 4) Customer distribution (country / gender / age band)
-----------------------------------------------------------------------
SELECT
    c.country,
    COUNT(*) AS customer_count
FROM gold.dim_customers c
GROUP BY c.country
ORDER BY customer_count DESC;

SELECT
    c.gender,
    COUNT(*) AS customer_count
FROM gold.dim_customers c
GROUP BY c.gender
ORDER BY customer_count DESC;

;WITH customer_age AS (
    SELECT
        c.customer_key,
        c.birthdate,
        -- Accurate age
        (DATEDIFF(year, c.birthdate, GETDATE())
         - CASE WHEN DATEADD(year, DATEDIFF(year, c.birthdate, GETDATE()), c.birthdate) > GETDATE() THEN 1 ELSE 0 END
        ) AS age
    FROM gold.dim_customers c
    WHERE c.birthdate IS NOT NULL
)
SELECT
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        WHEN age BETWEEN 50 AND 59 THEN '50-59'
        ELSE '60+'
    END AS age_group,
    COUNT(*) AS customer_count
FROM customer_age
GROUP BY
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        WHEN age BETWEEN 50 AND 59 THEN '50-59'
        ELSE '60+'
    END
ORDER BY customer_count DESC;

-----------------------------------------------------------------------
-- 5) Revenue and units by customer country
-----------------------------------------------------------------------
SELECT
    c.country,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales,
    CAST(SUM(CAST(f.quantity AS decimal(18,2))) AS decimal(18,2)) AS total_units,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
GROUP BY c.country
ORDER BY total_sales DESC;

-----------------------------------------------------------------------
-- 6) Top performers (products / customers)
-----------------------------------------------------------------------
SELECT TOP (10)
    p.product_name,
    p.category,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales,
    CAST(SUM(CAST(f.quantity AS decimal(18,2))) AS decimal(18,2)) AS total_units
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
GROUP BY p.product_name, p.category
ORDER BY total_sales DESC;

SELECT TOP (10)
    c.customer_number,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.country,
    CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
GROUP BY c.customer_number, CONCAT(c.first_name, ' ', c.last_name), c.country
ORDER BY total_sales DESC;

-----------------------------------------------------------------------
-- 7) Pareto: cumulative revenue share by product
-----------------------------------------------------------------------
;WITH product_sales AS (
    SELECT
        p.product_key,
        p.product_name,
        CAST(SUM(CAST(f.sales_amount AS decimal(18,2))) AS decimal(18,2)) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY p.product_key, p.product_name
),
ranked AS (
    SELECT
        product_key,
        product_name,
        total_sales,
        SUM(total_sales) OVER () AS grand_total_sales,
        SUM(total_sales) OVER (ORDER BY total_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_sales,
        ROW_NUMBER() OVER (ORDER BY total_sales DESC) AS revenue_rank
    FROM product_sales
)
SELECT
    revenue_rank,
    product_name,
    total_sales,
    CAST(100.0 * total_sales / NULLIF(grand_total_sales,0) AS decimal(6,2)) AS pct_of_total,
    CAST(100.0 * running_total_sales / NULLIF(grand_total_sales,0) AS decimal(6,2)) AS cumulative_pct_of_total
FROM ranked
ORDER BY revenue_rank;
