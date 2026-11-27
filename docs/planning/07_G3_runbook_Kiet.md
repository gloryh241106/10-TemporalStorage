# Runbook G3 – Kiệt (TV4) chạy đối chứng hai nhánh

**Phiên bản:** 1.0 · 18/11/2026 · Kiệt soạn  
**Đầu vào:** [Test Plan 1.1](04_testplan_Kiet_G1.md), [hợp đồng V4](02_team_data_contract.md), [bàn giao G2](06_G2_handoff.md)  
**Dự kiến chạy:** 22–25/11, sau khi Thùy và Trung cùng bàn giao.

Các script trong `sql/04_testing/` chỉ đọc. Kiệt không sửa script của TV2/TV3 để test xanh. Nếu FAIL, ghi lại kết quả và báo người phụ trách nhánh.

## 0. Điều kiện nhận bàn giao

| Hạng mục | Thùy – Manual | Trung – Native |
|---|---|---|
| Script cài đặt (`sql/01_trigger/` / `sql/02_native_temporal/`) | ⬜ | ⬜ (bản trên `main` còn thiếu `USE`, `GO`, `INFINITE`) |
| Script DML T1–T5 đúng dữ liệu Test Plan, tách khỏi script cài đặt | ⬜ | ⬜ |
| Output thử UPDATE trên SQL Server 2025 trong `evidence/` | ⬜ | ⬜ |
| Không đổi giá R0, không xóa History, retention `INFINITE` | ⬜ | ⬜ |

## 1. Chuẩn bị database

1. Dùng database thử mới hoặc trống, đặt tên `TemporalSeminarDB`.
2. Chạy `sql/00_setup/00_create_and_seed.sql`, rồi `sql/00_setup/01_verify_setup.sql`. Phải thấy `PASS G1 / T0 - Baseline V4`. Lưu output vào `evidence/G3_<yyyymmdd>_T0.txt`.
3. Chạy script cài đặt của Thùy, rồi của Trung. Chưa chạy DML.

## 2. Chạy T1–T5 và ghi mốc UTC

Mỗi bước là một giao tác đã commit. Hai nhánh chạy cùng bước rồi mới sang bước sau. Ghi mốc bằng `SELECT SYSUTCDATETIME();` trên chính SQL Server này, không dùng giờ máy client.

| Bước | Ai chạy | Việc | Ghi mốc sau bước |
|---|---|---|---|
| T1 | Thùy, Trung | INSERT 105 = 19.000 | – |
| Kiểm | Kiệt | `T1_T5_verify_dml_events.sql` với `@AfterStep = 1` | – |
| Mốc | Kiệt | – | `@t_ready` = ________ |
| T2 | Thùy, Trung | UPDATE 101 → 27.000 | – |
| Mốc | Kiệt | Đợi cả hai nhánh commit T2 | `@t_between` = ________ |
| T3 | Thùy, Trung | UPDATE 101 → 30.000 (giao tác riêng) | – |
| Mốc | Kiệt | Đợi cả hai nhánh commit T3 | `@t_after_T3` = ________ |
| T4 | Thùy, Trung | DELETE 104 | – |
| T5 | Thùy, Trung | UPDATE 102, 103 +2.000 trong **một** câu lệnh | – |

> Nếu một nhánh phải chạy ở buổi khác, ghi một bộ ba mốc riêng cho nhánh đó và chạy T6/T7 riêng với bộ mốc ấy (Test Plan, T6).

## 3. Kiểm chứng

1. `T1_T5_verify_dml_events.sql` với `@AfterStep = 5`. Lưu output vào `evidence/G3_<yyyymmdd>_T1_T5.txt`.
2. Điền ba mốc vào đầu `T6_T7_time_travel_queries.sql` rồi chạy. Lưu output vào `evidence/G3_<yyyymmdd>_T6_T7.txt`.
3. Chép Status từng ca vào ma trận bằng chứng (Test Plan, mục 6).

Đọc kết quả:

- `PASS`: khớp kỳ vọng.
- `FAIL`: lệch kỳ vọng. Chuyển cho Thùy (Manual) hoặc Trung (Native), chạy lại từ bước 1 trên database mới sau khi sửa.
- `BLOCKED`: nhánh chưa cài đúng hợp đồng. Không tính là FAIL.
- `INFO`: chỉ ghi nhận, ví dụ mốc mở của R0 bên Native.

Không so sánh timestamp hai nhánh với nhau: Native lấy giờ bắt đầu giao tác, Trigger lấy giờ chạy câu DML. Chỉ so giá trị, thứ tự phiên bản và kết quả `AS OF`/khoảng.

## 4. Sau khi có bằng chứng

- Lập bảng so sánh C1–C6 (Test Plan, mục 7) từ output đã lưu, ghi rõ nguồn của từng nhận xét.
- Không kết luận hiệu năng (ngoài phạm vi, không đo).
- Gửi Hoàng bảng kết quả và bảng so sánh để ghép Master Report.
