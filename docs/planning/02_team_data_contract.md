# Hợp đồng dữ liệu G1 - Nhóm 10 / Chủ đề 8

**Trạng thái:** Quy ước chốt ngày 10/11/2026. Baseline V4 đã qua T0 trên SQL Server 2025 Standard Developer, build 17.0.1145.4. Xem [kết quả chạy G1](../../evidence/G1_V4_sqlcmd.txt). Ngày 13/11 chạy lại T0 trên build 17.0.1155.3 vẫn PASS ([log](../../evidence/G1_V4_T0_rerun_20261113.txt)).

## Phạm vi

Bài toán: theo dõi **giá hiện hành và lịch sử giá** của sản phẩm trong quán đồ uống/thức ăn. `dbo.Product` là bảng danh mục thông thường, **không** lưu lịch sử đổi tên. Không nghiên cứu lưu giá hiệu lực tương lai (application-time/valid-time) trong phần demo native.

Môi trường chốt cho cả nhóm: **SQL Server 2025 (17.x)**, compatibility level 170. T0 kiểm tra đúng phiên bản này; script G2 và G3 cũng chạy trên SQL Server 2025.

## Đối tượng TV1 sở hữu

| Đối tượng | Quy tắc |
|---|---|
| `dbo.Product` | `ProductID` là khóa định danh DUY NHẤT (PK), không có `ProductCode`; `ProductName` và `Category` bắt buộc |
| `demo.ProductPrice_Manual` | PK+FK ProductID, UnitPrice >= 0, CurrencyCode mặc định VND, PriceNote nullable |
| `demo.ProductPrice_Native` | Cùng business columns/ràng buộc với Manual; **chưa** temporal ở G1 |

Cardinality cho từng nhánh: `Product ||--o| ProductPrice` (một sản phẩm có 0..1 giá hiện tại trên nhánh; mỗi dòng giá thuộc đúng 1 sản phẩm). Hai nhánh là hai phương án thí nghiệm, không phải hai nguồn giá trong vận hành thương mại thật. Không có supertype/subtype.

G1 V4 dùng `ProductID` làm mã định danh và FK chung. Hai nhánh bắt đầu với cùng dữ liệu R0. T0 kiểm tra trực tiếp dữ liệu và metadata của ba bảng nghiệp vụ.

## Baseline R0 (dữ liệu minh họa, không phải giá thực tế)

| ProductID | ProductName | Manual price | Native price |
|---|---|---:|---:|
| 101 | Cà phê sữa đá | 25.000 | 25.000 |
| 102 | Trà đào cam sả | 25.000 | 25.000 |
| 103 | Bánh mì thịt | 28.000 | 28.000 |
| 104 | Matcha latte | 45.000 | 45.000 |
| 105 | Bánh quy bơ | Chưa có | Chưa có |

Tất cả giá VND. Cặp 101 và 102 được chọn cùng giá để kiểm chứng ProductID trong truy vấn; 105 dùng cho INSERT; 104 dùng cho DELETE. Thực hiện thay đổi *sau* khi kích hoạt hai cơ chế lịch sử.

## Quyền sở hữu và cấm chồng lấn

- **Hoàng (TV1):** giữ nguyên business columns, schema/seed/verify, ERD, báo cáo nền; chỉ giao khi G1 PASS trên SQL Server thực.
- **Thùy (TV2):** tạo `demo.ProductPrice_ManualHistory`, dùng `HistoryID BIGINT IDENTITY` làm PK kỹ thuật và `ProductID` để tra phiên bản. Current và History dùng `ValidFrom`/`ValidTo` kiểu `DATETIME2(7)` theo UTC. Trigger xử lý theo tập qua `inserted` và `deleted`, lấy một mốc UTC mỗi câu DML. Khi truy vấn, Kiệt dùng cùng danh sách cột từ Current và History qua `UNION ALL`. Khi bật nhánh Manual, các dòng R0 đang có trong Current được gán `ValidFrom` bằng một mốc UTC chung lấy lúc bật và `ValidTo` = `9999-12-31 23:59:59.9999999`; History bắt đầu rỗng. Không dùng NULL cho `ValidTo`.
- **Trung (TV3):** bổ sung period `ValidFrom`/`ValidTo` kiểu `DATETIME2(7)` và bật `SYSTEM_VERSIONING` trên `demo.ProductPrice_Native`. SQL Server tạo và quản lý `demo.ProductPrice_NativeHistory`. Giữ `INFINITE` cho lần đối chứng chính.
- **Kiệt (TV4):** thiết kế test plan từ G1, chạy đối chứng sau G2, xác nhận truy vấn `AS OF`, truy vấn khoảng, và so sánh trên bằng chứng. Không thay code của TV2/TV3 để 'làm xanh' test.

## Điểm đặc biệt về thời gian

SQL Server temporal native dùng UTC **thời điểm bắt đầu giao tác** cho period. Thùy dùng Trigger có thể ghi thời điểm thực thi DML khác với period native. Phải ghi rõ hai semantics và so sánh theo trạng thái/sự kiện; KHÔNG ép hai timestamp bằng nhau hay tự tạo các ngày lịch sử ảo. Kiệt nên lưu mốc UTC giao tác của từng nhánh và chọn `AS OF` nằm giữa các sự kiện đã commit. Không đặt hai lần thay đổi một sản phẩm trong một transaction nếu cần khảo sát lịch sử trung gian bằng `AS OF`.

## Gates

- **G1:** Hoàng bàn giao schema và dữ liệu R0 đã qua `01_verify_setup.sql` (T0). Kiệt chuẩn bị ca kiểm thử từ hợp đồng này.
- **G2:** Thùy và Trung soạn song song. Mỗi người chạy nhánh riêng trên baseline đã qua T0. Bàn giao cho Kiệt khi có script cài đặt và kết quả thử UPDATE cho thấy dòng cũ đã vào History.
- **G3:** Kiệt chạy từng nhánh khi sẵn sàng và đối chứng khi đủ hai nhánh. Hoàng soạn phần lý thuyết, ERD và slide mở đầu song song, rồi ghép kết luận từ kết quả G3.

## Tái lập và an toàn

- Khởi tạo V4 trên database thử nghiệm mới hoặc trống. Nếu `TemporalSeminarDB` đã có dữ liệu, giữ nguyên và chạy trên một database thử khác.
- `00_create_and_seed.sql` từ chối database có đối tượng người dùng. Schema và seed được áp dụng trong cùng giao tác.
- Chạy `01_verify_setup.sql` ngay sau setup và trước G2. `02_demo_current_only.sql` chỉ ghi vào bảng tạm của phiên chạy.

Quy ước làm việc và tiêu chí bàn giao đầy đủ nằm trong [tab Đồ án Lý thuyết](https://docs.google.com/document/d/1mPEMmDRuefvWg4WnW67O9pyIm1HDXP-jaOmJqN2wasI/edit?tab=t.0).
