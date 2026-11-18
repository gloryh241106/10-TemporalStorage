/*
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script  : T1_T5_verify_dml_events.sql (v1.1, dong bo hop dong V4 va Test Plan 1.1)
Giai doan: G2/G3 - CHI DOC, khong INSERT/UPDATE/DELETE bang nghiep vu.
Muc dich: Kiem chung trang thai Current + History cua tung nhanh sau cac su kien
          T1-T5 do Thuy (Manual) va Trung (Native) chay. In bang
          Expected / Actual / Status giong T6_T7_time_travel_queries.sql.

Cach dung:
  1. Dat @AfterStep = buoc cuoi cung DA COMMIT tren nhanh (1..5). Mac dinh 5.
       1 = T1 INSERT 105 = 19000
       2 = T2 UPDATE 101: 25000 -> 27000
       3 = T3 UPDATE 101: 27000 -> 30000 (giao tac rieng)
       4 = T4 DELETE 104
       5 = T5 UPDATE 102, 103 +2000 trong MOT cau lenh
  2. Chay ca file. Nhanh chua cai dat duoc bao BLOCKED (khong phai FAIL).
  3. Chep bang ket qua vao evidence/ va ma tran bang chung (Test Plan muc 6).

Quy uoc kiem (hop dong V4, 06_G2_handoff.md):
  - Current va History dung ValidFrom/ValidTo DATETIME2(7) UTC.
  - Ban hien hanh: ValidTo = 9999-12-31 23:59:59.9999999, khong NULL.
  - INSERT (T1) khong tao dong History. History chi chua phien ban da dong.
  - Manual: HistoryID BIGINT IDENTITY la PK; trigger xu ly theo tap.
  - Native: SYSTEM_VERSIONING = ON, HISTORY_RETENTION_PERIOD = INFINITE.
  - Khong ep timestamp hai nhanh bang nhau; chi so sanh gia tri va thu tu.
================================================================================
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;

DECLARE @AfterStep TINYINT = 5;   -- <<< SUA THEO BUOC DA CHAY

IF @AfterStep NOT BETWEEN 1 AND 5
    THROW 55000, N'@AfterStep phai trong khoang 1..5.', 1;

DECLARE @MaxTo DATETIME2(7) = '9999-12-31 23:59:59.9999999';

IF OBJECT_ID('tempdb..#Result') IS NOT NULL DROP TABLE #Result;
IF OBJECT_ID('tempdb..#Cur')    IS NOT NULL DROP TABLE #Cur;
IF OBJECT_ID('tempdb..#Hist')   IS NOT NULL DROP TABLE #Hist;
IF OBJECT_ID('tempdb..#ExpCur') IS NOT NULL DROP TABLE #ExpCur;
IF OBJECT_ID('tempdb..#ExpHist') IS NOT NULL DROP TABLE #ExpHist;
IF OBJECT_ID('tempdb..#Branch') IS NOT NULL DROP TABLE #Branch;

CREATE TABLE #Result (
    Seq      INT IDENTITY(1,1),
    TestCase NVARCHAR(20),
    Branch   NVARCHAR(10),
    CheckName NVARCHAR(80),
    Expected NVARCHAR(200),
    Actual   NVARCHAR(400),
    Status   NVARCHAR(10)
);
CREATE TABLE #Cur  (Branch NVARCHAR(10), ProductID INT, UnitPrice DECIMAL(12,2),
                    ValidFrom DATETIME2(7) NULL, ValidTo DATETIME2(7) NULL);
CREATE TABLE #Hist (Branch NVARCHAR(10), ProductID INT, UnitPrice DECIMAL(12,2),
                    ValidFrom DATETIME2(7) NULL, ValidTo DATETIME2(7) NULL);

/* ---------------------------------------------------------------------------
   1. Ket qua ky vong theo @AfterStep (Test Plan 1.1, muc 4)
--------------------------------------------------------------------------- */
CREATE TABLE #ExpCur (ProductID INT, Price DECIMAL(12,2) NULL); -- NULL = khong co dong
INSERT INTO #ExpCur VALUES
    (101, CASE WHEN @AfterStep >= 3 THEN 30000 WHEN @AfterStep = 2 THEN 27000 ELSE 25000 END),
    (102, CASE WHEN @AfterStep >= 5 THEN 27000 ELSE 25000 END),
    (103, CASE WHEN @AfterStep >= 5 THEN 30000 ELSE 28000 END),
    (104, CASE WHEN @AfterStep >= 4 THEN NULL  ELSE 45000 END),
    (105, 19000);

