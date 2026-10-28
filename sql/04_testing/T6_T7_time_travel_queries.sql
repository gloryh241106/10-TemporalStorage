/*
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script: T6_T7_time_travel_queries.sql
Muc dich: Time Travel Queries – phan Kiet tu thiet ke va tu chay.
           CHAY SAU khi T2 va T3 da hoan thanh va co UTC timestamp.
           
Truoc khi chay, dien cac gia tri UTC nay tu bang ghi moc:
  @t_before_T2 : moc UTC truoc khi Thuy/Trung UPDATE 101 lan 1
  @t_after_T2  : moc UTC sau khi UPDATE 101 lan 1 (gia 27000 da co hieu luc)
  @t_before_T3 : moc UTC truoc khi Thuy/Trung UPDATE 101 lan 2
  @t_after_T3  : moc UTC sau khi UPDATE 101 lan 2 (gia 30000 da co hieu luc)

Quy uoc: Chon cac moc nam GIUA cac su kien (cach moi bien de hon 1 giay).
         Khong chon chinh xac bang timestamp cua transaction.
================================================================================
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;

-- ============================================================
-- BUOC 1: Dien moc UTC thuc te da ghi duoc
-- Thay the bang gia tri thuc te tu ban ghi moc cua ban
-- ============================================================
DECLARE @t_before_T2 DATETIME2(7) = '2026-11-XX XX:XX:XX.XXXXXXX'; -- Truoc UPDATE 101 lan 1
DECLARE @t_after_T2  DATETIME2(7) = 'YYYY-MM-DD HH:MM:SS.XXXXXXX'; -- Sau UPDATE, gia 27000
DECLARE @t_before_T3 DATETIME2(7) = 'YYYY-MM-DD HH:MM:SS.XXXXXXX'; -- Truoc UPDATE 101 lan 2
DECLARE @t_after_T3  DATETIME2(7) = 'YYYY-MM-DD HH:MM:SS.XXXXXXX'; -- Sau UPDATE, gia 30000

-- Moc kiểm tra trung gian (dung cho T6):
-- t_check_1 = @t_before_T2 - 1 giay  => ky vong 25000
-- t_check_2 = giua @t_after_T2 va @t_before_T3 => ky vong 27000
-- t_check_3 = @t_after_T3 + 1 giay   => ky vong 30000

DECLARE @t_check_1 DATETIME2(7) = DATEADD(SECOND, -1, @t_before_T2);
DECLARE @t_check_2 DATETIME2(7) = DATEADD(MILLISECOND,
    DATEDIFF(MILLISECOND, @t_after_T2, @t_before_T3) / 2, @t_after_T2);
DECLARE @t_check_3 DATETIME2(7) = DATEADD(SECOND, 1, @t_after_T3);

PRINT N'=== [KIET] T6: TIME TRAVEL QUERY – AS OF ===';
PRINT N'Moc t_check_1 (ky vong 25000): ' + CONVERT(NVARCHAR(40), @t_check_1, 126);
PRINT N'Moc t_check_2 (ky vong 27000): ' + CONVERT(NVARCHAR(40), @t_check_2, 126);
PRINT N'Moc t_check_3 (ky vong 30000): ' + CONVERT(NVARCHAR(40), @t_check_3, 126);
PRINT N'';

-- ============================================================
-- T6-A: Nhanh Native – FOR SYSTEM_TIME AS OF
-- ============================================================
PRINT N'--- T6-A: Nhanh Native FOR SYSTEM_TIME AS OF ---';

PRINT N'Tai t_check_1 (ky vong: 25000):';
SELECT ProductID, UnitPrice, ValidFrom, ValidTo
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME AS OF @t_check_1
WHERE ProductID = 101;

PRINT N'Tai t_check_2 (ky vong: 27000):';
SELECT ProductID, UnitPrice, ValidFrom, ValidTo
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME AS OF @t_check_2
WHERE ProductID = 101;

PRINT N'Tai t_check_3 (ky vong: 30000):';
SELECT ProductID, UnitPrice, ValidFrom, ValidTo
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME AS OF @t_check_3
WHERE ProductID = 101;

-- ============================================================
-- T6-B: Nhanh Manual – Query thu cong tren ManualHistory
-- Thuy can xac nhan ten cot StartTime/EndTime chinh xac
-- ============================================================
PRINT N'';
PRINT N'--- T6-B: Nhanh Manual – Query thu cong ---';
PRINT N'  (Thuy can xac nhan ten cot StartTime/EndTime va semantics)';

IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
BEGIN
    -- Query dang tong quat – Thuy xac nhan ten cot dung
    -- Gia dinh cot: ProductID, UnitPrice, StartTime (DATETIME2), EndTime (DATETIME2 NULL = current)

    PRINT N'Tai t_check_1 (ky vong: 25000 – xem trong ManualHistory hoac Current):';
    SELECT *
    FROM demo.ProductPrice_ManualHistory
    WHERE ProductID = 101
      AND StartTime <= @t_check_1
      AND (EndTime > @t_check_1 OR EndTime IS NULL);
    -- Neu khong co ket qua tu History, co the la dang trong Current: xem ProductPrice_Manual

    PRINT N'Tai t_check_2 (ky vong: 27000):';
    SELECT *
    FROM demo.ProductPrice_ManualHistory
    WHERE ProductID = 101
      AND StartTime <= @t_check_2
      AND (EndTime > @t_check_2 OR EndTime IS NULL);

    PRINT N'Tai t_check_3 (ky vong: 30000 – co the chi co trong Current):';
    SELECT *
    FROM demo.ProductPrice_Manual  -- Current table
    WHERE ProductID = 101;
END
ELSE
    PRINT N'  [FAIL] Bang ManualHistory chua ton tai. Bao Thuy xu ly.';

GO

-- ============================================================
-- T7: Truy van khoang thoi gian – tat ca phien ban ProductID=101
-- ============================================================
DECLARE @t_range_start DATETIME2(7) = '2026-11-01 00:00:00.0000000'; -- Thay bang moc thuc te
DECLARE @t_range_end   DATETIME2(7) = SYSUTCDATETIME();               -- Den hien tai

PRINT N'';
PRINT N'=== [KIET] T7: RANGE QUERY – Tat ca phien ban ProductID=101 ===';
PRINT N'Khoang thoi gian: ' + CONVERT(NVARCHAR(40), @t_range_start, 126)
      + N' -> ' + CONVERT(NVARCHAR(40), @t_range_end, 126);
PRINT N'';

-- ============================================================
-- T7-A: Nhanh Native – FOR SYSTEM_TIME BETWEEN / FROM-TO / CONTAINED IN
-- ============================================================
PRINT N'--- T7-A: Nhanh Native – FOR SYSTEM_TIME BETWEEN (bieu kien inclusive) ---';
SELECT ProductID, UnitPrice, ValidFrom, ValidTo
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME BETWEEN @t_range_start AND @t_range_end
WHERE ProductID = 101
ORDER BY ValidFrom;

PRINT N'--- T7-A2: Nhanh Native – FOR SYSTEM_TIME FROM...TO (exclusive end) ---';
SELECT ProductID, UnitPrice, ValidFrom, ValidTo
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME FROM @t_range_start TO @t_range_end
WHERE ProductID = 101
ORDER BY ValidFrom;

PRINT N'--- T7-A3: Nhanh Native – FOR SYSTEM_TIME CONTAINED IN (ca hai bien la subset) ---';
SELECT ProductID, UnitPrice, ValidFrom, ValidTo
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME CONTAINED IN (@t_range_start, @t_range_end)
WHERE ProductID = 101
ORDER BY ValidFrom;

PRINT N'';
PRINT N'Ghi chu bieu kien:';
PRINT N'  BETWEEN    : lay ban ghi co [ValidFrom, ValidTo] giao voi [@start, @end] (>= @start AND <= @end)';
PRINT N'  FROM...TO  : lay ban ghi co ValidFrom < @end AND ValidTo > @start';
PRINT N'  CONTAINED  : lay ban ghi co ValidFrom >= @start AND ValidTo <= @end';

-- ============================================================
-- T7-B: Nhanh Manual – Toan bo phien ban tu ManualHistory + Current
-- ============================================================
PRINT N'';
PRINT N'--- T7-B: Nhanh Manual – Hop nhat History va Current ---';
IF OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
BEGIN
    -- Tat ca phien ban trong History + Current (UNION ALL)
    SELECT ProductID, UnitPrice, 'History' AS Source,
           StartTime, EndTime   -- ten cot Thuy xac nhan
    FROM demo.ProductPrice_ManualHistory
    WHERE ProductID = 101

    UNION ALL

    SELECT ProductID, UnitPrice, 'Current' AS Source,
           NULL AS StartTime, NULL AS EndTime
    FROM demo.ProductPrice_Manual
    WHERE ProductID = 101

    ORDER BY StartTime;
    -- Ghi chu: Thuy can xac nhan ten cot StartTime/EndTime chinh xac
END
ELSE
    PRINT N'  [FAIL] Bang ManualHistory chua ton tai. Bao Thuy xu ly.';

GO

PRINT N'';
PRINT N'=== HOAN THANH T6 va T7 ===';
PRINT N'Luu output nay lam bang chung: script + anh SSMS + timestamp UTC.';
PRINT N'Dien ket qua vao bang ma tran bang chung trong 04_testplan_Kiet_G1.md.';
GO
