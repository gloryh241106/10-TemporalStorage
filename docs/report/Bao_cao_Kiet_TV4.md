# Báo cáo Kiểm thử Đối chứng & Đánh giá (TV4 – Kiệt)

**Đồ án:** Chủ đề 8 – Temporal Database · **Môn:** CSC12003 – Hệ quản trị Cơ sở dữ liệu  
**Nhóm:** 10 · **Phụ trách:** Kiệt (TV4)  
**Ngày thực nghiệm G3:** 27/11/2026  
**Môi trường thực tế:** Microsoft SQL Server 2025 Standard Developer Edition (64-bit), build `17.0.1000.7`, compatibility level `170`, database `TemporalSeminarDB`.

---

## 1. Mục tiêu và phương pháp đối chứng

Mục tiêu của giai đoạn G3 là chạy cùng một kịch bản nghiệp vụ (T0–T7) trên hai nhánh đã triển khai độc lập:

- **Nhánh A – Manual History (TV2 – Thùy):** bảng `demo.ProductPrice_Manual`, bảng lịch sử `demo.ProductPrice_ManualHistory` (`HistoryID BIGINT IDENTITY`), và trigger `demo.trg_ProductPrice_Manual_History`.
- **Nhánh B – Native Temporal (TV3 – Trung):** bảng `demo.ProductPrice_Native` bật `SYSTEM_VERSIONING = ON` với bảng lịch sử `demo.ProductPrice_NativeHistory` (retention `INFINITE`).

### Quy trình chạy và tách biệt trách nhiệm

1. Tạo database sạch `TemporalSeminarDB` bằng `sql/00_setup/00_create_and_seed.sql`, xác nhận T0 PASS bằng `sql/00_setup/01_verify_setup.sql`.
2. Cài đặt nhánh Manual (`create_manual_history.sql`, `add_manual_period_columns.sql`, `create_manual_trigger.sql`) và nhánh Native (`enable_system_versioning.sql`).
3. Chạy luồng DML chung `sql/04_testing/g3_dml_flow_t1_t5.sql`: thực hiện lần lượt T1–T5 bằng các giao tác riêng biệt đã commit, tự động chụp số dòng/giá sau từng bước và ghi 3 mốc UTC thực tế từ SQL Server (`SYSUTCDATETIME()`):
   - `@t_ready`: sau khi cả hai nhánh sẵn sàng (sau T1), **trước** T2.
   - `@t_between`: sau khi cả hai nhánh commit T2, **trước** T3.
   - `@t_after_T3`: sau khi cả hai nhánh commit T3.
4. Chạy hai script **chỉ đọc** để kiểm chứng và xuất bảng `Expected / Actual / Status`:
   - `sql/04_testing/T1_T5_verify_dml_events.sql` (`@AfterStep = 5`)
   - `sql/04_testing/T6_T7_time_travel_queries.sql` (với 3 mốc UTC thật vừa ghi)

Toàn bộ output không chỉnh sửa được lưu tại [`evidence/G3_20261127/`](../../evidence/G3_20261127/) (kèm `run_info.txt` ghi người chạy, phiên bản SQL Server, Git commit SHA và 3 mốc UTC).

---

## 2. Kết quả thực nghiệm T0–T7

Tổng kết lần chạy ngày 27/11/2026: **49/49 mục kiểm tra PASS, 0 FAIL, 0 BLOCKED** (37 mục ở `07_verify_T1_T5.txt` + 12 mục ở `08_T6_T7.txt`, kèm T0 PASS ở `01_T0.txt`).

### 2.1. Diễn biến trạng thái Current và History qua T0–T5

Nguồn: [`evidence/G3_20261127/06_dml_flow_T1_T5.txt`](../../evidence/G3_20261127/06_dml_flow_T1_T5.txt) và [`07_verify_T1_T5.txt`](../../evidence/G3_20261127/07_verify_T1_T5.txt).

