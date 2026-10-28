# Khung kiểm thử G1 – Hoàng chuẩn bị, Kiệt sở hữu và phê duyệt

**Lưu ý:** Đây là mẫu đầu vào cho baseline V4 (chỉ `ProductID`, không `ProductCode`), không phải kết quả đã chạy. Kiệt được quyền bổ sung/tinh chỉnh sau G1.

| Mã | Thao tác/tình huống | Kết quả có thể kiểm chứng | Ai thực hiện |
|---|---|---|---|
| T0 | Đọc baseline hai nhánh | 5 Product, 4 giá mỗi nhánh, 105 chưa có; cùng giá/ghi chú | Hoàng |
| T1 | Sau khi gắn cơ chế, INSERT giá 105 = 19.000 | Có dòng Current; không có phiên bản cũ của 105 do thao tác này | Thùy/Trung |
| T2 | UPDATE 101: 25.000 → 27.000 | Current mới, phiên bản cũ được lưu | Thùy/Trung |
| T3 | UPDATE 101: 27.000 → 30.000 ở một giao tác khác | Lịch sử có thêm phiên bản; mốc thời gian được ghi thật | Thùy/Trung |
| T4 | DELETE giá 104 | Bản ghi Current biến mất; phiên bản trước xóa còn trong History | Thùy/Trung |
| T5 | UPDATE đồng thời 102 và 103 (một statement) | Cả hai phiên bản cũ đều được ghi; không 'rơi' dòng | Thùy/Trung |
| T6 | Truy vấn giá 101 tại mốc UTC trước/sau T2, T3 | Kết quả theo đúng khoảng hiệu lực thực tế từng nhánh | Kiệt |
| T7 | Truy vấn các phiên bản 101 trong một khoảng UTC | Quan sát được các phiên bản chồng khoảng được chọn; giải thích biên khoảng | Kiệt |

**Không gán mốc thời gian giả trong script**. Native lưu system-time UTC theo transaction begin; Trigger tự xây phải công khai quy ước timestamp. Khi đo, tránh gộp T2 và T3 trong cùng một giao tác. Nếu muốn demo tốc độ/retention, đó là phần mở rộng tùy thời gian, không được kết luận thiếu bằng chứng.

## Ma trận bằng chứng

Mỗi test case sau G2 cần ít nhất: script SQL đang chạy, output/ảnh SSMS, bản ghi current/history trước và sau, thời gian UTC quan sát, trạng thái Pass/Fail và người xác nhận. Không chỉ chụp một màn hình có chữ PASS do người viết tự in.
