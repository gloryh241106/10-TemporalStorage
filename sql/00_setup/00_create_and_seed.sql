/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV1: Hoang
G1: Create tables and insert initial data in an empty test database
SQL Server 2025 (17.x)
*/

-- 1. Create database
USE master;
GO

IF DB_ID(N'TemporalSeminarDB') IS NULL
    CREATE DATABASE TemporalSeminarDB;
GO

USE TemporalSeminarDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'TemporalSeminarDB'
    THROW 52000, N'Setup must run in TemporalSeminarDB.', 1;

IF @@TRANCOUNT <> 0 OR SCHEMA_ID(N'demo') IS NOT NULL
   OR EXISTS (SELECT 1 FROM sys.objects WHERE is_ms_shipped = 0)
    THROW 52001, N'Setup requires an empty test database and no open transaction.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- CREATE SCHEMA needs its own batch. Keep the DDL and seed in one transaction.
    EXEC(N'CREATE SCHEMA demo AUTHORIZATION dbo;');

    -- 2. Product information
    CREATE TABLE dbo.Product (
        ProductID INT NOT NULL,
        ProductName NVARCHAR(100) NOT NULL,
        Category NVARCHAR(60) NOT NULL,

        CONSTRAINT PK_Product
            PRIMARY KEY (ProductID)
    );

    -- 3. Manual branch: TV2 adds history and triggers in G2
    CREATE TABLE demo.ProductPrice_Manual (
        ProductID INT NOT NULL,
        UnitPrice DECIMAL(12,2) NOT NULL,
        CurrencyCode CHAR(3) NOT NULL DEFAULT 'VND',
        PriceNote NVARCHAR(120) NULL,

        CONSTRAINT PK_Price_Manual
            PRIMARY KEY (ProductID),

        CONSTRAINT FK_Price_Manual_Product
            FOREIGN KEY (ProductID)
            REFERENCES dbo.Product(ProductID),

        CONSTRAINT CK_Price_Manual_NonNegative
            CHECK (UnitPrice >= 0)
    );

    -- 4. Native branch: TV3 adds the period and system-versioning in G2
    CREATE TABLE demo.ProductPrice_Native (
        ProductID INT NOT NULL,
        UnitPrice DECIMAL(12,2) NOT NULL,
        CurrencyCode CHAR(3) NOT NULL DEFAULT 'VND',
        PriceNote NVARCHAR(120) NULL,

        CONSTRAINT PK_Price_Native
            PRIMARY KEY (ProductID),

        CONSTRAINT FK_Price_Native_Product
            FOREIGN KEY (ProductID)
            REFERENCES dbo.Product(ProductID),

        CONSTRAINT CK_Price_Native_NonNegative
            CHECK (UnitPrice >= 0)
    );

    -- 5. Insert R0 data
    INSERT INTO dbo.Product
        (ProductID, ProductName, Category)
    VALUES
        (101, N'Cà phê sữa đá', N'Đồ uống'),
        (102, N'Trà đào cam sả', N'Đồ uống'),
        (103, N'Bánh mì thịt', N'Thức ăn'),
        (104, N'Matcha latte', N'Đồ uống'),
        (105, N'Bánh quy bơ', N'Thức ăn');

    INSERT INTO demo.ProductPrice_Manual
        (ProductID, UnitPrice, CurrencyCode, PriceNote)
    VALUES
        (101, 25000.00, 'VND', N'Giá khởi tạo'),
        (102, 25000.00, 'VND', N'Giá khởi tạo'),
        (103, 28000.00, 'VND', N'Giá khởi tạo'),
        (104, 45000.00, 'VND', N'Giá khởi tạo');

    INSERT INTO demo.ProductPrice_Native
        (ProductID, UnitPrice, CurrencyCode, PriceNote)
    VALUES
        (101, 25000.00, 'VND', N'Giá khởi tạo'),
        (102, 25000.00, 'VND', N'Giá khởi tạo'),
        (103, 28000.00, 'VND', N'Giá khởi tạo'),
        (104, 45000.00, 'VND', N'Giá khởi tạo');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- 6. Verify record counts
SELECT N'Product' AS TableName, COUNT(*) AS RecordTotal
FROM dbo.Product

UNION ALL

SELECT N'Price_Manual', COUNT(*)
FROM demo.ProductPrice_Manual

UNION ALL

SELECT N'Price_Native', COUNT(*)
FROM demo.ProductPrice_Native;
GO

-- 7. Compare initial prices
SELECT
    p.ProductID,
    p.ProductName,
    m.UnitPrice AS ManualPrice,
    n.UnitPrice AS NativePrice,

    CASE
        WHEN m.ProductID IS NULL
             AND n.ProductID IS NULL
            THEN N'BOTH_MISSING'

        WHEN m.ProductID IS NULL
            THEN N'ONLY_NATIVE'

        WHEN n.ProductID IS NULL
            THEN N'ONLY_MANUAL'

        WHEN m.UnitPrice = n.UnitPrice
             AND m.CurrencyCode = n.CurrencyCode
             AND (
                 m.PriceNote = n.PriceNote
                 OR (
                     m.PriceNote IS NULL
                     AND n.PriceNote IS NULL
                 )
             )
            THEN N'MATCH'

        ELSE N'DIFF'
    END AS CompareStatus

FROM dbo.Product AS p
LEFT JOIN demo.ProductPrice_Manual AS m
    ON p.ProductID = m.ProductID
LEFT JOIN demo.ProductPrice_Native AS n
    ON p.ProductID = n.ProductID

ORDER BY p.ProductID;
GO
