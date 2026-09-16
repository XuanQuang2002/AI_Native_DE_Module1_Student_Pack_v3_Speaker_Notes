1. Khó khăn khi cài Docker/DBeaver và cách bạn xử lý?

- Trong buổi thực hành, khó khăn lớn nhất là ở bước cài đặt môi trường và khởi tạo database từ dbdiagram. Cụ thể, khi cài Docker, máy báo lỗi do chưa bật tính năng virtualization trong BIOS, còn DBeaver thì ban đầu không kết nối được vì sai cổng hoặc chưa có driver JDBC phù hợp. Ngoài ra, việc export schema từ dbdiagram sang SQL rồi chạy trên PostgreSQL cũng gặp một số lỗi cú pháp nhỏ do khác biệt phiên bản.

- Cách xử lý là chủ động tìm tài liệu chính thống từ trang docs của Docker và DBeaver, đồng thời tra cứu thông báo lỗi cụ thể trên Stack Overflow. Ngoài ra, nhờ bạn bè trong nhóm hỗ trợ kiểm tra lại từng bước cũng giúp phát hiện ra những lỗi nhỏ bị bỏ sót. Qua đó, mình rút ra được bài học: đọc kỹ thông báo lỗi thay vì bỏ qua, vì phần lớn lỗi đều có gợi ý nguyên nhân ngay trong dòng log.

2. Vì sao chọn data type như vậy cho tiền tệ / thời gian / ID? Cho 1 ví dụ cụ thể.

- Việc chọn đúng kiểu dữ liệu ảnh hưởng trực tiếp đến độ chính xác, hiệu năng và tính nhất quán của hệ thống.

* Tiền tệ chọn NUMERIC(10, 2) để lưu chính xác tuyệt đối, không bị lỗi làm tròn như FLOAT
* Thời gian chọn TIMESTAMPTZ để lưu kèm múi giờ, tránh sai lệch khi hệ thống chạy đa vùng
* ID chọn SERIAL đê tự động tăng, không cần xử lý thủ công, đảm bảo tính duy nhất

Ví dụ cụ thể: Trong bảng payments, cột amount NUMERIC(10, 2) lưu giá trị 1,250,000.50 VNĐ. Nếu dùng FLOAT, kết quả có thể trở thành 1250000.4999999... do lỗi dấu phẩy động – điều này rất nguy hiểm trong bài toán tài chính. Tương tự, cột created_at TIMESTAMPTZ khi lưu 2025-06-01 08:30:00+07 sẽ tự quy đổi về UTC bên trong, giúp so sánh thời gian chính xác dù người dùng ở các múi giờ khác nhau.

3. Hiểu thế nào về quan hệ 1:N giữa customers và orders? Vẽ/kể ví dụ 1
   customer có N orders.

Quan hệ 1:N (một-nhiều) có nghĩa là một bản ghi ở bảng cha có thể liên kết với nhiều bản ghi ở bảng con, nhưng chiều ngược lại thì không – mỗi bản ghi con chỉ thuộc về đúng một bản ghi cha.

customers
┌─────────────────────────────┐
│ customer_id │ name │
│ 1 │ Nguyễn Văn A │
└─────────────────────────────┘
│
┌─────────┼──────────┐
▼ ▼ ▼
orders
┌──────────────────────────────────────────┐
│ order_id │ customer_id │ total_amount │
│ 101 │ 1 │ 500,000 │
│ 102 │ 1 │ 1,200,000 │
│ 103 │ 1 │ 750,000 │
└──────────────────────────────────────────┘

Khách hàng Nguyễn Văn A (customer_id = 1) có 3 đơn hàng khác nhau. Trong bảng orders, cột customer_id đóng vai trò Foreign Key trỏ về customers(customer_id), đảm bảo không thể tạo đơn hàng cho khách hàng không tồn tại.

4. Nếu schema cần sửa sau này (thêm cột, đổi FK), bạn sẽ xử lý thế nào (ALTER
   vs tạo lại)?

Khi cần thay đổi schema trên hệ thống đang chạy, nguyên tắc quan trọng nhất là không được xóa và tạo lại bảng nếu đã có dữ liệu thật, vì sẽ gây mất toàn bộ dữ liệu. Thay vào đó, nên dùng lệnh ALTER TABLE.

VD:
-- Thêm cột mới
ALTER TABLE orders ADD COLUMN note TEXT;

-- Đổi kiểu dữ liệu
ALTER TABLE orders ALTER COLUMN total_amount TYPE NUMERIC(18, 2);

-- Thêm Foreign Key mới
ALTER TABLE orders
ADD COLUMN promo_id INT,
ADD CONSTRAINT fk_promo
FOREIGN KEY (promo_id) REFERENCES promotions(promo_id);

-- Đặt lại tên cột
ALTER TABLE customers RENAME COLUMN phone TO phone_number;

Khi nào mới cân nhắc tạo lại bảng? Chỉ trong giai đoạn phát triển ban đầu (chưa có dữ liệu thật) hoặc khi thay đổi quá lớn mà ALTER không đáp ứng được – và lúc đó phải backup dữ liệu trước, migrate sang bảng mới, rồi mới xóa bảng cũ.

Từ đó rút ra: Thiết kế schema cẩn thận từ đầu sẽ giảm thiểu việc phải ALTER về sau. Nhưng nếu bắt buộc phải sửa, ALTER TABLE là công cụ an toàn và nên được ưu tiên.
