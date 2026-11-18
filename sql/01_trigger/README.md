# Manual History – Thùy (TV2)

Phần G2 tự xây lịch sử giá bằng trigger cho `demo.ProductPrice_Manual`, theo [hợp đồng dữ liệu V4](../../docs/planning/02_team_data_contract.md) và [hướng dẫn bàn giao G2](../../docs/planning/06_G2_handoff.md).

**Trạng thái ngày 18/11/2026:** T1–T7 Manual PASS khi Thùy chạy độc lập trong SSMS trên SQL Server 2025 Standard Developer Edition (64-bit), build **17.0.1000.7**. Hai hạng mục cài Manual History/trigger nhiều dòng và bàn giao Manual AS OF/truy vấn khoảng đã triển khai, kiểm thử đạt trên máy Thùy, sẵn sàng gửi nhóm review. Kiệt chưa chạy đối chứng với Native trong lần thử này.

## Thứ tự chạy

Chạy trên database thử nghiệm `TemporalSeminarDB`. Khi tạo một môi trường mới, chạy `sql/00_setup/00_create_and_seed.sql`, rồi `sql/00_setup/01_verify_setup.sql` và nhận `PASS G1 / T0 - Baseline V4` trước khi cài Manual.

| Thứ tự | File trong thư mục này | Chức năng |
|---|---|---|
| 1 | [create_manual_history.sql](create_manual_history.sql) | Tạo bảng History rỗng |
| 2 | [add_manual_period_columns.sql](add_manual_period_columns.sql) | Thêm period UTC vào Current, khởi tạo cùng mốc cho các dòng R0 |
| 3 | [create_manual_trigger.sql](create_manual_trigger.sql) | Cài trigger INSERT, UPDATE, DELETE theo tập dữ liệu |
| 4 | [test_manual_t1_insert.sql](test_manual_t1_insert.sql) | Thêm giá đầu tiên cho 105 |
| 5 | [test_manual_t2_update.sql](test_manual_t2_update.sql) | Đổi giá 101 từ 25.000 lên 27.000 |
| 6 | [test_manual_t3_update.sql](test_manual_t3_update.sql) | Đổi giá 101 từ 27.000 lên 30.000 trong giao tác riêng |
| 7 | [test_manual_t4_delete.sql](test_manual_t4_delete.sql) | Xóa dòng giá hiện tại của 104 |
| 8 | [test_manual_t5_multirow_update.sql](test_manual_t5_multirow_update.sql) | Một lệnh tăng 2.000 cho cả 102 và 103 |
| 9 | [manual_as_of_queries.sql](manual_as_of_queries.sql) | Chỉ đọc: tìm giá tại ba mốc UTC thật, kiểm tra T6 Manual |
| 10 | [manual_range_queries.sql](manual_range_queries.sql) | Chỉ đọc: truy vấn khoảng và kiểm tra biên T7 Manual |

Các file T1–T5 thay đổi dữ liệu và commit khi các kiểm tra đạt. Nếu kiểm tra trong giao tác thất bại, script rollback và báo lỗi. Mỗi test chạy một lần theo thứ tự trên cho một lần demo mới; không dùng chúng để reset. Sau khi đóng SSMS hoặc khởi động lại máy, tiếp tục từ test chưa chạy trên database đã lưu, không chạy lại setup hoặc các test đã commit.

## Thiết kế

- Current giữ một dòng cho mỗi sản phẩm đang có giá. History giữ các phiên bản đã đóng, dùng `HistoryID BIGINT IDENTITY` làm PK và `ProductID` để tra các phiên bản của một sản phẩm.
- Current và History dùng `ValidFrom`/`ValidTo` kiểu `DATETIME2(7)` theo UTC. Current dùng `ValidTo = 9999-12-31 23:59:59.9999999`. Khoảng của một phiên bản là `[ValidFrom, ValidTo)`.
- Trigger `demo.trg_ProductPrice_Manual_History` lấy một `SYSUTCDATETIME()` cho mỗi câu DML, dùng chung để đóng bản cũ và mở bản mới. Đây là thời điểm trigger thực thi, khác với thời điểm bắt đầu giao tác mà Native sử dụng.
- INSERT mở phiên bản đầu và không ghi History. UPDATE ghi toàn bộ bản cũ từ `deleted` vào History rồi mở bản mới trong Current. DELETE chỉ đóng và lưu bản cũ.
- `INSERT ... SELECT FROM deleted` và `UPDATE ... JOIN inserted` xử lý tất cả dòng bị tác động. Trigger kiểm tra mức lồng của chính nó để tránh lưu History lặp do UPDATE period nội bộ.
- Demo không cho UPDATE `ProductID` hoặc sửa period trực tiếp. Một UPDATE giữ nguyên giá vẫn tạo phiên bản. Luồng seminar dùng các câu INSERT, UPDATE, DELETE riêng.
- Thao tác gốc và trigger cùng tham gia giao tác; các test chỉ báo PASS sau khi kiểm tra dữ liệu và commit. Chưa có ca kiểm thử rollback riêng trong bộ bằng chứng T1–T5.

