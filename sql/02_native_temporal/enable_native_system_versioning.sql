/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV3: Trung
G2: Implement System-Versioning
Run after 01_verify_setup.sql
*/
USE [TemporalSeminarDB]
GO

ALTER DATABASE [TemporalSeminarDB]
SET TEMPORAL_HISTORY_RETENTION ON;
GO

ALTER TABLE demo.ProductPrice_Native
ADD 
    ValidFrom DATETIME2(7) GENERATED ALWAYS AS ROW START
    NOT NULL
    DEFAULT SYSUTCDATETIME(),

    ValidTo DATETIME2(7) GENERATED ALWAYS AS ROW END
    NOT NULL
    DEFAULT CONVERT(DATETIME2(7), '9999-12-31 23:59:59.9999999'),

    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO

ALTER TABLE demo.ProductPrice_Native
SET
(
    SYSTEM_VERSIONING = ON
    (
        HISTORY_TABLE = demo.ProductPrice_NativeHistory,
        HISTORY_RETENTION_PERIOD = INFINITE
    )
)
GO



