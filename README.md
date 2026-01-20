# Exploratory Data Analysis (EDA) – SQL-Based Business Insights

## Business Context

In many analytics roles, stakeholders require timely insights without the overhead of complex modelling or advanced tooling. SQL-based EDA is often the first and most critical step in understanding business performance, validating assumptions, and identifying opportunities or risks.

---

## Data Source

All EDA queries run against the Gold layer views/tables:

- `gold.fact_sales` (grain: order line)
- `gold.dim_customers`
- `gold.dim_products`


Key characteristics:

* Cleaned and standardised data
* Star schema design
* Suitable for BI and analytical exploration

---
## KPI & segmentation contract
### Core KPIs
- **Total Sales** = `SUM(sales_amount)`
- **Total Quantity** = `SUM(quantity)`
- **Total Orders** = `COUNT(DISTINCT order_number)`
- **AOV (Average Order Value)** = `SUM(sales_amount) / COUNT(DISTINCT order_number)`
- **ASP (Average Selling Price)** = `AVG(sales_amount / NULLIF(quantity,0))` (product-level)

### Recency
- **Customer Recency (months)** = `DATEDIFF(month, last_order_date, GETDATE())`
- **Product Recency (months)** = `DATEDIFF(month, last_sale_date, GETDATE())`

### Decile-based segmentation
To avoid arbitrary thresholds, customer and product segments are based on deciles:

- **Customer Sales Decile** = `NTILE(10) OVER (ORDER BY total_sales DESC)`
- **Product Revenue Decile** = `NTILE(10) OVER (ORDER BY total_sales DESC)`

Default segment labels:
- Customers:
  - **VIP** = top decile (`decile = 1`)
  - **Regular** = deciles 2–4
  - **Occasional** = deciles 5–10
  - **New** = very short activity window (e.g., `active_months <= 2`) — applied as a practical onboarding lens
- Products:
  - **Hero** = top decile (`decile = 1`)
  - **Core** = deciles 2–4
  - **Long Tail** = deciles 5–10
  - **New** = `active_months <= 2`

---

## Scripts included

### 1) `Overall Analysis_v2.sql`
Business-wide overview and sanity checks:
- KPI snapshot
- Monthly sales trend (EOMONTH)
- Category/subcategory contribution
- Customer distribution cuts (country, gender, age bands)
- Pareto concentration lens (cumulative revenue share by product)


### 2) `Customer Report_v2.sql`
Customer performance pack:
- customer-level aggregation (orders, sales, quantity, distinct products)
- recency and activity window
- decile scoring + segment labels (VIP/Regular/Occasional/New)
- output ordered by total sales for prioritisation


### 3) `Product Report_v2.sql`
Product performance pack:
- product-level aggregation (orders, customers, sales, quantity)
- ASP/AOR and monthly revenue lens
- decile scoring + segment labels (Hero/Core/Long Tail/New)

---

## Outputs
Each script returns a set of tables intended for:
- ad-hoc analysis
- KPI validation against BI report
- exporting to CSV for documentation / checks

---

## Skills Involved

This project demonstrates the following analyst-relevant capabilities:

* SQL-based exploratory data analysis
* Translating business questions into analytical queries
* Interpreting transactional data at multiple levels
* Structuring analysis for stakeholder consumption
* Working with analytics-ready data models






