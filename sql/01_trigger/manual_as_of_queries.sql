/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / Manual T6 handoff: Query the price at three observed UTC instants
SQL Server 2025 (17.x)
Run after T2 and T3 have committed on the Manual branch.
Read objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: Product 101 has prices 25000 / 27000 / 30000 at the three marks.
Read-only for persistent data; table variables only hold query results.
This script can be rerun without modifying prices or History.

DEMO NOTE: The three hard-coded UTC marks below belong ONLY to the run
on 2026-11-18. Before EVERY new demo/run/database, replace @t_ready,
@t_between and @t_after_T3 with the UTC marks observed in that run.
For the group's Manual/Native comparison, use Kiet's script instead:
sql/04_testing/T6_T7_time_travel_queries.sql (fill its observed UTC marks).
Manual query semantics: ValidFrom <= @AtUtc AND ValidTo > @AtUtc.
Zero-duration versions are excluded, as with Native FOR SYSTEM_TIME.
Reference: https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal/overview
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;

-- 1. Use the UTC instants recorded during T2 and T3
DECLARE @ProductID INT = 101;
DECLARE @t_ready DATETIME2(7) = '2026-11-18T02:39:13.0228905';
DECLARE @t_between DATETIME2(7) = '2026-11-18T02:39:13.1297539';
DECLARE @t_after_T3 DATETIME2(7) = '2026-11-18T02:42:58.2776693';

IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52400, N'Run Manual AS OF outside an open transaction, with implicit transactions OFF.', 1;

IF @t_ready IS NULL OR @t_between IS NULL OR @t_after_T3 IS NULL
   OR NOT (@t_ready < @t_between AND @t_between < @t_after_T3)
    THROW 52401, N'Provide three observed UTC marks in increasing order.', 1;

-- 2. Combine matching business and period columns from Current and History
-- HistoryID belongs only to History and is deliberately not part of this union.
DECLARE @Versions TABLE (
    ProductID INT,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

INSERT INTO @Versions
    (ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo)
SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM (
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_Manual
    UNION ALL
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_ManualHistory
) AS versions
WHERE ProductID = @ProductID AND ValidFrom < ValidTo;

IF NOT EXISTS (SELECT 1 FROM @Versions)
    THROW 52402, N'No positive-duration Manual versions were found for the requested product.', 1;

-- 3. Query the same version set at each recorded instant
DECLARE @Marks TABLE (
    Seq INT PRIMARY KEY,
    MarkName NVARCHAR(30),
    AtUtc DATETIME2(7),
    ExpectedPrice DECIMAL(12,2)
);

INSERT INTO @Marks VALUES
    (1, N'Before T2', @t_ready, 25000.00),
    (2, N'Between T2 and T3', @t_between, 27000.00),
    (3, N'After T3', @t_after_T3, 30000.00);

DECLARE @AsOf TABLE (
    Seq INT,
    MarkName NVARCHAR(30),
    AtUtc DATETIME2(7),
    ProductID INT,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

INSERT INTO @AsOf
SELECT m.Seq, m.MarkName, m.AtUtc,
       v.ProductID, v.UnitPrice, v.CurrencyCode, v.PriceNote, v.ValidFrom, v.ValidTo
FROM @Marks AS m
INNER JOIN @Versions AS v
    ON v.ValidFrom <= m.AtUtc AND v.ValidTo > m.AtUtc;

DECLARE @Checks TABLE (
    Seq INT,
    MarkName NVARCHAR(30),
    AtUtc DATETIME2(7),
    ExpectedPrice DECIMAL(12,2),
    ActualPrice DECIMAL(12,2),
    ActualRows INT,
    Status NVARCHAR(4)
);

INSERT INTO @Checks
SELECT m.Seq, m.MarkName, m.AtUtc, m.ExpectedPrice,
       actual.ActualPrice, actual.ActualRows,
       CASE WHEN actual.ActualRows = 1 AND actual.ActualPrice = m.ExpectedPrice
            THEN N'PASS' ELSE N'FAIL' END
FROM @Marks AS m
OUTER APPLY (
    SELECT COUNT(*) AS ActualRows, MIN(UnitPrice) AS ActualPrice
    FROM @AsOf AS a WHERE a.Seq = m.Seq
) AS actual;

-- 4. Display the input versions, actual rows and Expected/Actual checks
SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM @Versions ORDER BY ValidFrom, ValidTo;

SELECT MarkName, AtUtc, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM @AsOf ORDER BY Seq, ValidFrom;

SELECT N'T6 - Manual AS OF' AS TestCase,
       MarkName, AtUtc, ExpectedPrice, ActualPrice, ActualRows, Status
FROM @Checks ORDER BY Seq;

IF EXISTS (SELECT 1 FROM @Checks WHERE Status <> N'PASS')
    THROW 52403, N'Manual AS OF failed. Check recorded UTC marks and actual periods; do not rerun the DML tests.', 1;

SELECT N'PASS T6 - Manual AS OF' AS VerificationResult,
       SERVERPROPERTY('ProductVersion') AS ProductVersion,
       SERVERPROPERTY('Edition') AS Edition,
       SYSUTCDATETIME() AS VerifiedAtUtc;
GO
