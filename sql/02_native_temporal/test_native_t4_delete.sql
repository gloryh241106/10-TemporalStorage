/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV3: Trung
G2: Implement System-Versioning
Run after test_native_t3_update.sql
*/

USE [TemporalSeminarDB]
GO

DELETE demo.ProductPrice_Native
WHERE ProductID = 104

SELECT *
FROM demo.ProductPrice_Native
WHERE ProductID = 104

SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME ALL
WHERE ProductID = 104
ORDER BY ValidFrom DESC