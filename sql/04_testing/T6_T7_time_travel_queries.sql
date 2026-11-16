/*
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script : T6_T7_time_travel_queries.sql
Giai doan: G3 - chi doc, khong thay doi du lieu
Dieu kien truoc khi chay:
  - Nhanh can kiem tra da qua T1-T5 (Native: SYSTEM_VERSIONING = ON;
    Manual: co demo.ProductPrice_ManualHistory va cot ValidFrom/ValidTo
    tren ca Current lan History, theo Google Docs quy uoc, muc 10.3).
  - Da ghi 3 moc UTC tu cung SQL Server (SELECT SYSUTCDATETIME()):
      @t_ready    : sau khi ca hai nhanh san sang, TRUOC khi bat dau T2
      @t_between  : sau commit T2, TRUOC khi bat dau T3
      @t_after_T3 : sau commit T3
Doi tuong doc: demo.ProductPrice_Native (+ history), demo.ProductPrice_Manual,
               demo.ProductPrice_ManualHistory
Ket qua ky vong:
  T6 AS OF  : 25000 / 27000 / 30000 tai 3 moc, ca hai nhanh.
  T7 FROM..TO [@t_ready, ValidFrom cua ban 30000): 25000, 27000.
  Phu luc (cung khoang):
     BETWEEN      -> 25000, 27000, 30000 (ban bat dau dung can tren van duoc lay)
     CONTAINED IN -> 27000 (ban 25000 bat dau truoc @t_ready)
Ngu nghia khoang [ValidFrom, ValidTo):
  AS OF t        : ValidFrom <= t AND ValidTo > t
  FROM a TO b    : ValidFrom <  b AND ValidTo > a
  BETWEEN a AND b: ValidFrom <= b AND ValidTo > a
  CONTAINED IN   : ValidFrom >= a AND ValidTo <= b
  Nhanh Manual bo phien ban do dai 0 (ValidFrom = ValidTo) nhu SQL Server.
================================================================================
*/
USE [TemporalSeminarDB];
GO
SET NOCOUNT ON;

-- BUOC 1: Dien 3 moc UTC thuc te cua lan chay (khong dung moc tu dat).
DECLARE @t_ready    DATETIME2(7) = NULL;  -- vi du '2026-11-25 02:10:00.0000000'
DECLARE @t_between  DATETIME2(7) = NULL;
DECLARE @t_after_T3 DATETIME2(7) = NULL;

IF @t_ready IS NULL OR @t_between IS NULL OR @t_after_T3 IS NULL
    THROW 54000, N'Dien du 3 moc UTC @t_ready, @t_between, @t_after_T3 truoc khi chay.', 1;

IF NOT (@t_ready < @t_between AND @t_between < @t_after_T3)
    THROW 54001, N'Cac moc UTC phai tang dan: @t_ready < @t_between < @t_after_T3.', 1;

DECLARE @Result TABLE (
    TestCase  NVARCHAR(20),
    Branch    NVARCHAR(10),
    Point     NVARCHAR(60),
    Expected  NVARCHAR(60),
    Actual    NVARCHAR(200),
    Status    NVARCHAR(10)
);

DECLARE @Marks TABLE (Seq INT, Label NVARCHAR(20), At DATETIME2(7), Expected DECIMAL(12,2));
INSERT INTO @Marks VALUES
    (1, N't_ready',    @t_ready,    25000),
    (2, N't_between',  @t_between,  27000),
    (3, N't_after_T3', @t_after_T3, 30000);

DECLARE @NativeReady BIT =
    CASE WHEN EXISTS (SELECT 1 FROM sys.tables
                      WHERE object_id = OBJECT_ID(N'demo.ProductPrice_Native')
                        AND temporal_type = 2) THEN 1 ELSE 0 END;

DECLARE @ManualReady BIT =
    CASE WHEN OBJECT_ID(N'demo.ProductPrice_ManualHistory', N'U') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_Manual', N'ValidFrom') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_Manual', N'ValidTo') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_ManualHistory', N'ValidFrom') IS NOT NULL
          AND COL_LENGTH(N'demo.ProductPrice_ManualHistory', N'ValidTo') IS NOT NULL
         THEN 1 ELSE 0 END;

-- Dynamic SQL so the script still compiles before G2 exists on a branch.
DECLARE @NativeAll NVARCHAR(MAX) = N'
    SELECT ProductID, UnitPrice, ValidFrom, ValidTo
    FROM demo.ProductPrice_Native FOR SYSTEM_TIME ALL
    WHERE ProductID = 101';

