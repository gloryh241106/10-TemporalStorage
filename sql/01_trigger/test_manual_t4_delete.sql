/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / T4: Delete the current price of product 104
SQL Server 2025 (17.x)
Run after test_manual_t3_update.sql passes and commits, before T5.
Affected objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: Current no longer has 104; History keeps its 45000 version.
Product 104 remains in dbo.Product; previous history and other prices stay intact.
This script changes data and commits T4 when checks pass. Run once per demo.
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 1. Check execution mode and trigger installation
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52330, N'Run T4 with no open transaction and implicit transactions OFF.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.triggers
    WHERE object_id = OBJECT_ID(N'demo.trg_ProductPrice_Manual_History')
      AND is_disabled = 0
)
    THROW 52331, N'The Manual History trigger must be installed and enabled.', 1;

DECLARE @BeforeDeleteUtc DATETIME2(7);
DECLARE @AfterDeleteUtc DATETIME2(7);

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

    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 5
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 2
       OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual
                      WHERE ProductID = 101 AND UnitPrice = 30000)
       OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual
                      WHERE ProductID = 104 AND UnitPrice = 45000)
       OR EXISTS (SELECT 1 FROM demo.ProductPrice_ManualHistory WHERE ProductID = 104)
       OR NOT EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID = 104)
    BEGIN
        THROW 52332, N'T4 requires the committed T3 state and product 104 with a current price of 45000.', 1;
    END;

    INSERT INTO @Before
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_Manual;

    INSERT INTO @HistoryBefore
    SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_ManualHistory;

    -- 2. Delete the price row, not the product in the catalog
    SET @BeforeDeleteUtc = SYSUTCDATETIME();

    DELETE FROM demo.ProductPrice_Manual
    WHERE ProductID = 104;

    SET @AfterDeleteUtc = SYSUTCDATETIME();

    -- 3. Verify the deleted version survives with a closed UTC period
    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 4
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 3
       OR EXISTS (SELECT 1 FROM demo.ProductPrice_Manual WHERE ProductID = 104)
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory WHERE ProductID = 104) <> 1
       OR NOT EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID = 104)
       OR NOT EXISTS (
           SELECT 1 FROM demo.ProductPrice_ManualHistory
           WHERE ProductID = 104
             AND UnitPrice = 45000.00
             AND ValidFrom < ValidTo
             AND ValidTo >= @BeforeDeleteUtc
             AND ValidTo <= @AfterDeleteUtc
       )
    BEGIN
        THROW 52333, N'T4 failed: current deletion, saved history, period or product existence is incorrect.', 1;
    END;

    -- Preserve the full old row, earlier history and every unaffected price.
    IF EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM @Before WHERE ProductID = 104
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM demo.ProductPrice_ManualHistory WHERE ProductID = 104
    ) OR EXISTS (
        SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @HistoryBefore
        EXCEPT
        SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_ManualHistory
    ) OR EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @Before WHERE ProductID <> 104
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_Manual
    )
    BEGIN
        THROW 52334, N'T4 failed: the deleted snapshot, earlier history or unaffected prices changed.', 1;
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
    N'PASS T4 - Manual DELETE' AS VerificationResult,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    @BeforeDeleteUtc AS BeforeDeleteUtc,
    @AfterDeleteUtc AS AfterDeleteUtc,
    SYSUTCDATETIME() AS VerifiedAtUtc;

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_Manual WHERE ProductID = 104;

SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_ManualHistory WHERE ProductID = 104;

SELECT ProductID, ProductName, Category
FROM dbo.Product WHERE ProductID = 104;

SELECT
    (SELECT COUNT(*) FROM demo.ProductPrice_Manual) AS CurrentRows,
    (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) AS HistoryRows;
GO
