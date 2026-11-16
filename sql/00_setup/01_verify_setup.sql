/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV1: Hoang
G1/T0: Verify the V4 baseline on SQL Server 2025
Run after 00_create_and_seed.sql, before G2
*/

USE TemporalSeminarDB;
GO

SET NOCOUNT ON;

IF DB_NAME() <> N'TemporalSeminarDB'
    THROW 52108, N'T0 must run in TemporalSeminarDB.', 1;

IF CONVERT(INT, SERVERPROPERTY('ProductMajorVersion')) <> 17
    THROW 52109, N'Use SQL Server 2025 (17.x) for G1 evidence.', 1;

-- 1. Check required tables
IF OBJECT_ID(N'dbo.Product', N'U') IS NULL
   OR OBJECT_ID(N'demo.ProductPrice_Manual', N'U') IS NULL
   OR OBJECT_ID(N'demo.ProductPrice_Native', N'U') IS NULL
    THROW 52100, N'Missing required tables.', 1;

-- 2. Check simplified Product schema
IF COL_LENGTH(N'dbo.Product', N'ProductCode') IS NOT NULL
    THROW 52101, N'ProductCode should not exist.', 1;

IF OBJECT_ID(N'demo.SeedState', N'U') IS NOT NULL
   OR OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
   OR OBJECT_ID(N'demo.ProductPrice_NativeHistory', N'U') IS NOT NULL
    THROW 52110, N'G1 V4 must not contain a seed marker or price history table.', 1;

-- 3. Check initial record counts
IF (SELECT COUNT(*) FROM dbo.Product) <> 5
   OR (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 4
   OR (SELECT COUNT(*) FROM demo.ProductPrice_Native) <> 4
    THROW 52102, N'Incorrect initial record counts.', 1;

-- 4. Check initial products
IF EXISTS (
    SELECT ProductID, ProductName, Category
    FROM (VALUES
        (101, N'Cà phê sữa đá', N'Đồ uống'),
        (102, N'Trà đào cam sả', N'Đồ uống'),
        (103, N'Bánh mì thịt', N'Thức ăn'),
        (104, N'Matcha latte', N'Đồ uống'),
        (105, N'Bánh quy bơ', N'Thức ăn')
    ) AS Expected(ProductID, ProductName, Category)

    EXCEPT

    SELECT ProductID, ProductName, Category
    FROM dbo.Product
)
    THROW 52103, N'Product data does not match baseline.', 1;

-- 5. Check initial prices
DECLARE @ExpectedPrices TABLE (
    ProductID INT,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120)
);

INSERT INTO @ExpectedPrices VALUES
    (101, 25000, 'VND', N'Giá khởi tạo'),
    (102, 25000, 'VND', N'Giá khởi tạo'),
    (103, 28000, 'VND', N'Giá khởi tạo'),
    (104, 45000, 'VND', N'Giá khởi tạo');

-- Manual branch
IF EXISTS (
    SELECT * FROM @ExpectedPrices
    EXCEPT
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote
    FROM demo.ProductPrice_Manual
)
    THROW 52104, N'Manual price data does not match baseline.', 1;

-- Native branch
IF EXISTS (
    SELECT * FROM @ExpectedPrices
    EXCEPT
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote
    FROM demo.ProductPrice_Native
)
    THROW 52105, N'Native price data does not match baseline.', 1;

-- 6. A period can exist even when system versioning is off.
IF EXISTS (
    SELECT 1
    FROM sys.periods
    WHERE object_id IN (
        OBJECT_ID(N'dbo.Product'),
        OBJECT_ID(N'demo.ProductPrice_Manual'),
        OBJECT_ID(N'demo.ProductPrice_Native')
    )
)
    THROW 52111, N'A system-time period already exists.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.tables
    WHERE object_id IN (
        OBJECT_ID(N'demo.ProductPrice_Manual'),
        OBJECT_ID(N'demo.ProductPrice_Native')
    )
    AND temporal_type <> 0
)
    THROW 52106, N'Temporal versioning is already enabled.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.triggers
    WHERE parent_id IN (
        OBJECT_ID(N'demo.ProductPrice_Manual'),
        OBJECT_ID(N'demo.ProductPrice_Native')
    )
)
    THROW 52107, N'Price triggers already exist.', 1;

-- 7. Verification result and environment for the evidence log
SELECT
    N'PASS G1 / T0 - Baseline V4' AS VerificationResult,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    compatibility_level AS CompatibilityLevel,
    SYSUTCDATETIME() AS VerifiedAtUtc
FROM sys.databases
WHERE database_id = DB_ID();

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote
FROM demo.ProductPrice_Manual
ORDER BY ProductID;
GO
