



---
<p align="center">
  <img src="https://github.com/user-attachments/assets/b560b5c5-7f8d-4bd3-bdea-28e6720e0c90" alt="Brown-Jersey-Ultimo" width="400">
</p>





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
This project queries and analyzes order quantity, stock quantity, and sale value to:     
✔️ Identify customer behavior   
✔️ Enhance product performance   
✔️ Improve stock rates  
   
   
### 👤 Who is this project for?  
✔️ Data Analysts & Business Analysts  
✔️ Decision Makers & Stakeholders  



---

## 📂 Dataset Description 

### 📌 Data Source  
- Source: AdventureWorks is a sample of Dataedo documentation from the Microsoft SQL Server sample database.
  
### 📌 Data Dictionary
https://drive.google.com/file/d/1bwwsS3cRJYOg1cvNppc1K_8dQLELN16T/view?usp=sharing



## ⚒️ Main Process

<details>
  <summary> 1. Subcategory Revenue Analysis </summary>
 Calculate the quantity of items, sales value, and order quantity by each Subcategory in the last 12 months.   

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
  <summary> 2. Subcategory Growth Analysis </summary>
Calculate the % YoY growth rate by Subcategory and release the top 3 with the highest growth rate.   

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
WHERE rk <=3
```

Query Result:

| Name            | qty_item                 | prv_qty                   | qty_diff                   |
|-----------------|--------------------------|---------------------------|----------------------------|
| Road Frames     | 5564                     | 1137                      | 3.89                       |
| Mountain Frames | 3168                     | 510                       | 5.21                       |
| Socks           | 2724                     | 523                       | 4.21                       |

</details>


<details>
  <summary> 3. Sale Territory Analysis </summary>
Ranking the top 3 TerritoryID with the biggest order quantity every year.  

```sql
WITH  order_count as(
  SELECT 
    EXTRACT(YEAR FROM detail.ModifiedDate) as yr
    ,header.TerritoryID
    ,sum(detail.OrderQty) as order_cnt
  FROM `adventureworks2019.Sales.SalesOrderDetail` as detail
  LEFT JOIN `adventureworks2019.Sales.SalesOrderHeader` as header 
    ON detail.SalesOrderID = header.SalesOrderID
  GROUP BY yr, header.TerritoryID
) 

,ranking as(
  SELECT
    yr
    ,TerritoryID
    ,order_cnt
    ,DENSE_RANK() OVER(PARTITION BY yr ORDER BY order_cnt DESC) as rk
  FROM order_count
  ORDER BY yr DESC
)

SELECT 
  yr
  ,TerritoryID
  ,order_cnt
  ,rk
FROM ranking
WHERE rk <=3
```

Query Result:

| yr   | Territory ID | order_cnt   | rk |
|------|--------------|-------------|------|
| 2014 | 4            | 11,632      | 1    |
| 2014 | 6            | 9,711       | 2    |
| 2014 | 1            | 8,823       | 3    |
| 2013 | 4            | 26,682      | 1    |
| 2013 | 6            | 22,553      | 2    |
| 2013 | 1            | 17,452      | 3    |
| 2012 | 4            | 17,553      | 1    |
| 2012 | 6            | 14,412      | 2    |
| 2012 | 1            | 8,537       | 3    |


</details>


<details>
  <summary> 4. Seasonal Discount Analysis  </summary>
Calculate the total discount cost of the Seasonal Discount for each Subcategory.  
  
```sql
SELECT 
  Year
  ,Name
  ,SUM(disc_cost) as Total_cost
FROM
  (
  SELECT 
      FORMAT_DATE('%Y', s.ModifiedDate) as Year
      , ps.Name
      , so.DiscountPct
      , s.OrderQty * so.DiscountPct * s.UnitPrice as disc_cost 
      FROM `adventureworks2019.Sales.SalesOrderDetail` as s
      LEFT JOIN `adventureworks2019.Production.Product` as p ON s.ProductID = p.ProductID
      LEFT JOIN `adventureworks2019.Production.ProductSubcategory` ps ON CAST(p.ProductSubcategoryID as int) = ps.ProductSubcategoryID
      LEFT JOIN `adventureworks2019.Sales.SpecialOffer` so ON s.SpecialOfferID = so.SpecialOfferID
      WHERE lower(so.Type) like '%seasonal discount%' 
  )
  GROUP BY Year, Name
