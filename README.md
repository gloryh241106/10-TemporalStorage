# 10-TemporalStorage

Đồ án lý thuyết CSC12003, Nhóm 10, Chủ đề 8. Nhóm dùng cùng một bộ giá mẫu để đối chiếu History tự xây bằng trigger và Temporal native trên SQL Server 2025.

## Chạy G1 trên SQL Server 2025

1. Kết nối bằng SSMS vào instance thử nghiệm. Dùng `TemporalSeminarDB` mới hoặc trống. Nếu tên này đã có dữ liệu, chọn instance thử khác hoặc dùng một tên database mới nhất quán trong các script.
2. Chạy [`00_create_and_seed.sql`](sql/00_setup/00_create_and_seed.sql), rồi chạy [`01_verify_setup.sql`](sql/00_setup/01_verify_setup.sql) để kiểm tra T0 trước G2. Kết quả cần có `PASS G1 / T0 - Baseline V4`, 5 sản phẩm, 4 giá mỗi nhánh và sản phẩm 105 chưa có giá.
3. Chạy [`02_demo_current_only.sql`](sql/00_setup/02_demo_current_only.sql) để minh họa UPDATE trên một bảng tạm thông thường. Giá mẫu ở hai bảng G1 vẫn là R0.

G1 đã chốt; nhóm đang ở G2. Thùy và Trung soạn script song song theo [hợp đồng V4](docs/planning/02_team_data_contract.md) và [bàn giao G2](docs/planning/06_G2_handoff.md). Mỗi nhánh chạy riêng sau T0 và bàn giao script cài đặt cùng kết quả thử UPDATE. Kiệt chuẩn bị kỳ vọng từ G1 và đối chứng sau khi có đủ hai nhánh. Hoàng chuẩn bị báo cáo và slide mở đầu trong thời gian đó, rồi ghép kết quả G3 vào hồ sơ cuối.

[Quy ước đã chốt và bảng tiến độ](https://docs.google.com/document/d/1mPEMmDRuefvWg4WnW67O9pyIm1HDXP-jaOmJqN2wasI/edit?tab=t.0) · [Kết quả chạy G1 trên SQL Server 2025](evidence/G1_V4_sqlcmd.txt) · [Chạy lại T0 ngày 13/11](evidence/G1_V4_T0_rerun_20261113.txt)

[Slide mở đầu của Hoàng](docs/slides/Slides_mo_dau_Hoang.pptx) · [Lời dẫn và cách chạy demo mở đầu](docs/slides/Kich_ban_mo_dau_Hoang.md)