| Mã test | Thao tác | Current (Manual = Native) | History (Manual = Native) | Trạng thái |
|---|---|---|---|---|
| **T0** | Baseline V4 trước G2 | 4 dòng (`101=25k, 102=25k, 103=28k, 104=45k`), 105 chưa có | Chưa tạo / chưa bật | **PASS** |
| **T1** | `INSERT` 105 = 19.000 | 5 dòng (thêm `105=19k`) | **0 dòng** (INSERT không tạo History) | **PASS** |
| **T2** | `UPDATE` 101: 25.000 → 27.000 | 5 dòng (`101=27k`) | 1 dòng (`101=25k`) | **PASS** |
| **T3** | `UPDATE` 101: 27.000 → 30.000 (giao tác riêng) | 5 dòng (`101=30k`) | 2 dòng (`101=25k, 27k`) | **PASS** |
| **T4** | `DELETE` 104 | 4 dòng (mất 104; `dbo.Product` vẫn còn 104) | 3 dòng (thêm `104=45k`) | **PASS** |
| **T5** | 1 lệnh `UPDATE` tăng +2.000 cho 102 và 103 | 4 dòng (`102=27k, 103=30k`) | 5 dòng (thêm `102=25k, 103=28k` cùng 1 mốc) | **PASS** |

### 2.2. Period thực tế của sản phẩm 101 và kết quả T6, T7

Nguồn: [`evidence/G3_20261127/08_T6_T7.txt`](../../evidence/G3_20261127/08_T6_T7.txt).

**Các phiên bản của sản phẩm 101 quan sát được (UTC):**

| Nhánh | UnitPrice | ValidFrom | ValidTo |
|---|---:|---|---|
| **Manual** | 25.000 | `2026-11-27 08:53:42.4747802` | `2026-11-27 08:53:44.9838106` |
| **Manual** | 27.000 | `2026-11-27 08:53:44.9838106` | `2026-11-27 08:53:47.0266864` |
| **Manual** | 30.000 | `2026-11-27 08:53:47.0266864` | `9999-12-31 23:59:59.9999999` |
| **Native** | 25.000 | `2026-11-27 08:53:42.6940316` | `2026-11-27 08:53:44.9858198` |
| **Native** | 27.000 | `2026-11-27 08:53:44.9858198` | `2026-11-27 08:53:47.0276791` |
| **Native** | 30.000 | `2026-11-27 08:53:47.0276791` | `9999-12-31 23:59:59.9999999` |

Nhận xét từ số liệu thật: ở cả hai nhánh, `ValidTo` của phiên bản trước trùng khớp tuyệt đối với `ValidFrom` của phiên bản kế tiếp (không có khoảng hở hay chồng lấn). Timestamp giữa hai nhánh lệch khoảng 1–2 ms vì hai giao tác chạy nối tiếp và khác ngữ nghĩa ghi thời gian (Manual lấy `SYSUTCDATETIME()` lúc trigger chạy; Native lấy thời điểm bắt đầu giao tác).

**Kết quả Time Travel Query (T6 và T7):**

Ba mốc UTC ghi được:
- `@t_ready` = `2026-11-27 08:53:43.9598271`
- `@t_between` = `2026-11-27 08:53:46.0135258`
- `@t_after_T3` = `2026-11-27 08:53:48.0340757`

| Ca kiểm thử | Mệnh đề / Mốc | Kỳ vọng | Manual (Thực tế) | Native (Thực tế) | Trạng thái |
|---|---|---|---|---|---|
| **T6 – AS OF** | `@t_ready` | `25000.00` | `25000.00` | `25000.00` | **PASS** |
| **T6 – AS OF** | `@t_between` | `27000.00` | `27000.00` | `27000.00` | **PASS** |
| **T6 – AS OF** | `@t_after_T3` | `30000.00` | `30000.00` | `30000.00` | **PASS** |
| **T7 – FROM…TO** | `[@t_ready, ValidFrom_30000)` | `25000.00, 27000.00` | `25000.00, 27000.00` | `25000.00, 27000.00` | **PASS** |
| Phụ lục `BETWEEN` | `[@t_ready, ValidFrom_30000]` | `25000.00, 27000.00, 30000.00` | `25000.00, 27000.00, 30000.00` | `25000.00, 27000.00, 30000.00` | **PASS** |
| Phụ lục `CONTAINED IN` | `(@t_ready, ValidFrom_30000)` | `27000.00` | `27000.00` | `27000.00` | **PASS** |

