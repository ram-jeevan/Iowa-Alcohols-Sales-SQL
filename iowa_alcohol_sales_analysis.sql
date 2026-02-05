-- ============================================================
-- Iowa Alcohol Sales Analysis
-- ============================================================
-- This file contains all SQL queries used to analyze Iowa's
-- Alcoholic Beverages Division sales data.
-- Database: PostgreSQL
-- Tables: products, sales, stores
-- ============================================================


-- ============================================================
-- SECTION 1: PRODUCT & VENDOR ANALYSIS
-- ============================================================

-- 1. Count total products in the Products table
SELECT COUNT(item_description) AS total_products
FROM products;
-- Result: 9,977 products

-- 2. Top vendors by product diversity (distinct products offered)
SELECT vendor_name, COUNT(DISTINCT item_no) AS product_count
FROM products
GROUP BY vendor_name
ORDER BY product_count DESC;
-- Top 3: Jim Beam Brands (925), Diageo Americas (907), Pernod Ricard USA (599)


-- ============================================================
-- SECTION 2: BEST-SELLING PRODUCTS
-- ============================================================

-- 3. Top 10 products by total unit sales (bottles sold)
SELECT p.item_description, 
       SUM(s.bottle_qty) AS total_bottles_sold
FROM products AS p
JOIN sales AS s ON p.item_description = s.description
GROUP BY p.item_description
ORDER BY total_bottles_sold DESC
LIMIT 10;
-- Top 3: Black Velvet (8,361,720), Hawkeye Vodka (8,349,173), 
--        Fireball Cinnamon Whiskey (4,662,434)

-- 4. Top 10 products by total dollar value (gross profit)
SELECT p.item_description, 
       SUM((s.btl_price - s.state_btl_cost) * s.bottle_qty) AS revenue
FROM products AS p
JOIN sales AS s ON p.item_description = s.description
GROUP BY p.item_description
ORDER BY revenue DESC
LIMIT 10;
-- Top 3: Black Velvet ($30,723,528), Captain Morgan Spiced Rum ($27,541,720),
--        Fireball Cinnamon Whiskey ($24,790,141)


-- ============================================================
-- SECTION 3: CATEGORY PERFORMANCE
-- ============================================================

-- 5. Top 10 liquor categories by total sales revenue
SELECT p.category_name, 
       SUM((s.btl_price - s.state_btl_cost) * s.bottle_qty) AS revenue
FROM products AS p
JOIN sales AS s ON p.category_name = s.category_name
GROUP BY p.category_name
ORDER BY revenue DESC
LIMIT 10;
-- Top categories: Canadian Whiskies, Tequila, 80 Proof Vodka, 
--                 Imported Vodka, Straight Bourbon Whiskies


-- ============================================================
-- SECTION 4: CATEGORY-SPECIFIC ANALYSIS
-- ============================================================

-- 6a. Rum categories with sales revenue greater than $10,000
SELECT p.category_name, 
       CAST(SUM(((s.btl_price::numeric) - (s.state_btl_cost::numeric)) 
       * s.bottle_qty) AS INTEGER) AS revenue
FROM products AS p
JOIN sales AS s ON p.category_name = s.category_name
WHERE p.category_name LIKE '%RUM%'
GROUP BY p.category_name
HAVING CAST(SUM(((s.btl_price::numeric) - (s.state_btl_cost::numeric)) 
       * s.bottle_qty) AS INTEGER) > 10000
ORDER BY revenue DESC
LIMIT 10;

-- 6b. Whiskey categories with sales revenue greater than $10,000
SELECT p.category_name, 
       CAST(SUM(((s.btl_price::numeric) - (s.state_btl_cost::numeric)) 
       * s.bottle_qty) AS INTEGER) AS revenue
