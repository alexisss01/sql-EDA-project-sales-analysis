-- Customer Report (v2)
-- Purpose: Customer-level performance, segmentation, and KPIs using Gold layer.


;WITH base_query AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        CAST(f.sales_amount AS decimal(18,2)) AS sales_amount,
        CAST(f.quantity AS decimal(18,2)) AS quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.birthdate,
        -- Accurate age
        (DATEDIFF(year, c.birthdate, GETDATE())
         - CASE WHEN DATEADD(year, DATEDIFF(year, c.birthdate, GETDATE()), c.birthdate) > GETDATE() THEN 1 ELSE 0 END
        ) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),
customer_aggregation AS (
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        CAST(SUM(sales_amount) AS decimal(18,2)) AS total_sales,
        CAST(SUM(quantity) AS decimal(18,2)) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        -- Active months inclusive (avoids zero when first and last are in same month)
        (DATEDIFF(month, MIN(order_date), MAX(order_date)) + 1) AS active_months
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
),
scored AS (
    SELECT
        ca.*,
        NTILE(10) OVER (ORDER BY ca.total_sales DESC) AS sales_decile
    FROM customer_aggregation ca
)
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age IS NULL THEN 'Unknown'
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        WHEN age BETWEEN 50 AND 59 THEN '50-59'
        ELSE '60+'
    END AS age_group,

    sales_decile,

    CASE
        WHEN active_months <= 2 THEN 'New'
        WHEN sales_decile = 1 THEN 'VIP'
        WHEN sales_decile <= 4 THEN 'Regular'
        ELSE 'Occasional'
    END AS customer_segment,

    first_order_date,
    last_order_date,

    DATEDIFF(month, last_order_date, GETDATE()) AS recency_in_months,

    total_orders,
    total_sales,
    total_quantity,
    total_products,
    active_months,

    -- Average order value (AOV)
    CAST(total_sales / NULLIF(total_orders,0) AS decimal(18,2)) AS avg_order_value,

    -- Average monthly spend
    CAST(total_sales / NULLIF(active_months,0) AS decimal(18,2)) AS avg_monthly_spend
FROM scored
ORDER BY total_sales DESC;
