/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / Manual T7 handoff: Query versions in a UTC range and explain boundaries
SQL Server 2025 (17.x)
Run after T2 and T3 have committed; product 101 must currently cost 30000.
Read objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: FROM start TO start-of-30000 returns 25000 and 27000 only.
Read-only for persistent data; table variables only hold query results.
This script can be rerun without modifying prices or History.

DEMO NOTE: The hard-coded @StartUtc below belongs ONLY to the run
on 2026-11-18. Before EVERY new demo/run/database, replace it with the
ReadyUtc observed before T2 in that run.
For the group's Manual/Native comparison, use Kiet's script instead:
sql/04_testing/T6_T7_time_travel_queries.sql (fill its observed UTC marks).
The upper bound is read from the actual current version, not invented.
All predicates exclude zero-duration versions through the shared version set.
Reference: https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal/overview
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;

-- 1. Set the observed lower bound; obtain the upper bound from Current
DECLARE @ProductID INT = 101;
DECLARE @StartUtc DATETIME2(7) = '2026-11-18T02:39:13.0228905';
DECLARE @EndUtc DATETIME2(7);
DECLARE @Start27Utc DATETIME2(7);

IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52410, N'Run Manual range queries outside an open transaction, with implicit transactions OFF.', 1;

SELECT @EndUtc = ValidFrom
FROM demo.ProductPrice_Manual
WHERE ProductID = @ProductID AND UnitPrice = 30000.00;

IF @StartUtc IS NULL OR @EndUtc IS NULL OR @StartUtc >= @EndUtc
    THROW 52411, N'FROM/TO requires start < end and the current 30000 version after T3.', 1;

-- 2. Combine Current and History, keeping matching column lists
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

IF (SELECT COUNT(*) FROM @Versions WHERE UnitPrice = 27000.00) <> 1
    THROW 52412, N'The boundary example requires exactly one 27000 version from T2.', 1;

SELECT @Start27Utc = ValidFrom FROM @Versions WHERE UnitPrice = 27000.00;

IF @Start27Utc >= @EndUtc
    THROW 52413, N'The 27000 version must start before the current 30000 version.', 1;

-- 3. Main T7 query: version interval overlaps [start, end)
DECLARE @Range TABLE (
    ProductID INT,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

INSERT INTO @Range
SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM @Versions
WHERE ValidFrom < @EndUtc AND ValidTo > @StartUtc;

-- 4. Evaluate the main result and four related boundary examples
DECLARE @Actual TABLE (
    CaseID INT,
    UnitPrice DECIMAL(12,2),
    ValidFrom DATETIME2(7)
);

INSERT INTO @Actual SELECT 1, UnitPrice, ValidFrom FROM @Range;

-- The 25000 version ends exactly at this lower bound and must be excluded.
INSERT INTO @Actual
SELECT 2, UnitPrice, ValidFrom FROM @Versions
WHERE ValidFrom < @EndUtc AND ValidTo > @Start27Utc;

-- AS OF includes the version starting exactly at the chosen instant.
INSERT INTO @Actual
SELECT 3, UnitPrice, ValidFrom FROM @Versions
WHERE ValidFrom <= @EndUtc AND ValidTo > @EndUtc;

-- BETWEEN also includes versions starting exactly at its upper bound.
INSERT INTO @Actual
SELECT 4, UnitPrice, ValidFrom FROM @Versions
WHERE ValidFrom <= @EndUtc AND ValidTo > @StartUtc;

-- CONTAINED IN requires the full version interval to fit inside the range.
INSERT INTO @Actual
SELECT 5, UnitPrice, ValidFrom FROM @Versions
WHERE ValidFrom >= @StartUtc AND ValidTo <= @EndUtc;

DECLARE @Cases TABLE (
    CaseID INT PRIMARY KEY,
    TestCase NVARCHAR(70),
    ExpectedRows INT,
    ExpectedPrices NVARCHAR(100)
);

INSERT INTO @Cases VALUES
    (1, N'T7 - FROM ready TO start-of-30000', 2, N'25000.00, 27000.00'),
    (2, N'Boundary - FROM start-of-27000 TO start-of-30000', 1, N'27000.00'),
    (3, N'Boundary - AS OF start-of-30000', 1, N'30000.00'),
    (4, N'Appendix - BETWEEN ready AND start-of-30000', 3, N'25000.00, 27000.00, 30000.00'),
    (5, N'Appendix - CONTAINED IN (ready, start-of-30000)', 1, N'27000.00');

DECLARE @Checks TABLE (
    CaseID INT,
    TestCase NVARCHAR(70),
    ExpectedPrices NVARCHAR(100),
    ActualPrices NVARCHAR(200),
    ExpectedRows INT,
    ActualRows INT,
    Status NVARCHAR(4)
);

INSERT INTO @Checks
SELECT c.CaseID, c.TestCase, c.ExpectedPrices, actual.ActualPrices,
       c.ExpectedRows, actual.ActualRows,
       CASE WHEN actual.ActualRows = c.ExpectedRows
                  AND actual.ActualPrices = c.ExpectedPrices
            THEN N'PASS' ELSE N'FAIL' END
FROM @Cases AS c
OUTER APPLY (
    SELECT COUNT(*) AS ActualRows,
           STRING_AGG(CONVERT(NVARCHAR(MAX), UnitPrice), N', ')
               WITHIN GROUP (ORDER BY ValidFrom, UnitPrice) AS ActualPrices
    FROM @Actual AS a WHERE a.CaseID = c.CaseID
) AS actual;

-- 5. Display real boundaries, main T7 rows and the comparison table
SELECT @ProductID AS ProductID, @StartUtc AS StartUtc,
       @Start27Utc AS StartOf27000Utc, @EndUtc AS EndUtc_StartOf30000;

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM @Range ORDER BY ValidFrom, ValidTo;

SELECT TestCase, ExpectedPrices, ActualPrices, ExpectedRows, ActualRows, Status
FROM @Checks ORDER BY CaseID;

IF EXISTS (SELECT 1 FROM @Checks WHERE Status <> N'PASS')
    THROW 52414, N'Manual range or boundary checks failed. Inspect the recorded start and actual periods.', 1;

SELECT N'PASS T7 - Manual range and boundaries' AS VerificationResult,
       SERVERPROPERTY('ProductVersion') AS ProductVersion,
       SERVERPROPERTY('Edition') AS Edition,
       SYSUTCDATETIME() AS VerifiedAtUtc;
GO
