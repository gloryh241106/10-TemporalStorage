/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2: Implement multirow Manual History tracking
SQL Server 2025 (17.x)
Run after create_manual_history.sql and add_manual_period_columns.sql.
Affected objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory,
                  demo.trg_ProductPrice_Manual_History
Expected result: The trigger is enabled for INSERT, UPDATE and DELETE.
Installing the trigger does not change the initial prices or history.

Manual timestamps use UTC at trigger execution, not transaction start.
Each statement uses one timestamp for closing and opening versions.
ProductID is immutable; period columns are managed by this trigger.
An UPDATE with unchanged business values still creates a version.
The trigger and the original DML participate in the same transaction.
The supported seminar flow uses separate INSERT/UPDATE/DELETE statements.

References:
https://learn.microsoft.com/en-us/sql/relational-databases/triggers/create-dml-triggers-to-handle-multiple-rows-of-data
https://learn.microsoft.com/en-us/sql/t-sql/functions/trigger-nestlevel-transact-sql
*/

USE [TemporalSeminarDB];
GO

-- 1. Create the statement-level trigger
CREATE OR ALTER TRIGGER demo.trg_ProductPrice_Manual_History
ON demo.ProductPrice_Manual
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- A DML statement can fire a trigger even when it affects no rows.
    IF ROWCOUNT_BIG() = 0
        RETURN;

    SET NOCOUNT ON;

    -- Skip this trigger's own period UPDATE if recursive triggers are enabled.
    -- Check this specific trigger, not the total nesting depth of all triggers.
    IF TRIGGER_NESTLEVEL(
        OBJECT_ID(N'demo.trg_ProductPrice_Manual_History'),
        'AFTER',
        'DML'
    ) > 1
        RETURN;

    -- 2. Protect the identifier and system-managed period columns
    IF UPDATE(ProductID) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        THROW 52210, N'ProductID cannot be updated in the Manual demo.', 1;
    END;

    IF (UPDATE(ValidFrom) OR UPDATE(ValidTo))
       AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        THROW 52211, N'Manual period columns are managed by the trigger.', 1;
    END;

    DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @EndUtc DATETIME2(7)
        = '9999-12-31T23:59:59.9999999';

    -- Reject a backwards clock movement instead of storing an invalid interval.
    IF EXISTS (SELECT 1 FROM deleted WHERE ValidFrom > @NowUtc)
    BEGIN
        THROW 52212, N'UTC timestamp precedes the current version start.', 1;
    END;

    -- 3. Close every old version affected by UPDATE or DELETE
    -- For INSERT, deleted is empty, so no history row is created.
    INSERT INTO demo.ProductPrice_ManualHistory
        (ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo)
    SELECT
        d.ProductID,
        d.UnitPrice,
        d.CurrencyCode,
        d.PriceNote,
        d.ValidFrom,
        @NowUtc
    FROM deleted AS d;

    -- 4. Open every new current version affected by INSERT or UPDATE
    -- For DELETE, inserted is empty, so no current row is updated.
    UPDATE current_price
    SET
        ValidFrom = @NowUtc,
        ValidTo = @EndUtc
    FROM demo.ProductPrice_Manual AS current_price
    INNER JOIN inserted AS i
        ON i.ProductID = current_price.ProductID;
END;
GO

-- 5. Verify trigger installation without changing prices
SELECT
    name AS TriggerName,
    is_disabled AS IsDisabled
FROM sys.triggers
WHERE object_id = OBJECT_ID(N'demo.trg_ProductPrice_Manual_History');

SELECT
    (SELECT COUNT(*) FROM demo.ProductPrice_Manual) AS CurrentRows,
    (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) AS HistoryRows;
GO
