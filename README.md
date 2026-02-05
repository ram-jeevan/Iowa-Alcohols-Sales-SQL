# Iowa Alcohol Sales Analysis

An SQL-based analysis of Iowa's liquor sales data, examining product performance, vendor diversity, geographic trends, and seasonal patterns across 9,977 products and multiple years of transaction data.

![SQL](https://img.shields.io/badge/SQL-PostgreSQL-blue)
![Dataset](https://img.shields.io/badge/Dataset-Iowa%20ABD-green)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

## Overview

This project analyzes Iowa's Alcoholic Beverages Division sales data to uncover insights about product performance, vendor market share, geographic sales patterns, and seasonal trends. The analysis uses JOINs, CTEs, window functions, and aggregations to answer business questions relevant to distributors and retailers.

### Key Findings

| Metric | Finding |
|--------|---------|
| **Total Products** | 9,977 |
| **Top Seller (Units)** | Black Velvet (8.36M bottles) |
| **Top Seller (Revenue)** | Black Velvet ($30.7M) |
| **Most Diverse Vendor** | Jim Beam Brands (925 products) |
| **Top Vodka County (Feb 2014)** | Polk (202,012 bottles) |

**Revenue by Category (Top 5):**
1. Canadian Whiskies — $4.20B
2. Tequila — $4.03B
3. 80 Proof Vodka — $4.01B
4. Imported Vodka — $3.70B
5. Straight Bourbon Whiskies — $2.79B

## Dataset

The analysis uses three related tables from the Iowa Alcoholic Beverages Division:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `products` | Product catalog | item_no, item_description, vendor_name, category_name |
| `sales` | Transaction records | date, store, county, description, bottle_qty, btl_price, state_btl_cost |
| `stores` | Store information | store, name, county |

## Analysis Sections

### 1. Product & Vendor Analysis

Identified the product catalog size and vendor diversity to understand market structure.

```sql
-- Most diverse vendors by product count
SELECT vendor_name, COUNT(DISTINCT item_no) AS product_count
FROM products
GROUP BY vendor_name
ORDER BY product_count DESC;
```

| Vendor | Products |
|--------|----------|
| Jim Beam Brands | 925 |
| Diageo Americas | 907 |
| Pernod Ricard USA | 599 |

### 2. Best-Selling Products

Analyzed products by both unit sales and revenue to identify top performers.

```sql
-- Top products by revenue (profit margin × quantity)
SELECT p.item_description, 
       SUM((s.btl_price - s.state_btl_cost) * s.bottle_qty) AS revenue
FROM products p
JOIN sales s ON p.item_description = s.description
GROUP BY p.item_description
ORDER BY revenue DESC
LIMIT 10;
```

**Key Insight:** Black Velvet leads in both unit sales (8.36M bottles) and revenue ($30.7M), indicating strong market penetration across price points.

### 3. Category Performance

Identified the most profitable liquor categories by calculating gross profit.

```sql
SELECT p.category_name, 
       SUM((s.btl_price - s.state_btl_cost) * s.bottle_qty) AS revenue
FROM products p
JOIN sales s ON p.category_name = s.category_name
GROUP BY p.category_name
ORDER BY revenue DESC
LIMIT 10;
```

### 4. Category-Specific Analysis

Filtered results for specific spirit types using pattern matching and the `HAVING` clause.

```sql
-- Rum categories with revenue > $10,000
SELECT p.category_name, 
       CAST(SUM(((s.btl_price::numeric) - (s.state_btl_cost::numeric)) 
       * s.bottle_qty) AS INTEGER) AS revenue
FROM products p
JOIN sales s ON p.category_name = s.category_name
WHERE p.category_name LIKE '%RUM%'
GROUP BY p.category_name
HAVING CAST(SUM(((s.btl_price::numeric) - (s.state_btl_cost::numeric)) 
       * s.bottle_qty) AS INTEGER) > 10000
ORDER BY revenue DESC;
```

### 5. Geographic Analysis (Vodka Sales)

Used CTEs and window functions to identify top-performing counties for vodka sales.

```sql
-- Counties in top 10 for vodka sales in any month of 2014
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
    SELECT month, county, bottles_sold, 
           ROW_NUMBER() OVER (PARTITION BY month ORDER BY bottles_sold DESC) AS row_num
    FROM vodka_sales_2014
)
SELECT DISTINCT county
FROM ranking_vodka
WHERE row_num <= 10
ORDER BY county;
```

**Result:** 12 counties appeared in the top 10 at least once: Black Hawk, Cerro Gordo, Dallas, Des Moines, Dubuque, Johnson, Linn, Polk, Pottawattamie, Scott, Story, Woodbury.

**Key Insight:** 9 counties consistently ranked in the top 10 every month. Dallas and Des Moines emerged as outliers in June and December respectively, potentially indicating seasonal or demographic shifts.

### 6. Seasonal Trend Analysis

Categorized bottle sizes and analyzed monthly revenue distribution to test the hypothesis that larger bottles sell more during holidays.

```sql
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
```

**Finding:** Contrary to the hypothesis, the distribution between bottle size categories remained relatively constant throughout the year. Small (S) bottles consistently generated the most revenue in every month.

### 7. Store Performance

Identified high-performing stores using aggregate filters.

```sql
-- Stores with over $2M in total sales
SELECT COUNT(*) AS stores_over_2m
FROM (
    SELECT s.name
    FROM stores s
    JOIN sales sa ON s.store = sa.store
    GROUP BY s.name
    HAVING SUM((sa.btl_price::numeric - sa.state_btl_cost::numeric) 
           * sa.bottle_qty) > 2000000
) AS high_performers;
-- Result: 3 stores
```

### 8. Data Quality Investigation

Discovered category mismatches between sales and products tables, identifying potential data integrity issues.

```sql
SELECT s.category_name AS sales_category, 
       p.category_name AS product_category, 
       COUNT(*) AS mismatch_count
FROM sales s
JOIN products p ON s.description = p.item_description
WHERE s.category_name <> p.category_name
GROUP BY s.category_name, p.category_name
ORDER BY mismatch_count DESC;
```

**Finding:** 324,443 category mismatches were identified. Common patterns include "Spiced Rum" and "80 Proof Vodka" in sales not matching product categories, with Captain Morgan Spiced Rum being the most frequently mismatched item.

## SQL Techniques Demonstrated

| Technique | Usage |
|-----------|-------|
| **JOINs** | Linking products, sales, and stores tables |
| **Aggregations** | SUM, COUNT, AVG with GROUP BY |
| **HAVING Clause** | Filtering aggregated results |
| **CTEs (WITH)** | Creating reusable subqueries for complex analysis |
| **Window Functions** | ROW_NUMBER(), PARTITION BY for ranking |
| **CASE Statements** | Categorizing bottle sizes |
| **DATE_TRUNC** | Monthly aggregation of time-series data |
| **Type Casting** | Converting money types to numeric for calculations |
| **Pattern Matching** | LIKE for filtering categories |
| **Subqueries** | Nested queries for counting filtered results |

## Business Recommendations

Based on the analysis:

1. **Inventory Focus:** Prioritize Black Velvet, Hawkeye Vodka, and Fireball Cinnamon Whiskey for stock management
2. **Vendor Relationships:** Jim Beam Brands and Diageo Americas offer the most product diversity for broader selection
3. **Geographic Targeting:** Polk County consistently leads vodka sales; monitor Dallas and Des Moines for emerging growth
4. **Category Strategy:** Canadian Whiskies, Tequila, and Vodka categories drive the most revenue
5. **Data Quality:** Implement validation rules to prevent category mismatches between sales and product records

## Repository Structure

```
├── README.md
├── sql/
│   └── iowa_alcohol_sales_analysis.sql
└── data/
    └── data_source_info.md
```

## How to Reproduce

1. Access Iowa Alcoholic Beverages Division data from [data.iowa.gov](https://data.iowa.gov/)
2. Import into PostgreSQL as `products`, `sales`, and `stores` tables
3. Run queries from `sql/iowa_alcohol_sales_analysis.sql`

## Tools Used

- **Database:** PostgreSQL
- **Analysis:** SQL
- **Visualization:** Built-in database charts

## About

This project was completed as part of the General Assembly Data Analytics Bootcamp, demonstrating SQL proficiency in multi-table analysis, window functions, and business intelligence.

## License

This project uses publicly available Iowa state data. Analysis and code are available under the MIT License.

---

*Analysis completed February 2025*
