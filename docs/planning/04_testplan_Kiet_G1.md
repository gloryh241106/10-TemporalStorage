# Test Plan G1 – Kiệt (TV4) sở hữu và phê duyệt

**Phiên bản:** 1.0  
**Người tạo:** Kiệt (TV4)  
**Ngày tạo:** 2026-10-28  
**Trạng thái:** ĐÃ DUYỆT – chờ xác nhận chữ ký G1  
**Tham chiếu:** `03_testplan_G1_for_Kiet.md` (Hoàng soạn khung), `02_team_data_contract.md`

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
| DBMS | SQL Server 2016 (13.x) trở lên |
| Database | `TemporalSeminarDB` |
| Baseline | Marker `TV1_BASELINE_V3` đã tồn tại trong `demo.SeedState` |
| Trạng thái trước G2 | `01_verify_setup.sql` PASS (chưa có Trigger, chưa có period, chưa có History) |
| Timezone ghi nhận | **UTC** – dùng `SYSUTCDATETIME()` làm mốc đo |

> **Quy ước timestamp:**
> - Native Temporal: ghi UTC tại **thời điểm bắt đầu giao tác** (transaction begin)
> - Trigger thủ công: ghi UTC tại **thời điểm thực thi DML** (có thể nhỏ hơn vài ms so với native)
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
| **Thời điểm thực hiện** | Ngay sau khi Thùy/Trung gắn cơ chế lịch sử (trước T1) |
| **Người thực hiện** | Hoàng (TV1) – Kiệt xác nhận output |
| **Script** | `01_verify_setup.sql` |

**Kết quả kỳ vọng:**
```
VerificationResult: PASS G1 - TV1 baseline V3 khop tung dong; 5 Product, 4 Manual, 4 Native, ProductID=105 chua co gia
```
- Bảng `dbo.Product`: đúng 5 dòng
- Bảng `demo.ProductPrice_Manual`: đúng 4 dòng (101–104), **không có** dòng 105
- Bảng `demo.ProductPrice_Native`: đúng 4 dòng (101–104), **không có** dòng 105
- Hai bảng giá khớp nhau hoàn toàn (UnitPrice, CurrencyCode, PriceNote)
- Chưa có Trigger trên bất kỳ bảng giá nào
- Chưa có cơ chế temporal trên bất kỳ bảng giá nào

**Bằng chứng cần lưu:** Screenshot SSMS output `01_verify_setup.sql` chạy PASS

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
| Bảng History sau INSERT | **0 dòng** cho ProductID=105 (INSERT thuần không tạo History) | **0 dòng** cho ProductID=105 trong History table |
| Lý do | Trigger thường chỉ kích hoạt khi UPDATE/DELETE; INSERT lần đầu không có "phiên bản cũ" | Native temporal chỉ lưu phiên bản cũ khi có UPDATE/DELETE |

> ⚠️ Thùy cần công khai rõ: Trigger có xử lý INSERT không? Nếu có logic INSERT trong Trigger, cần giải thích rõ khi nào mới bắt đầu lưu History.

---

### T2 – UPDATE một dòng: 101 từ 25.000 → 27.000

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra cơ chế lưu lịch sử khi có thay đổi đơn dòng |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `UPDATE ... SET UnitPrice = 27000.00 WHERE ProductID = 101` |
| **Yêu cầu** | Ghi lại timestamp UTC `@t2_utc = SYSUTCDATETIME()` ngay trước khi UPDATE |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual | Nhánh Native |
|---|---|---|
| Current table sau UPDATE | 101 = **27.000** VND | 101 = **27.000** VND |
| History sau UPDATE | Có 1 dòng: 101 = **25.000** VND (phiên bản cũ) | Có 1 dòng: 101 = **25.000** VND trong History table |
| Timestamp phiên bản cũ | Ghi theo quy ước Trigger (UTC DML time) | `ValidFrom` = UTC transaction begin, `ValidTo` = UTC lúc kết thúc hiệu lực |
| Timestamp phiên bản mới | N/A (Current table) | `ValidFrom` = UTC transaction begin T2 |