FROM products AS p
JOIN sales AS s ON p.category_name = s.category_name
WHERE p.category_name LIKE '%WHISKEY%'
GROUP BY p.category_name
HAVING CAST(SUM(((s.btl_price::numeric) - (s.state_btl_cost::numeric)) 
       * s.bottle_qty) AS INTEGER) > 10000
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- SECTION 5: GEOGRAPHIC ANALYSIS (VODKA SALES)
-- ============================================================

-- 7. County with most vodka sales in February 2014
SELECT county, 
       SUM(bottle_qty) AS vodka_sold
FROM sales
WHERE category_name LIKE '%VODKA%'
AND date BETWEEN '2014-02-01' AND '2014-02-28'
GROUP BY county
ORDER BY vodka_sold DESC;
-- Result: Polk County with 202,012 bottles

-- 8. Counties that appeared in top 10 for vodka sales in any month of 2014
-- Uses CTE and window function for monthly ranking
WITH vodka_sales_2014 AS (
    SELECT county, 
           DATE_TRUNC('month', date) AS month,
           SUM(bottle_qty) AS bottles_sold
    FROM sales
    WHERE category_name LIKE '%VODKA%'
    AND date BETWEEN '2014-01-01' AND '2014-12-31'
    GROUP BY county, DATE_TRUNC('month', date)
),
ranking_vodka AS (
    SELECT month, 
           county, 
           bottles_sold, 
           ROW_NUMBER() OVER (PARTITION BY month ORDER BY bottles_sold DESC) AS row_num
    FROM vodka_sales_2014
)
SELECT DISTINCT county
FROM ranking_vodka
WHERE row_num <= 10
ORDER BY county;
-- Result: 12 counties including Black Hawk, Cerro Gordo, Dallas, Des Moines,
--         Dubuque, Johnson, Linn, Polk, Pottawattamie, Scott, Story, Woodbury

-- 9. Count how many times each county appeared in the top 10 monthly rankings
WITH vodka_sales_2014 AS (
    SELECT county, 
           DATE_TRUNC('month', date) AS month,
           SUM(bottle_qty) AS bottles_sold
    FROM sales
    WHERE category_name LIKE '%VODKA%'
    AND date BETWEEN '2014-01-01' AND '2014-12-31'
    GROUP BY county, DATE_TRUNC('month', date)
    ORDER BY month, bottles_sold DESC
),
ranking_vodka AS (
    SELECT month, 
           county, 
           bottles_sold, 
           ROW_NUMBER() OVER (PARTITION BY month ORDER BY bottles_sold DESC) AS row_num
    FROM vodka_sales_2014
)
SELECT county, COUNT(*) AS months_in_top_10
FROM ranking_vodka
WHERE row_num <= 10
GROUP BY county
ORDER BY months_in_top_10 DESC;
-- 9 counties appeared in top 10 all 12 months
-- Dallas and Des Moines appeared only once (June and December respectively)

-- Identify which months the outlier counties appeared in top 10
WITH vodka_sales_2014 AS (
    SELECT county, 
           DATE_TRUNC('month', date) AS month,
           SUM(bottle_qty) AS bottles_sold
    FROM sales
    WHERE category_name LIKE '%VODKA%'
    AND date BETWEEN '2014-01-01' AND '2014-12-31'
    GROUP BY county, DATE_TRUNC('month', date)
    ORDER BY month, bottles_sold DESC
),
ranking_vodka AS (
    SELECT month, 
           county, 
           bottles_sold, 
           ROW_NUMBER() OVER (PARTITION BY month ORDER BY bottles_sold DESC) AS row_num
    FROM vodka_sales_2014
)
SELECT county, month
FROM ranking_vodka
WHERE county IN ('Dallas', 'Des Moines')
AND row_num <= 10;


-- ============================================================
-- SECTION 6: SEASONAL TREND ANALYSIS
-- ============================================================

-- 10. Monthly sales trend by bottle size category
-- First, explore distinct liter sizes
SELECT DISTINCT liter_size
FROM sales
ORDER BY liter_size DESC;

