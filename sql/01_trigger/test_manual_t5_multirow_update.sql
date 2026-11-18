/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / T5: Increase the prices of products 102 and 103 in one UPDATE statement
SQL Server 2025 (17.x)
Run after test_manual_t4_delete.sql passes and commits.
Affected objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: Current 102 = 27000, 103 = 30000; History saves 25000 and 28000.
Both rows must use the same UTC boundary for closing and opening versions.
Earlier history and unaffected current rows must remain unchanged.
This script changes data and commits T5 when checks pass. Run once per demo.
It does not reset data or rerun setup/T1-T4 after restarting SQL Server or SSMS.
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 1. Check execution mode and trigger installation
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52340, N'Run T5 with no open transaction and implicit transactions OFF.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.triggers
    WHERE object_id = OBJECT_ID(N'demo.trg_ProductPrice_Manual_History')
      AND is_disabled = 0
)
    THROW 52341, N'The Manual History trigger must be installed and enabled.', 1;

DECLARE @BeforeUpdateUtc DATETIME2(7);
DECLARE @AfterUpdateUtc DATETIME2(7);

DECLARE @Before TABLE (
    ProductID INT PRIMARY KEY,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

DECLARE @HistoryBefore TABLE (
    HistoryID BIGINT PRIMARY KEY,
    ProductID INT,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

BEGIN TRY
    BEGIN TRANSACTION;

    -- Require the saved state after T4; refuse an accidental repeat of T5.
    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 4
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 3
       OR EXISTS (
           SELECT ProductID, UnitPrice
           FROM (VALUES (101, 30000.00), (102, 25000.00),
                        (103, 28000.00), (105, 19000.00)) AS expected(ProductID, UnitPrice)
           EXCEPT
           SELECT ProductID, UnitPrice FROM demo.ProductPrice_Manual
       )
       OR EXISTS (
           SELECT ProductID, UnitPrice
           FROM (VALUES (101, 25000.00), (101, 27000.00),
                        (104, 45000.00)) AS expected(ProductID, UnitPrice)
           EXCEPT
           SELECT ProductID, UnitPrice FROM demo.ProductPrice_ManualHistory
       )
    BEGIN
        THROW 52342, N'T5 requires the committed T4 state: four current prices and three history versions. Do not rerun old tests.', 1;
    END;

    INSERT INTO @Before
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_Manual;

    INSERT INTO @HistoryBefore
    SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_ManualHistory;

-- 2. Affect both products with one business UPDATE statement
    SET @BeforeUpdateUtc = SYSUTCDATETIME();

    UPDATE demo.ProductPrice_Manual
    SET UnitPrice = UnitPrice + 2000.00
    WHERE ProductID IN (102, 103);

    SET @AfterUpdateUtc = SYSUTCDATETIME();

    -- 3. Verify that neither affected row was lost or duplicated
    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 4
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 5
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory
           WHERE ProductID IN (102, 103)) <> 2
       OR EXISTS (
           SELECT ProductID, UnitPrice
           FROM (VALUES (102, 27000.00), (103, 30000.00)) AS expected(ProductID, UnitPrice)
           EXCEPT
           SELECT ProductID, UnitPrice FROM demo.ProductPrice_Manual
       )
    BEGIN
        THROW 52343, N'T5 failed: current prices or history row counts are incorrect.', 1;
    END;

    -- The two current versions must start at the same timestamp.
    IF (SELECT COUNT(DISTINCT ValidFrom) FROM demo.ProductPrice_Manual
        WHERE ProductID IN (102, 103)) <> 1
       OR (
           SELECT COUNT(*)
           FROM demo.ProductPrice_Manual AS c
           INNER JOIN demo.ProductPrice_ManualHistory AS h
               ON h.ProductID = c.ProductID
           INNER JOIN @Before AS b
               ON b.ProductID = c.ProductID
           WHERE c.ProductID IN (102, 103)
             AND c.UnitPrice = b.UnitPrice + 2000.00
             AND h.UnitPrice = b.UnitPrice
             AND h.ValidFrom = b.ValidFrom
             AND h.ValidFrom < h.ValidTo
             AND h.ValidTo = c.ValidFrom
             AND c.ValidFrom >= @BeforeUpdateUtc
             AND c.ValidFrom <= @AfterUpdateUtc
             AND c.ValidTo = CONVERT(DATETIME2(7), '9999-12-31T23:59:59.9999999')
       ) <> 2
    BEGIN
        THROW 52344, N'T5 failed: both rows must have matching old/new periods and one shared UTC boundary.', 1;
    END;

    -- Verify full old snapshots, retained history and unaffected current rows.
    IF EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM @Before WHERE ProductID IN (102, 103)
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM demo.ProductPrice_ManualHistory WHERE ProductID IN (102, 103)
    ) OR EXISTS (
        SELECT ProductID, CurrencyCode, PriceNote FROM @Before
        WHERE ProductID IN (102, 103)
        EXCEPT
        SELECT ProductID, CurrencyCode, PriceNote FROM demo.ProductPrice_Manual
        WHERE ProductID IN (102, 103)
    ) OR EXISTS (
        SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @HistoryBefore
        EXCEPT
        SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_ManualHistory
    ) OR EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @Before WHERE ProductID NOT IN (102, 103)
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_Manual WHERE ProductID NOT IN (102, 103)
    )
    BEGIN
        THROW 52345, N'T5 failed: an old snapshot, earlier history or unaffected values changed.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

-- 4. Display evidence after a successful commit
SELECT
    N'PASS T5 - Manual multirow UPDATE' AS VerificationResult,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    @BeforeUpdateUtc AS BeforeUpdateUtc,
    @AfterUpdateUtc AS AfterUpdateUtc,
    SYSUTCDATETIME() AS VerifiedAtUtc;

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_Manual WHERE ProductID IN (102, 103)
ORDER BY ProductID;

SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_ManualHistory WHERE ProductID IN (102, 103)
ORDER BY ProductID;

SELECT
    (SELECT COUNT(*) FROM demo.ProductPrice_Manual) AS CurrentRows,
    (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) AS HistoryRows;
GO
