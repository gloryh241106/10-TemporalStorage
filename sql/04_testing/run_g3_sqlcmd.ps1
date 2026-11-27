<#
================================================================================
CSC12003 | Nhom 10 | Chu de 8 | Kiet (TV4)
Script   : run_g3_sqlcmd.ps1
Giai doan: G3 - chay doi chung tu dau den cuoi tren mot database MOI
Muc dich : Tao baseline V4 -> T0 -> cai Manual + Native -> luong DML T1-T5 ->
           T1_T5_verify (AfterStep=5) -> T6_T7. Luu output va thong tin lan chay
           (Git SHA, ban SQL Server, nguoi chay, moc UTC) vao evidence/G3_<ngay>/.
Dieu kien: sqlcmd, quyen tao database. Database dich chua ton tai hoac dang trong
           (00_create_and_seed.sql se tu choi database da co du lieu).
Vi du    : powershell -ExecutionPolicy Bypass -File sql\04_testing\run_g3_sqlcmd.ps1
           powershell ... -NativeEnableScript sql\02_native_temporal\enable_native_system_versioning.sql
Luu y    : Script KHONG xoa database. Muon chay lai: dung ten database khac (-Database).
================================================================================
#>
param(
    [string]$Server = '.',
    [string]$Database = 'TemporalSeminarDB',
    [string]$RunBy = $env:USERNAME,
    [string]$NativeEnableScript = '',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $NativeEnableScript) {
    $cand = @('sql\02_native_temporal\enable_native_system_versioning.sql',
              'sql\02_native_temporal\enable_system_versioning.sql')
    $NativeEnableScript = ($cand | Where-Object { Test-Path (Join-Path $repo $_) } | Select-Object -First 1)
}
$nativePath = if ([IO.Path]::IsPathRooted($NativeEnableScript)) { $NativeEnableScript } else { Join-Path $repo $NativeEnableScript }
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmm')
if (-not $OutDir) { $OutDir = Join-Path $repo "evidence\Kiet" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$tmp = Join-Path $env:TEMP "g3_$stamp"; New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Invoke-Step([string]$name, [string]$sqlText) {
    $f = Join-Path $tmp "$name.sql"
    $sqlText.Replace('[TemporalSeminarDB]', "[$Database]").Replace("N'TemporalSeminarDB'", "N'$Database'").Replace('USE TemporalSeminarDB;', "USE [$Database];").Replace("DB_ID(N'TemporalSeminarDB')", "DB_ID(N'$Database')").Replace('CREATE DATABASE TemporalSeminarDB;', "CREATE DATABASE [$Database];") |
        Set-Content $f -Encoding UTF8
    $log = Join-Path $OutDir "$name.txt"
    & sqlcmd -S $Server -E -C -b -f 65001 -W -s '|' -i $f *> $log
    $code = $LASTEXITCODE
    Write-Host ("{0,-28} exit={1}" -f $name, $code)
    if ($code -ne 0) { throw "Buoc $name loi (xem $log)." }
    return (Get-Content $log -Encoding UTF8)
}
function Read-Sql([string]$path) { Get-Content $path -Raw -Encoding UTF8 }

$sha = (& git -C $repo rev-parse HEAD).Trim()
$dirty = (& git -C $repo status --porcelain --untracked-files=no)
$nativeSha = (& git -C $repo log -1 --format=%H -- $NativeEnableScript 2>$null)
$ver = (& sqlcmd -S $Server -E -C -h -1 -W -Q "SET NOCOUNT ON; SELECT CONCAT(CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion')), N' | ', CONVERT(NVARCHAR(128), SERVERPROPERTY('Edition')))").Trim()

Invoke-Step '00_setup'      (Read-Sql "$repo\sql\00_setup\00_create_and_seed.sql") | Out-Null
$t0 = Invoke-Step '01_T0'   (Read-Sql "$repo\sql\00_setup\01_verify_setup.sql")
if (-not ($t0 -match 'PASS G1 / T0')) { throw 'T0 khong PASS.' }
Invoke-Step '02_manual_history' (Read-Sql "$repo\sql\01_trigger\create_manual_history.sql") | Out-Null
Invoke-Step '03_manual_period'  (Read-Sql "$repo\sql\01_trigger\add_manual_period_columns.sql") | Out-Null
Invoke-Step '04_manual_trigger' (Read-Sql "$repo\sql\01_trigger\create_manual_trigger.sql") | Out-Null
Invoke-Step '05_native_enable'  ("USE [TemporalSeminarDB];`nGO`n" + (Read-Sql $nativePath)) | Out-Null
$flow = Invoke-Step '06_dml_flow_T1_T5' (Read-Sql "$repo\sql\04_testing\g3_dml_flow_t1_t5.sql")
$marks = ($flow | Where-Object { $_ -like 'G3_MARKS|*' } | Select-Object -First 1).Split('|')
$verify = Invoke-Step '07_verify_T1_T5' (Read-Sql "$repo\sql\04_testing\T1_T5_verify_dml_events.sql")
$t67 = (Read-Sql "$repo\sql\04_testing\T6_T7_time_travel_queries.sql").
    Replace("DECLARE @t_ready    DATETIME2(7) = NULL;", "DECLARE @t_ready    DATETIME2(7) = '$($marks[1])';").
    Replace("DECLARE @t_between  DATETIME2(7) = NULL;", "DECLARE @t_between  DATETIME2(7) = '$($marks[2])';").
    Replace("DECLARE @t_after_T3 DATETIME2(7) = NULL;", "DECLARE @t_after_T3 DATETIME2(7) = '$($marks[3])';")
$tt = Invoke-Step '08_T6_T7' $t67

$fail = @($verify + $tt | Where-Object { $_ -match '\|(FAIL|BLOCKED)\|' }).Count
$pass = @($verify + $tt | Where-Object { $_ -match '\|PASS\|' }).Count
@"
G3 run info
RunBy          : $RunBy
RunAtUtc       : $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))
Server/Database: $Server / $Database
SQL Server     : $ver
Git HEAD       : $sha $(if ($dirty) { '(working tree co thay doi chua commit)' })
Native script  : $NativeEnableScript (commit gan nhat: $nativeSha)
Marks (UTC)    : t_ready=$($marks[1]) | t_between=$($marks[2]) | t_after_T3=$($marks[3])
Result rows    : PASS=$pass, FAIL/BLOCKED=$fail
Files          : 00_setup, 01_T0, 02-05 cai dat, 06_dml_flow_T1_T5, 07_verify_T1_T5, 08_T6_T7
"@ | Set-Content (Join-Path $OutDir 'run_info.txt') -Encoding UTF8
Remove-Item $tmp -Recurse -Force
Write-Host "Xong. PASS=$pass FAIL/BLOCKED=$fail. Evidence: $OutDir"