**Giải thích điều kiện biên (T7):** Mỗi phiên bản có khoảng nửa mở `[ValidFrom, ValidTo)`. Khi đặt cận trên `@e` đúng bằng `ValidFrom` của phiên bản `30000.00`:
- `FROM @s TO @e` (`ValidFrom < @e AND ValidTo > @s`) **loại** phiên bản `30000.00` vì `ValidFrom = @e`.
- `BETWEEN @s AND @e` (`ValidFrom <= @e AND ValidTo > @s`) **nhận** cả phiên bản `30000.00`.
- `CONTAINED IN (@s, @e)` (`ValidFrom >= @s AND ValidTo <= @e`) chỉ lấy `27000.00` vì phiên bản `25000.00` bắt đầu trước `@t_ready` và phiên bản `30000.00` chưa đóng.

---

## 3. Bảng so sánh hai phương pháp theo 6 tiêu chí (C1–C6)

| # | Tiêu chí | Nhánh A – Manual (Trigger + History Table) | Nhánh B – Native (System-Versioned Temporal Table) | Bằng chứng / Nguồn |
|---|---|---|---|---|
| **C1** | **Tính tự động hóa** | Thấp. Phải tự viết 3 script cài đặt (~240 dòng SQL): tạo bảng History, thêm & khởi tạo cột period, viết trigger `AFTER INSERT, UPDATE, DELETE` xử lý `inserted`/`deleted`, chặn sửa `ProductID`/`ValidFrom`/`ValidTo` và chặn lồng trigger (`TRIGGER_NESTLEVEL`). | Cao. Chỉ cần khai báo 2 cột `GENERATED ALWAYS AS ROW START/END`, `PERIOD FOR SYSTEM_TIME` và bật `SYSTEM_VERSIONING = ON` (~25 dòng SQL). Engine tự tạo bảng History và tự chuyển phiên bản cũ khi UPDATE/DELETE. | `sql/01_trigger/` vs `sql/02_native_temporal/enable_system_versioning.sql` |
| **C2** | **Ý nghĩa timestamp** | Lấy `SYSUTCDATETIME()` tại **thời điểm câu DML / trigger thực thi**. Nếu một giao tác chạy lâu có nhiều câu lệnh, mỗi câu có thể có timestamp khác nhau. Nhóm phải tự quy ước lấy chung 1 biến `@NowUtc` để đóng bản cũ và mở bản mới (đạt ở T5). | SQL Server tự ghi UTC theo **thời điểm bắt đầu giao tác** (`transaction begin`). Nhất quán hoàn toàn trong cùng một giao tác; các phiên bản độ dài 0 (sửa 2 lần cùng khóa trong 1 giao tác) bị `FOR SYSTEM_TIME` tự động lọc bỏ. | `evidence/G3_20261127/07_verify_T1_T5.txt`, Microsoft Learn (*Temporal Tables*) |
| **C3** | **Cách truy vấn lịch sử** | Phức tạp và dễ sai biên. Phải tự viết `UNION ALL` giữa Current và History (đảm bảo cùng danh sách cột), tự loại phiên bản độ dài 0 (`ValidFrom < ValidTo`), rồi tự viết biểu thức so sánh khoảng (`<=`, `>`, `<`) cho từng loại truy vấn. | Ngắn gọn, khai báo rõ ý định với `FOR SYSTEM_TIME AS OF`, `FROM … TO`, `BETWEEN … AND`, `CONTAINED IN`, `ALL`. Engine tự hợp nhất Current + History và tự xử lý điều kiện biên. | `sql/04_testing/T6_T7_time_travel_queries.sql`, `08_T6_T7.txt` |
| **C4** | **Phần phải tự bảo trì** | Cao. Khi thêm 1 cột nghiệp vụ (ví dụ `PriceSource`), phải sửa ít nhất **3 nơi**: bảng `ManualHistory`, câu `INSERT` trong trigger, và mọi truy vấn `UNION ALL`. Nếu thêm cột vào History nhưng quên sửa trigger, bản ghi lịch sử âm thầm lưu `NULL` thay vì giá trị cũ. | Thấp hơn rõ rệt. Khi chạy `ALTER TABLE` thêm/đổi cột trên bảng Current, SQL Server tự động đồng bộ schema tương ứng sang bảng History và không có trigger nào phải sửa. | Thực nghiệm C4 của Thùy: `evidence/Thuy/thuy_c4_schema_maintenance.txt` (4/4 bước PASS), Microsoft Learn (*Changing the Schema of a System-Versioned Temporal Table*) |
| **C5** | **Tính linh hoạt** | Cao. Lập trình viên có toàn quyền tùy biến: chỉ ghi lịch sử khi `UnitPrice` thực sự đổi (bỏ qua no-op UPDATE), lưu thêm metadata ứng dụng (người sửa, lý do), hoặc tự thiết kế cấu trúc bảng History. | Thấp hơn. Cơ chế ghi lịch sử cố định ở mức dòng theo System Time; mọi UPDATE (kể cả không đổi giá trị) đều sinh dòng History, không chèn thêm logic lọc tùy biến vào quá trình ghi History. | Thiết kế trigger `sql/01_trigger/create_manual_trigger.sql`, Microsoft Learn (*Temporal Table Considerations and Limitations*) |
| **C6** | **Giới hạn & ràng buộc** | Không bị ràng buộc bởi phiên bản SQL Server hay cấu trúc PK, nhưng lịch sử có thể bị người có quyền `UPDATE`/`DELETE` sửa trực tiếp nếu không phân quyền chặt; tự phải xây lịch dọn dữ liệu cũ (retention). | Yêu cầu SQL Server 2016+; bảng Current bắt buộc có PK; không cho `UPDATE`/`DELETE` trực tiếp bảng History khi `SYSTEM_VERSIONING = ON` (tăng tính toàn vẹn kiểm toán); hỗ trợ sẵn `HISTORY_RETENTION_PERIOD` (dọn nền theo `ValidTo`, cần bật `TEMPORAL_HISTORY_RETENTION` ở mức DB). | `evidence/G3_20261127/07_verify_T1_T5.txt` (`INFINITE`), Microsoft Learn (*Manage Retention of Historical Data*) |

