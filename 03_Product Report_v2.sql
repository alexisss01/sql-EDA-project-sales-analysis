-- Product Report (v2)
-- Purpose: Product-level performance, segmentation, and KPIs using Gold layer.



;WITH base_query AS (
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        CAST(f.sales_amount AS decimal(18,2)) AS sales_amount,
        CAST(f.quantity AS decimal(18,2)) AS quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        CAST(p.cost AS decimal(18,2)) AS cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),
product_aggregations AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        MIN(order_date) AS first_sale_date,
        MAX(order_date) AS last_sale_date,
        (DATEDIFF(month, MIN(order_date), MAX(order_date)) + 1) AS active_months,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        CAST(SUM(sales_amount) AS decimal(18,2)) AS total_sales,
        CAST(SUM(quantity) AS decimal(18,2)) AS total_quantity,
        -- Avg selling price (unit-level); protected divide by zero
        CAST(AVG(sales_amount / NULLIF(quantity,0)) AS decimal(18,2)) AS avg_selling_price
    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
),
scored AS (
    SELECT
        pa.*,
        NTILE(10) OVER (ORDER BY pa.total_sales DESC) AS revenue_decile
    FROM product_aggregations pa
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    first_sale_date,
    last_sale_date,
    DATEDIFF(month, last_sale_date, GETDATE()) AS recency_in_months,

    revenue_decile,

    CASE
        WHEN active_months <= 2 THEN 'New'
        WHEN revenue_decile = 1 THEN 'Hero'
        WHEN revenue_decile <= 4 THEN 'Core'
        ELSE 'Long Tail'
    END AS product_segment,

    active_months,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,

    -- Average Order Revenue (AOR)
    CAST(total_sales / NULLIF(total_orders,0) AS decimal(18,2)) AS avg_order_revenue,

    -- Average Monthly Revenue
    CAST(total_sales / NULLIF(active_months,0) AS decimal(18,2)) AS avg_monthly_revenue
FROM scored
ORDER BY total_sales DESC;