-- Danh sach gia trong History, sap theo ValidFrom; '' = 0 dong.
CREATE TABLE #ExpHist (ProductID INT, TestCase NVARCHAR(20), Prices NVARCHAR(100));
INSERT INTO #ExpHist VALUES
    (101, CASE WHEN @AfterStep >= 3 THEN N'T3' ELSE N'T2' END,
          CASE WHEN @AfterStep >= 3 THEN N'25000.00, 27000.00'
               WHEN @AfterStep = 2 THEN N'25000.00' ELSE N'' END),
    (102, N'T5', CASE WHEN @AfterStep >= 5 THEN N'25000.00' ELSE N'' END),
    (103, N'T5', CASE WHEN @AfterStep >= 5 THEN N'28000.00' ELSE N'' END),
    (104, N'T4', CASE WHEN @AfterStep >= 4 THEN N'45000.00' ELSE N'' END),
    (105, N'T1', N'');

/* ---------------------------------------------------------------------------
   2. Nhan dien nhanh da san sang
--------------------------------------------------------------------------- */
DECLARE @NativeHist NVARCHAR(300) =
    (SELECT QUOTENAME(SCHEMA_NAME(ht.schema_id)) + N'.' + QUOTENAME(ht.name)
     FROM sys.tables t JOIN sys.tables ht ON ht.object_id = t.history_table_id
     WHERE t.object_id = OBJECT_ID(N'demo.ProductPrice_Native') AND t.temporal_type = 2);

DECLARE @ManualReady BIT =
    CASE WHEN OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_Manual', N'ValidFrom') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_Manual', N'ValidTo') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_ManualHistory', N'ValidFrom') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_ManualHistory', N'ValidTo') IS NOT NULL
         THEN 1 ELSE 0 END;

CREATE TABLE #Branch (Branch NVARCHAR(10), Ready BIT);
INSERT INTO #Branch VALUES (N'Manual', @ManualReady),
                           (N'Native', CASE WHEN @NativeHist IS NULL THEN 0 ELSE 1 END);

IF @ManualReady = 0
    INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
    VALUES (N'SETUP', N'Manual', N'Nhanh da cai dat', N'ManualHistory + ValidFrom/ValidTo',
            N'Chua co theo hop dong V4', N'BLOCKED');
IF @NativeHist IS NULL
    INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
    VALUES (N'SETUP', N'Native', N'Nhanh da cai dat', N'SYSTEM_VERSIONING = ON',
            N'Chua bat', N'BLOCKED');

/* ---------------------------------------------------------------------------
   3. Doc du lieu vao bang tam (dynamic SQL de script van bien dich truoc G2)
--------------------------------------------------------------------------- */
IF @ManualReady = 1
BEGIN
    INSERT INTO #Cur EXEC (N'SELECT N''Manual'', ProductID, UnitPrice, ValidFrom, ValidTo
                             FROM demo.ProductPrice_Manual;');
    INSERT INTO #Hist EXEC (N'SELECT N''Manual'', ProductID, UnitPrice, ValidFrom, ValidTo
                              FROM demo.ProductPrice_ManualHistory;');
END;

IF @NativeHist IS NOT NULL
BEGIN
    INSERT INTO #Cur EXEC (N'SELECT N''Native'', ProductID, UnitPrice, ValidFrom, ValidTo
                             FROM demo.ProductPrice_Native;');
    INSERT INTO #Hist EXEC (N'SELECT N''Native'', ProductID, UnitPrice, ValidFrom, ValidTo
                              FROM ' + @NativeHist + N';');
