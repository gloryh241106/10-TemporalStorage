# Test Plan G1 – Kiệt (TV4) sở hữu và phê duyệt

**Phiên bản:** 1.1 (đồng bộ hợp đồng V4)  
**Người tạo:** Kiệt (TV4)  
**Ngày tạo:** 2026-10-28 · **Cập nhật:** 2026-11-13 (Hoàng soạn thay) · 2026-11-18 (Kiệt rà, xác nhận 1.1, nâng `T1_T5_verify_dml_events.sql` lên v1.1)  
**Trạng thái:** T0 V4 đã chạy lại trên database thử sạch. T6/T7 đã theo `ValidFrom`/`ValidTo` và ba mốc UTC theo mục 10.4 trong Google Docs quy ước. Kiệt đã xác nhận bản 1.1 ngày 18/11; phần đối chứng chạy sau khi nhận hai nhánh theo [runbook G3](07_G3_runbook_Kiet.md).
**Tham chiếu:** `02_team_data_contract.md`

---

## 1. Phạm vi và mục tiêu kiểm thử

Kiểm thử đối chứng hai phương án lưu lịch sử giá sản phẩm:
- **Nhánh A (TV2 – Thùy):** Trigger tự xây + bảng `demo.ProductPrice_ManualHistory`
- **Nhánh B (TV3 – Trung):** `SYSTEM_VERSIONED TEMPORAL TABLE` native trên `demo.ProductPrice_Native`

**Mục tiêu kiểm thử:**
1. Xác nhận cả hai nhánh lưu đúng lịch sử khi có INSERT / UPDATE / DELETE
2. Xác nhận Time Travel Query (`AS OF`, khoảng thời gian) hoạt động chính xác
3. Thu thập bằng chứng khách quan để lập bảng so sánh 6 tiêu chí

**Ngoài phạm vi:**
- Đo hiệu năng / benchmark (chưa có bằng chứng → không kết luận)
- Lịch sử tên sản phẩm (`ProductName`) – chỉ theo dõi giá
- Application-time / valid-time tương lai

---

## 2. Môi trường kiểm thử

| Mục | Yêu cầu |
|---|---|
| DBMS | SQL Server 2025 (17.x) |
| Database | `TemporalSeminarDB` |
| Baseline | V4 với 5 sản phẩm, 4 giá ở mỗi nhánh và chưa có giá cho sản phẩm 105 |
| Trạng thái trước G2 | `01_verify_setup.sql` PASS (chưa có Trigger, chưa có period, chưa có History) |
| Timezone ghi nhận | **UTC** – dùng `SYSUTCDATETIME()` làm mốc đo |

> **Quy ước timestamp:**
> - Native Temporal: ghi UTC tại **thời điểm bắt đầu giao tác** (transaction begin)
> - Trigger thủ công: ghi một mốc UTC tại lúc trigger xử lý mỗi câu DML. Khoảng chênh với thời gian Native tùy giao tác.
> - Cả hai nhánh dùng `ValidFrom`/`ValidTo` kiểu `DATETIME2(7)`; bản hiện hành có `ValidTo = 9999-12-31 23:59:59.9999999`, không dùng NULL.
> - Hai semantics này **không ép bằng nhau**; phải ghi rõ khi so sánh

---

## 3. Dữ liệu baseline R0 (đã chốt tại G1)

| ProductID | ProductName | Category | Manual Price | Native Price |
|---|---|---|---:|---:|
| 101 | Cà phê sữa đá | Đồ uống | 25.000 VND | 25.000 VND |
| 102 | Trà đào cam sả | Đồ uống | 25.000 VND | 25.000 VND |
| 103 | Bánh mì thịt | Thức ăn | 28.000 VND | 28.000 VND |
| 104 | Matcha latte | Đồ uống | 45.000 VND | 45.000 VND |
| 105 | Bánh quy bơ | Thức ăn | *(chưa có)* | *(chưa có)* |

**Ghi chú thiết kế:**
- 101 và 102 cùng giá 25.000 → kiểm chứng query dùng đúng `ProductID`
- 105 chưa có giá → dùng cho test INSERT (T1)
- 104 có giá → dùng cho test DELETE (T4)

