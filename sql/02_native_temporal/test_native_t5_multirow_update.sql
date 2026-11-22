/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV3: Trung
G2: Implement System-Versioning
Run after test_native_t4_delete.sql
*/

USE [TemporalSeminarDB]
GO


BEGIN TRANSACTION

    UPDATE demo.ProductPrice_Native
    SET UnitPrice = 27000.00,
        PriceNote = N'Tăng giá'
    WHERE ProductID = 102

    UPDATE demo.ProductPrice_Native
    SET UnitPrice = 30000.00,
        PriceNote = N'Tăng giá'
    WHERE ProductID = 103

COMMIT TRANSACTION

SELECT *
FROM demo.ProductPrice_Native
WHERE ProductID IN (102, 103)
ORDER BY ProductID ASC

SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME ALL
WHERE ProductID IN (102, 103)
ORDER BY ProductID ASC, ValidFrom DESC