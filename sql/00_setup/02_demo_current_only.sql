/* CSC12003 - Group 10 - TV1 Hoang
Run after T0 on the R0 baseline. Only the session's temporary table changes. */
USE TemporalSeminarDB;
GO

SET NOCOUNT ON;

IF DB_NAME() <> N'TemporalSeminarDB'
    THROW 52200, N'This example must run in TemporalSeminarDB.', 1;

SELECT ProductID, UnitPrice
INTO #PriceCurrentOnly
FROM demo.ProductPrice_Manual
WHERE ProductID = 101 AND UnitPrice = 25000;

IF @@ROWCOUNT <> 1
BEGIN
    DROP TABLE #PriceCurrentOnly;
    THROW 52201, N'Run the example with product 101 at the R0 price of 25000.', 1;
END;

SELECT N'Before UPDATE' AS Step, ProductID, UnitPrice FROM #PriceCurrentOnly;

UPDATE #PriceCurrentOnly SET UnitPrice = 27000 WHERE ProductID = 101;

SELECT N'After UPDATE' AS Step, ProductID, UnitPrice FROM #PriceCurrentOnly;

DROP TABLE #PriceCurrentOnly;
GO