---

## 4. Ma trận kiểm thử T0–T7 (đầy đủ kết quả kỳ vọng)

### T0 – Đọc baseline hai nhánh

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Xác nhận dữ liệu nền đúng trước khi bắt đầu bất kỳ thao tác nào |
| **Thời điểm thực hiện** | Sau khi nạp R0 và trước khi Thùy hoặc Trung cài cơ chế lưu lịch sử |
| **Người thực hiện** | Hoàng (TV1) – Kiệt xác nhận output |
| **Script** | `01_verify_setup.sql` |

**Kết quả kỳ vọng:**
```
VerificationResult: PASS G1 / T0 - Baseline V4
```
- Bảng `dbo.Product`: đúng 5 dòng
- Bảng `demo.ProductPrice_Manual`: đúng 4 dòng (101–104), **không có** dòng 105
- Bảng `demo.ProductPrice_Native`: đúng 4 dòng (101–104), **không có** dòng 105
- Hai bảng giá khớp nhau hoàn toàn (UnitPrice, CurrencyCode, PriceNote)
- Chưa có Trigger trên bất kỳ bảng giá nào
- Chưa có cơ chế temporal trên bất kỳ bảng giá nào

**Bằng chứng G1:** [Output sqlcmd ngày 10/11](../../evidence/G1_V4_sqlcmd.txt) và [lần chạy lại ngày 13/11](../../evidence/G1_V4_T0_rerun_20261113.txt). Khi đối chứng trên DB khác, lưu thêm output T0 của lần chạy đó.

---

### T1 – INSERT giá mới cho sản phẩm 105

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra hành vi khi INSERT vào bảng đã có cơ chế lịch sử |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `INSERT INTO ... (ProductID, UnitPrice, ...) VALUES (105, 19000.00, ...)` |
| **Kiệt kiểm chứng** | Sau T1, chạy query T1 verify (xem mục 5) |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual (Trigger) | Nhánh Native (Temporal) |
|---|---|---|
| Bảng Current sau INSERT | Có 1 dòng: 105 = 19.000 VND | Có 1 dòng: 105 = 19.000 VND |
| Bảng History sau INSERT | **0 dòng** cho ProductID=105 | **0 dòng** cho ProductID=105 trong History table |
| Period của dòng mới | Trigger INSERT mở phiên bản đầu: `ValidFrom` = mốc UTC của câu DML, `ValidTo` = giá trị cực đại | `ValidFrom` = UTC lúc bắt đầu giao tác, `ValidTo` = giá trị cực đại |
| Lý do | Theo mục 10.3 trong Google Docs quy ước, INSERT chỉ mở phiên bản; chưa có phiên bản cũ để đưa vào History | Native chỉ đưa phiên bản cũ vào History khi UPDATE/DELETE |

---

### T2 – UPDATE một dòng: 101 từ 25.000 → 27.000

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra cơ chế lưu lịch sử khi có thay đổi đơn dòng |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `UPDATE ... SET UnitPrice = 27000.00 WHERE ProductID = 101` |
| **Yêu cầu** | Kiệt ghi `@t_ready = SYSUTCDATETIME()` sau khi cả hai nhánh sẵn sàng và trước khi bắt đầu T2 |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual | Nhánh Native |
|---|---|---|
| Current table sau UPDATE | 101 = **27.000** VND | 101 = **27.000** VND |
| History sau UPDATE | Có 1 dòng: 101 = **25.000** VND (phiên bản cũ) | Có 1 dòng: 101 = **25.000** VND trong History table |
| Timestamp phiên bản cũ | Giữ `ValidFrom`; chốt `ValidTo` theo mốc UTC của câu DML | Giữ `ValidFrom`; `ValidTo` là UTC lúc bắt đầu giao tác T2 |
| Timestamp phiên bản mới | `ValidFrom` lấy cùng mốc UTC với lúc đóng phiên bản cũ | `ValidFrom` là UTC lúc bắt đầu giao tác T2 |

---