DECLARE @ManualAll NVARCHAR(MAX) = N'
    SELECT ProductID, UnitPrice, ValidFrom, ValidTo
    FROM (
        SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM demo.ProductPrice_Manual
        UNION ALL
        SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM demo.ProductPrice_ManualHistory
    ) AS v
    WHERE ProductID = 101 AND ValidFrom < ValidTo';

-- Show every version of 101 per branch, for the evidence log.
IF @NativeReady = 1
BEGIN
    PRINT N'--- Native: tat ca phien ban cua 101 (FOR SYSTEM_TIME ALL) ---';
    EXEC (@NativeAll + N' ORDER BY ValidFrom;');
END
ELSE
    INSERT INTO @Result VALUES (N'T6/T7', N'Native', N'-', N'-', N'SYSTEM_VERSIONING chua bat', N'BLOCKED');

IF @ManualReady = 1
BEGIN
    PRINT N'--- Manual: tat ca phien ban cua 101 (Current UNION ALL History) ---';
    EXEC (@ManualAll + N' ORDER BY ValidFrom;');
END
ELSE
    INSERT INTO @Result VALUES (N'T6/T7', N'Manual', N'-', N'-', N'Chua co ManualHistory/ValidFrom/ValidTo theo hop dong', N'BLOCKED');

-- ============================================================
-- T6: AS OF tai 3 moc
-- ============================================================
DECLARE @Seq INT = 1, @Label NVARCHAR(20), @At DATETIME2(7), @Exp DECIMAL(12,2);
DECLARE @Actual NVARCHAR(200), @Rows INT, @Sql NVARCHAR(MAX);

WHILE @Seq <= 3
BEGIN
    SELECT @Label = Label, @At = At, @Exp = Expected FROM @Marks WHERE Seq = @Seq;

    IF @NativeReady = 1
    BEGIN
        SET @Sql = N'
            SELECT @rows = COUNT(*),
                   @actual = STRING_AGG(CONVERT(NVARCHAR(20), UnitPrice), N'', '')
            FROM demo.ProductPrice_Native FOR SYSTEM_TIME AS OF @at
            WHERE ProductID = 101;';
        EXEC sp_executesql @Sql,
            N'@at DATETIME2(7), @rows INT OUTPUT, @actual NVARCHAR(200) OUTPUT',
            @at = @At, @rows = @Rows OUTPUT, @actual = @Actual OUTPUT;

        INSERT INTO @Result VALUES (N'T6 AS OF', N'Native', @Label + N' = ' + CONVERT(NVARCHAR(30), @At, 121),
            CONVERT(NVARCHAR(20), @Exp), ISNULL(@Actual, N'(0 dong)'),
            CASE WHEN @Rows = 1 AND @Actual = CONVERT(NVARCHAR(20), @Exp) THEN N'PASS' ELSE N'FAIL' END);
    END

    IF @ManualReady = 1
    BEGIN
        SET @Sql = N'
            SELECT @rows = COUNT(*),
                   @actual = STRING_AGG(CONVERT(NVARCHAR(20), UnitPrice), N'', '')
            FROM (' + @ManualAll + N') AS m
            WHERE ValidFrom <= @at AND ValidTo > @at;';
        EXEC sp_executesql @Sql,
            N'@at DATETIME2(7), @rows INT OUTPUT, @actual NVARCHAR(200) OUTPUT',
            @at = @At, @rows = @Rows OUTPUT, @actual = @Actual OUTPUT;

        INSERT INTO @Result VALUES (N'T6 AS OF', N'Manual', @Label + N' = ' + CONVERT(NVARCHAR(30), @At, 121),
            CONVERT(NVARCHAR(20), @Exp), ISNULL(@Actual, N'(0 dong)'),
            CASE WHEN @Rows = 1 AND @Actual = CONVERT(NVARCHAR(20), @Exp) THEN N'PASS' ELSE N'FAIL' END);
    END

    SET @Seq += 1;
END;

-- ============================================================
-- T7: truy van khoang. Can duoi = @t_ready; can tren = ValidFrom cua ban
-- 30000 o tung nhanh (doc tu bang Current, khong tu dat).
-- ============================================================
DECLARE @Ranges TABLE (Seq INT, Name NVARCHAR(20), NativeClause NVARCHAR(100),
                       ManualFilter NVARCHAR(200), Expected NVARCHAR(60));
