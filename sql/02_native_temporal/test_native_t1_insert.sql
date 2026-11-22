/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV3: Trung
G2: Implement System-Versioning
Run after enable_native_system_versioning.sql
*/

USE [TemporalSeminarDB]
GO

INSERT INTO demo.ProductPrice_Native 
    (ProductID, UnitPrice, CurrencyCode, PriceNote)
VALUES
    (105, 19000.00, 'VND', N'Giá khởi tạo');

SELECT *
FROM demo.ProductPrice_Native
WHERE ProductID = 105

SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME ALL
WHERE ProductID = 105