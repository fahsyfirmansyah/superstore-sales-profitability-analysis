CREATE DATABASE IF NOT EXISTS store;
USE store;

CREATE TABLE superstore (
    RowID INT,
    OrderID VARCHAR(50),
    OrderDate VARCHAR(50),       
    ShipDate VARCHAR(50),
    ShipMode VARCHAR(50),
    CustomerID VARCHAR(50),
    CustomerName VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    PostalCode INT,
    Region VARCHAR(50),
    ProductID VARCHAR(50),
    Category VARCHAR(50),
    SubCategory VARCHAR(50),
    ProductName VARCHAR(255),
    Sales DECIMAL(10, 2),
    Quantity INT,
    Discount DECIMAL(4, 2),
    Profit DECIMAL(10, 2),
    OrderMonth INT,
    OrderYear INT,
    ShippingDays INT,
    DiscountBucket VARCHAR(50)
);

-- Import file melalui file manager
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Superstore 001_SQL.csv'
INTO TABLE superstore
FIELDS TERMINATED BY ';' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Menghitung jumlah rows data yang diinput
SELECT COUNT(*) AS total_rows
	FROM superstore;

-- Validasi tanggal
SELECT
    MIN(OrderDate) AS earliest_order,
    MAX(OrderDate) AS latest_order,
    MIN(ShipDate) AS earliest_ship,
    MAX(ShipDate) AS latest_ship,
    SUM(CASE
            WHEN ShipDate < OrderDate THEN 1
            ELSE 0
        END) AS invalid_ship_dates
FROM superstore;

-- Periksa contoh tanggal (dilakukan jika validasi tangal terdapat error)
SELECT
    OrderID,
    OrderDate,
    ShipDate
FROM superstore
LIMIT 20;

-- Uji konversi tanggal (dilakukan jika validasi tangal terdapat error)
SELECT
    OrderID,
    OrderDate,
    STR_TO_DATE(OrderDate, '%d/%m/%Y %H.%i')
        AS OrderDate_Converted,
    ShipDate,
    STR_TO_DATE(ShipDate, '%d/%m/%Y %H.%i')
        AS ShipDate_Converted
FROM superstore
LIMIT 20;

-- Validasi seluruh tanggal yang dikonversi (dilakukan jika validasi tangal terdapat error)
SELECT
    COUNT(*) AS TotalRows,

    SUM(
        OrderDate IS NULL
        OR STR_TO_DATE(OrderDate, '%d/%m/%Y %H.%i') IS NULL
    ) AS InvalidOrderDates,

    SUM(
        ShipDate IS NULL
        OR STR_TO_DATE(ShipDate, '%d/%m/%Y %H.%i') IS NULL
    ) AS InvalidShipDates,

    MIN(STR_TO_DATE(OrderDate, '%d/%m/%Y %H.%i'))
        AS EarliestOrder,

    MAX(STR_TO_DATE(OrderDate, '%d/%m/%Y %H.%i'))
        AS LatestOrder,

    MIN(STR_TO_DATE(ShipDate, '%d/%m/%Y %H.%i'))
        AS EarliestShip,

    MAX(STR_TO_DATE(ShipDate, '%d/%m/%Y %H.%i'))
        AS LatestShip,

    SUM(
        STR_TO_DATE(ShipDate, '%d/%m/%Y %H.%i')
        < STR_TO_DATE(OrderDate, '%d/%m/%Y %H.%i')
    ) AS ShipBeforeOrder

FROM superstore; 

-- Membuat kolom sementara untuk format tanggal yang dikonversikan (dilakukan jika validasi tangal terdapat error)
ALTER TABLE superstore 
ADD COLUMN OrderDate_new DATE,
ADD COLUMN ShipDate_new DATE;
   
-- 1. Matikan safe update mode sementara
SET SQL_SAFE_UPDATES = 0;

-- 2. Update kedua kolom untuk seluruh baris sekaligus (dilakukan jika validasi tangal terdapat error)
UPDATE superstore 
SET OrderDate_new = STR_TO_DATE(OrderDate, '%d/%m/%Y %H.%i'),
    ShipDate_new  = STR_TO_DATE(ShipDate, '%d/%m/%Y %H.%i');
    
