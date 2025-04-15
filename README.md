



---
![Brown-Jersey-Ultimo-5-640x427](https://github.com/user-attachments/assets/b560b5c5-7f8d-4bd3-bdea-28e6720e0c90)




# 📊 Project Title: Manufacturing Sale Performance Analysis (SQL in BigQuery)   
Author: Nguyễn Văn Trí   
Date: 2024-10-19      


---

## 📑 Table of Contents  
1. [📌 Background & Overview](#-background--overview)  
2. [📂 Dataset Description](#-dataset-description)  
3. [🔎 Final Conclusion & Recommendations](#-final-conclusion--recommendations)

---

## 📌 Background & Overview  

### Objective:
### 📖 What is this project about? What Business Question will it solve?
This project queries and analyzes user interactions, shopping patterns, and product performance to:   
✔️ Identify customer behavior  
✔️ Enhance user experience  
✔️ Improve conversion rates  
✔️ Optimize marketing strategies
  
### 👤 Who is this project for?  
✔️ Data Analysts & Business Analysts  
✔️ Decision Makers & Stakeholders  



---

## 📂 Dataset Description 

### 📌 Data Source  
- Source: Adventureworks2019
  
### 📌 Data Dictionary
https://drive.google.com/file/d/1bwwsS3cRJYOg1cvNppc1K_8dQLELN16T/view?usp=sharing



## ⚒️ Main Process

<details>
  <summary> 1. Subcategory Revenue Analysis </summary>
 Calculate the quantity of items, sales value & order quantity by each Subcategory in the last 12 months. 

```sql
SELECT 
  FORMAT_DATE('%b %Y', s.ModifiedDate) as period
  ,ps.Name
  ,SUM(s.OrderQty) as qty_item
  ,SUM(s.LineTotal) total_sales
  ,COUNT(DISTINCT s.SalesOrderID) as order_cnt
FROM `adventureworks2019.Sales.SalesOrderDetail` as s
LEFT JOIN `adventureworks2019.Production.Product` as p
  ON s.ProductID=p.ProductID
LEFT JOIN `adventureworks2019.Production.ProductSubcategory` as ps
  ON CAST(p.ProductSubcategoryID as INT) = ps.ProductSubcategoryID
WHERE DATE(s.ModifiedDate) >= (SELECT DATE_SUB(DATE(MAX(ModifiedDate)), INTERVAL 12 MONTH) 
                                    FROM `adventureworks2019.Sales.SalesOrderDetail`)
GROUP BY period, ps.Name
ORDER BY period DESC, ps.Name
```

Query Result:
| period    |  Name               | qty_item       | total_sales   | order_cnt    |
|-----------|---------------------|----------------|---------------|--------------|
| Sep 2013 | Bike Racks          | 312            | 22,828.51     | 71           |
| Sep 2013 | Bike Stands         | 26             | 4,134.00      | 26           |
| Sep 2013 | Bottles and Cages   | 803            | 4,676.56      | 380          |
| Sep 2013 | Bottom Brackets     | 60             | 3,118.14      | 19           |
| Sep 2013 | Brakes              | 100            | 6,390.00      | 29           |


</details>


<details>
  <summary> 2. Subcategory Growth Analysis  S</summary>
Calculate the % YoY growth rate by Subcategory & release the top 3 with the highest growth rate.
```sql
WITH qty_by_year as(
  SELECT 
    FORMAT_DATE('%Y', s.ModifiedDate) as period
    ,ps.Name as Name
    ,SUM(s.OrderQty) qty_item
  FROM `adventureworks2019.Sales.SalesOrderDetail` as s
  LEFT JOIN `adventureworks2019.Production.Product` as p
  ON s.ProductID=p.ProductID
  LEFT JOIN `adventureworks2019.Production.ProductSubcategory` ps
  ON CAST(p.ProductSubcategoryID as INT) = ps.ProductSubcategoryID
  GROUP BY period, Name
)

,qty_by_prv_year as(
  SELECT 
    period
    ,Name
    ,qty_item 
    ,LAG(qty_item) OVER(PARTITION BY Name ORDER BY period) as prv_qty
  FROM qty_by_year
  ORDER BY Name, period
)

,YoY_ranking as(
  SELECT 
  Name
  ,qty_item 
  ,prv_qty
  ,ROUND((qty_item - prv_qty)/prv_qty,2) as qty_diff
  ,DENSE_RANK() OVER(ORDER BY (qty_item - prv_qty)/prv_qty DESC) as rk
  FROM qty_by_prv_year
)

SELECT 
  Name
  ,qty_item 
  ,prv_qty
  ,qty_diff
FROM YoY_ranking
WHERE rk <=3;
```

Query Result:

| Name            | qty_item                 | prv_qty                   | qty_diff                   |
|-----------------|--------------------------|---------------------------|----------------------------|
| Road Frames     | 5564                     | 1137                      | 3.89                       |
| Mountain Frames | 3168                     | 510                       | 5.21                       |
| Socks           | 2724                     | 523                       | 4.21                       |

</details>


<details>
  <summary> 3. Revenue Breakdown</summary>
 Analyzed revenue by traffic source weekly and monthly in June 2017 to assess the best-performing acquisition channels.

```sql
-- Revenue by traffic source by week, by month in June 2017
WITH week_revenue as(
  SELECT 
    'Week'as time_type
    ,FORMAT_DATE('%Y%W',PARSE_DATE('%Y%m%d', date)) as time
    ,trafficSource.source 
    ,SUM(productRevenue)/1000000.0 as revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
  UNNEST (hits) hits,
  UNNEST (hits.product) product
  WHERE productRevenue is not null
  GROUP BY time, trafficSource.source
  ORDER BY time, trafficSource.source
)

,month_revenue as(
  SELECT 
    'Month'as time_type
    ,FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as time
    ,trafficSource.source
    ,SUM(productRevenue)/1000000.0 as revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
  UNNEST (hits) hits,
  UNNEST (hits.product) product
  WHERE productRevenue is not null
  GROUP BY time, trafficSource.source
  ORDER BY time, trafficSource.source
)

SELECT *
FROM week_revenue
UNION ALL
SELECT *
FROM month_revenue
ORDER BY source, revenue
```

Query Result:

| Time Type| Time | Source             | Revenue ($) |
| ------ | ------ | ------------------ | ----------- |
| Week   | 201722 | (direct)           | 6888.90     |
| Week   | 201726 | (direct)           | 14914.81    |
| Week   | 201723 | (direct)           | 17325.68    |
| Week   | 201725 | (direct)           | 27295.32    |
| Week   | 201724 | (direct)           | 30908.91    |
| Month  | 201706 | (direct)           | 97333.62    |
| Month  | 201706 | bing               | 13.98       |
| Week   | 201724 | bing               | 13.98       |
| Month  | 201706 | chat.google.com    | 74.03       |
| Week   | 201723 | chat.google.com    | 74.03       |
| Week   | 201724 | dealspotr.com      | 72.95       |
| Month  | 201706 | dealspotr.com      | 72.95       |

</details>


<details>
  <summary> 4. Traffic & Engagement Analysis</summary>
Compared the browsing patterns of purchasers and non-purchasers in June & July 2017 to identify key engagement drivers.
  
```sql
-- Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.
WITH avg_pageview_purchaser as(
  SELECT  
    FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as month
    ,ROUND(SUM(totals.pageviews)/COUNT(DISTINCT fullVisitorId),2) as avg_pageviews_purchase
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
  UNNEST (hits) hits,
  UNNEST (hits.product) product
  WHERE _table_suffix BETWEEN "0601" AND '0731'
    AND totals.transactions >=1
    AND productRevenue is not null
  GROUP BY month
  ORDER BY month
)

,avg_pageviews_non_purchaser as(
  SELECT  
    FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as month
    ,ROUND(SUM(totals.pageviews)/COUNT(DISTINCT fullVisitorId),2) as avg_pageviews_non_purchase
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
  UNNEST (hits) hits,
  UNNEST (hits.product) product
  WHERE _table_suffix BETWEEN "0601" AND '0731'
    AND totals.transactions is null
    AND productRevenue is null
  GROUP BY month
  ORDER BY month
)

SELECT 
  pur.month
  ,pur.avg_pageviews_purchase
  ,non_pur.avg_pageviews_non_purchase
FROM  avg_pageview_purchaser as pur
FULL JOIN avg_pageviews_non_purchaser as non_pur
ON pur.month = non_pur.month
```

Query Result:

| Month  | Avg Pageviews (Purchase) | Avg Pageviews (Non-Purchase) |
|--------|-------------------------:|-----------------------------:|
| 201706 | 94.02                    | 316.87                      |
| 201707 | 124.24                   | 334.06                      |

</details>



<details>
  <summary> 5. Customer Loyalty & Spending Patterns Analysis</summary>
Measured transaction frequency per user  in July 2017 to gauge purchase consistency and spending habits.
  
```sql
-- Average number of transactions per user that made a purchase in July 2017
SELECT 
  FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as month
  ,ROUND(SUM(totals.transactions)/COUNT(DISTINCT fullVisitorId),2) as Avg_total_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST (hits) hits,
UNNEST (hits.product) product
WHERE totals.transactions >=1
  AND productRevenue is not null
GROUP BY month
ORDER BY month
```
Query Result:

| Month  | Avg Total Transactions per User |
|--------|--------------------------------:|
| 201707 | 4.16                            |


```sql
-- Average amount of money spent per session. Only include purchaser data in July 2017
SELECT 
  FORMAT_DATE('%Y%m',PARSE_DATE('%Y%m%d', date)) as month
  ,ROUND(SUM(productRevenue)/(SUM(totals.visits)*1000000),2) as avg_spend_per_session
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST (hits) hits,
UNNEST (hits.product) product
WHERE totals.transactions >=1
  AND productRevenue is not null
GROUP BY month
```
Query Result:

| Month  | Avg Revenue Per Visit (USD) |
|--------|----------------------------:|
| 201707 | 43.86                       |


</details>


<details>
  <summary>6. Product Affinity & Cross-Selling</summary>
Identified frequently co-purchased products with YouTube Men's Vintage Henley to uncover bundling and recommendation opportunities.
  
```sql
-- Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017.
WITH buyer_list as(
    SELECT
        DISTINCT fullVisitorId  
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
    , UNNEST(hits) as hits
    , UNNEST(hits.product) as product
    WHERE product.v2ProductName = "YouTube Men's Vintage Henley"
    AND totals.transactions>=1
    AND product.productRevenue is not null
)

SELECT
  product.v2ProductName as other_purchased_products,
  SUM(product.productQuantity) as quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
, UNNEST(hits) as hits
, UNNEST(hits.product) as product
INNER JOIN buyer_list USING(fullVisitorId)
WHERE product.v2ProductName != "YouTube Men's Vintage Henley"
 AND product.productRevenue is not null
GROUP BY other_purchased_products
ORDER BY quantity DESC
```
Query Result:

| Product Name                                      | Quantity |
|--------------------------------------------------|---------:|
| Google Sunglasses                                | 20       |
| Google Women's Vintage Hero Tee Black           | 7        |
| SPF-15 Slim & Slender Lip Balm                  | 6        |
| Google Women's Short Sleeve Hero Tee Red Heather | 4        |
| YouTube Men's Fleece Hoodie Black               | 3        |
| Google Men's Short Sleeve Badge Tee Charcoal    | 3        |


</details>


<details>
  <summary> 7. Conversion Funnel Optimization</summary>
Built a cohort analysis to track product view-to-purchase conversion rates in Q1 2017, revealing key drop-off points in the buying journey.

```sql
-- Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. 
WITH product_data as(
SELECT
  format_date('%Y%m', parse_date('%Y%m%d',date)) as month
  ,count(CASE WHEN eCommerceAction.action_type = '2' THEN product.v2ProductName END) as num_product_view
  ,count(CASE WHEN eCommerceAction.action_type = '3' THEN product.v2ProductName END) as num_add_to_cart
  ,count(CASE WHEN eCommerceAction.action_type = '6' and product.productRevenue is not null THEN product.v2ProductName END) as num_purchase
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
,UNNEST(hits) as hits
,UNNEST (hits.product) as product
WHERE _table_suffix BETWEEN '20170101' AND '20170331'
  AND eCommerceAction.action_type in ('2','3','6')
GROUP BY month
ORDER BY  month
)

SELECT
    *,
    ROUND(num_add_to_cart/num_product_view * 100, 2) as add_to_cart_rate,
    ROUND(num_purchase/num_product_view * 100, 2) as purchase_rate
FROM product_data
```
Query Result:

| Month  | Product Views | Add to Cart | Purchases | Add-to-Cart Rate (%) | Purchase Rate (%) |
|--------|--------------|-------------|-----------|----------------------|------------------:|
| 201701 | 25,787       | 7,342       | 2,143     | 28.47                | 8.31             |
| 201702 | 21,489       | 7,360       | 2,060     | 34.25                | 9.59             |
| 201703 | 23,549       | 8,782       | 2,977     | 37.29                | 12.64            |


</details>

## 🔎 Final Conclusion & Recommendations  

👉🏻 Based on the insights and findings above, we would recommend the stakeholder team to consider the following:    
✔️ Visits are stable in Q1 2017, while transactions rose and improved the conversion rate from 1.10% to 1.42%.   
✔️ Google has a high number of visits but also a very high bounce rate, while YouTube had the worst engagement (66.73% bounce rate). Reddit had the lowest (28.57%), showing better content relevance.   
✔️ Although the Average Pageviews of Purchase increased by 32% (from 94 to 124), the Average Pageviews of Non-Purchase remain high (from 94 to 124), indicating that customers are struggling to find suitable products and      make purchasing decisions.  
✔️ Add-to-cart rate (28.47% → 37.29%) and purchase rate (8.31% → 12.64%) steadily improved in Q1 2017, signaling better conversion efficiency.   

📌 Key Takeaways:  
✔️ Conduct surveys or phone calls to understand customers better to improve the landing page.  
✔️ Simplify navigation and optimize the payment process to increase the number of buyers.  
✔️ Create attractive banners and promotional vouchers for products, coupled with solutions for cart abandonment to increase add-to-cart and purchase rates.  
