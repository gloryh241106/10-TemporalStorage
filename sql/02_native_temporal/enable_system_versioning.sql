/*
CSC12003 - Group 10 - Topic 8: Temporal Database
TV3: Trung
G2: Implement System-Versioning
Run after 01_verify_setup.sql
*/
USE [TemporalSeminarDB]
GO

SET NOCOUNT ON;

ALTER DATABASE [TemporalSeminarDB]
SET TEMPORAL_HISTORY_RETENTION ON;

ALTER TABLE demo.ProductPrice_Native
ADD 
    ValidFrom DATETIME2(7) GENERATED ALWAYS AS ROW START
    NOT NULL
    DEFAULT SYSUTCDATETIME(),

    ValidTo DATETIME2(7) GENERATED ALWAYS AS ROW END
    NOT NULL
    DEFAULT CONVERT(DATETIME2(7), '9999-12-31 23:59:59.9999999'),

    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)

ALTER TABLE demo.ProductPrice_Native
SET
(
    SYSTEM_VERSIONING = ON
    (
        HISTORY_TABLE = demo.ProductPrice_NativeHistory,
        HISTORY_RETENTION_PERIOD = 30 DAYS
    )
)

--Phần Test Module
DECLARE @StartTime DATETIME2(7);

BEGIN TRANSACTION

    SET @StartTime = SYSUTCDATETIME(); -- Dùng để truy vấn SYSTEM_TIME
    PRINT(@StartTime)

    --Bắt đầu insert ProductID = 105
    INSERT INTO demo.ProductPrice_Native (ProductID, UnitPrice, CurrencyCode, PriceNote)
    VALUES
        (105, 65000.00, 'VND', N'Giá khởi tạo');   

    WAITFOR DELAY '00:00:05';
COMMIT TRANSACTION



BEGIN TRANSACTION
    --Truy vấn tình trạng hiện tại Product 105 trong bảng chính
    SELECT *
    FROM demo.ProductPrice_Native
    WHERE ProductID = 105
    
    --Truy vấn lịch sử ProductID  = 105 sau khi Insert (Dự đoán: 1 dòng trong history)
    SELECT *
    FROM demo.ProductPrice_Native
    FOR SYSTEM_TIME ALL
    WHERE ProductID = 105
    ORDER BY ValidFrom DESC 

    --Bắt đầu Update ProductID = 105
    UPDATE demo.ProductPrice_Native
    SET UnitPrice = 85000.00, PriceNote = N'Giá điều chỉnh'
    WHERE ProductID = 105;

    WAITFOR DELAY '00:00:03';
COMMIT TRANSACTION

BEGIN TRANSACTION
    --Truy vấn tình trạng hiện tại Product 105 trong bảng chính
    SELECT *
    FROM demo.ProductPrice_Native
    WHERE ProductID = 105

    --Truy vấn lịch sử ProductID  = 105 sau khi Insert, Update (Dự đoán: 2 dòng trong history)
    SELECT *
    FROM demo.ProductPrice_Native
    FOR SYSTEM_TIME ALL
    WHERE ProductID = 105
    ORDER BY ValidFrom DESC

    DELETE FROM demo.ProductPrice_Native
    WHERE ProductID = 105;
COMMIT TRANSACTION

--Truy vấn tình trạng hiện tại Product 105 trong bảng chính
SELECT *
FROM demo.ProductPrice_Native
WHERE ProductID = 105
--Truy vấn lịch sử ProductID  = 105 sau khi Insert, Update, Delete (Dự đoán: 2 dòng trong history, với ValidTo của record mới nhất là giá trị không phải MAX)
SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME ALL
WHERE ProductID = 105
ORDER BY ValidFrom DESC

--Truy vấn tại thời điểm StartTime (Dự đoán: Price = 65000)
SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME AS OF @StartTime
WHERE ProductID = 105;

/*
Time --> StartTime = 0  1  2  3  4  5  6  7*  8  9  ...  (*: EndTime)
Insert:              [              )
Update:                             [         )
Delete:                                       [ ...
------------------------------------------------------------------------            
FromTo:              (                    )      (I,U matched) - các record có một phần thời gian hiệu lực trong (StartTime, EndTime)
BetweenAnd:          (                    ]      (I,U matched) - các record có một phần thời gian hiệu lực trong (StartTime, EndTime]
ContainedIn:         [                    ]      (I matched) - các record có thời gian hiệu lực nằm hoàn toàn trong [StartTime, EndTime]
*/


--Truy vấn khoảng thời gian sau khi Insert, Update mà chưa delete (Dự đoán: 2 dòng)
DECLARE @EndTime DATETIME2(7);
SET @EndTime = DATEADD(SECOND, 7, @StartTime);
PRINT(@EndTime) 
SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME FROM @StartTime TO @EndTime -- FROM .. TO .. 
WHERE ProductID = 105;

--Truy vấn khoảng thời gian sau khi Insert, Update mà chưa delete (Dự đoán: 2 dòng)
SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME BETWEEN @StartTime AND @EndTime -- BETWEEN .. AND .. 
WHERE ProductID = 105;

--Truy vấn khoảng thời gian sau khi Insert, Update mà chưa delete (Dự đoán: 1 dòng)
SELECT *
FROM demo.ProductPrice_Native
FOR SYSTEM_TIME CONTAINED IN (@StartTime, @EndTime) -- CONTAINED IN .. 
WHERE ProductID = 105;

BEGIN TRANSACTION
    --Xóa dữ liệu History liên quan đến ProductID = 105 (dữ liệu Test)
    EXEC(
        'ALTER TABLE demo.ProductPrice_Native
        SET (SYSTEM_VERSIONING = OFF);'
    );

    EXEC(
        'DELETE FROM demo.ProductPrice_NativeHistory
        WHERE ProductID = 105;'
    );

    EXEC(
        'ALTER TABLE demo.ProductPrice_Native
        SET (
            SYSTEM_VERSIONING = ON
            (
                HISTORY_TABLE = demo.ProductPrice_NativeHistory
            )
        );'
    );
    
COMMIT TRANSACTION