> **Lưu ý phạm vi:** Báo cáo **không** đưa ra kết luận phương pháp nào nhanh hơn (hiệu năng/latency/I/O) vì benchmark nằm ngoài phạm vi đồ án và nhóm chưa tiến hành đo đạc định lượng.

---

## 4. Trả lời câu hỏi trọng tâm (K08 / M5)

> **Câu hỏi:** *So với cách tự dùng Trigger + History Table để mô phỏng Temporal Database, tại sao DBMS phải cung cấp Temporal Database như một tính năng native?*

Từ kết quả đối chứng T0–T7 và thực nghiệm bảo trì C4, cả hai phương pháp đều cho ra **cùng tập dữ liệu lịch sử và cùng kết quả truy vấn** khi được cài đặt cẩn thận. Tuy nhiên, việc DBMS tích hợp sẵn Temporal Database (System-Versioning) là cần thiết vì 4 lý do cốt lõi:

1. **Chuyển trách nhiệm toàn vẹn lịch sử từ ứng dụng vào engine:** Khi dùng Trigger, toàn bộ tính đúng đắn phụ thuộc vào kỷ luật lập trình — xử lý đúng multi-row qua `inserted`/`deleted` (nếu dùng biến đơn sẽ mất dòng ở T5), chặn vòng lặp trigger lồng nhau, bảo vệ cột `ValidFrom`/`ValidTo` khỏi bị sửa tay, và bảo vệ bảng History khỏi bị chỉnh sửa trái phép. Với Native Temporal, SQL Server đảm bảo các bất biến này ở tầng engine và khóa hoàn toàn việc sửa trực tiếp bảng History.
2. **Giảm mạnh chi phí bảo trì khi schema thay đổi (đã kiểm chứng ở C4):** Trong hệ thống thực tế, cấu trúc bảng luôn thay đổi theo thời gian. Bằng chứng `thuy_c4_schema_maintenance.txt` cho thấy chỉ cần thêm một cột `PriceSource`, nhánh Manual phải đồng bộ thủ công bảng History, trigger và các truy vấn đọc — nếu bỏ sót trigger, dữ liệu lịch sử bị ghi thiếu (`NULL`) mà không báo lỗi. Native Temporal tự động lan truyền thay đổi schema sang bảng History.
3. **Chuẩn hóa ngữ nghĩa thời gian và cú pháp truy vấn Time Travel:** Thay vì mỗi lập trình viên tự viết `UNION ALL` kèm điều kiện biên (`<`, `<=`, `>`) rất dễ lệch ở biên khoảng (như sự khác nhau giữa `FROM…TO` và `BETWEEN` trong T7) hoặc quên lọc phiên bản độ dài 0, DBMS cung cấp cú pháp chuẩn `FOR SYSTEM_TIME` ngắn gọn, nhất quán theo thời điểm bắt đầu giao tác.
4. **Tích hợp sẵn quản lý vòng đời lịch sử (Retention):** Bảng lịch sử tăng trưởng liên tục theo thời gian. Native Temporal cung cấp chính sách `HISTORY_RETENTION_PERIOD` chạy nền theo `ValidTo`, giúp giảm công tự xây job dọn dẹp như ở nhánh Trigger.

