/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy - C4 maintenance experiment (optional, separate from T1-T7)
Run after installing Manual History and its trigger; Current must have a row.
Creates disposable copies in schema c4_maintenance inside one transaction.
Copies the installed trigger, then adds PriceSource NVARCHAR(40) NULL.
All experimental DDL/DML is rolled back, including the copied trigger/schema.
The original demo tables and trigger are only read.
Expected: missing History column, NULL history value with the old trigger,
then correct old/new values after updating History, trigger and query.
Run outside a transaction with IMPLICIT_TRANSACTIONS OFF; requires DDL rights.
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52500, N'Run C4 outside a transaction, with implicit transactions OFF.', 1;
IF SCHEMA_ID(N'c4_maintenance') IS NOT NULL
    THROW 52501, N'c4_maintenance already exists; use a clean experiment namespace.', 1;

DECLARE @TriggerSql NVARCHAR(MAX) = OBJECT_DEFINITION(
    OBJECT_ID(N'demo.trg_ProductPrice_Manual_History'));
IF @TriggerSql IS NULL
    THROW 52502, N'Install the Manual trigger first; its definition must be readable.', 1;
IF NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual)
    THROW 52503, N'The experiment needs at least one current price.', 1;

DECLARE @ProductID INT = (SELECT MIN(ProductID) FROM demo.ProductPrice_Manual);
DECLARE @Cases TABLE (Step INT, Observation NVARCHAR(160), Status VARCHAR(4));
DECLARE @BeforeRepairUtc DATETIME2(7), @AfterRepairUtc DATETIME2(7);

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC(N'CREATE SCHEMA c4_maintenance AUTHORIZATION dbo;');
    -- SELECT INTO copies the data/columns, not the original constraints/indexes.
    -- Index design is outside this column-maintenance experiment.
    SELECT * INTO c4_maintenance.ProductPrice_Manual
    FROM demo.ProductPrice_Manual;
    SELECT TOP (0) * INTO c4_maintenance.ProductPrice_ManualHistory
    FROM demo.ProductPrice_ManualHistory;

    SET @TriggerSql = REPLACE(@TriggerSql, N'demo.', N'c4_maintenance.');
    -- Normalize the header so this works with CREATE / ALTER / CREATE OR ALTER.
    DECLARE @BodyAt INT = CHARINDEX(N'TRIGGER ', @TriggerSql);
    IF @BodyAt = 0
        THROW 52504, N'Cannot locate the installed trigger header.', 1;
    SET @TriggerSql = N'CREATE OR ALTER ' + SUBSTRING(@TriggerSql, @BodyAt, LEN(@TriggerSql));
    EXEC sys.sp_executesql @TriggerSql;

    -- 1. Adding only to Current leaves History out of sync.
    ALTER TABLE c4_maintenance.ProductPrice_Manual ADD PriceSource NVARCHAR(40) NULL;
    IF COL_LENGTH(N'c4_maintenance.ProductPrice_ManualHistory', N'PriceSource') IS NOT NULL
        THROW 52505, N'Expected History to remain unchanged in Manual.', 1;
    INSERT INTO @Cases VALUES (1, N'Current has PriceSource; Manual History does not add it automatically.', 'PASS');

    -- 2. Adding History alone still loses the old value with the old trigger.
    ALTER TABLE c4_maintenance.ProductPrice_ManualHistory ADD PriceSource NVARCHAR(40) NULL;
    EXEC sys.sp_executesql N'
        UPDATE c4_maintenance.ProductPrice_Manual SET PriceSource = N''web'' WHERE ProductID = @id;
        SELECT @start = ValidFrom FROM c4_maintenance.ProductPrice_Manual WHERE ProductID = @id;
        UPDATE c4_maintenance.ProductPrice_Manual SET PriceSource = N''counter'' WHERE ProductID = @id;',
        N'@id INT, @start DATETIME2(7) OUTPUT', @id = @ProductID, @start = @BeforeRepairUtc OUTPUT;
    EXEC sys.sp_executesql N'
        IF NOT EXISTS (SELECT 1 FROM c4_maintenance.ProductPrice_ManualHistory
                       WHERE ProductID = @id AND ValidFrom = @start AND PriceSource IS NULL)
            THROW 52506, N''Expected the old trigger to omit the web value.'', 1;',
        N'@id INT, @start DATETIME2(7)', @id = @ProductID, @start = @BeforeRepairUtc;
    INSERT INTO @Cases VALUES (2, N'History column exists, but the old trigger records NULL instead of web.', 'PASS');

    -- 3. Repair BOTH the INSERT column list and its SELECT from deleted.
    IF CHARINDEX(N'CurrencyCode, PriceNote, ValidFrom, ValidTo)', @TriggerSql) = 0
       OR CHARINDEX(N'd.PriceNote,', @TriggerSql) = 0
        THROW 52507, N'Trigger layout changed; adapt the two explicit column lists.', 1;
    SET @TriggerSql = REPLACE(@TriggerSql,
        N'CurrencyCode, PriceNote, ValidFrom, ValidTo)',
        N'CurrencyCode, PriceNote, PriceSource, ValidFrom, ValidTo)');
    SET @TriggerSql = REPLACE(@TriggerSql, N'd.PriceNote,', N'd.PriceNote, d.PriceSource,');
    EXEC sys.sp_executesql @TriggerSql;

    EXEC sys.sp_executesql N'
        SELECT @start = ValidFrom FROM c4_maintenance.ProductPrice_Manual WHERE ProductID = @id;
        UPDATE c4_maintenance.ProductPrice_Manual SET PriceSource = N''mobile'' WHERE ProductID = @id;
        IF NOT EXISTS (SELECT 1 FROM c4_maintenance.ProductPrice_ManualHistory
                       WHERE ProductID = @id AND ValidFrom = @start AND PriceSource = N''counter'')
            THROW 52508, N''The repaired trigger must preserve counter in History.'', 1;',
        N'@id INT, @start DATETIME2(7) OUTPUT', @id = @ProductID, @start = @AfterRepairUtc OUTPUT;
    INSERT INTO @Cases VALUES (3, N'After repairing the trigger, History preserves the old counter value.', 'PASS');

    -- 4. Extend BOTH UNION projections and the result shape to expose the column.
    -- The old six-column queries still run but cannot return PriceSource.
    EXEC sys.sp_executesql N'
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, PriceSource, ValidFrom, ValidTo
        FROM (
            SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, PriceSource, ValidFrom, ValidTo
            FROM c4_maintenance.ProductPrice_Manual
            UNION ALL
            SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, PriceSource, ValidFrom, ValidTo
            FROM c4_maintenance.ProductPrice_ManualHistory
        ) AS v WHERE ProductID = @id ORDER BY ValidFrom, ValidTo;
        IF (SELECT PriceSource FROM c4_maintenance.ProductPrice_Manual WHERE ProductID = @id) <> N''mobile''
            THROW 52509, N''Expected mobile in Current.'', 1;', N'@id INT', @id = @ProductID;
    INSERT INTO @Cases VALUES (4, N'The extended Current UNION ALL History query returns PriceSource.', 'PASS');

    -- Remove all disposable objects and data; keep observations in table variables.
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

IF SCHEMA_ID(N'c4_maintenance') IS NOT NULL
    THROW 52510, N'Experimental schema should be absent after rollback.', 1;

SELECT Step, Observation, Status FROM @Cases ORDER BY Step;
SELECT N'PASS C4 - Manual schema maintenance; experimental objects rolled back' AS VerificationResult,
       CONVERT(VARCHAR(30), SERVERPROPERTY('ProductVersion')) AS ProductVersion,
       CONVERT(NVARCHAR(100), SERVERPROPERTY('Edition')) AS Edition,
       SYSUTCDATETIME() AS VerifiedAtUtc;
GO
