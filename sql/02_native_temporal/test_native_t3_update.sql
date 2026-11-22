/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV3: Trung
G2: Implement System-Versioning
Run after test_native_t2_update.sql
*/

USE [TemporalSeminarDB]
GO

UPDATE demo.ProductPrice_Native
SET UnitPrice = 30000.00,
    PriceNote = N'Tăng giá'
WHERE ProductID = 101

SELECT *
FROM demo.ProductPrice_Native
WHERE ProductID = 101

SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME ALL
WHERE ProductID = 101
ORDER BY ValidFrom DESC