**Kết luận ngắn:** Trigger + History Table vẫn hữu ích khi cần logic nghiệp vụ đặc thù (như chỉ ghi log có điều kiện hoặc theo dõi Valid Time nghiệp vụ). Nhưng với bài toán cốt lõi là **lưu trữ và truy vấn lịch sử thay đổi dữ liệu theo thời gian hệ thống**, cung cấp Temporal Database native giúp giảm lỗi lập trình, bảo đảm tính toàn vẹn kiểm toán và cắt giảm đáng kể chi phí bảo trì dài hạn.

---

## 5. Gợi ý bố cục Slide 9–11 và phần Demo (Kiệt – TV4)

Theo Quy ước 1.3 (mục 12.1–12.2): Kiệt phụ trách **4 phút thuyết trình (Slide 9–11)** và **6 phút demo (phút 4:00–10:00 trên SSMS)**.

- **Slide 9 – Kiểm chứng đối chứng T0–T7 & Trục thời gian 101:**
  - Hình: trục thời gian sản phẩm 101 (`25.000` → `27.000` → `30.000`) đánh dấu 3 mốc `@t_ready`, `@t_between`, `@t_after_T3`.
  - Bảng tóm tắt: 49/49 mục kiểm tra PASS trên SQL Server 2025 (`17.0.1000.7`), hai nhánh khớp hoàn toàn về giá và thứ tự phiên bản.
- **Slide 10 – So sánh Time Travel Query & Điều kiện biên (T6, T7):**
  - Đặt cạnh nhau 2 đoạn SQL ngắn: `FOR SYSTEM_TIME AS OF @t` (Native) vs `UNION ALL` + `ValidFrom <= @t AND ValidTo > @t` (Manual).
  - Minh họa nhanh sự khác biệt biên trên giữa `FROM…TO` (25k, 27k) và `BETWEEN` (25k, 27k, 30k).
- **Slide 11 – Bảng so sánh C1–C6 & Trả lời câu hỏi trọng tâm:**
  - Bảng 2 cột gọn: *Phần SQL Server tự quản lý (Native)* vs *Phần nhóm phải tự viết & bảo trì (Manual)*, nhấn mạnh bằng chứng C4 (`PriceSource`) và chốt không kết luận hiệu năng.
  - Câu kết trả lời thẳng câu hỏi của đề bài, chuyển sang phần demo SSMS.
