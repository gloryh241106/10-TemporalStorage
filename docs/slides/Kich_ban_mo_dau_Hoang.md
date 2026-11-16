# Kịch bản mở đầu của Hoàng

Dùng slide **01 → 02 → 04** trong [bản slide mở đầu](Slides_mo_dau_Hoang.pptx). Hoàng có khoảng 3 phút, gồm 40 giây cho ví dụ bảng thường. Giữ slide 03 làm hình giải thích cho phần Native của Trung khi ghép deck chung. Đánh lại số slide ở bản ghép.

| Slide | Cách trình bày | Lời dẫn gợi ý |
|---|---|---|
| 01 – Khi giá thay đổi, dữ liệu quá khứ ở đâu? (45 giây) | Chỉ vào giá hiện tại 30.000đ, rồi chỉ lại hai giá trước. Các mốc T1, T2, T3 trên hình là mốc minh họa. Sau slide này, cho xem kết quả UPDATE bảng thường bên dưới. | “Giả sử quán đã đổi giá cà phê sữa đá hai lần và hôm nay đang bán 30.000 đồng. Nếu mình chỉ có cột giá hiện tại thì nhìn vào bảng cũng không biết lần trước quán bán 25.000 hay 27.000. Vậy mình cần lưu gì để trả lời được câu đó?” |
| 02 – Hai cách giữ lịch sử (50 giây) | Chỉ vào hai cột trên slide. Giữ phần cú pháp cho các bạn phụ trách. | “Cách thứ nhất là nhóm tự viết trigger để đưa dòng cũ vào bảng lịch sử. Cách thứ hai là bật system-versioning để SQL Server quản lý các phiên bản. Cả hai đều có thể giữ giá cũ. Nhóm sẽ xem mỗi cách cần tự viết và bảo trì những phần nào.” |
| 04 – Cùng dữ liệu, hai nhánh so sánh (45 giây) | Chỉ bảng Product chung và hai nhánh. Nêu sản phẩm 105 chỉ có trong danh mục để dùng cho ca INSERT. | “Để so sánh công bằng, hai nhánh bắt đầu từ cùng một bộ dữ liệu: năm sản phẩm và bốn dòng giá mỗi bên. Hai nhánh thử cùng các thay đổi, rồi Kiệt đối chiếu kết quả. Trước hết, Thùy sẽ trình bày cách nhóm tự lưu lịch sử bằng trigger.” |

Sau slide 01, dành khoảng 40 giây để chiếu kết quả của [script bảng thường](../../sql/00_setup/02_demo_current_only.sql). Chạy trước cả file trong SSMS trên một database thử đã chạy setup và [T0](../../sql/00_setup/01_verify_setup.sql):

1. Chỉ hai bảng kết quả: `Before UPDATE` là **25.000 VND** và `After UPDATE` là **27.000 VND** cho sản phẩm 101. Giải thích rằng hàng thứ nhất là kết quả SELECT trước khi sửa. Sau UPDATE, bảng tạm chỉ còn hàng giá 27.000 VND.
2. Nói câu chuyển: “Nếu sau khi đổi giá mình mới nhận câu hỏi ‘trước lúc sửa giá là bao nhiêu?’, bảng này không trả lời được. Bây giờ thử lại cùng tình huống với một bảng có lưu lịch sử.”
3. Quay lại slide 02, rồi chuyển cho Thùy sau slide 04. Ví dụ đã chạy trên bảng tạm, nên dữ liệu R0 ở hai bảng giá vẫn nguyên. Nếu có trục trặc khi trình chiếu, dùng [log chạy thật](../../evidence/G1_V4_sqlcmd.txt) ở mục “TV1 ordinary table example”.

Khi cả nhóm bắt đầu 10 phút demo chung, Hoàng dành phút đầu để hiện phiên bản SQL Server và chỉ giá R0 của sản phẩm 101 ở cả hai nhánh. Sau đó chuyển sang lần UPDATE đầu trên hai nhánh theo [kịch bản nhóm](https://docs.google.com/document/d/1mPEMmDRuefvWg4WnW67O9pyIm1HDXP-jaOmJqN2wasI/edit?tab=t.0).