END;

/* ---------------------------------------------------------------------------
   4. Kiem tra metadata theo hop dong
--------------------------------------------------------------------------- */
-- 4a. Kieu DATETIME2(7) cho ca 4 cot period moi nhanh
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', b.Branch, N'ValidFrom/ValidTo la DATETIME2(7) (Current + History)',
       N'4 cot', CONVERT(NVARCHAR(10), x.Cnt) + N' cot',
       CASE WHEN x.Cnt = 4 THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
CROSS APPLY (
    SELECT COUNT(*) AS Cnt
    FROM sys.columns c
    WHERE c.name IN (N'ValidFrom', N'ValidTo')
      AND TYPE_NAME(c.system_type_id) = N'datetime2' AND c.scale = 7
      AND c.object_id IN (
            CASE b.Branch WHEN N'Manual' THEN OBJECT_ID(N'demo.ProductPrice_Manual')
                          ELSE OBJECT_ID(N'demo.ProductPrice_Native') END,
            CASE b.Branch WHEN N'Manual' THEN OBJECT_ID(N'demo.ProductPrice_ManualHistory')
                          ELSE OBJECT_ID(@NativeHist) END)
) x
WHERE b.Ready = 1;

-- 4b. Manual: trigger dang bat tren bang Current
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', N'Manual', N'Trigger tren demo.ProductPrice_Manual', N'>= 1 trigger dang bat',
       ISNULL(STRING_AGG(tr.name, N', '), N'(khong co)'),
       CASE WHEN COUNT(tr.object_id) >= 1 THEN N'PASS' ELSE N'FAIL' END
FROM (SELECT 1 AS x) d
LEFT JOIN sys.triggers tr
       ON tr.parent_id = OBJECT_ID(N'demo.ProductPrice_Manual') AND tr.is_disabled = 0
HAVING @ManualReady = 1;

-- 4c. Manual: PK cua History la HistoryID BIGINT IDENTITY (khong dung ProductID)
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', N'Manual', N'PK ManualHistory', N'HistoryID BIGINT IDENTITY',
       ISNULL(STRING_AGG(c.name + N' ' + TYPE_NAME(c.system_type_id)
              + CASE WHEN c.is_identity = 1 THEN N' IDENTITY' ELSE N'' END, N', '), N'(khong co PK)'),
       CASE WHEN COUNT(*) = 1 AND MAX(c.name) = N'HistoryID'
                 AND MAX(TYPE_NAME(c.system_type_id)) = N'bigint'
                 AND MAX(CONVERT(INT, c.is_identity)) = 1 THEN N'PASS' ELSE N'FAIL' END
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'demo.ProductPrice_ManualHistory') AND i.is_primary_key = 1
HAVING @ManualReady = 1;

-- 4d. Native: History do SQL Server quan ly, retention INFINITE cho lan doi chung chinh
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', N'Native', N'History table va retention',
       N'demo.ProductPrice_NativeHistory, INFINITE',
       @NativeHist + N', ' + ISNULL(t.history_retention_period_unit_desc, N'?'),
       CASE WHEN @NativeHist = N'[demo].[ProductPrice_NativeHistory]'
                 AND t.history_retention_period_unit_desc = N'INFINITE' THEN N'PASS' ELSE N'FAIL' END
FROM sys.tables t
WHERE @NativeHist IS NOT NULL AND t.object_id = OBJECT_ID(N'demo.ProductPrice_Native');

-- 4e. Danh muc khong doi: 5 Product, 104 van con sau DELETE gia
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'T4', N'Chung', N'dbo.Product khong doi (5 dong, co 104)', N'5 dong, 104 ton tai',
       CONVERT(NVARCHAR(10), COUNT(*)) + N' dong, 104 '
       + CASE WHEN SUM(CASE WHEN ProductID = 104 THEN 1 ELSE 0 END) = 1 THEN N'ton tai' ELSE N'MAT' END,
       CASE WHEN COUNT(*) = 5 AND SUM(CASE WHEN ProductID = 104 THEN 1 ELSE 0 END) = 1
            THEN N'PASS' ELSE N'FAIL' END
