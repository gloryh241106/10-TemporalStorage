# Checklist G1 và bàn giao – Hoàng + Kiệt

Quy ước [tab Đồ án Lý thuyết](https://docs.google.com/document/d/1mPEMmDRuefvWg4WnW67O9pyIm1HDXP-jaOmJqN2wasI/edit?tab=t.0) chốt ngày 10/11/2026. Các mục kỹ thuật bên dưới dựa trên [log SQL Server](../../evidence/G1_V4_sqlcmd.txt).

## A. Hoàng – nghiên cứu và thiết kế

- [x] Viết phần phân biệt thời gian hệ thống, thời gian nghiệp vụ và cơ chế lưu lịch sử bằng trigger hoặc native.
- [x] Chốt phạm vi theo dõi giá và ghi chú; lịch sử tên sản phẩm nằm ngoài phạm vi.
- [x] Đồng bộ ERD, SQL và báo cáo: mỗi nhánh có 0..1 giá hiện tại cho mỗi Product. Hai bảng giá là hai nhánh đối chứng; mô hình không dùng supertype/subtype.
- [x] Dùng `ProductID` làm mã định danh và khóa nối chung. Sản phẩm 105 có trong danh mục và chưa có giá.
- [x] Chuẩn bị demo mở đầu cho UPDATE trên bảng thường và lời dẫn sang hai nhánh.

## B. Hoàng – kiểm tra SQL

- [x] Ghi SQL Server 2025 Standard Developer 17.0.1145.4, compatibility level 170.
- [x] Chạy setup và T0 trên database thử mới. Hai bảng giá có cùng dữ liệu R0; số dòng là 5/4/4; chưa có trigger, history hay period.
- [x] Kiểm tra setup từ chối chạy lại trên baseline đã có dữ liệu; T0 vẫn PASS.
- [x] Chạy demo bảng tạm: sản phẩm 101 đổi từ 25.000 lên 27.000 VND trong bảng tạm. T0 sau demo vẫn PASS.
- [x] Chạy lại setup và T0 ngày 13/11 trên database thử mới, SQL Server 2025 build 17.0.1155.3: T0 PASS, setup chạy lại bị từ chối. Xem [log](../../evidence/G1_V4_T0_rerun_20261113.txt).
- [ ] Lưu output T0 trên môi trường nhóm sẽ dùng để chạy G2, nếu khác máy của Hoàng.

## C. Bàn giao và đối chứng

- [x] Ghi hợp đồng V4, README và log G1 trong repo để từng nhánh có đầu vào.
- [x] Kiệt xác nhận test plan và kỳ vọng T0–T7 ngày 28/10/2026. Xem [test plan](04_testplan_Kiet_G1.md); mốc này là duyệt kế hoạch.
- [x] Hoàng cập nhật Test Plan 1.1 và script T6/T7 theo hợp đồng V4 (13/11): `ValidFrom`/`ValidTo`, ba mốc UTC, cận trên T7 là `ValidFrom` của bản 30.000, bảng Expected/Actual/Status. Script đã chạy thử trên sandbox giả lập hai nhánh; đó không phải bằng chứng G2.
- [x] Hoàng chốt phần G1 ngày 16/11: hợp đồng ghi SQL Server 2025, quy tắc mốc cho dòng R0 bên Manual, bộ mốc UTC dùng chung cho hai nhánh. G2 bắt đầu theo [bàn giao G2](06_G2_handoff.md).
- [ ] Kiệt rà và xác nhận Test Plan 1.1 cùng log T0 ngày 13/11.
- [ ] Thùy bàn giao script Manual, quy ước timestamp và output thử UPDATE.
- [ ] Trung bàn giao script Native, period `DATETIME2(7)` và output thử UPDATE.
- [ ] Kiệt chạy từng nhánh khi nhận bàn giao, sau đó đối chứng khi có đủ hai nhánh. Lưu kết quả theo lần chạy.

## D. Hoàng – tích hợp và chuẩn bị nộp

- [ ] Ghép báo cáo, slide và gói minh họa từ đầu ra G2/G3; ghi tỷ lệ hoàn thành thực tế của cả nhóm.
- [ ] Chạy thử toàn bài: 15 phút trình bày, 10 phút minh họa; tối đa 20 slide.
- [ ] In báo cáo cho seminar 08/12/2026; nộp đúng 3 file lên Moodle trước 23:00 ngày 10/12/2026.
