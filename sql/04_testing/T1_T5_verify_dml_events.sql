/*
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script: T1_T5_dml_events.sql
Muc dich: Cac su kien DML T1-T5 do Thuy (Manual) va Trung (Native) thuc hien.
           Kiet su dung script nay de KIEM CHUNG ket qua SAU khi Thuy/Trung bàn giao.
           Phan "KIEM CHUNG" duoi tung su kien la phan Kiet tu chay.

CANH BAO:
  - Khong chay bat ky DML (INSERT/UPDATE/DELETE) nao neu ban la Kiet – do la cua TV2/TV3.
  - Kiet chi chay cac block "-- [KIET KIEM CHUNG]".
  - Ghi lai UTC timestamp truoc/sau moi su kien vao bang log (xem cuoi file).
================================================================================
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;

/*
==============================================================================
BANG GHI MOC UTC – Kiet ghi truoc va sau moi su kien
Dung cho T6 (AS OF) va T7 (range query)
==============================================================================
*/
-- Kiet tu mo file text hoac dung SSMS de ghi lai cac moc nay:
-- @t_before_T1 = SYSUTCDATETIME() -- truoc khi Thuy/Trung insert 105
-- @t_after_T1  = SYSUTCDATETIME() -- sau khi insert xong
-- @t_before_T2 = SYSUTCDATETIME() -- truoc khi update 101 lan 1
-- @t_after_T2  = SYSUTCDATETIME()
-- @t_before_T3 = SYSUTCDATETIME() -- truoc khi update 101 lan 2
-- @t_after_T3  = SYSUTCDATETIME()
-- @t_before_T4 = SYSUTCDATETIME() -- truoc khi delete 104
-- @t_after_T4  = SYSUTCDATETIME()
-- @t_before_T5 = SYSUTCDATETIME() -- truoc khi update 102+103
-- @t_after_T5  = SYSUTCDATETIME()

-- ============================================================
-- T1: INSERT gia cho ProductID 105 (Thuy/Trung thuc hien)
-- Kiet ghi moc TRUOC khi Thuy/Trung chay
-- ============================================================

-- ===== [KIET KIEM CHUNG SAU T1] =====
PRINT N'=== [KIET] Kiem chung T1: INSERT 105 ===';

-- Nhanh Manual
PRINT N'-- Nhanh Manual (Current):';
SELECT ProductID, UnitPrice, CurrencyCode, PriceNote
FROM demo.ProductPrice_Manual
WHERE ProductID = 105;
-- Ky vong: 1 dong, UnitPrice = 19000.00

-- Nhanh Native
PRINT N'-- Nhanh Native (Current):';
SELECT ProductID, UnitPrice, CurrencyCode, PriceNote
FROM demo.ProductPrice_Native
WHERE ProductID = 105;
-- Ky vong: 1 dong, UnitPrice = 19000.00

-- Kiem tra History Manual (neu Thuy da tao bang ManualHistory)
PRINT N'-- Nhanh Manual (History cho 105 - ky vong: 0 dong):';
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
    SELECT * FROM demo.ProductPrice_ManualHistory WHERE ProductID = 105;
ELSE
    PRINT N'  [INFO] Bang ManualHistory chua duoc tao (binh thuong truoc G2).';

-- Kiem tra History Native
PRINT N'-- Nhanh Native (History cho 105 - ky vong: 0 dong):';
DECLARE @NativeHistoryTable NVARCHAR(200);
SELECT TOP 1 @NativeHistoryTable = SCHEMA_NAME(ht.schema_id) + N'.' + ht.name
FROM sys.tables t
JOIN sys.tables ht ON t.history_table_id = ht.object_id
WHERE t.object_id = OBJECT_ID(N'demo.ProductPrice_Native');

IF @NativeHistoryTable IS NOT NULL
BEGIN
    EXEC(N'SELECT * FROM ' + @NativeHistoryTable + N' WHERE ProductID = 105');
END
ELSE
    PRINT N'  [INFO] Temporal chua duoc bat tren bang Native (binh thuong truoc G2).';
GO

-- ============================================================
-- T2: UPDATE 101: 25000 -> 27000 (Thuy/Trung thuc hien)
-- ============================================================

-- ===== [KIET KIEM CHUNG SAU T2] =====
PRINT N'=== [KIET] Kiem chung T2: UPDATE 101 lan 1 (25000->27000) ===';

PRINT N'-- Nhanh Manual (Current 101, ky vong: 27000):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Manual WHERE ProductID = 101;

PRINT N'-- Nhanh Native (Current 101, ky vong: 27000):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Native WHERE ProductID = 101;

PRINT N'-- Nhanh Manual (History 101, ky vong: 1 dong gia 25000):';
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
    SELECT * FROM demo.ProductPrice_ManualHistory WHERE ProductID = 101;
ELSE
    PRINT N'  [INFO] Bang ManualHistory chua ton tai.';

PRINT N'-- Nhanh Native (History 101, ky vong: 1 dong gia 25000):';
DECLARE @NativeHistoryTable2 NVARCHAR(200);
SELECT TOP 1 @NativeHistoryTable2 = SCHEMA_NAME(ht.schema_id) + N'.' + ht.name
FROM sys.tables t
JOIN sys.tables ht ON t.history_table_id = ht.object_id
WHERE t.object_id = OBJECT_ID(N'demo.ProductPrice_Native');
IF @NativeHistoryTable2 IS NOT NULL
    EXEC(N'SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM ' + @NativeHistoryTable2 + N' WHERE ProductID = 101');
ELSE
    PRINT N'  [INFO] Native Temporal chua duoc bat.';
