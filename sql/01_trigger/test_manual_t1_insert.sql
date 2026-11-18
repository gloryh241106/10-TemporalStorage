/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / T1: Insert the first price for product 105
SQL Server 2025 (17.x)
Run after create_manual_trigger.sql, before T2-T5.
Prerequisite: Four initial Current rows, empty History, trigger enabled.
Affected objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: Current has product 105 at 19000 VND; History stays empty.
This script changes data and commits T1 when its checks pass.
Run once per fresh demo. It does not delete data or reset previous tests.
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 1. Check execution mode and trigger installation
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52300, N'Run T1 with no open transaction and implicit transactions OFF.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.triggers
    WHERE object_id = OBJECT_ID(N'demo.trg_ProductPrice_Manual_History')
      AND is_disabled = 0
)
    THROW 52301, N'The Manual History trigger must be installed and enabled.', 1;

DECLARE @BeforeInsertUtc DATETIME2(7);
DECLARE @AfterInsertUtc DATETIME2(7);

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM demo.ProductPrice_Manual WHERE ProductID = 105)
       OR (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 4
       OR EXISTS (SELECT 1 FROM demo.ProductPrice_ManualHistory)
    BEGIN
        THROW 52302, N'T1 requires four initial prices, no price for 105 and empty History.', 1;
    END;

    -- 2. Insert a business row without supplying period columns
    SET @BeforeInsertUtc = SYSUTCDATETIME();

    INSERT INTO demo.ProductPrice_Manual
        (ProductID, UnitPrice, CurrencyCode, PriceNote)
    VALUES
        (105, 19000.00, 'VND', N'Giá khởi tạo');

    SET @AfterInsertUtc = SYSUTCDATETIME();

    -- 3. Verify the new current version and its observed UTC period
    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 5
       OR NOT EXISTS (
           SELECT 1
           FROM demo.ProductPrice_Manual
           WHERE ProductID = 105
             AND UnitPrice = 19000.00
             AND CurrencyCode = 'VND'
             AND PriceNote = N'Giá khởi tạo'
             AND ValidFrom >= @BeforeInsertUtc
             AND ValidFrom <= @AfterInsertUtc
             AND ValidTo = CONVERT(DATETIME2(7), '9999-12-31T23:59:59.9999999')
       )
    BEGIN
        THROW 52303, N'T1 failed: the inserted current version or period is incorrect.', 1;
    END;

    -- INSERT opens a first version; no old version should enter History.
    IF EXISTS (SELECT 1 FROM demo.ProductPrice_ManualHistory)
        THROW 52304, N'T1 failed: INSERT unexpectedly created History rows.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

-- 4. Display evidence after a successful commit
SELECT
    N'PASS T1 - Manual INSERT' AS VerificationResult,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    @BeforeInsertUtc AS BeforeInsertUtc,
    @AfterInsertUtc AS AfterInsertUtc,
    SYSUTCDATETIME() AS VerifiedAtUtc;

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_Manual
WHERE ProductID = 105;

SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_ManualHistory
WHERE ProductID = 105;

SELECT
    (SELECT COUNT(*) FROM demo.ProductPrice_Manual) AS CurrentRows,
    (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) AS HistoryRows;
GO