---

### T3 – UPDATE lần 2: 101 từ 27.000 → 30.000 (giao tác khác)

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra lịch sử tích lũy qua nhiều lần thay đổi; đảm bảo 2 phiên bản cũ được lưu |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `UPDATE ... SET UnitPrice = 30000.00 WHERE ProductID = 101` |
| **Yêu cầu** | ⚠️ Phải là **giao tác riêng biệt** với T2; ghi `@t3_utc = SYSUTCDATETIME()` trước UPDATE |

**Kết quả kỳ vọng:**

| Kiểm tra | Nhánh Manual | Nhánh Native |
|---|---|---|
| Current table sau T3 | 101 = **30.000** VND | 101 = **30.000** VND |
| History sau T3 | **2 dòng** cho 101: 25.000 và 27.000 | **2 dòng** trong History: 25.000 và 27.000 |
| Thứ tự lịch sử | Có thể truy vấn theo thứ tự thời gian | `ValidFrom` tăng dần theo thứ tự |
| Không trùng giao tác | `@t2_utc ≠ @t3_utc` → có thể phân biệt bằng AS OF | ValidFrom của 2 bản ghi khác nhau |

---

### T4 – DELETE giá sản phẩm 104

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra hành vi khi xóa dữ liệu – bản ghi cũ có còn trong History không |
| **Người thực hiện** | Thùy (nhánh Manual), Trung (nhánh Native) |
| **DML thực hiện** | `DELETE FROM ... WHERE ProductID = 104` |
| **Yêu cầu** | Ghi `@t4_utc = SYSUTCDATETIME()` trước DELETE |

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
| **Phụ thuộc** | T2 và T3 đã chạy xong; đã ghi `@t2_utc` và `@t3_utc` |

**Các mốc thời gian cần kiểm tra:**

| Mốc | Mô tả | Kết quả kỳ vọng (cả 2 nhánh) |
|---|---|---|
| Trước T2 (`@t2_utc - 1 giây`) | Khi giá còn là 25.000 | Trả về 101 = **25.000** VND |
| Giữa T2 và T3 (`@t2_utc + X`) | Khi giá là 27.000 | Trả về 101 = **27.000** VND |
| Sau T3 (`@t3_utc + 1 giây`) | Khi giá là 30.000 | Trả về 101 = **30.000** VND |

**Cú pháp kỳ vọng:**
- Native: `SELECT * FROM demo.ProductPrice_Native FOR SYSTEM_TIME AS OF @timestamp WHERE ProductID = 101`
- Manual: Query thủ công trên ManualHistory với điều kiện `StartTime <= @timestamp AND (EndTime > @timestamp OR EndTime IS NULL)`

> ⚠️ Chọn `@timestamp` nằm **giữa** hai sự kiện đã commit, không phải đúng bằng thời điểm transaction.

---

### T7 – Truy vấn khoảng thời gian: tất cả phiên bản 101 trong UTC range

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kiểm tra truy vấn khoảng (range) lịch sử; giải thích biên khoảng |
| **Người thực hiện** | **Kiệt (TV4)** – tự viết và chạy |
| **Phụ thuộc** | T2 và T3 đã chạy; có đủ các phiên bản lịch sử |

**Kết quả kỳ vọng:**
- Truy vấn trả về **tất cả phiên bản** của ProductID=101 từ R0 đến hiện tại
- Có thể quan sát được các phiên bản: 25.000 → 27.000 → 30.000 theo thứ tự thời gian
- Giải thích rõ biên khoảng: `[ValidFrom, ValidTo)` (inclusive start, exclusive end) với native

**Cú pháp kỳ vọng (native):**
```sql
SELECT * FROM demo.ProductPrice_Native
FOR SYSTEM_TIME BETWEEN @start AND @end
WHERE ProductID = 101
ORDER BY ValidFrom;
-- Hoặc: FOR SYSTEM_TIME FROM @start TO @end
-- Hoặc: FOR SYSTEM_TIME CONTAINED IN (@start, @end)
```

