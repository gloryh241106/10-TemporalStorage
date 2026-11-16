# Bàn giao G2 – Thùy (Manual) và Trung (Native)

**Trạng thái:** Hoàng chốt phần G1 ngày 16/11/2026. G2 bắt đầu, hạn bàn giao cho Kiệt 22/11. Kiệt vẫn cần xác nhận Test Plan 1.1 ([checklist](05_CHECKLIST_G1.md)).

Môi trường: SQL Server 2025, database thử đã qua `00_create_and_seed.sql` và `01_verify_setup.sql` (T0 PASS). Quy ước dữ liệu và timestamp nằm trong [hợp đồng](02_team_data_contract.md). Kỳ vọng từng ca nằm trong [Test Plan 1.1](04_testplan_Kiet_G1.md).

## Mỗi nhánh nộp gì

| Hạng mục | Thùy – `sql/01_trigger/` | Trung – `sql/02_native_temporal/` |
|---|---|---|
| Script cài đặt | Thêm `ValidFrom`/`ValidTo` vào `demo.ProductPrice_Manual`, gán mốc cho dòng R0, tạo `demo.ProductPrice_ManualHistory`, tạo trigger | Thêm period và bật `SYSTEM_VERSIONING` trên `demo.ProductPrice_Native` |
| Script T1–T5 | Chạy đúng dữ liệu của Test Plan: 105 = 19.000; 101: 25.000 → 27.000 → 30.000 (hai giao tác); xóa 104; 102 và 103 +2.000 trong một câu | Như Thùy |
| Bằng chứng | Output chạy trên SQL Server 2025, lưu trong `evidence/` | Như Thùy |
| Phần báo cáo | Cách trigger ghi lịch sử, chi phí khi đổi schema | Cách SQL Server quản lý History, retention |

Script cài đặt và script DML để riêng. Không gộp cài đặt, demo và dọn dẹp vào một file. Mỗi script bắt đầu bằng `USE [TemporalSeminarDB];` và có header đúng tên, vai trò.

## Điều kiện để Kiệt nhận

- Chạy trên baseline đã qua T0, không sửa giá R0 hay bảng của TV1.
- Sau T2, History có đúng một dòng 25.000 cho 101; INSERT ở T1 không tạo dòng History.
- Current và History dùng `DATETIME2(7)` UTC; `ValidTo` của dòng hiện hành là `9999-12-31 23:59:59.9999999`, không NULL.
- Tên bảng và cột khớp với `T1_T5_verify_dml_events.sql` và `T6_T7_time_travel_queries.sql`.

## Việc riêng của Thùy

- Trigger xử lý theo tập qua `inserted`/`deleted`, chạy đúng với T5 (hai dòng một câu).
- Lấy một mốc `SYSUTCDATETIME()` cho mỗi câu DML, dùng cho cả đóng bản cũ và mở bản mới.
- `HistoryID BIGINT IDENTITY` là PK; không dùng `ProductID` làm khóa của History.

## Việc riêng của Trung

Script hiện có trên `main` (`enable_system_versioning.sql`) đúng về hướng, cần chỉnh trước khi bàn giao:

- Header đang ghi "TV4: Trung"; Trung là TV3.
- Thiếu `USE [TemporalSeminarDB];` và dấu `;`/`GO` cuối câu `ALTER TABLE`.
- Ghi rõ `HISTORY_RETENTION_PERIOD = INFINITE` trên bảng chính.

Branch `feature/update-system-versioning` chưa merge và cần tách lại: không đặt retention 30 ngày trên bảng chính, không xóa History, không dùng dữ liệu 105 khác Test Plan. Retention minh họa trên một database thử riêng.

Báo cáo TV3 cần sửa: INSERT không đưa dòng vào History; History chỉ chứa phiên bản đã đóng sau UPDATE/DELETE. Period là thời gian hệ thống, không gọi là "thời gian hiệu lực". Retention dọn dòng History theo `ValidTo`, chạy nền, không xóa ngay lập tức.
