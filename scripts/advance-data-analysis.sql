/* Advance Data Analysis Project
=======================================================================================
Purpose:
      We create queries that help us analyse in detail the aggregations to the measures,
      which will in the end be used to create business reports
======================================================================================= */

/* 1. Change Over Time Analysis
Analyzing the change of a measure over time */

-- using YEAR and MONTH
SELECT
	YEAR(order_date) AS order_year,
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

--using DATETRUNC
SELECT
	DATETRUNC(YEAR, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date)
ORDER BY DATETRUNC(YEAR, order_date);

-- using FORMAT
SELECT
	FORMAT(order_date, 'yyyy-MMM') AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');

/* ==================================================================== */

/* 2. Cumulative Analysis
Aggregate the data progressively over time */

SELECT
	order_month,
	total_sales,
	SUM(total_sales) OVER(ORDER BY order_month) AS running_total, -- running total, can add PARTITION BY if needed
	AVG(avg_price) OVER(ORDER BY order_month) AS moving_avg -- moving average
FROM (SELECT
	DATETRUNC(MONTH, order_date) order_month,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date))t

/* ==================================================================== */
  
/* 3. Performance Analysis

Analyze yearly performance of products by comparing sales
to both average sales performance of product and previous year's sales */

WITH yearly_product_sales AS (
SELECT
	YEAR(fs.order_date) AS order_year,
	dp.product_name,
	SUM(fs.sales_amount) AS current_sales
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS dp
ON fs.product_key = dp.product_key
WHERE fs.order_date IS NOT NULL
GROUP BY 
YEAR(fs.order_date), dp.product_name
)

SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS diff_in_avg_sales,
	CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Average'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Average'
		ELSE 'Average'
	END growth_in_avg_sales,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS previous_year,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_in_previous_sales,
	CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increasing'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decreasing'
		ELSE 'No change'
		END comparision_with_previous_year
FROM yearly_product_sales
ORDER BY product_name, order_year

/* ==================================================================== */
  
/* 4. Part to Whole Analysis
Gives the part contribution of a measure in the overall measure */

-- Show the percentage contribution of each category in the overall category sales
WITH category_total_sales AS (
SELECT
	dp.category,
	SUM(fs.sales_amount) AS total_sales_per_category
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS dp
ON fs.product_key = dp.product_key
GROUP BY dp.category
)

SELECT
	category,
	total_sales_per_category,
	SUM(total_sales_per_category) OVER() AS grand_total_sales,
	CONCAT(ROUND((CAST (total_sales_per_category AS FLOAT) / SUM(total_sales_per_category) OVER()) * 100, 2), '%') AS percentage_of_contribution
FROM category_total_sales
ORDER BY total_sales_per_category DESC

/* ==================================================================== */

/* 5. Data Segmentation
Create new and different data segments using measures */

-- Segment the products into cost ranges and count how many products fall in each segment
SELECT
	cost_range,
	COUNT(product_key) AS product_per_range
FROM (SELECT
	product_key,
	product_name,
	cost,
	CASE WHEN cost < 100 THEN 'Below 100'
		WHEN cost BETWEEN 100 AND 500 THEN 'Between 100-500'
		WHEN cost BETWEEN 500 AND 1000 THEN 'Between 500-1000'
		ELSE 'Above 1000'
	END AS cost_range
FROM gold.dim_products)t
GROUP BY cost_range
ORDER BY product_per_range DESC

/* ==================================================================== */  

/* Create a new Data Segment to group customers into 3 segments:

	1. VIP: atleast 12 months of history and spends more than 5000
	2. Regular: atleast 12 months of history but spends less than or equal to 5000
	3. New: less than 12 months of lifespan

And find total number of customers in each segment */

WITH customer_spending AS (
SELECT 
	dc.customer_key,
	SUM(fs.sales_amount) AS total_sales,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customers AS dc
ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_key
)
SELECT
	customer_segment,
	COUNT(customer_key) AS total_customers_per_segment
FROM (SELECT
	customer_key,
	CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END AS customer_segment
FROM customer_spending) t
GROUP BY customer_segment
ORDER BY total_customers_per_segment DESC

/* ==================================================================== */

