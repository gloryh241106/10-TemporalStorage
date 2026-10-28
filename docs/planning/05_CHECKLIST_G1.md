# Checklist nghiệm thu G1 – Hoàng + Kiệt

## A. Hoàng – nghiên cứu và thiết kế
- [ ] Giải thích được system time khác valid time.
- [ ] Giải thích được Trigger tự xây History và điểm khác native Temporal.
- [ ] Nêu được vì sao chọn bài toán theo dõi giá, không theo dõi lịch sử ProductName.
- [ ] Chốt ERD Crow's Foot và 0..1 giá hiện tại cho mỗi Product trên từng nhánh.
- [ ] Nêu rõ không có supertype/subtype ở mô hình này.
- [ ] Xác nhận chỉ dùng `ProductID` làm mã định danh; `ProductCode` đã loại bỏ khỏi ERD và SQL.
- [ ] Chốt schema/fk/check và xử lý dữ liệu Product 105 chưa có giá.

## B. Kiểm tra SQL thật – BẮT BUỘC, chưa hoàn thành trong gói
- [ ] Ghi thông tin `SELECT @@VERSION` và tên instance SQL Server.
- [ ] Nếu có database V3: sao lưu nếu cần, chạy migration V3→V4; nếu database mới: chạy 00 setup V4. Lưu chứng cứ.
- [ ] Chạy 01 verify **bản V4** nhận PASS và lưu chứng cứ (ảnh PASS V3 không thay thế).
- [ ] Chạy lại 00 trên baseline, số dòng không đổi.
- [ ] Kiểm tra trước khi gắn G2: chưa có Trigger/History/period trên các bảng giá.
- [ ] Nếu DB tồn tại trước đó: được chủ sở hữu cho phép sử dụng hoặc chuyển sang sandbox mới.

## C. Hợp đồng nhóm – BẮT BUỘC
- [ ] Kiệt xác nhận test cases T0–T7 và kết quả kỳ vọng.
- [ ] Thùy xác nhận hiểu nghĩa timestamp của ManualHistory và xử lý nhiều dòng.
- [ ] Trung xác nhận period DATETIME2 và phiên bản SQL Server thực tế.
- [ ] Hoàng ghi quyết định G1, ngày chốt và người xác nhận.

## D. Công việc nhóm trưởng liên tục
- [ ] Gửi bản G1 được duyệt cho Thùy/Trung/Kiệt.
- [ ] Nhận báo cáo và evidence G2; không tự bịa output thử nghiệm.
- [ ] Ghép Master Report, slide và kiểm tra 15 phút lý thuyết + 10 phút demo.
- [ ] Tổng hợp % hoàn thành thực tế của từng thành viên dựa trên bằng chứng.
- [ ] Nộp đúng 3 file; bản in báo cáo ngày 08/12/2026.
