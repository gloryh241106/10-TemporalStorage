/*
CSC12003 | Nhom 10 | Chu de 8 | Hoang (TV1) | G1 baseline v4 (one ProductID)
TARGET: Microsoft SQL Server 2016+; chay bang SSMS hoac sqlcmd (GO la batch separator).
CONG DUNG: tao database/schema, Product, hai bang gia CHUA temporal, seed R0.
KHONG tao trigger / history / period columns / SYSTEM_VERSIONING.
AN TOAN: khong DROP, khong reset; neu gap du lieu da co ma thieu marker thi STOP.
CHU Y: dung tren instance thu nghiem; sao luu neu database cung ten da ton tai.
Ban V4 da sua schema, CHUA duoc chay xac minh trong phien cap nhat nay.
*/
SET NOCOUNT ON;
GO
IF TRY_CONVERT(INT, SERVERPROPERTY('ProductMajorVersion')) < 13
    THROW 52000, N'Can SQL Server 2016 (13.x) hoac moi hon.', 1;
GO
USE [master];
GO
IF DB_ID(N'TemporalSeminarDB') IS NULL
    EXEC(N'CREATE DATABASE [TemporalSeminarDB]');
GO
USE [TemporalSeminarDB];
GO
-- Neu DB da co baseline V3: chay 02_migrate_v3_to_v4_once.sql TRUOC khi setup V4.
-- Script nay khong tu dong DROP cot/constraint cua database da ton tai.
IF COL_LENGTH(N'dbo.Product', N'ProductCode') IS NOT NULL
    THROW 52002, N'Phat hien schema V3 (ProductCode). Chay migration 02_migrate_v3_to_v4_once.sql truoc.', 1;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
IF SCHEMA_ID(N'demo') IS NULL EXEC(N'CREATE SCHEMA [demo]');
GO
IF OBJECT_ID(N'dbo.Product', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Product (
        ProductID INT NOT NULL,
        ProductName NVARCHAR(100) NOT NULL,
        Category NVARCHAR(60) NOT NULL,
        CONSTRAINT PK_Product PRIMARY KEY (ProductID)
    );
END;
GO
IF OBJECT_ID(N'demo.ProductPrice_Manual', N'U') IS NULL
BEGIN
    CREATE TABLE demo.ProductPrice_Manual (
        ProductID INT NOT NULL,
        UnitPrice DECIMAL(12,2) NOT NULL,
        CurrencyCode CHAR(3) NOT NULL CONSTRAINT DF_Manual_Currency DEFAULT ('VND'),
        PriceNote NVARCHAR(120) NULL,
        CONSTRAINT PK_Price_Manual PRIMARY KEY (ProductID),
        CONSTRAINT FK_Price_Manual_Product FOREIGN KEY (ProductID) REFERENCES dbo.Product(ProductID),
        CONSTRAINT CK_Price_Manual_NonNegative CHECK (UnitPrice >= 0)
    );
END;
GO
IF OBJECT_ID(N'demo.ProductPrice_Native', N'U') IS NULL
BEGIN
    CREATE TABLE demo.ProductPrice_Native (
        ProductID INT NOT NULL,
        UnitPrice DECIMAL(12,2) NOT NULL,
        CurrencyCode CHAR(3) NOT NULL CONSTRAINT DF_Native_Currency DEFAULT ('VND'),
        PriceNote NVARCHAR(120) NULL,
        CONSTRAINT PK_Price_Native PRIMARY KEY (ProductID),
        CONSTRAINT FK_Price_Native_Product FOREIGN KEY (ProductID) REFERENCES dbo.Product(ProductID),
        CONSTRAINT CK_Price_Native_NonNegative CHECK (UnitPrice >= 0)
    );
END;
GO
IF OBJECT_ID(N'demo.SeedState', N'U') IS NULL
BEGIN
    CREATE TABLE demo.SeedState (
        SetupKey NVARCHAR(40) NOT NULL CONSTRAINT PK_SeedState PRIMARY KEY,
        SeededAtUtc DATETIME2(7) NOT NULL CONSTRAINT DF_Seed_At DEFAULT SYSUTCDATETIME()
    );
END;
GO
IF NOT EXISTS (SELECT 1 FROM demo.SeedState WHERE SetupKey = N'TV1_BASELINE_V4')
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Product)
       OR EXISTS (SELECT 1 FROM demo.ProductPrice_Manual)
       OR EXISTS (SELECT 1 FROM demo.ProductPrice_Native)
       OR EXISTS (SELECT 1 FROM demo.SeedState)
    BEGIN
        THROW 52001, N'Da co du lieu/moc seed khac V4. Khong ghi de. Hay su dung database thu nghiem moi.', 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.Product (ProductID, ProductName, Category) VALUES
          (101,N'Cà phê sữa đá',N'Đồ uống'),
          (102,N'Trà đào cam sả',N'Đồ uống'),
          (103,N'Bánh mì thịt',N'Thức ăn'),
          (104,N'Matcha latte',N'Đồ uống'),
          (105,N'Bánh quy bơ',N'Thức ăn');

        INSERT INTO demo.ProductPrice_Manual (ProductID,UnitPrice,CurrencyCode,PriceNote) VALUES
          (101,25000.00,'VND',N'Giá khởi tạo'),
          (102,25000.00,'VND',N'Giá khởi tạo'),
          (103,28000.00,'VND',N'Giá khởi tạo'),
          (104,45000.00,'VND',N'Giá khởi tạo');

        INSERT INTO demo.ProductPrice_Native (ProductID,UnitPrice,CurrencyCode,PriceNote) VALUES
          (101,25000.00,'VND',N'Giá khởi tạo'),
          (102,25000.00,'VND',N'Giá khởi tạo'),
          (103,28000.00,'VND',N'Giá khởi tạo'),
          (104,45000.00,'VND',N'Giá khởi tạo');

        INSERT INTO demo.SeedState (SetupKey) VALUES (N'TV1_BASELINE_V4');
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Quan sat: KHONG phai reset / khong tu tao History.
SELECT N'Product' AS TableName, COUNT(*) AS RecordTotal FROM dbo.Product
UNION ALL SELECT N'Price_Manual',COUNT(*) FROM demo.ProductPrice_Manual
UNION ALL SELECT N'Price_Native',COUNT(*) FROM demo.ProductPrice_Native;
GO
SELECT p.ProductID, p.ProductName,
       m.UnitPrice AS ManualPrice, n.UnitPrice AS NativePrice,
       CASE
           WHEN m.ProductID IS NULL AND n.ProductID IS NULL THEN N'BOTH_MISSING'
           WHEN m.ProductID IS NULL THEN N'ONLY_NATIVE'
           WHEN n.ProductID IS NULL THEN N'ONLY_MANUAL'
           WHEN m.UnitPrice=n.UnitPrice AND m.CurrencyCode=n.CurrencyCode
                AND (m.PriceNote=n.PriceNote OR (m.PriceNote IS NULL AND n.PriceNote IS NULL))
                THEN N'MATCH'
           ELSE N'DIFF'
       END AS CompareStatus
FROM dbo.Product AS p
LEFT JOIN demo.ProductPrice_Manual AS m ON p.ProductID=m.ProductID
LEFT JOIN demo.ProductPrice_Native AS n ON p.ProductID=n.ProductID
ORDER BY p.ProductID;
GO
