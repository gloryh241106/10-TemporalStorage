/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2: Add UTC period columns to Manual Current
SQL Server 2025 (17.x)
Run after create_manual_history.sql on a baseline that passed T0.
Manual triggers must not be installed yet.
Affected object: demo.ProductPrice_Manual
Expected result: Four initial rows have the same ValidFrom;
                 ValidTo is the maximum datetime2(7) value.
*/

USE [TemporalSeminarDB];
GO

SET XACT_ABORT ON;

-- 1. Check installation prerequisites
-- Prevent accidentally running the installation twice.
IF COL_LENGTH(N'demo.ProductPrice_Manual', N'ValidFrom') IS NOT NULL
   OR COL_LENGTH(N'demo.ProductPrice_Manual', N'ValidTo') IS NOT NULL
BEGIN
    THROW 52200, N'Manual period columns already exist.', 1;
END;

-- Run this installation outside an existing transaction.
IF @@TRANCOUNT <> 0
BEGIN
    THROW 52201, N'An open transaction already exists.', 1;
END;

-- 2. Add and initialize period columns in one transaction
BEGIN TRY
    BEGIN TRANSACTION;

    -- One real UTC timestamp for all initial rows.
    DECLARE @StartUtc DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @EndUtc DATETIME2(7)
        = '9999-12-31T23:59:59.9999999';

    -- Temporarily allow NULL while initializing existing rows.
    ALTER TABLE demo.ProductPrice_Manual
    ADD
        ValidFrom DATETIME2(7) NULL,
        ValidTo DATETIME2(7) NULL;

    -- Compile this UPDATE after the new columns exist.
    EXEC sys.sp_executesql
        N'UPDATE demo.ProductPrice_Manual
          SET ValidFrom = @StartUtc,
              ValidTo = @EndUtc;',
        N'@StartUtc DATETIME2(7), @EndUtc DATETIME2(7)',
        @StartUtc = @StartUtc,
        @EndUtc = @EndUtc;

    -- Every current row must have both timestamps.
    ALTER TABLE demo.ProductPrice_Manual
        ALTER COLUMN ValidFrom DATETIME2(7) NOT NULL;

    ALTER TABLE demo.ProductPrice_Manual
        ALTER COLUMN ValidTo DATETIME2(7) NOT NULL;

    -- Defaults for future INSERT statements.
    ALTER TABLE demo.ProductPrice_Manual
    ADD CONSTRAINT DF_ProductPrice_Manual_ValidFrom
        DEFAULT (SYSUTCDATETIME()) FOR ValidFrom;

    ALTER TABLE demo.ProductPrice_Manual
    ADD CONSTRAINT DF_ProductPrice_Manual_ValidTo
        DEFAULT ('9999-12-31T23:59:59.9999999') FOR ValidTo;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- 3. Verify current prices and initialized periods
SELECT
    ProductID,
    UnitPrice,
    CurrencyCode,
    PriceNote,
    ValidFrom,
    ValidTo
FROM demo.ProductPrice_Manual
ORDER BY ProductID;
GO
