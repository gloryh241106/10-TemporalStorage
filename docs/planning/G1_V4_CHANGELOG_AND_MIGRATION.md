# G1 V4 — Bỏ ProductCode, dùng ProductID làm mã duy nhất

## Quyết định và phạm vi

- `dbo.Product`: `ProductID INT PK`, `ProductName NVARCHAR(100) NOT NULL`, `Category NVARCHAR(60) NOT NULL`.
- Hai bảng giá giữ `ProductID` là PK+FK; vẫn có `UnitPrice`, `CurrencyCode`, `PriceNote`.
- Giữ nguyên baseline 101–105, 5 Product, 4 giá/nhánh, mọi test T0–T7.
- `dbo.Product` không có lịch sử; Temporal chỉ áp dụng cho bảng giá về sau.
- `ProductCode` không cần thiết cho minh họa giá và được loại khỏi schema V4.

## Cách áp dụng cho DB đã chạy V3 trên máy Hoàng

**Không chạy lại file setup V4 rồi mong ProductCode tự biến mất.**

1. Kiểm tra chưa có Trigger, History hoặc System-Versioning G2; không có code bổ sung phụ thuộc `ProductCode`.
2. Sao lưu/snapshot nếu cần; mở SSMS và chọn đúng server/database thử nghiệm.
3. Chạy `sql/00_setup/02_migrate_v3_to_v4_once.sql` **một lần** trên database V3 đang có. Script chỉ bỏ unique constraint và cột `ProductCode`, giữ dữ liệu giá; đổi marker từ `TV1_BASELINE_V3` sang `TV1_BASELINE_V4`.
4. Chạy `sql/00_setup/01_verify_setup.sql` **bản V4**. Chỉ ghi nhận nghiệm thu sau khi màn hình báo `PASS G1 - TV1 baseline V4...`.
5. Nếu muốn kiểm tra idempotent, chạy lại `00_create_and_seed.sql` V4 *sau khi migration thành công*, bảo đảm vẫn là 5/4/4.
6. Đề nghị Kiệt chốt lại schema V4 và biên bản G1, sau đó Thùy/Trung mới làm tiếp.

## Cách áp dụng cho DB mới

Chạy `00_create_and_seed.sql` V4 trên instance test không có database trùng tên; tiếp theo chạy `01_verify_setup.sql` V4. **KHÔNG chạy migration** khi chưa có V3.

## Trạng thái kiểm thử

Ảnh SSMS trước đây chứng minh V3 PASS; **không chứng minh V4 PASS**. Script V4/migration ở đây được chuẩn bị và kiểm tra tĩnh, chưa được thực thi trên SQL Server trong phiên cập nhật này.

## Danh sách file thay đổi

- `sql/00_setup/00_create_and_seed.sql`: schema và seed V4.
- `sql/00_setup/01_verify_setup.sql`: test theo V4 và kiểm tra không còn ProductCode.
- `sql/00_setup/02_migrate_v3_to_v4_once.sql`: migration cho database V3 hiện hữu.
- `docs/erd/ERD_CrowsFoot.mmd`, `.svg`, `.png`: ERD mới.
- `docs/planning/02_team_data_contract.md`, `03_testplan_G1_for_Kiet.md`, `05_CHECKLIST_G1.md`: ghi nhận quyết định.
- `docs/report/Bao_cao_Hoang_TV1.docx`, `Master_Report_Nhom10.docx`: cập nhật phần BR01 và bảng schema, ảnh ERD.

`README.md` và `LICENSE` hiện có trong repository của em được giữ nguyên; gói này không ghi đè lên chúng. `Slides_mo_dau_Hoang.pptx` không nhắc ProductCode nên không cần sửa.