-- Categorize bottle sizes and analyze monthly revenue distribution
-- Size categories: XL (3000-6000ml), L (1500-2400ml), M (800-1200ml), 
--                  S (300-754ml), XS (12-250ml)
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', date) AS month,
        CASE
            WHEN liter_size BETWEEN 3000 AND 6000 THEN 'XL'
            WHEN liter_size BETWEEN 1500 AND 2400 THEN 'L'
            WHEN liter_size BETWEEN 800 AND 1200 THEN 'M'
            WHEN liter_size BETWEEN 300 AND 754 THEN 'S'
            WHEN liter_size BETWEEN 12 AND 250 THEN 'XS'
            ELSE 'Other'
        END AS liter_category,
        SUM((btl_price - state_btl_cost) * bottle_qty)::numeric AS revenue
    FROM sales
    GROUP BY month, liter_category
)
SELECT
    month,
    liter_category,
    revenue,
    ROUND(revenue::decimal / SUM(revenue) OVER (PARTITION BY month) * 100, 2) 
        AS pct_of_monthly_revenue
FROM monthly_revenue
ORDER BY month, liter_category;
-- Finding: S bottles generate the most income consistently across all months
-- Distribution between categories remains relatively stable throughout the year


-- ============================================================
-- SECTION 7: STORE PERFORMANCE
-- ============================================================

-- 11a. Count of stores with more than $2,000,000 in total sales
SELECT COUNT(*) AS stores_over_2m
FROM (
    SELECT s.name
    FROM stores AS s
    JOIN sales AS sa ON s.store = sa.store
    GROUP BY s.name
    HAVING SUM((sa.btl_price::numeric - sa.state_btl_cost::numeric) 
           * sa.bottle_qty) > 2000000
) AS high_performers;
-- Result: 3 stores

-- 11b. Count of stores with average bottle price greater than $20
SELECT COUNT(*) AS stores_above_20_avg
FROM (
    SELECT s.name
    FROM stores AS s
    JOIN sales AS sa ON s.store = sa.store
    GROUP BY s.name
    HAVING ROUND(AVG(sa.btl_price::numeric)) > 20
) AS premium_stores;
-- Result: 21 stores


-- ============================================================
-- SECTION 8: DATA QUALITY INVESTIGATION
-- ============================================================

-- BONUS: Identify category mismatches between sales and products tables
SELECT s.category_name AS sales_category, 
       p.category_name AS product_category, 
       COUNT(*) AS mismatch_count
FROM sales s
JOIN products p ON s.description = p.item_description
WHERE s.category_name <> p.category_name
GROUP BY s.category_name, p.category_name
ORDER BY mismatch_count DESC;
-- Result: 324,443 total mismatches
-- Common patterns: "Spiced Rum" and "80 Proof Vodka" categories in sales
-- don't match product categories
-- Captain Morgan Spiced Rum has the most mismatches


-- ============================================================
-- BONUS: ADDITIONAL ANALYSIS QUERIES
-- ============================================================

-- Year-over-year revenue comparison
SELECT 
    EXTRACT(YEAR FROM date) AS year,
    SUM((btl_price - state_btl_cost) * bottle_qty)::numeric AS total_revenue
FROM sales
GROUP BY EXTRACT(YEAR FROM date)
ORDER BY year;

-- Top 10 stores by total revenue
SELECT s.name AS store_name,
       s.county,
       SUM((sa.btl_price::numeric - sa.state_btl_cost::numeric) 
           * sa.bottle_qty) AS total_revenue
FROM stores s
JOIN sales sa ON s.store = sa.store
GROUP BY s.name, s.county
ORDER BY total_revenue DESC
LIMIT 10;

-- Average transaction size by county
SELECT county,
       ROUND(AVG(bottle_qty), 2) AS avg_bottles_per_transaction,
       ROUND(AVG((btl_price - state_btl_cost) * bottle_qty)::numeric, 2) AS avg_revenue_per_transaction
FROM sales
GROUP BY county
ORDER BY avg_revenue_per_transaction DESC
LIMIT 10;