INSERT INTO @Ranges VALUES
    (1, N'T7 FROM..TO',     N'FROM @s TO @e',           N'ValidFrom <  @e AND ValidTo >  @s', N'25000.00, 27000.00'),
    (2, N'Phu luc BETWEEN', N'BETWEEN @s AND @e',       N'ValidFrom <= @e AND ValidTo >  @s', N'25000.00, 27000.00, 30000.00'),
    (3, N'Phu luc CONTAINED', N'CONTAINED IN (@s, @e)', N'ValidFrom >= @s AND ValidTo <= @e', N'27000.00');

DECLARE @End DATETIME2(7), @Name NVARCHAR(20), @Clause NVARCHAR(100),
        @Filter NVARCHAR(200), @ExpSet NVARCHAR(60);

IF @NativeReady = 1
BEGIN
    SELECT @End = NULL;
    EXEC sp_executesql
        N'SELECT @e = ValidFrom FROM demo.ProductPrice_Native WHERE ProductID = 101 AND UnitPrice = 30000;',
        N'@e DATETIME2(7) OUTPUT', @e = @End OUTPUT;

    IF @End IS NULL
        INSERT INTO @Result VALUES (N'T7', N'Native', N'-', N'-', N'Current 101 khong phai 30000', N'BLOCKED');
    ELSE
    BEGIN
        SET @Seq = 1;
        WHILE @Seq <= 3
        BEGIN
            SELECT @Name = Name, @Clause = NativeClause, @ExpSet = Expected FROM @Ranges WHERE Seq = @Seq;
            SET @Sql = N'
                SELECT @actual = STRING_AGG(CONVERT(NVARCHAR(20), UnitPrice), N'', '')
                                 WITHIN GROUP (ORDER BY ValidFrom)
                FROM demo.ProductPrice_Native FOR SYSTEM_TIME ' + @Clause + N'
                WHERE ProductID = 101;';
            SET @Actual = NULL;
            EXEC sp_executesql @Sql,
                N'@s DATETIME2(7), @e DATETIME2(7), @actual NVARCHAR(200) OUTPUT',
                @s = @t_ready, @e = @End, @actual = @Actual OUTPUT;

            INSERT INTO @Result VALUES (@Name, N'Native',
                CONVERT(NVARCHAR(30), @t_ready, 121) + N' -> ' + CONVERT(NVARCHAR(30), @End, 121),
                @ExpSet, ISNULL(@Actual, N'(0 dong)'),
                CASE WHEN ISNULL(@Actual, N'') = @ExpSet THEN N'PASS' ELSE N'FAIL' END);
            SET @Seq += 1;
        END;
    END;
END;

IF @ManualReady = 1
BEGIN
    SELECT @End = NULL;
    EXEC sp_executesql
        N'SELECT @e = ValidFrom FROM demo.ProductPrice_Manual WHERE ProductID = 101 AND UnitPrice = 30000;',
        N'@e DATETIME2(7) OUTPUT', @e = @End OUTPUT;

    IF @End IS NULL
        INSERT INTO @Result VALUES (N'T7', N'Manual', N'-', N'-', N'Current 101 khong phai 30000', N'BLOCKED');
    ELSE
    BEGIN
        SET @Seq = 1;
        WHILE @Seq <= 3
        BEGIN
            SELECT @Name = Name, @Filter = ManualFilter, @ExpSet = Expected FROM @Ranges WHERE Seq = @Seq;
            SET @Sql = N'
                SELECT @actual = STRING_AGG(CONVERT(NVARCHAR(20), UnitPrice), N'', '')
                                 WITHIN GROUP (ORDER BY ValidFrom)
                FROM (' + @ManualAll + N') AS m
                WHERE ' + @Filter + N';';
            SET @Actual = NULL;
            EXEC sp_executesql @Sql,
                N'@s DATETIME2(7), @e DATETIME2(7), @actual NVARCHAR(200) OUTPUT',
                @s = @t_ready, @e = @End, @actual = @Actual OUTPUT;

            INSERT INTO @Result VALUES (@Name, N'Manual',
                CONVERT(NVARCHAR(30), @t_ready, 121) + N' -> ' + CONVERT(NVARCHAR(30), @End, 121),
                @ExpSet, ISNULL(@Actual, N'(0 dong)'),
                CASE WHEN ISNULL(@Actual, N'') = @ExpSet THEN N'PASS' ELSE N'FAIL' END);
            SET @Seq += 1;
        END;
    END;
END;

-- Bang ket qua de chep vao ma tran bang chung (04_testplan_Kiet_G1.md, muc 6).
SELECT TestCase, Branch, Point, Expected, Actual, Status,
       SERVERPROPERTY('ProductVersion') AS ProductVersion,
       SYSUTCDATETIME() AS CheckedAtUtc
FROM @Result
ORDER BY TestCase, Branch, Point;
GO
