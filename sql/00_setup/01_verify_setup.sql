/*
CSC12003 TV1 G1 – BASELINE V4 PRE-FLIGHT (read-only).
CHAY CHI SAU setup va TRUOC Trigger, Temporal native hoac bat ky DML demo nao.
Expected: Product exact 5, Price exact 4/4, two prices identical, 105 unpriced.
Khong duoc hieu PASS la da thuc thi trong moi truong tao tai lieu: can chay tai SSMS.
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;
DECLARE @Products TABLE (ProductID INT PRIMARY KEY, ProductName NVARCHAR(100), Category NVARCHAR(60));
INSERT INTO @Products VALUES
(101,N'Cà phê sữa đá',N'Đồ uống'),
(102,N'Trà đào cam sả',N'Đồ uống'),
(103,N'Bánh mì thịt',N'Thức ăn'),
(104,N'Matcha latte',N'Đồ uống'),
(105,N'Bánh quy bơ',N'Thức ăn');

DECLARE @Prices TABLE (ProductID INT PRIMARY KEY, UnitPrice DECIMAL(12,2), CurrencyCode CHAR(3), PriceNote NVARCHAR(120));
INSERT INTO @Prices VALUES
(101,25000.00,'VND',N'Giá khởi tạo'),
(102,25000.00,'VND',N'Giá khởi tạo'),
(103,28000.00,'VND',N'Giá khởi tạo'),
(104,45000.00,'VND',N'Giá khởi tạo');

IF OBJECT_ID(N'dbo.Product',N'U') IS NULL
   OR OBJECT_ID(N'demo.ProductPrice_Manual',N'U') IS NULL
   OR OBJECT_ID(N'demo.ProductPrice_Native',N'U') IS NULL
   OR OBJECT_ID(N'demo.SeedState',N'U') IS NULL
    THROW 52100,N'Thieu bang nen TV1.',1;

IF COL_LENGTH(N'dbo.Product', N'ProductCode') IS NOT NULL
    THROW 52109,N'Schema cu van co ProductCode; chay migration V3 -> V4.',1;

IF NOT EXISTS(SELECT 1 FROM demo.SeedState WHERE SetupKey=N'TV1_BASELINE_V4')
   OR (SELECT COUNT(*) FROM demo.SeedState)<>1
    THROW 52101,N'Marker V4 khong hop le.',1;

IF EXISTS(SELECT ProductID,ProductName,Category FROM @Products
          EXCEPT SELECT ProductID,ProductName,Category FROM dbo.Product)
   OR EXISTS(SELECT ProductID,ProductName,Category FROM dbo.Product
          EXCEPT SELECT ProductID,ProductName,Category FROM @Products)
    THROW 52102,N'Danh muc Product khong dung baseline theo tung dong.',1;

IF EXISTS(SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM @Prices
          EXCEPT SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM demo.ProductPrice_Manual)
   OR EXISTS(SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM demo.ProductPrice_Manual
          EXCEPT SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM @Prices)
    THROW 52103,N'Bang Manual khong dung baseline theo tung dong.',1;

IF EXISTS(SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM @Prices
          EXCEPT SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM demo.ProductPrice_Native)
   OR EXISTS(SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM demo.ProductPrice_Native
          EXCEPT SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM @Prices)
    THROW 52104,N'Bang Native khong dung baseline theo tung dong.',1;

IF EXISTS(SELECT 1 FROM sys.tables
          WHERE object_id IN(OBJECT_ID(N'demo.ProductPrice_Manual'), OBJECT_ID(N'demo.ProductPrice_Native'))
            AND temporal_type<>0)
    THROW 52105,N'Da bat temporal; script nay chi kiem tra G1 truoc demo.',1;

IF EXISTS(SELECT 1 FROM sys.triggers
          WHERE parent_id IN(OBJECT_ID(N'demo.ProductPrice_Manual'),OBJECT_ID(N'demo.ProductPrice_Native')))
    THROW 52106,N'Da co Trigger tren bang gia; chay verify truoc G2.',1;

IF OBJECT_ID(N'demo.ProductPrice_ManualHistory',N'U') IS NOT NULL
    THROW 52107,N'History thu cong da duoc tao; khong con trang thai G1.',1;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN
      (OBJECT_ID(N'demo.ProductPrice_Manual'), OBJECT_ID(N'demo.ProductPrice_Native')))<>2
    THROW 52108,N'Thieu hoac thua FK trong hai bang gia.',1;

SELECT N'PASS G1 - TV1 baseline V4 khop tung dong; 5 Product, 4 Manual, 4 Native, ProductID=105 chua co gia' AS VerificationResult;
SELECT ProductID,UnitPrice,CurrencyCode,PriceNote FROM demo.ProductPrice_Manual ORDER BY ProductID;
GO
