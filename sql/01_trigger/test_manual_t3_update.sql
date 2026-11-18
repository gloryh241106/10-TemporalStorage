/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV2: Thuy
G2 / T3: Update product 101 from 27000 to 30000 VND
SQL Server 2025 (17.x)
Run after test_manual_t2_update.sql passes and commits, before T4-T5.
Affected objects: demo.ProductPrice_Manual, demo.ProductPrice_ManualHistory
Expected result: Current has 101 at 30000; History keeps both 25000 and 27000.
Both history versions and the current version have adjoining UTC periods.
This script commits T3 in a separate transaction from T2. Run once per demo.
UTC markers are for this local Manual run; integrated testing uses new markers.
*/

USE [TemporalSeminarDB];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- 1. Require a separate transaction and an enabled trigger
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2) <> 0
    THROW 52320, N'Run T3 with no open transaction and implicit transactions OFF.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.triggers
    WHERE object_id = OBJECT_ID(N'demo.trg_ProductPrice_Manual_History')
      AND is_disabled = 0
)
    THROW 52321, N'The Manual History trigger must be installed and enabled.', 1;

DECLARE @BetweenUtc DATETIME2(7);
DECLARE @BeforeUpdateUtc DATETIME2(7);
DECLARE @AfterUpdateUtc DATETIME2(7);
DECLARE @AfterT3Utc DATETIME2(7);

DECLARE @Before TABLE (
    ProductID INT PRIMARY KEY,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

DECLARE @HistoryBefore TABLE (
    HistoryID BIGINT PRIMARY KEY,
    ProductID INT,
    UnitPrice DECIMAL(12,2),
    CurrencyCode CHAR(3),
    PriceNote NVARCHAR(120),
    ValidFrom DATETIME2(7),
    ValidTo DATETIME2(7)
);

BEGIN TRY
    BEGIN TRANSACTION;

    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 5
       OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_Manual
                      WHERE ProductID = 101 AND UnitPrice = 27000)
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 1
       OR NOT EXISTS (SELECT 1 FROM demo.ProductPrice_ManualHistory
                      WHERE ProductID = 101 AND UnitPrice = 25000)
    BEGIN
        THROW 52322, N'T3 requires the committed T2 state: current 27000 and one history version at 25000.', 1;
    END;

    INSERT INTO @Before
    SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_Manual;

    INSERT INTO @HistoryBefore
    SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
    FROM demo.ProductPrice_ManualHistory;

    -- Record a point after T2 committed and before the T3 price change.
    SET @BetweenUtc = SYSUTCDATETIME();
    WAITFOR DELAY '00:00:00.020';

    -- 2. Perform the second price change in this new transaction
    SET @BeforeUpdateUtc = SYSUTCDATETIME();

    UPDATE demo.ProductPrice_Manual
    SET UnitPrice = 30000.00
    WHERE ProductID = 101;

    SET @AfterUpdateUtc = SYSUTCDATETIME();

    -- 3. Verify all three versions and both shared boundaries
    IF (SELECT COUNT(*) FROM demo.ProductPrice_Manual) <> 5
       OR (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) <> 2
       OR NOT EXISTS (
           SELECT 1
           FROM demo.ProductPrice_Manual AS c
           INNER JOIN demo.ProductPrice_ManualHistory AS h27
               ON h27.ProductID = c.ProductID AND h27.UnitPrice = 27000.00
           INNER JOIN demo.ProductPrice_ManualHistory AS h25
               ON h25.ProductID = c.ProductID AND h25.UnitPrice = 25000.00
           WHERE c.ProductID = 101
             AND c.UnitPrice = 30000.00
             AND h25.ValidFrom < h25.ValidTo
             AND h25.ValidTo = h27.ValidFrom
             AND h27.ValidFrom <= @BetweenUtc
             AND @BetweenUtc < h27.ValidTo
             AND h27.ValidTo = c.ValidFrom
             AND c.ValidFrom >= @BeforeUpdateUtc
             AND c.ValidFrom <= @AfterUpdateUtc
             AND c.ValidTo = CONVERT(DATETIME2(7), '9999-12-31T23:59:59.9999999')
       )
    BEGIN
        THROW 52323, N'T3 failed: version prices, history count or period boundaries are incorrect.', 1;
    END;

    -- The earlier 25000 history row must survive without any changes.
    IF EXISTS (
        SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @HistoryBefore
        EXCEPT
        SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_ManualHistory
    ) OR EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM @Before WHERE ProductID = 101
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom
        FROM demo.ProductPrice_ManualHistory WHERE ProductID = 101 AND UnitPrice = 27000
    ) OR EXISTS (
        SELECT ProductID, CurrencyCode, PriceNote FROM @Before WHERE ProductID = 101
        EXCEPT
        SELECT ProductID, CurrencyCode, PriceNote
        FROM demo.ProductPrice_Manual WHERE ProductID = 101
    ) OR EXISTS (
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM @Before WHERE ProductID <> 101
        EXCEPT
        SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
        FROM demo.ProductPrice_Manual WHERE ProductID <> 101
    )
    BEGIN
        THROW 52324, N'T3 failed: an old snapshot or unaffected values were not preserved.', 1;
    END;

    COMMIT TRANSACTION;
    SET @AfterT3Utc = SYSUTCDATETIME();
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

-- 4. Display committed versions and UTC markers for the evidence log
SELECT
    N'PASS T3 - Manual second UPDATE' AS VerificationResult,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    @BetweenUtc AS BetweenUtc,
    @BeforeUpdateUtc AS BeforeUpdateUtc,
    @AfterUpdateUtc AS AfterUpdateUtc,
    @AfterT3Utc AS AfterT3Utc;

SELECT ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_Manual WHERE ProductID = 101;

SELECT HistoryID, ProductID, UnitPrice, CurrencyCode, PriceNote, ValidFrom, ValidTo
FROM demo.ProductPrice_ManualHistory WHERE ProductID = 101
ORDER BY ValidFrom, HistoryID;

SELECT
    (SELECT COUNT(*) FROM demo.ProductPrice_Manual) AS CurrentRows,
    (SELECT COUNT(*) FROM demo.ProductPrice_ManualHistory) AS HistoryRows;
GO
