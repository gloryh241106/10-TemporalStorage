# Hợp đồng dữ liệu G1 - Nhóm 10 / Chủ đề 8

**Trạng thái:** ĐỀ XUẤT CẦN CẢ NHÓM CHỐT G1. Bản thay đổi V4 chưa được chạy trực tiếp trong phiên cập nhật; ảnh PASS trước đó thuộc baseline V3.

## Phạm vi

Bài toán: theo dõi **giá hiện hành và lịch sử giá** của sản phẩm trong quán đồ uống/thức ăn. `dbo.Product` là bảng danh mục thông thường, **không** lưu lịch sử đổi tên. Không nghiên cứu lưu giá hiệu lực tương lai (application-time/valid-time) trong phần demo native.

## Đối tượng TV1 sở hữu

| Đối tượng | Quy tắc |
|---|---|
| `dbo.Product` | `ProductID` là khóa định danh DUY NHẤT (PK), không có `ProductCode`; `ProductName` và `Category` bắt buộc |
| `demo.ProductPrice_Manual` | PK+FK ProductID, UnitPrice >= 0, CurrencyCode mặc định VND, PriceNote nullable |
| `demo.ProductPrice_Native` | Cùng business columns/ràng buộc với Manual; **chưa** temporal ở G1 |
| `demo.SeedState` | Metadata kỹ thuật, marker `TV1_BASELINE_V4`, không thuộc nghiệp vụ |

Cardinality cho từng nhánh: `Product ||--o| ProductPrice` (một sản phẩm có 0..1 giá hiện tại trên nhánh; mỗi dòng giá thuộc đúng 1 sản phẩm). Hai nhánh là hai phương án thí nghiệm, không phải hai nguồn giá trong vận hành thương mại thật. Không có supertype/subtype.

**Quyết định G1 V4:** bỏ `ProductCode` vì không có yêu cầu nghiệp vụ riêng; cả hai bảng giá tiếp tục FK về `dbo.Product(ProductID)`. Không thay đổi số dòng hoặc giá R0.

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
- **Thùy (TV2):** tạo ManualHistory và Trigger; tự quyết định khóa History và semantics của khoảng thời gian **có thỏa thuận với Kiệt**. `ProductID` riêng lẻ không thể là khóa duy nhất cho mọi phiên bản History.
- **Trung (TV3):** bổ sung period `DATETIME2(7)` và bật `SYSTEM_VERSIONING` trên bảng Native; không sửa giá baseline trước G1; History do SQL Server quản lý. Không tự tạo PK/FK vào native History.
- **Kiệt (TV4):** thiết kế test plan từ G1, chạy đối chứng sau G2, xác nhận truy vấn `AS OF`, truy vấn khoảng, và so sánh trên bằng chứng. Không thay code của TV2/TV3 để 'làm xanh' test.

## Điểm đặc biệt về thời gian

SQL Server temporal native dùng UTC **thời điểm bắt đầu giao tác** cho period. Thùy dùng Trigger có thể ghi thời điểm thực thi DML khác với period native. Phải ghi rõ hai semantics và so sánh theo trạng thái/sự kiện; KHÔNG ép hai timestamp bằng nhau hay tự tạo các ngày lịch sử ảo. Kiệt nên lưu mốc UTC giao tác của từng nhánh và chọn `AS OF` nằm giữa các sự kiện đã commit. Không đặt hai lần thay đổi một sản phẩm trong một transaction nếu cần khảo sát lịch sử trung gian bằng `AS OF`.

## Gates

- **G1 (Hoàng + Kiệt):** xác nhận scope; schema; SQL Server version; setup được chạy trên instance test; `01_verify_setup.sql` PASS; test plan được duyệt.
- **G2 (Thùy và Trung song song):** mỗi nhánh script tạo cơ chế lịch sử, query và evidence riêng; Kiệt tiếp nhận kết quả kiểm thử độc lập.
- **G3:** Kiệt đối chứng, kiểm tra timestamp/Time Travel; Hoàng tích hợp báo cáo và slide.

## Tái lập và an toàn

- Với database đã khởi tạo theo V3, chạy `02_migrate_v3_to_v4_once.sql` **trước** `01_verify_setup.sql` V4. Script migration chỉ cho phép ở baseline chưa có G2; không xóa dữ liệu hay reset giá. Nếu database đã được dùng cho G2, dừng và thống nhất phương án mới.
- Chạy `00_create_and_seed.sql` V4 trực tiếp trên database V3 không tự loại bỏ `ProductCode`, do đó không thay thế migration.

- Script `00_create_and_seed.sql` chạy lại **không** reset dữ liệu khi đã có marker V4; tuyệt đối không dùng script này như một tool phục hồi sau demo.
- Muốn quay về R0 cần database sandbox/snapshot/backup riêng hoặc tạo mới trên môi trường thử nghiệm, không DROP một CSDL đang có dữ liệu người dùng.
- `01_verify_setup.sql` chỉ chạy sau seed và **trước** khi Thùy/Trung gắn Trigger hoặc bật Temporal; chạy sau demo có thể FAIL là điều bình thường.
- `CREATE TABLE`/`DROP TABLE` là DDL, không được ngộ nhận Temporal History có thể tự khôi phục schema đã DROP.

## Quyết định phải ký chốt tại G1

- [ ] Cho phép Product không có giá hiện tại (0..1) - đề xuất CÓ.
- [ ] Chỉ lịch sử bảng giá, không lịch sử tên Product - đề xuất CÓ.
- [ ] Chốt timestamp/interval semantics cho ManualHistory; `DATETIME2(7)` cho native.
- [ ] Chốt test plan T0–T7 và trách nhiệm bằng chứng.
- [ ] Chốt SQL Server edition/version/test environment; các tính năng retention tùy phiên bản.