FROM dbo.Product;

/* ---------------------------------------------------------------------------
   5. Current: gia tung san pham va ValidTo cuc dai
--------------------------------------------------------------------------- */
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT CASE e.ProductID WHEN 105 THEN N'T1' WHEN 101 THEN N'T2/T3' WHEN 104 THEN N'T4' ELSE N'T5' END,
       b.Branch, N'Current ' + CONVERT(NVARCHAR(10), e.ProductID),
       ISNULL(CONVERT(NVARCHAR(20), e.Price), N'(khong co dong)'),
       ISNULL(a.Prices, N'(khong co dong)'),
       CASE WHEN ISNULL(a.Prices, N'') = ISNULL(CONVERT(NVARCHAR(20), e.Price), N'')
            THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
CROSS JOIN #ExpCur e
OUTER APPLY (SELECT STRING_AGG(CONVERT(NVARCHAR(20), c.UnitPrice), N', ') AS Prices
             FROM #Cur c WHERE c.Branch = b.Branch AND c.ProductID = e.ProductID) a
WHERE b.Ready = 1;

INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', b.Branch, N'Current: ValidTo = 9999-12-31 23:59:59.9999999, khong NULL',
       N'0 dong sai', CONVERT(NVARCHAR(10), COUNT(c.ProductID)) + N' dong sai',
       CASE WHEN COUNT(c.ProductID) = 0 THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
LEFT JOIN #Cur c ON c.Branch = b.Branch AND (c.ValidTo IS NULL OR c.ValidTo <> @MaxTo
                                             OR c.ValidFrom IS NULL)
WHERE b.Ready = 1
GROUP BY b.Branch;

/* ---------------------------------------------------------------------------
   6. History: danh sach gia da dong theo tung san pham
--------------------------------------------------------------------------- */
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT e.TestCase, b.Branch, N'History ' + CONVERT(NVARCHAR(10), e.ProductID),
       CASE WHEN e.Prices = N'' THEN N'(0 dong)' ELSE e.Prices END,
       ISNULL(a.Prices, N'(0 dong)'),
       CASE WHEN ISNULL(a.Prices, N'') = e.Prices THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