```

Query Result:
| Year | Product | Total_cost |
|------|---------|------------|
| 2012 | Helmets | 827.65     |
| 2013 | Helmets | 1606.04    |


</details>



<details>
  <summary> 5. Retention Rate Analysis </summary>
Retention rate of customers in 2014 with status of Successfully Shipped.     
  
```sql
WITH info as(
  SELECT 
    EXTRACT(MONTH FROM ModifiedDate) as month_no
    ,EXTRACT(YEAR FROM ModifiedDate) as year_no
    ,CustomerID
  FROM `adventureworks2019.Sales.SalesOrderHeader`
  WHERE status = 5 AND FORMAT_DATE("%Y", ModifiedDate) = '2014'
  GROUP BY 1, 2, 3
  ORDER BY 3,1
)

,rn as(           ---đánh số thứ tự các tháng họ mua hàng
  SELECT
   month_no
   ,CustomerID
   ,ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY month_no) as row_num
  FROM info
)

,first_month as(           ---lấy ra tháng đầu tiên của từng khách
  SELECT 
    month_no as month_join
    ,customerID
  FROM rn
  WHERE row_num = 1
)

,month_gap as(
  SELECT 
    a.month_no as month_order
    ,a.CustomerID
    ,b.month_join
    ,CONCAT("M","-", a.month_no - b.month_join) as month_diff
  FROM info a
  LEFT JOIN first_month b
  ON a.CustomerID = b.CustomerID
  ORDER BY 2,1
)

SELECT 
  month_join
  ,month_diff
  ,COUNT(DISTINCT CustomerID) customer_cnt
FROM month_gap
GROUP BY 1, 2
ORDER BY 1, 2
```
Query Result:

| month_join   | month_diff       | customer_cnt   |
|--------------|------------------|----------------|
| 1            | M-0              | 2076           |
| 1            | M-1              | 78             |
| 1            | M-2              | 89             |
| 1            | M-3              | 252            |
| 1            | M-4              | 96             |
| 1            | M-5              | 61             |
| 1            | M-6              | 18             |
| 2            | M-0              | 1805           |
| 2            | M-1              | 51             |
| 2            | M-2              | 61             |


</details>

<details>
  <summary>6. Monthly Stock Analysis </summary>
Trend of Stock level and MoM diff %  by all products in 2011.  
  
```sql
WITH stock_qty_2011 as(
  SELECT 
    p.Name
      ,FORMAT_DATE('%m', w.ModifiedDate) as mth
      ,FORMAT_DATE('%Y', w.ModifiedDate) as yr
      ,SUM(w.StockedQty) stock_qty
  FROM `adventureworks2019.Production.Product` as p
  LEFT JOIN `adventureworks2019.Production.WorkOrder` as w
    ON p.ProductID = w.ProductID
  WHERE FORMAT_DATE('%Y', w.ModifiedDate) = '2011'
  GROUP BY 1,2,3
  ORDER BY 1,2
)

,stock_qty_prv_mth as(
  SELECT
    Name 
    ,mth 
    ,yr
    ,stock_qty 
    ,LAG(stock_qty) OVER(PARTITION BY Name ORDER BY mth) as stock_prv 
  FROM stock_qty_2011
  ORDER BY 1,2
)

SELECT 
  Name 
  ,mth 
  ,yr 
  ,stock_qty
  ,stock_prv
  ,CASE WHEN stock_prv != 0 THEN ROUND(100 * (stock_qty - stock_prv) / stock_prv, 1)
   ELSE 0 END AS diff
FROM stock_qty_prv_mth
ORDER BY 1,2 DESC