### T3 – UPDATE lần 2: 101 từ 27.000 → 30.000 (giao tác khác)

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra lịch sử tích lũy qua nhiều lần thay đổi; đảm bảo 2 phiên bản cũ được lưu |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `UPDATE ... SET UnitPrice = 30000.00 WHERE ProductID = 101` |
| **Yêu cầu** | ⚠️ Phải là **giao tác riêng biệt** với T2. Kiệt ghi `@t_between` sau commit T2 và trước khi bắt đầu T3, rồi ghi `@t_after_T3` sau commit T3 |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual | Nhánh Native |
|---|---|---|
| Current table sau T3 | 101 = **30.000** VND | 101 = **30.000** VND |
| History sau T3 | **2 dòng** cho 101: 25.000 và 27.000 | **2 dòng** trong History: 25.000 và 27.000 |
| Thứ tự lịch sử | Có thể truy vấn theo thứ tự thời gian | `ValidFrom` tăng dần theo thứ tự |
| Không trùng giao tác | `@t_ready < @t_between < @t_after_T3` → phân biệt được bằng AS OF | ValidFrom của 2 bản ghi khác nhau |

---

### T4 – DELETE giá sản phẩm 104

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra hành vi khi xóa dữ liệu – bản ghi cũ có còn trong History không |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `DELETE FROM ... WHERE ProductID = 104` |
| **Yêu cầu** | Ghi period của dòng 104 trong History sau DELETE |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual | Nhánh Native |
|---|---|---|
| Current table sau DELETE | **Không còn** dòng 104 | **Không còn** dòng 104 |
| History sau DELETE | Có 1 dòng: 104 = 45.000 (phiên bản trước DELETE) | Có 1 dòng trong History: 104 = 45.000 |
| Toàn vẹn dữ liệu | Product 104 vẫn tồn tại trong `dbo.Product` | Product 104 vẫn tồn tại trong `dbo.Product` |

---

### T5 – UPDATE nhiều dòng cùng lúc (102 và 103 trong 1 statement)

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra Trigger xử lý UPDATE multi-row; native tự xử lý |
| **Người thực hiện** | Thùy (nhánh Manual – quan trọng nhất), Trung (nhánh Native) |
| **DML thực hiện** | `UPDATE ... SET UnitPrice = UnitPrice + 2000 WHERE ProductID IN (102, 103)` |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual (Trigger) | Nhánh Native |
|---|---|---|
| Current 102 sau UPDATE | **27.000** VND (25.000 + 2.000) | **27.000** VND |
| Current 103 sau UPDATE | **30.000** VND (28.000 + 2.000) | **30.000** VND |
| History 102 | Có 1 dòng: **25.000** (phiên bản cũ) | Có 1 dòng: **25.000** |
| History 103 | Có 1 dòng: **28.000** (phiên bản cũ) | Có 1 dòng: **28.000** |
| Điều kiện PASS | **Cả hai dòng đều có History** – không "rơi" dòng nào | Luôn đúng (native tự xử lý) |

> ⚠️ **Đây là test case quan trọng nhất cho nhánh Trigger.** Trigger viết sai (dùng `@@ROWCOUNT` hoặc giả định chỉ 1 dòng) sẽ FAIL ở đây. Thùy phải dùng bảng logic `inserted`/`deleted` đúng cách.

---

### T6 – Time Travel Query: truy vấn giá 101 tại mốc UTC cụ thể

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra khả năng truy vấn "giá tại một thời điểm trong quá khứ" |
| **Người thực hiện** | **Kiệt (TV4)** – tự viết và chạy |
| **Phụ thuộc** | T2 và T3 đã commit ở nhánh đang kiểm tra; đã ghi mốc UTC của từng lần chạy |

**Các mốc thời gian cần kiểm tra:**

| Mốc | Mô tả | Kết quả kỳ vọng (cả 2 nhánh) |
|---|---|---|
| `@t_ready` | Sau khi cả hai nhánh sẵn sàng, trước khi bắt đầu T2 | Trả về 101 = **25.000** VND |
| `@t_between` | Sau commit T2 và trước khi bắt đầu T3 | Trả về 101 = **27.000** VND |
| `@t_after_T3` | Sau commit T3 | Trả về 101 = **30.000** VND |