-- 3. Nyalakan kembali safe update mode
SET SQL_SAFE_UPDATES = 1;

describe superstore;

SELECT 
    COUNT(*) AS TotalRows,
    SUM(OrderDate_new IS NULL) AS FailedOrderConversions,
    SUM(ShipDate_new IS NULL) AS FailedShipConversions
FROM superstore;

SELECT OrderDate, ShipDate FROM superstore;

-- Mengganti nama kolom lama sebagai arsip, lalu menaikkan status kolom baru
ALTER TABLE superstore 
RENAME COLUMN OrderDate TO OrderDate_string,
RENAME COLUMN OrderDate_new TO OrderDate;

ALTER TABLE superstore 
RENAME COLUMN ShipDate TO ShipDate_string,
RENAME COLUMN ShipDate_new TO ShipDate;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ANALISIS

-- Validasi jumlah baris
SELECT COUNT(*) AS total_rows
FROM superstore;

-- Validasi missing value
SELECT
    SUM(CASE WHEN OrderID IS NULL THEN 1 ELSE 0 END)
        AS missing_order_id,
    SUM(CASE WHEN OrderDate IS NULL THEN 1 ELSE 0 END)
        AS missing_order_date,
    SUM(CASE WHEN ShipDate IS NULL THEN 1 ELSE 0 END)
        AS missing_ship_date,
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END)
        AS missing_sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END)
        AS missing_profit
FROM superstore;

-- Periksa duplikasi data
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT RowID) AS unique_row_ids
FROM superstore;

-- Validasi tanggal
SELECT
    MIN(OrderDate) AS earliest_order,
    MAX(OrderDate) AS latest_order,
    MIN(ShipDate) AS earliest_ship,
    MAX(ShipDate) AS latest_ship,
    SUM(
		CASE
            WHEN ShipDate < OrderDate THEN 1
            ELSE 0
        END) AS invalid_ship_dates
FROM superstore;

-- Rekonsiliasi KPI dengan Excel
SELECT
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    SUM(Quantity) AS total_quantity,
    COUNT(DISTINCT OrderID) AS total_orders,
    ROUND(
		100.0 * SUM(Profit)
        / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore;

-- 1. Annual Sales Trend Analysis-------------------------------------------------------------------------------------------------------------------------------------
-- Sales, Profit, dan Margin per Tahun
SELECT
    YEAR(OrderDate) AS order_year,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    SUM(Quantity) AS total_quantity,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY YEAR(OrderDate)
ORDER BY order_year;

-- Pertumbuhan sales dan profit
WITH 
yearly AS (
    SELECT
        YEAR(OrderDate) AS order_year,
        SUM(Sales) AS total_sales,
        SUM(Profit) AS total_profit
    FROM superstore
    GROUP BY YEAR(OrderDate)
),
yearly_comparison AS (
    SELECT
        order_year,
        total_sales,
        total_profit,
        LAG(total_sales) OVER (
            ORDER BY order_year
        ) AS previous_sales,
        LAG(total_profit) OVER (
            ORDER BY order_year
        ) AS previous_profit
    FROM yearly
)
SELECT
    order_year,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(
        100.0 * (total_sales - previous_sales)
        / NULLIF(previous_sales, 0),
        2
    ) AS sales_growth_pct,
    ROUND(
        100.0 * (total_profit - previous_profit)
        / NULLIF(ABS(previous_profit), 0),
        2
    ) AS profit_change_pct
FROM yearly_comparison
ORDER BY order_year;

-- 2. Product & Category Profitability Analysis-----------------------------------------------------------------------------------------------------------------------
-- Performa kategori dan sub-kategori
SELECT
    Category,
    SubCategory,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    SUM(Quantity) AS total_quantity,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY Category, SubCategory
ORDER BY total_profit ASC;

-- Top 10 produk dengan profit tertinggi
SELECT
    ProductID,
    ProductName,
    Category,
    SubCategory,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY
	ProductID,
    ProductName,
    Category,
    SubCategory
ORDER BY total_profit DESC
LIMIT 10;

-- Top 10 peoduk dengan kerugian terbesar
SELECT
	ProductID,
    ProductName,
    Category,
    SubCategory,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit
FROM superstore
GROUP BY
    ProductID,
    ProductName,
    Category,
    SubCategory
HAVING SUM(Profit) < 0
ORDER BY total_profit ASC
LIMIT 10;

-- 3. Discount & Profitability Analysis-------------------------------------------------------------------------------------------------------------------------------
-- Performa untuk setiap tingkat discount
SELECT
    Discount,
    COUNT(*) AS transaction_rows,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY Discount
ORDER BY Discount;

-- Kelompok discount
WITH discount_analysis AS (
    SELECT
        CASE
            WHEN Discount = 0 THEN '0%'
            WHEN Discount <= 0.20 THEN '>0%-20%'
            WHEN Discount <= 0.30 THEN '>20%-30%'
            ELSE '>30%'
        END AS discount_group,
        Discount,
        Sales,
        Profit
    FROM superstore
)
SELECT
    discount_group,
    COUNT(*) AS transaction_rows,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM discount_analysis
GROUP BY discount_group
ORDER BY MIN(Discount);

-- Periksa kategori dan subkategori pada diskon tinggi
SELECT
    Category,
    SubCategory,
    Discount,
    COUNT(*) AS transaction_rows,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
WHERE Discount > 0.20
GROUP BY
    Category,
    SubCategory,
    Discount
ORDER BY total_profit ASC;

-- 4. Regional Performance Analysis-----------------------------------------------------------------------------------------------------------------------------------
-- Performa setiap wilayah
SELECT
    Region,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    SUM(Quantity) AS total_quantity,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(Discount) * 100, 2) AS avg_discount_pct