## Kết quả kiểm thử đã quan sát

Nguồn: ảnh kết quả SQL Server do Thùy cung cấp. Các test có phần kiểm tra giá, số phiên bản, period và các giá trị cần được giữ nguyên trước khi commit.

| Test | Kết quả quan sát | Current | History | Bằng chứng |
|---|---|---:|---:|---|
| T0 | PASS baseline V4 trước G2 | 4 | Chưa tạo | [Ảnh T0](../../evidence/Thuy/thuy_t0_baseline.png) |
| T1 | PASS: 105 = 19.000; không sinh bản cũ | 5 | 0 | [Ảnh T1](../../evidence/Thuy/thuy_t1_insert.png) |
| T2 | PASS: 101 hiện tại 27.000; lịch sử 25.000 | 5 | 1 | [Ảnh T2](../../evidence/Thuy/thuy_t2_update.png) |
| T3 | PASS: 101 hiện tại 30.000; lịch sử 25.000 và 27.000 | 5 | 2 | [Ảnh T3](../../evidence/Thuy/thuy_t3_update.png) |
| T4 | PASS: xóa giá 104; giữ bản 45.000; danh mục vẫn có 104 | 4 | 3 | [Ảnh T4](../../evidence/Thuy/thuy_t4_delete.png) |
| T5 | PASS: Current 102 = 27.000, 103 = 30.000; History giữ 25.000 và 28.000 | 4 | 5 | [Ảnh T5](../../evidence/Thuy/thuy_t5_multirow_update.png) |

T5 ghi nhận cùng một mốc **2026-11-18 10:20:40.2170456 UTC** cho `ValidFrom` của cả hai dòng Current và `ValidTo` của hai bản cũ tương ứng.

Các mốc phục vụ truy vấn lịch sử **của lần chạy Manual này**, lấy từ output T2/T3:

| Mốc | Giá trị UTC | Giá 101 kỳ vọng |
|---|---|---:|
| Trước T2 (`ReadyUtc` của T2) | `2026-11-18 02:39:13.0228905` | 25.000 |
| Sau commit T2, trước T3 (`BetweenUtc` của T2) | `2026-11-18 02:39:13.1297539` | 27.000 |
| Sau commit T3 (`AfterT3Utc` của T3) | `2026-11-18 02:42:58.2776693` | 30.000 |

Kiệt cần ghi mốc mới khi chạy đối chứng hai nhánh; không dùng các mốc trên cho một database hoặc lần chạy khác.

## Bàn giao Manual AS OF và truy vấn khoảng

Hai file truy vấn chạy độc lập sau khi đã có dữ liệu T2/T3, có thể chạy lại nhiều lần. Các lệnh `INSERT` trong hai file chỉ đưa kết quả vào biến bảng (`@Versions`, `@Checks`, ...), không ghi vào bảng nghiệp vụ hay History. Dữ liệu sau T5 vẫn dùng được để kiểm tra lịch sử của 101.

### AS OF – `manual_as_of_queries.sql`

Đầu file có `@ProductID = 101` và ba mốc thật từ bảng trên. File ghép cùng danh sách sáu cột từ Current và History bằng `UNION ALL`, loại dòng có `ValidFrom >= ValidTo`, rồi áp dụng:

```sql
WHERE ValidFrom <= @AtUtc AND ValidTo > @AtUtc
```

Phiên bản bắt đầu đúng tại `@AtUtc` được lấy; phiên bản kết thúc đúng tại mốc đó bị loại. File kiểm tra tại mỗi mốc phải có đúng một dòng và đúng giá, tránh báo PASS khi xuất hiện hai phiên bản chồng lấn. Kỳ vọng ba dòng kiểm tra đều PASS, lần lượt là 25.000, 27.000 và 30.000. Khi đạt, kết quả cuối là `PASS T6 - Manual AS OF`.

### Truy vấn khoảng – `manual_range_queries.sql`

`@StartUtc` mặc định là `ReadyUtc` thực tế của T2. `@EndUtc` đọc từ `ValidFrom` của dòng Current 101 giá 30.000 trong chính database đang truy vấn. Script từ chối cận NULL hoặc `@StartUtc >= @EndUtc`.

Các điều kiện sau áp dụng trên cùng tập Current `UNION ALL` History đã loại phiên bản độ dài 0:

| Kiểu truy vấn | Điều kiện | Kết quả mong đợi với khoảng chính |
|---|---|---|
| AS OF t | `ValidFrom <= t AND ValidTo > t` | Một phiên bản tại t |
| FROM a TO b | `ValidFrom < b AND ValidTo > a` | 25.000 và 27.000 |
| BETWEEN a AND b | `ValidFrom <= b AND ValidTo > a` | 25.000, 27.000 và 30.000 |
| CONTAINED IN (a, b) | `ValidFrom >= a AND ValidTo <= b` | 27.000 |