**Cú pháp kỳ vọng:**
- Native: `SELECT * FROM demo.ProductPrice_Native FOR SYSTEM_TIME AS OF @t WHERE ProductID = 101`
- Manual: hợp nhất Current và History bằng `UNION ALL` (cùng danh sách cột), bỏ phiên bản có `ValidFrom = ValidTo`, rồi lọc `ProductID = 101 AND ValidFrom <= @t AND ValidTo > @t`.

Hai nhánh dùng chung một bộ mốc: T2 đã commit trên **cả hai** nhánh rồi mới ghi `@t_between`; T3 chạy trên cả hai nhánh sau `@t_between`, rồi mới ghi `@t_after_T3`. Nếu một nhánh phải chạy ở buổi khác, ghi một bộ ba mốc riêng cho nhánh đó và chạy `T6_T7_time_travel_queries.sql` riêng với bộ mốc ấy.

Không dùng mốc tự đặt hay "trước T2 trừ 1 giây": mốc đó có thể rơi vào lúc cơ chế lịch sử chưa bật, khi đó AS OF trả về rỗng. Nếu cần kiểm tra đúng biên, tách thành ca riêng và dùng cột period thực tế.

---

### T7 – Truy vấn khoảng thời gian: tất cả phiên bản 101 trong UTC range

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra truy vấn khoảng (range) lịch sử; giải thích biên khoảng |
| **Người thực hiện** | **Kiệt (TV4)** – tự viết và chạy |
| **Phụ thuộc** | T2 và T3 đã chạy; có đủ các phiên bản lịch sử |

**Khoảng kiểm tra:** cận dưới `@s = @t_ready`; cận trên `@e` = `ValidFrom` của phiên bản 30.000 ở từng nhánh (đọc từ bảng Current).

| Mệnh đề | Điều kiện ([Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal/query-data?view=sql-server-ver17)) | Kỳ vọng cả 2 nhánh |
|---|---|---|
| **T7 – `FROM @s TO @e`** (ca chính) | `ValidFrom < @e AND ValidTo > @s` | **25.000, 27.000** |
| Phụ lục – `BETWEEN @s AND @e` | `ValidFrom <= @e AND ValidTo > @s` | 25.000, 27.000, 30.000 (bản 30.000 bắt đầu đúng `@e` vẫn được lấy) |
| Phụ lục – `CONTAINED IN (@s, @e)` | `ValidFrom >= @s AND ValidTo <= @e` | 27.000 (bản 25.000 bắt đầu trước `@s`) |

Nhánh Manual dùng cùng điều kiện trên tập `UNION ALL` của Current và History.

**Cú pháp kỳ vọng (native):**
```sql
SELECT ProductID, UnitPrice, ValidFrom, ValidTo FROM demo.ProductPrice_Native
FOR SYSTEM_TIME FROM @start TO @end
WHERE ProductID = 101
ORDER BY ValidFrom;
```

---

## 5. Script kiểm chứng do Kiệt chuẩn bị (dùng sau G2)

Các script trong `sql/04_testing/` chỉ đọc. DML của T1–T5 do Thùy và Trung chạy trên nhánh của mình. Chạy và ghi kết quả sau khi nhánh liên quan được bàn giao. Nhánh chưa sẵn sàng được báo `BLOCKED`, không báo FAIL.

| Script | Nội dung |
|---|---|
| `01_verify_setup.sql` | Kiểm tra T0 trước G2. |
| `T1_T5_verify_dml_events.sql` | v1.1: đặt `@AfterStep` (1–5) theo bước đã commit. Kiểm metadata (DATETIME2(7), trigger, PK `HistoryID`, retention `INFINITE`), giá Current/History, `ValidTo` cực đại, period liền mạch của 101, T5 dùng chung một mốc, rồi đối chứng giá trị hai nhánh. In bảng Expected/Actual/Status và Verdict từng nhánh |
| `T6_T7_time_travel_queries.sql` | Nhận 3 mốc UTC; chạy AS OF, `FROM ... TO` và hai mệnh đề phụ lục; in bảng Expected/Actual/Status cho từng nhánh |

---

## 6. Ma trận bằng chứng (template)

Mỗi test case sau G2 cần lưu đầy đủ:

