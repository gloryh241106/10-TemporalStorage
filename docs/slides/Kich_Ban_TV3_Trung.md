Kịch bản thuyết trình – Slide 6 & 7

Môn: CSC12003 · Nhóm 10 · Chủ đề 8: Temporal Database
Người trình bày: Trung (TV3)
Tổng thời lượng: ~95 giây (45 giây + 50 giây)

Mở đầu slide 6 : "Sau phần giới thiệu khái niệm và thực hiện tạo bảng lịch sử bằng Trigger, em xin đi vào cách SQL Server tự quản lý lịch sử thông qua System-Versioning."

Slide 6 – Giới thiệu System-Versioning (~45 giây)
Ý chính cần truyền đạt
Bảng giá hiện tại chỉ giữ giá mới nhất → các mức giá cũ bị mất nếu không tự lưu lịch sử.
System-Versioning giúp SQL Server tự lưu lịch sử vào một bảng riêng.
Cấu hình gồm 3 bước: thêm cột thời gian, khai báo PERIOD, bật SYSTEM_VERSIONING.
Lời thoại

Ở slide này, em xin giới thiệu System-Versioning.

Hãy nhìn vào ví dụ sản phẩm 101 ở bên phải. Bảng giá hiện tại chỉ có một dòng, giá 30.000 VND. Nhưng thực tế, sản phẩm này đã từng có giá 25.000 ban đầu, rồi tăng lên 27.000, và cuối cùng là 30.000. Nếu ta không tự lưu lịch sử, thì hai mức giá cũ sẽ biến mất khỏi bảng.

Để giải quyết, SQL Server cung cấp System-Versioning. Ở phía bên trái là đoạn lệnh cấu hình. Đầu tiên, ta bật tùy chọn retention cho cơ sở dữ liệu. Tiếp theo, ta thêm hai cột ValidFrom và ValidTo vào bảng ProductPrice_Native, hai cột này do hệ thống tự sinh, đại diện cho thời điểm bản ghi có hiệu lực và thời điểm bản ghi hết hiệu lực. Lưu ý, thời điểm hiệu lực của bản ghi khác với thời điểm thực tế mà thông tin bản ghi có hiệu lực (Business Valid Time) (cho ví dụ)
Sau đó khai báo PERIOD FOR SYSTEM_TIME để chỉ định cặp cột này.

Cuối cùng, ta bật SYSTEM_VERSIONING = ON và chỉ định bảng lịch sử là ProductPrice_NativeHistory, kèm thời gian lưu giữ là INFINITE (vô thời hạn)

Kết quả là mỗi lần giá thay đổi, phiên bản cũ được hệ thống tự động chuyển sang bảng lịch sử, và ta có thể truy vấn lại đầy đủ cả ba mức giá như bảng phía dưới.


Chuyển từ slide 6 sang 7: "Khi lịch sử được lưu tự động, vấn đề tiếp theo là kiểm soát dung lượng, đó chính là vai trò của Retention."


Slide 7 – Giới thiệu về Retention (~50 giây)

Ý chính cần truyền đạt
Retention là cơ chế dọn dẹp các bản ghi lịch sử quá cũ.
Cách xác định "quá cũ": khoảng thời gian từ ValidTo đến hiện tại vượt quá RetentionValue.
Người dùng tự chọn giá trị retention, từ ngắn hạn đến không giới hạn.
Native chạy sẵn, nhưng không mặc định đồng nghĩa với nhanh hơn trigger.

Lời thoại

Sau khi đã lưu lịch sử, một câu hỏi tự nhiên là: lịch sử sẽ phình to mãi sao? Đó là lý do cần Retention. Slide này chia làm ba phần.

Thứ nhất, mục tiêu: retention giúp xóa các bản ghi lịch sử quá cũ, để bảng lịch sử không tăng vô hạn.

Thứ hai, cách xác định: một bản ghi lịch sử bị coi là quá hạn khi khoảng thời gian từ ValidTo đến hiện tại lớn hơn RetentionValue. Nói đơn giản, bản ghi đã hết hạn càng lâu thì càng dễ bị dọn.

Thứ ba, thiết lập: ta chọn RetentionValue tùy nhu cầu, ví dụ 30 ngày, 1 năm, hoặc các mốc khác. Nếu muốn giữ mãi thì đặt INFINITE, tức là không bao giờ xóa.

Thứ tư, SQL Server dọn History bằng tác vụ chạy nền, vì thế các bản ghi đã quá hạn vẫn có thể tồn tại một lúc trước khi bị xóa bởi SQL.

Cuối cùng, cần lưu ý: ta hoàn toàn có thể tự viết trigger để làm việc tương tự, và trigger cũng cho kết quả đúng, nhưng chúng ta phải tự viết và tự bảo trì. Ngược lại, native không đồng nghĩa với luôn nhanh hơn, nên nhóm sẽ đánh giá dựa trên script và kết quả thực nghiệm của bạn Kiệt ở phần sau.


Kết thúc slide 7: “Ở nhánh này, SQL Server lưu phiên bản trước vào History. Hai cột thời gian cho biết hệ thống ghi nhận phiên bản trong khoảng nào. Kiệt sẽ dùng các mốc đó để truy vấn lại giá.”


