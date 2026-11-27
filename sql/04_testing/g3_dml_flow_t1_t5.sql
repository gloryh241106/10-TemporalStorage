/*
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script   : g3_dml_flow_t1_t5.sql
Giai doan: G3 - LAM THAY DOI DU LIEU (T1-T5 tren ca hai nhanh)
Muc dich : Luong DML chung theo Quy uoc 1.3 muc 10.4. Chay cung chuoi DML tren
           Manual va Native, ghi 3 moc UTC cho T6/T7 va chup so dong + gia o
           Current/History sau moi su kien.
Dieu kien truoc khi chay:
  - Database thu nghiem moi: 00_create_and_seed.sql -> 01_verify_setup.sql (T0 PASS).
  - Da cai Manual (sql/01_trigger: create_manual_history, add_manual_period_columns,
    create_manual_trigger) va Native (sql/02_native_temporal: bat SYSTEM_VERSIONING).
  - Chua chay bat ky DML T1-T5 nao.
  - Chay CA FILE trong mot phien (sqlcmd -b, hoac SSMS). Bang tam #G3* song qua cac GO.
Doi tuong tac dong: demo.ProductPrice_Manual, demo.ProductPrice_Native
  (trigger cua Thuy ghi demo.ProductPrice_ManualHistory; SQL Server ghi
  demo.ProductPrice_NativeHistory).
Ket qua du kien (Test Plan 1.1, muc 4):
  Current : 101=30000, 102=27000, 103=30000, 104 khong con, 105=19000
  History : 101: 25000, 27000 | 102: 25000 | 103: 28000 | 104: 45000 | 105: 0 dong
Sau khi chay:
  - Chep 3 moc in o cuoi vao T6_T7_time_travel_queries.sql.
  - Chay T1_T5_verify_dml_events.sql (@AfterStep = 5) va T6_T7_time_travel_queries.sql.
  - Script nay khong reset/cleanup. Muon chay lai: tao database moi.
================================================================================
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 0. Kiem tra dieu kien. Neu sai: dung lai, khong doi du lieu.
DECLARE @err NVARCHAR(400) = NULL;

IF NOT EXISTS (SELECT 1 FROM sys.triggers
               WHERE parent_id = OBJECT_ID(N'demo.ProductPrice_Manual') AND is_disabled = 0)
    SET @err = N'Nhanh Manual chua co trigger dang bat.';
ELSE IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NULL
    SET @err = N'Chua co demo.ProductPrice_ManualHistory.';
ELSE IF NOT EXISTS (SELECT 1 FROM sys.tables
                    WHERE object_id = OBJECT_ID(N'demo.ProductPrice_Native') AND temporal_type = 2)
    SET @err = N'Nhanh Native chua bat SYSTEM_VERSIONING.';
ELSE IF EXISTS (SELECT 1 FROM demo.ProductPrice_Manual WHERE ProductID = 105)
     OR EXISTS (SELECT 1 FROM demo.ProductPrice_Native WHERE ProductID = 105)
     OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual WHERE ProductID = 101 AND UnitPrice = 25000)
     OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Native WHERE ProductID = 101 AND UnitPrice = 25000)
    SET @err = N'Du lieu khong o trang thai R0 (da chay T1-T5?). Tao database moi.';

IF @err IS NOT NULL
BEGIN
    RAISERROR(N'[G3 BLOCKED] %s', 16, 1, @err);
    SET NOEXEC ON;   -- SSMS: cac batch sau chi bien dich, khong thuc thi
END
ELSE
    PRINT N'[G3] Dieu kien OK. Bat dau luong DML.';
GO

IF OBJECT_ID('tempdb..#G3Mark') IS NOT NULL DROP TABLE #G3Mark;
IF OBJECT_ID('tempdb..#G3Snap') IS NOT NULL DROP TABLE #G3Snap;
CREATE TABLE #G3Mark (Seq INT, Label NVARCHAR(20), AtUtc DATETIME2(7));
CREATE TABLE #G3Snap (Seq INT IDENTITY(1,1), EventName NVARCHAR(10), Branch NVARCHAR(10),
                      CurrentRows INT, HistoryRows INT,
                      CurrentPrices NVARCHAR(200), HistoryPrices NVARCHAR(300),
                      SnapUtc DATETIME2(7));
GO

-- Chup trang thai sau moi su kien (chi doc).
CREATE OR ALTER PROCEDURE #G3_Snapshot @EventName NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO #G3Snap (EventName, Branch, CurrentRows, HistoryRows, CurrentPrices, HistoryPrices, SnapUtc)
    SELECT @EventName, N'Manual',
        (SELECT COUNT(*) FROM demo.ProductPrice_Manual),
        (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory),
        (SELECT STRING_AGG(CONCAT(ProductID, N'=', UnitPrice), N'; ') WITHIN GROUP (ORDER BY ProductID)
           FROM demo.ProductPrice_Manual),
        (SELECT STRING_AGG(CONCAT(ProductID, N'=', UnitPrice), N'; ') WITHIN GROUP (ORDER BY ProductID, ValidFrom)
           FROM demo.ProductPrice_ManualHistory),
        SYSUTCDATETIME()
    UNION ALL
    SELECT @EventName, N'Native',
        (SELECT COUNT(*) FROM demo.ProductPrice_Native),
        (SELECT COUNT(*) FROM demo.ProductPrice_NativeHistory),
        (SELECT STRING_AGG(CONCAT(ProductID, N'=', UnitPrice), N'; ') WITHIN GROUP (ORDER BY ProductID)
           FROM demo.ProductPrice_Native),
        (SELECT STRING_AGG(CONCAT(ProductID, N'=', UnitPrice), N'; ') WITHIN GROUP (ORDER BY ProductID, ValidFrom)
           FROM demo.ProductPrice_NativeHistory),
        SYSUTCDATETIME();
END;
GO

EXEC #G3_Snapshot N'Truoc T1';
GO

-- T1: INSERT 105 = 19000 (moi nhanh mot giao tac)
BEGIN TRANSACTION;
    INSERT INTO demo.ProductPrice_Manual (ProductID, UnitPrice, CurrencyCode, PriceNote)
    VALUES (105, 19000.00, 'VND', N'Giá khởi tạo');
COMMIT TRANSACTION;
BEGIN TRANSACTION;
    INSERT INTO demo.ProductPrice_Native (ProductID, UnitPrice, CurrencyCode, PriceNote)
    VALUES (105, 19000.00, 'VND', N'Giá khởi tạo');
COMMIT TRANSACTION;
EXEC #G3_Snapshot N'T1';
GO

-- Moc 1: hai nhanh san sang, TRUOC T2
WAITFOR DELAY '00:00:01';
INSERT INTO #G3Mark VALUES (1, N't_ready', SYSUTCDATETIME());
WAITFOR DELAY '00:00:01';
GO

-- T2: UPDATE 101 25000 -> 27000 (giao tac rieng, da commit)
BEGIN TRANSACTION;
    UPDATE demo.ProductPrice_Manual SET UnitPrice = 27000.00 WHERE ProductID = 101;
COMMIT TRANSACTION;
BEGIN TRANSACTION;
    UPDATE demo.ProductPrice_Native SET UnitPrice = 27000.00 WHERE ProductID = 101;
COMMIT TRANSACTION;
EXEC #G3_Snapshot N'T2';
GO

-- Moc 2: sau commit T2 tren CA HAI nhanh, TRUOC T3
WAITFOR DELAY '00:00:01';
INSERT INTO #G3Mark VALUES (2, N't_between', SYSUTCDATETIME());
WAITFOR DELAY '00:00:01';
GO

-- T3: UPDATE 101 27000 -> 30000 (giao tac khac T2)
BEGIN TRANSACTION;
    UPDATE demo.ProductPrice_Manual SET UnitPrice = 30000.00 WHERE ProductID = 101;
COMMIT TRANSACTION;
BEGIN TRANSACTION;
    UPDATE demo.ProductPrice_Native SET UnitPrice = 30000.00 WHERE ProductID = 101;
COMMIT TRANSACTION;
EXEC #G3_Snapshot N'T3';
GO

-- Moc 3: sau commit T3
WAITFOR DELAY '00:00:01';
INSERT INTO #G3Mark VALUES (3, N't_after_T3', SYSUTCDATETIME());
WAITFOR DELAY '00:00:01';
GO

-- T4: DELETE gia 104
BEGIN TRANSACTION;
    DELETE FROM demo.ProductPrice_Manual WHERE ProductID = 104;
COMMIT TRANSACTION;
BEGIN TRANSACTION;
    DELETE FROM demo.ProductPrice_Native WHERE ProductID = 104;
COMMIT TRANSACTION;
EXEC #G3_Snapshot N'T4';
GO

-- T5: MOT cau UPDATE nhieu dong moi nhanh (102 va 103 +2000)
BEGIN TRANSACTION;
    UPDATE demo.ProductPrice_Manual SET UnitPrice = UnitPrice + 2000.00 WHERE ProductID IN (102, 103);
COMMIT TRANSACTION;
BEGIN TRANSACTION;
    UPDATE demo.ProductPrice_Native SET UnitPrice = UnitPrice + 2000.00 WHERE ProductID IN (102, 103);
COMMIT TRANSACTION;
EXEC #G3_Snapshot N'T5';
GO

-- Ket qua: trang thai sau moi su kien va 3 moc UTC
PRINT N'--- G3: trang thai Current/History sau moi su kien ---';
SELECT EventName, Branch, CurrentRows, HistoryRows, CurrentPrices, HistoryPrices, SnapUtc
FROM #G3Snap ORDER BY Seq;

PRINT N'--- G3: 3 moc UTC (dien vao T6_T7_time_travel_queries.sql) ---';
SELECT Label, CONVERT(VARCHAR(27), AtUtc, 121) AS AtUtc FROM #G3Mark ORDER BY Seq;

DECLARE @r VARCHAR(27), @b VARCHAR(27), @a VARCHAR(27);
SELECT @r = CONVERT(VARCHAR(27), AtUtc, 121) FROM #G3Mark WHERE Seq = 1;
SELECT @b = CONVERT(VARCHAR(27), AtUtc, 121) FROM #G3Mark WHERE Seq = 2;
SELECT @a = CONVERT(VARCHAR(27), AtUtc, 121) FROM #G3Mark WHERE Seq = 3;
PRINT 'G3_MARKS|' + @r + '|' + @b + '|' + @a;
PRINT 'DECLARE @t_ready    DATETIME2(7) = ''' + @r + ''';';
PRINT 'DECLARE @t_between  DATETIME2(7) = ''' + @b + ''';';
PRINT 'DECLARE @t_after_T3 DATETIME2(7) = ''' + @a + ''';';
GO
SET NOEXEC OFF;
GO
