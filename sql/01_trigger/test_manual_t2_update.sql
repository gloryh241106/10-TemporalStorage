/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / T2: Update product 101 from 25000 to 27000 VND
SQL Server 2025 (17.x)
Run after test_manual_t1_insert.sql passes, before T3-T5.
Affected objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: Current has 101 at 27000; History has its old 25000 version.
The old ValidTo must equal the new ValidFrom; other current rows stay unchanged.
This script commits T2 in its own transaction. Run once per fresh demo.
UTC markers below are for this local Manual run. Kiet records new common
markers when testing Manual and Native together.
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 1. Check execution mode and trigger installation
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52310, N'Run T2 with no open transaction and implicit transactions OFF.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.triggers
    WHERE object_id = OBJECT_ID(N'demo.trg_ProductPrice_Manual_History')
      AND is_disabled = 0
)
    THROW 52311, N'The Manual History trigger must be installed and enabled.', 1;

DECLARE @ReadyUtc DATETIME2(7);
DECLARE @BeforeUpdateUtc DATETIME2(7);
DECLARE @AfterUpdateUtc DATETIME2(7);
DECLARE @BetweenUtc DATETIME2(7);

DECLARE @Before TABLE (
    ProductID INT PRIMARY KEY,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

BEGIN TRY
    BEGIN TRANSACTION;

    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 5
       OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual
                      WHERE ProductID = 105 AND UnitPrice = 19000)
       OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual
                      WHERE ProductID = 101 AND UnitPrice = 25000)
       OR EXISTS (SELECT 1 FROM demo.ProductPrice_ManualHistory)
    BEGIN
        THROW 52312, N'T2 requires the state after T1: 101 at 25000, 105 at 19000, empty History.', 1;
    END;

    INSERT INTO @Before
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_Manual;

    -- Keep an observable point inside the initial 25000 version for AS OF.
    SET @ReadyUtc = SYSUTCDATETIME();
    WAITFOR DELAY '00:00:00.020';

    -- 2. Change only the business price; the trigger manages both periods
    SET @BeforeUpdateUtc = SYSUTCDATETIME();

    UPDATE demo.ProductPrice_Manual
    SET UnitPrice = 27000.00
    WHERE ProductID = 101;

    SET @AfterUpdateUtc = SYSUTCDATETIME();

    -- 3. Verify the old snapshot, the new price and the shared period boundary
    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 5
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 1
       OR NOT EXISTS (
           SELECT 1
           FROM demo.ProductPrice_Manual AS c
           INNER JOIN demo.ProductPrice_ManualHistory AS h
               ON h.ProductID = c.ProductID
           WHERE c.ProductID = 101
             AND c.UnitPrice = 27000.00
             AND h.UnitPrice = 25000.00
             AND h.ValidTo = c.ValidFrom
             AND h.ValidFrom <= @ReadyUtc
             AND @ReadyUtc < h.ValidTo
             AND c.ValidFrom >= @BeforeUpdateUtc
             AND c.ValidFrom <= @AfterUpdateUtc
             AND c.ValidTo = CONVERT(DATETIME2(7), '9999-12-31T23:59:59.9999999')
       )
    BEGIN
        THROW 52313, N'T2 failed: current price, history count or period boundary is incorrect.', 1;
    END;

    IF EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM @Before WHERE ProductID = 101
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM demo.ProductPrice_ManualHistory WHERE ProductID = 101
    ) OR EXISTS (
        SELECT ProductID, CurrencyCode, PriceNote FROM @Before WHERE ProductID = 101
        EXCEPT
        SELECT ProductID, CurrencyCode, PriceNote
        FROM demo.ProductPrice_Manual WHERE ProductID = 101
    ) OR EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @Before WHERE ProductID <> 101
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_Manual WHERE ProductID <> 101
    )
    BEGIN
        THROW 52314, N'T2 failed: the old snapshot or unaffected values were not preserved.', 1;
    END;

    COMMIT TRANSACTION;
    SET @BetweenUtc = SYSUTCDATETIME();
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

-- 4. Save this output before running T3 in a separate transaction
SELECT
    N'PASS T2 - Manual UPDATE' AS VerificationResult,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    @ReadyUtc AS ReadyUtc,
    @BeforeUpdateUtc AS BeforeUpdateUtc,
    @AfterUpdateUtc AS AfterUpdateUtc,
    @BetweenUtc AS BetweenUtc;

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_Manual WHERE ProductID = 101;

SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_ManualHistory WHERE ProductID = 101;

SELECT
    (SELECT COUNT(*) FROM demo.ProductPrice_Manual) AS CurrentRows,
    (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) AS HistoryRows;
GO
