/*
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script: T0_verify_baseline.sql
Muc dich: Kiem chung baseline truoc khi chay bat ky test nao.
           Chay TRUOC G2 (truoc khi Thuy/Trung gan Trigger/Temporal).
           Ket qua phai PASS – luu screenshot SSMS lam bang chung.
Nguoi chay: Kiet (TV4) – xac nhan voi Hoang
================================================================================
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;

PRINT N'=== T0: KIEM CHUNG BASELINE TRUOC G2 ===';
PRINT N'Thoi diem chay (UTC): ' + CONVERT(NVARCHAR(30), SYSUTCDATETIME(), 126);
PRINT N'';

-- Kiem tra marker V3
IF NOT EXISTS (SELECT 1 FROM demo.SeedState WHERE SetupKey = N'TV1_BASELINE_V3')
BEGIN
    RAISERROR(N'FAIL: Khong tim thay marker TV1_BASELINE_V3 trong demo.SeedState.', 16, 1);
    RETURN;
END
PRINT N'[OK] Marker TV1_BASELINE_V3 ton tai.';

-- Kiem tra so luong Product
DECLARE @ProductCount INT = (SELECT COUNT(*) FROM dbo.Product);
IF @ProductCount <> 5
BEGIN
    RAISERROR(N'FAIL: dbo.Product co %d dong, ky vong 5.', 16, 1, @ProductCount);
    RETURN;
END
PRINT N'[OK] dbo.Product: 5 dong.';

-- Kiem tra so luong gia Manual
DECLARE @ManualCount INT = (SELECT COUNT(*) FROM demo.ProductPrice_Manual);
IF @ManualCount <> 4
BEGIN
    RAISERROR(N'FAIL: ProductPrice_Manual co %d dong, ky vong 4.', 16, 1, @ManualCount);
    RETURN;
END
PRINT N'[OK] demo.ProductPrice_Manual: 4 dong.';

-- Kiem tra so luong gia Native
DECLARE @NativeCount INT = (SELECT COUNT(*) FROM demo.ProductPrice_Native);
IF @NativeCount <> 4
BEGIN
    RAISERROR(N'FAIL: ProductPrice_Native co %d dong, ky vong 4.', 16, 1, @NativeCount);
    RETURN;
END
PRINT N'[OK] demo.ProductPrice_Native: 4 dong.';

-- Kiem tra san pham 105 chua co gia (ca hai nhanh)
IF EXISTS (SELECT 1 FROM demo.ProductPrice_Manual  WHERE ProductID = 105)
   OR EXISTS (SELECT 1 FROM demo.ProductPrice_Native WHERE ProductID = 105)
BEGIN
    RAISERROR(N'FAIL: ProductID 105 da co gia – khong dung baseline R0.', 16, 1);
    RETURN;
END
PRINT N'[OK] ProductID 105 chua co gia (dung R0).';

-- Kiem tra hai nhanh co cung gia
IF EXISTS (
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote FROM demo.ProductPrice_Manual
    EXCEPT
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote FROM demo.ProductPrice_Native
)
OR EXISTS (
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote FROM demo.ProductPrice_Native
    EXCEPT
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote FROM demo.ProductPrice_Manual
)
BEGIN
    RAISERROR(N'FAIL: Hai bang gia khong khop nhau.', 16, 1);
    RETURN;
END
PRINT N'[OK] Hai nhanh Manual/Native co cung du lieu gia.';

-- Kiem tra chua co Trigger
IF EXISTS (
    SELECT 1 FROM sys.triggers
    WHERE parent_id IN (
        OBJECT_ID(N'demo.ProductPrice_Manual'),
        OBJECT_ID(N'demo.ProductPrice_Native')
    )
)
BEGIN
    RAISERROR(N'FAIL: Da co Trigger tren bang gia. Khong chay T0 sau G2.', 16, 1);
    RETURN;
END
PRINT N'[OK] Chua co Trigger tren cac bang gia.';

-- Kiem tra chua co Temporal period
IF EXISTS (
    SELECT 1 FROM sys.tables
    WHERE object_id IN (
        OBJECT_ID(N'demo.ProductPrice_Manual'),
        OBJECT_ID(N'demo.ProductPrice_Native')
    )
    AND temporal_type <> 0
)
BEGIN
    RAISERROR(N'FAIL: Da co Temporal period. Khong chay T0 sau G2.', 16, 1);
    RETURN;
END
PRINT N'[OK] Chua co Temporal period tren cac bang gia.';

-- Kiem tra chua co History thu cong
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
BEGIN
    RAISERROR(N'FAIL: History thu cong da ton tai. Khong con trang thai G1.', 16, 1);
    RETURN;
END
PRINT N'[OK] Chua co bang History thu cong.';

PRINT N'';
PRINT N'=== KET QUA T0: PASS – Baseline R0 hop le, san sang cho G2. ===';
PRINT N'Luu screenshot nay lam bang chung truoc G2.';

-- Hien thi du lieu baseline de chup man hinh
SELECT
    p.ProductID,
    p.ProductName,
    m.UnitPrice AS ManualPrice,
    n.UnitPrice AS NativePrice,
    CASE
        WHEN m.ProductID IS NULL AND n.ProductID IS NULL THEN N'BOTH_MISSING'
        WHEN m.ProductID IS NULL THEN N'ONLY_NATIVE'
        WHEN n.ProductID IS NULL THEN N'ONLY_MANUAL'
        WHEN m.UnitPrice = n.UnitPrice
             AND m.CurrencyCode = n.CurrencyCode
             AND (m.PriceNote = n.PriceNote OR (m.PriceNote IS NULL AND n.PriceNote IS NULL))
        THEN N'MATCH'
        ELSE N'DIFF'
    END AS CompareStatus
FROM dbo.Product AS p
LEFT JOIN demo.ProductPrice_Manual AS m ON p.ProductID = m.ProductID
LEFT JOIN demo.ProductPrice_Native AS n ON p.ProductID = n.ProductID
ORDER BY p.ProductID;
GO