| Test | Script chạy | Output/Ảnh SSMS | Before State | After State | UTC timestamp | Pass/Fail | Người xác nhận |
|---|---|---|---|---|---|---|---|
| T0 | `01_verify_setup.sql` | [G1_V4_T0_rerun_20261113.txt](../../evidence/G1_V4_T0_rerun_20261113.txt), [G3/01_T0.txt](../../evidence/Kiet/01_T0.txt) | DB thử trống | 5 Product / 4 Manual / 4 Native, 105 chưa có giá | `2026-11-27 08:53:42.2612901` | **PASS** | Hoàng (G1), Kiệt (G3) |
| T1 | `g3_dml_flow_t1_t5.sql` + `T1_T5_verify_dml_events.sql` | [G3/06_dml_flow_T1_T5.txt](../../evidence/Kiet/06_dml_flow_T1_T5.txt), [G3/07_verify_T1_T5.txt](../../evidence/Kiet/07_verify_T1_T5.txt) | Current 4, History 0 | Current 5 (105=19.000), History 0 (cả 2 nhánh) | `2026-11-27 08:53:42.9477635` | **PASS** | Kiệt |
| T2 | `g3_dml_flow_t1_t5.sql` + `T1_T5_verify_dml_events.sql` | [G3/06_dml_flow_T1_T5.txt](../../evidence/Kiet/06_dml_flow_T1_T5.txt), [G3/07_verify_T1_T5.txt](../../evidence/Kiet/07_verify_T1_T5.txt) | 101=25.000, History 0 | Current 101=27.000; History 1 dòng (101=25.000) | `2026-11-27 08:53:45.0098384` | **PASS** | Kiệt |
| T3 | `g3_dml_flow_t1_t5.sql` + `T1_T5_verify_dml_events.sql` | [G3/06_dml_flow_T1_T5.txt](../../evidence/Kiet/06_dml_flow_T1_T5.txt), [G3/07_verify_T1_T5.txt](../../evidence/Kiet/07_verify_T1_T5.txt) | 101=27.000, History 1 | Current 101=30.000; History 2 dòng (25.000, 27.000) | `2026-11-27 08:53:47.0286776` | **PASS** | Kiệt |
| T4 | `g3_dml_flow_t1_t5.sql` + `T1_T5_verify_dml_events.sql` | [G3/06_dml_flow_T1_T5.txt](../../evidence/Kiet/06_dml_flow_T1_T5.txt), [G3/07_verify_T1_T5.txt](../../evidence/Kiet/07_verify_T1_T5.txt) | Current 5 (104=45.000), History 2 | Current 4 (bỏ 104); History 3 (thêm 104=45.000); `dbo.Product` còn 104 | `2026-11-27 08:53:49.0551644` | **PASS** | Kiệt |
| T5 | `g3_dml_flow_t1_t5.sql` + `T1_T5_verify_dml_events.sql` | [G3/06_dml_flow_T1_T5.txt](../../evidence/Kiet/06_dml_flow_T1_T5.txt), [G3/07_verify_T1_T5.txt](../../evidence/Kiet/07_verify_T1_T5.txt) | 102=25.000, 103=28.000, History 3 | Current 102=27.000, 103=30.000; History 5 (thêm 102=25.000, 103=28.000 cùng 1 mốc) | `2026-11-27 08:53:49.0855193` | **PASS** | Kiệt |
| T6 | `T6_T7_time_travel_queries.sql` | [G3/08_T6_T7.txt](../../evidence/Kiet/08_T6_T7.txt) | 3 mốc UTC đã ghi (`t_ready`, `t_between`, `t_after_T3`) | AS OF trả về đúng `25000.00`, `27000.00`, `30000.00` ở cả 2 nhánh (6/6 PASS) | `08:53:43.9598271` / `08:53:46.0135258` / `08:53:48.0340757` | **PASS** | Kiệt |
| T7 | `T6_T7_time_travel_queries.sql` | [G3/08_T6_T7.txt](../../evidence/Kiet/08_T6_T7.txt) | Khoảng `[@t_ready, ValidFrom_30000)` | `FROM..TO`: `25000, 27000`; `BETWEEN`: `25000, 27000, 30000`; `CONTAINED IN`: `27000` (6/6 PASS) | `2026-11-27 08:53:50.3131691` | **PASS** | Kiệt |

