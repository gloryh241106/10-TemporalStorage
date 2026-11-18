/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2: Create the Manual History table
SQL Server 2025 (17.x)
Run after 01_verify_setup.sql passes T0, before installing Manual triggers.
Affected object: demo.ProductPrice_ManualHistory
Expected result: History table exists and is empty.
*/

USE [TemporalSeminarDB];
GO

-- 1. Create the history table
CREATE TABLE demo.ProductPrice_ManualHistory
(
    HistoryID BIGINT IDENTITY(1,1) NOT NULL,

    ProductID INT NOT NULL,
    UnitPrice DECIMAL(12,2) NOT NULL,
    CurrencyCode CHAR(3) NOT NULL,
    PriceNote NVARCHAR(120) NULL,

    ValidFrom DATETIME2(7) NOT NULL,
    ValidTo DATETIME2(7) NOT NULL,

    CONSTRAINT PK_ProductPrice_ManualHistory
        PRIMARY KEY (HistoryID)
);
GO

-- 2. Verify columns and the initially empty history table
SELECT
    HistoryID,
    ProductID,
    UnitPrice,
    CurrencyCode,
    PriceNote,
    ValidFrom,
    ValidTo
FROM demo.ProductPrice_ManualHistory;
GO