CROSS JOIN #ExpHist e
OUTER APPLY (SELECT STRING_AGG(CONVERT(NVARCHAR(20), h.UnitPrice), N', ')
                    WITHIN GROUP (ORDER BY h.ValidFrom, h.ValidTo) AS Prices
             FROM #Hist h WHERE h.Branch = b.Branch AND h.ProductID = e.ProductID) a
WHERE b.Ready = 1;

INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', b.Branch, N'History: ValidFrom < ValidTo < cuc dai, khong NULL',
       N'0 dong sai', CONVERT(NVARCHAR(10), COUNT(h.ProductID)) + N' dong sai',
       CASE WHEN COUNT(h.ProductID) = 0 THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
LEFT JOIN #Hist h ON h.Branch = b.Branch
                 AND (h.ValidFrom IS NULL OR h.ValidTo IS NULL
                      OR h.ValidFrom >= h.ValidTo OR h.ValidTo >= @MaxTo)
WHERE b.Ready = 1
GROUP BY b.Branch;

/* ---------------------------------------------------------------------------
   7. Tinh lien mach cua period
   - 101: ValidTo ban cu = ValidFrom ban ke tiep (khong ho, khong chong).
   - T5 : 102 va 103 dong cung mot moc (mot cau lenh, mot moc UTC).
--------------------------------------------------------------------------- */
;WITH v AS (
    SELECT Branch, ProductID, UnitPrice, ValidFrom, ValidTo FROM #Hist WHERE ProductID = 101
    UNION ALL
    SELECT Branch, ProductID, UnitPrice, ValidFrom, ValidTo FROM #Cur  WHERE ProductID = 101
), s AS (
    SELECT *, LEAD(ValidFrom) OVER (PARTITION BY Branch ORDER BY ValidFrom) AS NextFrom
    FROM v
)
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'T2/T3', b.Branch, N'101: ValidTo ban cu = ValidFrom ban ke tiep',
       CONVERT(NVARCHAR(10), CASE WHEN @AfterStep >= 3 THEN 2 WHEN @AfterStep = 2 THEN 1 ELSE 0 END)
           + N' moc noi khop',
       CONVERT(NVARCHAR(10), SUM(CASE WHEN s.NextFrom IS NOT NULL AND s.ValidTo = s.NextFrom THEN 1 ELSE 0 END))
           + N' khop / ' + CONVERT(NVARCHAR(10), SUM(CASE WHEN s.NextFrom IS NOT NULL THEN 1 ELSE 0 END)) + N' moc',
       CASE WHEN SUM(CASE WHEN s.NextFrom IS NOT NULL THEN 1 ELSE 0 END)
                 = CASE WHEN @AfterStep >= 3 THEN 2 WHEN @AfterStep = 2 THEN 1 ELSE 0 END
             AND SUM(CASE WHEN s.NextFrom IS NOT NULL AND s.ValidTo <> s.NextFrom THEN 1 ELSE 0 END) = 0
            THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
JOIN s ON s.Branch = b.Branch
WHERE b.Ready = 1
GROUP BY b.Branch;

IF @AfterStep >= 5
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'T5', b.Branch, N'102 va 103 dong/mo cung mot moc',
       N'1 moc ValidTo (History) = 1 moc ValidFrom (Current)',
       CONVERT(NVARCHAR(10), (SELECT COUNT(DISTINCT ValidTo)   FROM #Hist h WHERE h.Branch = b.Branch AND h.ProductID IN (102, 103)))
         + N' moc dong / '
         + CONVERT(NVARCHAR(10), (SELECT COUNT(DISTINCT ValidFrom) FROM #Cur c WHERE c.Branch = b.Branch AND c.ProductID IN (102, 103)))
         + N' moc mo',
       CASE WHEN (SELECT COUNT(DISTINCT ValidTo) FROM #Hist h WHERE h.Branch = b.Branch AND h.ProductID IN (102, 103)) = 1
             AND (SELECT COUNT(DISTINCT ValidFrom) FROM #Cur c WHERE c.Branch = b.Branch AND c.ProductID IN (102, 103)) = 1
             AND (SELECT MAX(ValidTo) FROM #Hist h WHERE h.Branch = b.Branch AND h.ProductID IN (102, 103))
               = (SELECT MAX(ValidFrom) FROM #Cur c WHERE c.Branch = b.Branch AND c.ProductID IN (102, 103))
            THEN N'PASS' ELSE N'FAIL' END
FROM #Branch b
WHERE b.Ready = 1;

-- Manual: cac dong R0 cung mot moc mo luc bat nhanh (hop dong V4). Native: chi ghi nhan.
;WITH firstv AS (
    SELECT Branch, ProductID, MIN(ValidFrom) AS FirstFrom
    FROM (SELECT Branch, ProductID, ValidFrom FROM #Hist
          UNION ALL SELECT Branch, ProductID, ValidFrom FROM #Cur) u
    WHERE ProductID IN (101, 102, 103, 104)
    GROUP BY Branch, ProductID
)
INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status)
SELECT N'META', f.Branch, N'R0 (101-104) co chung mot ValidFrom luc bat nhanh', N'1 moc',
       CONVERT(NVARCHAR(10), COUNT(DISTINCT f.FirstFrom)) + N' moc: '
         + CONVERT(NVARCHAR(30), MIN(f.FirstFrom), 121),
       CASE WHEN f.Branch = N'Native' THEN N'INFO'
            WHEN COUNT(DISTINCT f.FirstFrom) = 1 THEN N'PASS' ELSE N'FAIL' END
FROM firstv f
GROUP BY f.Branch;

/* ---------------------------------------------------------------------------
   8. Doi chung hai nhanh (chi khi ca hai san sang): cung gia tri, khong so timestamp
--------------------------------------------------------------------------- */
IF @ManualReady = 1 AND @NativeHist IS NOT NULL
BEGIN
    DECLARE @mCur NVARCHAR(400), @nCur NVARCHAR(400), @mHist NVARCHAR(400), @nHist NVARCHAR(400);
    SELECT @mCur = STRING_AGG(CONVERT(NVARCHAR(10), ProductID) + N'=' + CONVERT(NVARCHAR(20), UnitPrice), N'; ')
                   WITHIN GROUP (ORDER BY ProductID) FROM #Cur WHERE Branch = N'Manual';
    SELECT @nCur = STRING_AGG(CONVERT(NVARCHAR(10), ProductID) + N'=' + CONVERT(NVARCHAR(20), UnitPrice), N'; ')
                   WITHIN GROUP (ORDER BY ProductID) FROM #Cur WHERE Branch = N'Native';
    SELECT @mHist = STRING_AGG(CONVERT(NVARCHAR(10), ProductID) + N'=' + CONVERT(NVARCHAR(20), UnitPrice), N'; ')
                   WITHIN GROUP (ORDER BY ProductID, ValidFrom) FROM #Hist WHERE Branch = N'Manual';
    SELECT @nHist = STRING_AGG(CONVERT(NVARCHAR(10), ProductID) + N'=' + CONVERT(NVARCHAR(20), UnitPrice), N'; ')
                   WITHIN GROUP (ORDER BY ProductID, ValidFrom) FROM #Hist WHERE Branch = N'Native';

    INSERT INTO #Result (TestCase, Branch, CheckName, Expected, Actual, Status) VALUES
        (N'DOI CHUNG', N'Ca hai', N'Current Manual = Current Native',
         ISNULL(@nCur, N'(rong)'), ISNULL(@mCur, N'(rong)'),
         CASE WHEN ISNULL(@mCur, N'') = ISNULL(@nCur, N'') THEN N'PASS' ELSE N'FAIL' END),
        (N'DOI CHUNG', N'Ca hai', N'History Manual = History Native (gia, thu tu)',
         ISNULL(@nHist, N'(rong)'), ISNULL(@mHist, N'(rong)'),
         CASE WHEN ISNULL(@mHist, N'') = ISNULL(@nHist, N'') THEN N'PASS' ELSE N'FAIL' END);
END;

/* ---------------------------------------------------------------------------
   9. Xuat ket qua
--------------------------------------------------------------------------- */
PRINT N'--- Du lieu doc duoc: Current ---';
SELECT Branch, ProductID, UnitPrice, ValidFrom, ValidTo FROM #Cur ORDER BY Branch, ProductID;
PRINT N'--- Du lieu doc duoc: History ---';
SELECT Branch, ProductID, UnitPrice, ValidFrom, ValidTo FROM #Hist ORDER BY Branch, ProductID, ValidFrom;

SELECT TestCase, Branch, CheckName, Expected, Actual, Status,
       @AfterStep AS AfterStep,
       SERVERPROPERTY('ProductVersion') AS ProductVersion,
       SYSUTCDATETIME() AS CheckedAtUtc
FROM #Result
ORDER BY Seq;

SELECT Branch,
       SUM(CASE WHEN Status = N'PASS' THEN 1 ELSE 0 END)    AS PassCount,
       SUM(CASE WHEN Status = N'FAIL' THEN 1 ELSE 0 END)    AS FailCount,
       SUM(CASE WHEN Status = N'BLOCKED' THEN 1 ELSE 0 END) AS BlockedCount,
       CASE WHEN SUM(CASE WHEN Status = N'BLOCKED' THEN 1 ELSE 0 END) > 0 THEN N'BLOCKED'
            WHEN SUM(CASE WHEN Status = N'FAIL' THEN 1 ELSE 0 END) > 0 THEN N'FAIL'
            ELSE N'PASS' END AS Verdict
FROM #Result
GROUP BY Branch
ORDER BY Branch;
GO