> **Thông tin lần chạy G3:** SQL Server 2025 Standard Developer Edition (64-bit) build `17.0.1000.7`, compatibility level `170`, database `TemporalSeminarDB`, tổng **49/49 PASS, 0 FAIL, 0 BLOCKED**. Xem chi tiết trong [run_info.txt](../../evidence/Kiet/run_info.txt) và báo cáo đối chứng [Bao_cao_Kiet_TV4.md](../report/Bao_cao_Kiet_TV4.md).

---

## 7. Tiêu chí so sánh hai phương pháp (K01 – Kiệt xác định)

Sau khi hoàn thành T0–T7, lập bảng so sánh theo 6 tiêu chí sau:

| # | Tiêu chí | Mô tả |
|---|---|---|
| C1 | **Tính tự động hóa** | Cơ chế có tự lưu lịch sử không hay cần lập trình thêm? |
| C2 | **Ý nghĩa timestamp** | Mốc ghi theo đầu giao tác (Native) hay lúc chạy câu DML (Trigger)? Hệ quả khi truy vấn AS OF |
| C3 | **Cách truy vấn lịch sử** | `FOR SYSTEM_TIME` so với `UNION ALL` + điều kiện khoảng tự viết |
| C4 | **Phần phải tự bảo trì** | Khi thêm cột giá hoặc ghi chú, cần sửa bao nhiêu nơi (bảng History, trigger, truy vấn)? |
| C5 | **Tính linh hoạt** | Có thể tùy chỉnh logic lịch sử không (lọc điều kiện, giá trị đặc biệt)? |
| C6 | **Giới hạn và ràng buộc** | Giới hạn theo phiên bản SQL Server? Retention policy? Không thể UPDATE History? |

---

## 8. Xác nhận G1 – Chữ ký

| Thành viên | Vai trò | Xác nhận | Ngày |
|---|---|---|---|
| **Kiệt (TV4)** | Test plan T0–T7, tiêu chí so sánh | ✅ Đã xác nhận bản 1.0 (28/10) và bản 1.1 cùng log T0 ngày 13/11 | 2026-11-18 |
| Thùy (TV2) | Hiểu timestamp ManualHistory và multi-row | ⬜ Chờ ký | |
| Trung (TV3) | Xác nhận period DATETIME2 và SQL Server version | ⬜ Chờ ký | |
| Hoàng (TV1) | Ghi quyết định G1 và ngày chốt | Đã ghi quy ước và log T0 | 2026-11-10 |

---

## 9. Ghi chú rà soát bản 1.1 (Kiệt, 18/11)

- Kỳ vọng T0–T7 khớp hợp đồng V4 và `06_G2_handoff.md`; điều kiện biên của T7 (`FROM..TO`, `BETWEEN`, `CONTAINED IN`) khớp Microsoft Learn.
- `T1_T5_verify_dml_events.sql` bản cũ chỉ in `SELECT *`, không kiểm `ValidFrom`/`ValidTo` và không có PASS/FAIL. Bản 1.1 đã bổ sung, cùng định dạng kết quả với `T6_T7_time_travel_queries.sql`.
- Hai script đã chạy thử trên database giả lập (`TemporalSeminarDB_KietSim`, SQL Server 2025 17.0.1000.7) với trigger và temporal do Kiệt tự dựng tạm. Kết quả: nhánh đúng thì PASS hết; trigger chỉ đọc một dòng thì FAIL ở T5 (mất History 102); retention 30 ngày thì FAIL ở META. Đây là thử script, **không phải bằng chứng G2/G3**.
- Mốc thời gian: hạn bàn giao G2 là 22/11, trễ hơn hạn kiểm thử tích hợp 21/11 trong phân công. Đề xuất chạy G3 từ 22–25/11; báo cáo và slide của Kiệt vẫn giữ hạn 30/11.

---

*Kiệt (TV4) sở hữu test plan. Bản 1.1 do Hoàng cập nhật ngày 13/11/2026 theo hợp đồng V4; Kiệt rà và xác nhận ngày 18/11/2026.*