---

## 5. Script kiểm chứng do Kiệt chuẩn bị (dùng sau G2)

> Đây là **kế hoạch script** – sẽ được viết chi tiết trong `sql/04_testing/` sau G2.

| Script | Nội dung |
|---|---|
| `T0_verify_baseline.sql` | Chạy lại 01_verify_setup; xác nhận trạng thái trước G2 |
| `T1_insert_105.sql` | INSERT 105; query Current và History ngay sau |
| `T2_update_101_v1.sql` | Ghi `@t2_utc`; UPDATE 101→27.000; query kết quả |
| `T3_update_101_v2.sql` | Ghi `@t3_utc`; UPDATE 101→30.000 (giao tác mới); query |
| `T4_delete_104.sql` | Ghi `@t4_utc`; DELETE 104; query Current và History |
| `T5_update_multirow.sql` | UPDATE 102+103 cùng lúc; query cả 2 dòng Current và History |
| `T6_time_travel_AS_OF.sql` | Time Travel 101 tại 3 mốc; so sánh 2 nhánh |
| `T7_range_query.sql` | Truy vấn khoảng UTC cho 101; so sánh 2 nhánh |

---

## 6. Ma trận bằng chứng (template)

Mỗi test case sau G2 cần lưu đầy đủ:

| Test | Script chạy | Output/Ảnh SSMS | Before State | After State | UTC timestamp | Pass/Fail | Người xác nhận |
|---|---|---|---|---|---|---|---|
| T0 | `01_verify_setup.sql` | | | | | | Hoàng + Kiệt |
| T1 | `T1_insert_105.sql` | | | | | | Kiệt |
| T2 | `T2_update_101_v1.sql` | | | | | | Kiệt |
| T3 | `T3_update_101_v2.sql` | | | | | | Kiệt |
| T4 | `T4_delete_104.sql` | | | | | | Kiệt |
| T5 | `T5_update_multirow.sql` | | | | | | Kiệt |
| T6 | `T6_time_travel_AS_OF.sql` | | | | | | Kiệt |
| T7 | `T7_range_query.sql` | | | | | | Kiệt |

---

## 7. Tiêu chí so sánh hai phương pháp (K01 – Kiệt xác định)

Sau khi hoàn thành T0–T7, lập bảng so sánh theo 6 tiêu chí sau:

| # | Tiêu chí | Mô tả |
|---|---|---|
| C1 | **Tính tự động hóa** | Cơ chế có tự lưu lịch sử không hay cần lập trình thêm? |
| C2 | **Độ chính xác timestamp** | Timestamp lưu đúng thời điểm nào? Có bất nhất không? |
| C3 | **Cú pháp truy vấn lịch sử** | Query Time Travel đơn giản hay phức tạp? Cần self-join không? |
| C4 | **Khả năng bảo trì** | Khi schema thay đổi (thêm cột), cần sửa bao nhiêu nơi? |
| C5 | **Tính linh hoạt** | Có thể tùy chỉnh logic lịch sử không (lọc điều kiện, giá trị đặc biệt)? |
| C6 | **Giới hạn và ràng buộc** | Giới hạn theo phiên bản SQL Server? Retention policy? Không thể UPDATE History? |

---

## 8. Xác nhận G1 – Chữ ký

| Thành viên | Vai trò | Xác nhận | Ngày |
|---|---|---|---|
| **Kiệt (TV4)** | Test plan T0–T7, tiêu chí so sánh | ✅ ĐÃ XÁC NHẬN | 2026-10-28 |
| Thùy (TV2) | Hiểu timestamp ManualHistory và multi-row | ⬜ Chờ ký | |
| Trung (TV3) | Xác nhận period DATETIME2 và SQL Server version | ⬜ Chờ ký | |
| Hoàng (TV1) | Ghi quyết định G1 và ngày chốt | ⬜ Chờ ký | |

---

*Tài liệu này do Kiệt (TV4) sở hữu. Cập nhật lần cuối: 2026-10-28.*