```
Query Result:
| Name             | mth   | y  r | stock_qty| stock_prv         | diff     |
|------------------|-------|------|----------|-------------------|----------|
| BB Ball Bearing  | 12    | 2011 | 8475     | 14544             | -41.7    |
| BB Ball Bearing  | 11    | 2011 | 14544    | 19175             | -24.2    |
| BB Ball Bearing  | 10    | 2011 | 19175    | 8845              | 116.8    |
| BB Ball Bearing  | 09    | 2011 | 8845     | 9666              | -8.5     |
| BB Ball Bearing  | 08    | 2011 | 9666     | 12837             | -24.7    |
| BB Ball Bearing  | 07    | 2011 | 12837    | 5259              | 144.1    |
| BB Ball Bearing  | 06    | 2011 | 5259     | null              | 0.0      |
| Blade            | 12    | 2011 | 1842     | 3598              | -48.8    |
| Blade            | 11    | 2011 | 3598     | 4670              | -23.0    |
| Blade            | 10    | 2011 | 4670     | 2122              | 120.1    |


</details>



<details>
  <summary> 7. Product Stock Ratio Analysis  </summary>
Calculate the ratio of Stock / Sales in 2011 by product name, and by month.
  
```sql
WITH
  sale_info as (
    SELECT 
      EXTRACT(MONTH FROM a.ModifiedDate) as mth,
      EXTRACT(YEAR FROM a.ModifiedDate) as yr,
      a.ProductId,
      b.Name,
      SUM(a.OrderQty) as sales
    FROM `adventureworks2019.Sales.SalesOrderDetail` as a
    LEFT JOIN `adventureworks2019.Production.Product` as b
      ON a.ProductID = b.ProductID
    WHERE FORMAT_TIMESTAMP("%Y", a.ModifiedDate) = '2011'
    GROUP BY 1, 2, 3, 4
  )

  ,stock_info as (
    SELECT
      EXTRACT(MONTH FROM ModifiedDate) as mth,
      EXTRACT(YEAR FROM ModifiedDate) as yr,
      ProductId,
      SUM(StockedQty) as stock_cnt
    FROM `adventureworks2019.Production.WorkOrder`
    WHERE FORMAT_TIMESTAMP("%Y", ModifiedDate) = '2011'
    GROUP BY 1, 2, 3
  )

SELECT
  a.*,
  b.stock_cnt as stock,  
  ROUND(COALESCE(b.stock_cnt, 0) / sales, 2) as ratio
FROM sale_info as a
FULL JOIN stock_info as b
  ON a.ProductId = b.ProductId
  AND a.mth = b.mth
  AND a.yr = b.yr
ORDER BY 1 DESC, 7 DESC
```
Query Result:


| mth   | yr   | ProductId       | Name                         | sales | stock | ratio  |
|-------|------|------------|-----------------------------------|-------|-------|--------|
| 12    | 2011 | 745        | HL Mountain Frame - Black, 48     | 1     | 27    | 27.00  |
| 12    | 2011 | 743        | HL Mountain Frame - Black, 42     | 1     | 26    | 26.00  |
| 12    | 2011 | 748        | HL Mountain Frame - Silver, 38    | 2     | 32    | 16.00  |
| 12    | 2011 | 722        | LL Road Frame - Black, 58         | 4     | 47    | 11.75  |
| 12    | 2011 | 747        | HL Mountain Frame - Black, 38     | 3     | 31    | 10.33  |

</details>


<details>
  <summary> 8. Pending Order Analysis </summary>
Number of orders and value at Pending status in 2014.

```sql  
SELECT 
  EXTRACT(YEAR FROM ModifiedDate) yr
  ,Status
  ,COUNT(DISTINCT PurchaseOrderID) order_cnt 
  ,SUM(TotalDue) value
FROM `adventureworks2019.Purchasing.PurchaseOrderHeader`
WHERE EXTRACT(YEAR FROM ModifiedDate) = 2014
AND Status = 1
GROUP BY 1, 2
```
Query Result:
| yr   | Status       | order_cnt   | value              |
|------|--------------|-------------|--------------------|
| 2014 | 1            | 224         | 3,873,579.012      |

</details>


## 🔎 Final Conclusion & Recommendations  

👉🏻 Based on the insights and findings above, we would recommend the stakeholder team to consider the following:    

✔️ Mountain Bikes had the highest revenue ($14,191,949) in the past 12 months, with 12,572 units sold — more than three times the number of orders (3,755).    
✔️ Southwest had the highest number of orders from 2011 to 2014 but experienced a sharp decline in order quantity in 2014 (26,682 -> 11,632).   
✔️ The number of pending orders (224), accounting for 10% of total orders, is acceptable. However, specific actions are needed to reduce this rate to 5–7%.   
 
📌 Key Takeaways:  

✔️ Focus on high-revenue bestsellers and balance inventory levels for each product.    
✔️ Investigate the reasons behind the sharp decline in orders from Southwest, then propose solutions to address the issue.   
✔️ Identify the main reasons for pending orders — whether due to system errors, internal issues, or external factors (e.g., unconfirmed orders or missing customer information). In addition, optimize production and logistics processes.   