FROM/TO lấy các phiên bản có khoảng tồn tại giao với `[a,b)`, kể cả khi chúng bắt đầu trước a hoặc kết thúc sau b. Không dùng riêng `ValidFrom BETWEEN a AND b` để thay thế điều kiện giao khoảng.

Ngoài T7 chính, file kiểm tra phiên bản 25.000 bị loại khi cận dưới bằng thời điểm nó kết thúc; AS OF tại thời điểm bắt đầu bản 30.000 lấy đúng 30.000; cùng hai truy vấn phụ lục BETWEEN và CONTAINED IN. Kỳ vọng bảng kiểm tra có năm dòng PASS và kết quả cuối `PASS T7 - Manual range and boundaries`.

Các quy tắc này đối chiếu [Microsoft Learn về temporal query](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal/overview#how-do-i-query-temporal-data).

### Trạng thái kiểm thử và cách dùng khi tích hợp

| Hạng mục | Trạng thái hiện tại | Bằng chứng |
|---|---|---|
| T6 Manual, ba mốc AS OF | PASS – `VerifiedAtUtc = 2026-11-18 10:34:41.2191714` | [Ảnh T6](../../evidence/Thuy/thuy_t6_manual_as_of.png) |
| T7 Manual và các ca biên | PASS – năm dòng kiểm tra, `VerifiedAtUtc = 2026-11-18 10:45:08.5811421` | [Ảnh T7](../../evidence/Thuy/thuy_t7_manual_range.png) |

Chỉ đổi trạng thái thành PASS sau khi đọc output thực tế của lần chạy. Kiệt có thể dùng phần `UNION ALL` và các điều kiện trên để đối chứng trong `sql/04_testing/T6_T7_time_travel_queries.sql`; script của Kiệt được giữ nguyên. Khi chạy trên môi trường khác, thay ba mốc trong file AS OF và cận dưới trong file range bằng mốc UTC quan sát được của lần chạy mới. Các giá kỳ vọng hiện gắn với kịch bản 101 của nhóm; nếu đổi sản phẩm hoặc kịch bản thì phải đổi cả kỳ vọng. Không thêm/bật Native để chạy riêng hai file Manual này.

Kết quả kiểm thử lấy từ output SSMS: T6 có ba mốc PASS, mỗi mốc đúng một dòng với giá 25.000 / 27.000 / 30.000. T7 có năm dòng PASS: FROM/TO chính lấy 25.000 và 27.000; khoảng bắt đầu ở bản 27.000 chỉ lấy 27.000; AS OF đúng lúc bản 30.000 bắt đầu lấy 30.000; BETWEEN lấy cả ba giá; CONTAINED IN chỉ lấy 27.000.

## Rà soát và hồ sơ bằng chứng

- Ngày 18/11/2026, cả 10 file `.sql` trong thư mục được phân tích cú pháp bằng Microsoft SQL ScriptDom, parser TSql170: không có lỗi cú pháp. Đây là kiểm tra tĩnh, không thay thế kết quả thực thi SQL Server trong ảnh T0–T7.
- Rà soát thiết kế và đối chiếu kịch bản đã chạy không phát hiện lỗi chặn hai hạng mục Manual trong phạm vi demo. Các giới hạn đã nêu gồm timestamp tại lúc trigger chạy, khóa sản phẩm bất biến, chưa có thử nghiệm rollback riêng và chưa đối chứng với Native.
- Đủ tám ảnh T0–T7 trong `evidence/Thuy/`. Theo mục 5.3 của quy ước nhóm, output SSMS hoặc hình ảnh minh chứng đều được chấp nhận; không bắt buộc mỗi test có thêm một log `.txt`. Khi bàn giao vẫn cần gắn mã test, script, người thực hiện, phiên bản SQL Server, UTC và commit tương ứng.
- [run_manual_demo.txt](run_manual_demo.txt) là hướng dẫn chạy riêng nhánh Manual để ghép vào gói minh họa. File hướng dẫn `.txt` là hạng mục của gói nộp; nó có mục đích khác với ảnh hoặc log kết quả kiểm thử.

## Bàn giao và bảo trì

- Commit SQL và bằng chứng trên nhánh riêng, bổ sung Git SHA vào hồ sơ bàn giao rồi gửi nhóm review. Các ảnh thử hiện tại được tạo trước commit; ghi rõ quan hệ này khi dẫn commit đóng gói, không coi đó là bằng chứng đã chạy lại tại SHA đó.
- Khi thêm cột nghiệp vụ, cần cập nhật bảng History, danh sách cột ghi History trong trigger và các truy vấn/kiểm thử liên quan. Manual tự quản lý chính sách giữ và dọn History; bộ script này không tự xóa lịch sử.
- Giữ dữ liệu sau T5 để diễn tập lại AS OF/truy vấn khoảng. Hai task Manual đã kiểm thử độc lập đạt; nghiệm thu nhóm và đối chứng Native vẫn chờ nhóm thực hiện.
