--query1

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
ORDER BY period DESC, ps.Name;

--query2

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

--query3

WITH  order_count as(
  SELECT 
    EXTRACT(YEAR FROM detail.ModifiedDate) as yr
    ,header.TerritoryID
    ,sum(detail.OrderQty) as order_cnt
  FROM `adventureworks2019.Sales.SalesOrderDetail` detail
  LEFT JOIN `adventureworks2019.Sales.SalesOrderHeader` header 
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
WHERE rk <=3;

--query4

SELECT Year
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
  GROUP BY Year, Name;

--query5

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
ORDER BY 1, 2;

--query6

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
ORDER BY 1,2 DESC;

--query7

WITH sale_num as(
  SELECT  
    EXTRACT(MONTH FROM s.ModifiedDate) mth
    ,EXTRACT(YEAR FROM s.ModifiedDate) yr
    ,s.ProductID as ProductID
    ,p.Name Name
    ,SUM(s.OrderQty) sales
  FROM `adventureworks2019.Sales.SalesOrderDetail` s
  LEFT JOIN `adventureworks2019.Production.Product` p
    ON s.ProductID=p.ProductID
  WHERE EXTRACT(YEAR FROM s.ModifiedDate) = 2011
  GROUP BY 1, 2 ,3, 4
)

, stock_num as(
  SELECT 
    EXTRACT(MONTH FROM ModifiedDate) mth
    ,EXTRACT(YEAR FROM ModifiedDate) yr
    ,ProductID
    ,SUM(StockedQty) stock_cnt
  FROM `adventureworks2019.Production.WorkOrder` 
  WHERE EXTRACT(YEAR FROM ModifiedDate) = 2011
  GROUP BY 1, 2, 3
)

SELECT 
  sa.mth
  ,sa.yr
  ,sa.ProductID
  ,sa.Name
  ,sa.sales
  ,st.stock_cnt as stock
  ,ROUND(COALESCE(st.stock_cnt,0)/sa.sales,1) ratio
FROM sale_num as sa
LEFT JOIN stock_num as st
  ON sa.ProductID = st.ProductID
  AND sa.mth= st.mth
  AND sa.yr= st.yr
ORDER BY 1 DESC,7 DESC;

--query8

SELECT 
  EXTRACT(YEAR FROM ModifiedDate) yr
  ,Status
  ,COUNT(DISTINCT PurchaseOrderID) order_cnt 
  ,SUM(TotalDue) value
FROM `adventureworks2019.Purchasing.PurchaseOrderHeader`
WHERE EXTRACT(YEAR FROM ModifiedDate) = 2014
AND Status = 1
GROUP BY 1, 2