FROM superstore
GROUP BY Region
ORDER BY total_profit DESC;

-- Pendalaman berdasarkan wilayah dan kategori
SELECT
    Region,
    Category,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY Region, Category
ORDER BY Region, total_profit ASC;

-- 5. Customer Segment Analysis---------------------------------------------------------------------------------------------------------------------------------------
-- Performa segmen pelanggan
SELECT
    Segment,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    SUM(Quantity) AS total_quantity,
    COUNT(DISTINCT OrderID) AS total_orders,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY Segment
ORDER BY total_sales DESC;

-- Pendalaman segmen dan diskon
SELECT
    Segment,
    Discount,
    COUNT(*) AS transaction_rows,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY Segment, Discount
ORDER BY Segment, Discount;

-- 6. Analisis Lanjutan-----------------------------------------------------------------------------------------------------------------------------------------------
-- Periksa dampak diskon per kategori dan subkategori
SELECT
    Category,
    SubCategory,
    CASE
        WHEN Discount = 0 THEN '0% - No Discount'
        WHEN Discount <= 0.20 THEN '>0% - 20%'
        WHEN Discount <= 0.30 THEN '>20% - 30%'
        ELSE '>30%'
    END AS discount_group,
    COUNT(*) AS transaction_rows,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY
    Category,
    SubCategory,
    CASE
        WHEN Discount = 0 THEN '0% - No Discount'
        WHEN Discount <= 0.20 THEN '>0% - 20%'
        WHEN Discount <= 0.30 THEN '>20% - 30%'
        ELSE '>30%'
    END
ORDER BY
    Category,
    SubCategory,
    MIN(Discount);
    
-- Penyebab margin rendah di central
SELECT
    SubCategory,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct,
    ROUND(AVG(Discount) * 100, 2) AS avg_discount_pct
FROM superstore
WHERE Region = 'Central'
GROUP BY SubCategory
ORDER BY total_profit ASC;

-- Bandingkan margin tiap segmen dan kategori

SELECT
    Segment,
    Category,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
GROUP BY Segment, Category
ORDER BY Segment, total_profit ASC;

-- Produk merugi di Central dengan diskon di atas 20%
SELECT
    ProductID,
    ProductName,
    Category,
    SubCategory,
    Discount,
    COUNT(*) AS transaction_rows,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0),
        2
    ) AS profit_margin_pct
FROM superstore
WHERE Region = 'Central'
  AND Discount > 0.20
GROUP BY
  ProductID,
    ProductName,
    Category,
    SubCategory,
    Discount
HAVING SUM(Profit) < 0
ORDER BY total_profit ASC
LIMIT 15;