GO

-- ============================================================
-- T3: UPDATE 101: 27000 -> 30000 (GIAO TAC MOI, Thuy/Trung)
-- ============================================================

-- ===== [KIET KIEM CHUNG SAU T3] =====
PRINT N'=== [KIET] Kiem chung T3: UPDATE 101 lan 2 (27000->30000) ===';

PRINT N'-- Nhanh Manual (Current 101, ky vong: 30000):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Manual WHERE ProductID = 101;

PRINT N'-- Nhanh Native (Current 101, ky vong: 30000):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Native WHERE ProductID = 101;

PRINT N'-- Nhanh Manual (History 101, ky vong: 2 dong - 25000 va 27000):';
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
BEGIN
    SELECT * FROM demo.ProductPrice_ManualHistory WHERE ProductID = 101
    ORDER BY 1; -- Thuy xac nhan column thu tu phu hop
END
ELSE
    PRINT N'  [INFO] Bang ManualHistory chua ton tai.';

PRINT N'-- Nhanh Native (History 101, ky vong: 2 dong - 25000 va 27000):';
DECLARE @NativeHistoryTable3 NVARCHAR(200);
SELECT TOP 1 @NativeHistoryTable3 = SCHEMA_NAME(ht.schema_id) + N'.' + ht.name
FROM sys.tables t
JOIN sys.tables ht ON t.history_table_id = ht.object_id
WHERE t.object_id = OBJECT_ID(N'demo.ProductPrice_Native');
IF @NativeHistoryTable3 IS NOT NULL
    EXEC(N'SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM ' + @NativeHistoryTable3
         + N' WHERE ProductID = 101 ORDER BY ValidFrom');
ELSE
    PRINT N'  [INFO] Native Temporal chua duoc bat.';
GO

-- ============================================================
-- T4: DELETE gia cua ProductID 104 (Thuy/Trung thuc hien)
-- ============================================================

-- ===== [KIET KIEM CHUNG SAU T4] =====
PRINT N'=== [KIET] Kiem chung T4: DELETE 104 ===';

PRINT N'-- Nhanh Manual (Current 104, ky vong: 0 dong):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Manual WHERE ProductID = 104;

PRINT N'-- Nhanh Native (Current 104, ky vong: 0 dong):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Native WHERE ProductID = 104;

PRINT N'-- Nhanh Manual (History 104, ky vong: 1 dong gia 45000):';
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
    SELECT * FROM demo.ProductPrice_ManualHistory WHERE ProductID = 104;
ELSE
    PRINT N'  [INFO] Bang ManualHistory chua ton tai.';

PRINT N'-- Nhanh Native (History 104, ky vong: 1 dong gia 45000):';
DECLARE @NativeHistoryTable4 NVARCHAR(200);
SELECT TOP 1 @NativeHistoryTable4 = SCHEMA_NAME(ht.schema_id) + N'.' + ht.name
FROM sys.tables t
JOIN sys.tables ht ON t.history_table_id = ht.object_id
WHERE t.object_id = OBJECT_ID(N'demo.ProductPrice_Native');
IF @NativeHistoryTable4 IS NOT NULL
    EXEC(N'SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM ' + @NativeHistoryTable4
         + N' WHERE ProductID = 104');
ELSE
    PRINT N'  [INFO] Native Temporal chua duoc bat.';

-- Product 104 phai van con trong danh muc
PRINT N'-- dbo.Product 104 van ton tai (ky vong: 1 dong):';
SELECT ProductID, ProductName FROM dbo.Product WHERE ProductID = 104;
GO

-- ============================================================
-- T5: UPDATE nhieu dong: 102 va 103 cung mot statement
-- ============================================================

-- ===== [KIET KIEM CHUNG SAU T5] =====
PRINT N'=== [KIET] Kiem chung T5: UPDATE multi-row (102+103) ===';

PRINT N'-- Nhanh Manual (Current 102+103):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Manual WHERE ProductID IN (102, 103);
-- Ky vong: 102=27000, 103=30000

PRINT N'-- Nhanh Native (Current 102+103):';
SELECT ProductID, UnitPrice FROM demo.ProductPrice_Native WHERE ProductID IN (102, 103);
-- Ky vong: 102=27000, 103=30000

PRINT N'-- Nhanh Manual (History 102+103, ky vong: moi ID co 1 dong gia cu):';
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
    SELECT * FROM demo.ProductPrice_ManualHistory WHERE ProductID IN (102, 103);
ELSE
    PRINT N'  [INFO] Bang ManualHistory chua ton tai.';

PRINT N'-- Nhanh Native (History 102+103, ky vong: moi ID co 1 dong):';
DECLARE @NativeHistoryTable5 NVARCHAR(200);
SELECT TOP 1 @NativeHistoryTable5 = SCHEMA_NAME(ht.schema_id) + N'.' + ht.name
FROM sys.tables t
JOIN sys.tables ht ON t.history_table_id = ht.object_id
WHERE t.object_id = OBJECT_ID(N'demo.ProductPrice_Native');
IF @NativeHistoryTable5 IS NOT NULL
    EXEC(N'SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM ' + @NativeHistoryTable5
         + N' WHERE ProductID IN (102, 103) ORDER BY ProductID, ValidFrom');
ELSE
    PRINT N'  [INFO] Native Temporal chua duoc bat.';
GO

PRINT N'';
PRINT N'=== HOAN THANH KIEM CHUNG T1-T5 ===';
PRINT N'Ghi lai tat ca UTC timestamp vao bang log truoc khi chay T6/T7.';
GO
