
/* ===========================================================================
Creating Report
===============================================================================
Purpose:
        Creating Views that are ready to be pulled to create business reports
        using tools like Excel, PowerBi and Tableau

Usage:
      These Views can be executed and extracted to create reports and dashboards
      on Excel, PowerBi or Tableau
=============================================================================== */




/* 1. Customer Report
==================================================================================
  Purpose:
	  This report consolidates key customer metrics and behaviors

  Highlights:
  	1. Gather essential fields like name, age and transaction details
  	2. Segment customers into categories (VIP, Regular, New) and age groups
  	3. Aggregates customer-level metrics:
  		- total orders
  		- total sales
  		- total quantity purchased
  		- total products
  		- lifespan (in months)
  	4. Calculates valuable KPIs:
  		- recency (months since last order)
  		- average order value
  		- average monthly spend
==================================================================================== */

CREATE VIEW gold.report_customer AS
-- Step 1

WITH base_query AS (
-- Basic Query: Retriving core columns for table
SELECT
	fs.order_number,
	fs.product_key,
	fs.order_date,
	fs.sales_amount,
	fs.quantity,
	dc.customer_key,
	dc.customer_number,
	CONCAT(dc.first_name, ' ' , dc.last_name) AS customer_name,
	DATEDIFF(YEAR, dc.birthdate, GETDATE()) AS age
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customers AS dc
ON fs.customer_key = dc.customer_key
WHERE order_date IS NOT NULL )

-- Step 2:
, customer_aggregation AS (
SELECT
-- All aggregations from Base Query
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_products,
	MAX(order_date) AS last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY
	customer_key,
	customer_number,
	customer_name,
	age
	)

SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE 
		WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN 'Between 20-29'
		WHEN age BETWEEN 30 AND 39 THEN 'Between 30-39'
		WHEN age BETWEEN 40 AND 49 THEN 'Between 40-49'
		ELSE 'Above 50'
	END AS age_group,
	CASE 
		WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END AS customer_segment,
	last_order,
	DATEDIFF(MONTH, last_order, GETDATE()) AS recency_in_months,
	total_orders,
	total_sales,
	total_quantity,
	total_products,

	-- Calculating average order value
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
		END AS avg_order_value,
	lifespan AS lifespan_in_months,

	-- Calculating average monthly sales
	CASE
		WHEN lifespan = 0 THEN 0
		ELSE total_sales / lifespan
		END AS average_monthly_sales
FROM customer_aggregation





/* 2. Product Report
===================================================
  Purpose:
  	To create a report that shows the metrics and product behavior

  Highlights:
  		1. Gather essential fields such as name, category, subcategory and cost
  		2. Segment products to show 'High Performers', 'Mid Range Performers' and 'Low Performers'
  		3. Aggregate product level metrics:
  		- total orders
  		- total sales
  		- total quantity sold
  		- total customers (unique)
  		- lifespan (months)
  		4. Calculate KPIs:
  		- recency (months since last sale)
  		- average order revenue
  		- average monthly revenue
=================================================== */

CREATE VIEW gold.report_product AS 
-- Basic Query: get name and fields for table
WITH product_summary AS (
SELECT
	dp.product_key,
	dp.product_name,
	dp.category,
	dp.subcategory,
	dp.cost,
	fs.order_number,
	fs.order_date,
	fs.sales_amount,
	fs.quantity,
	fs.customer_key
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS dp
ON fs.product_key = dp.product_key
WHERE order_date IS NOT NULL
)

/* Aggregations */

, product_aggregations AS (
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers,
	MAX(order_date) AS last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan 
FROM product_summary
GROUP BY
	product_key,
	product_name,
	category,
	subcategory,
	cost
)


SELECT
	product_name,
	category,
	subcategory,
	last_order,
	total_sales,
	total_orders,
	DATEDIFF(MONTH, last_order, GETDATE()) AS recency_in_months,
	total_quantity,
	total_customers,

	-- Average order revenue
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders 
		END AS avg_order_revenue,

	-- Average monthly revenue
	CASE
		WHEN lifespan = 0 THEN 0
		ELSE total_sales/ lifespan 
		END AS avg_monthly_revenue,
	CASE
		WHEN total_sales > 50000 THEN 'High Performer'
		WHEN total_sales BETWEEN 10000 AND 50000 THEN 'Mid Range Performer'
		ELSE 'Low Performer'
	END AS product_performance
FROM product_aggregations
