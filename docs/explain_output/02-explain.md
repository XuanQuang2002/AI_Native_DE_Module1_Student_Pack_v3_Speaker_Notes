1. Giải thích lý do cần INDEX cho các cột hay dùng trong WHERE / JOIN

Khi cơ sở dữ liệu thực hiện các mệnh đề WHERE hoặc JOIN trên một bảng lớn không có index, hệ thống buộc phải quét toàn bộ bảng (Sequential Scan), kiểm tra từng dòng một từ đầu đến cuối rất tốn thời gian. Việc tạo Index (chỉ mục) sẽ xây dựng một cấu trúc dữ liệu dạng cây B-Tree giúp hệ thống tra cứu trực tiếp đến vị trí của bản ghi một cách cực kỳ nhanh chóng.

Ví dụ từ buổi học: Trong câu lệnh tính doanh thu theo tháng WHERE o.order_date >= '2026-07-01' AND o.order_date < '2026-08-01', cột order_date và cột order_id trong bảng orders và order_items là những ứng viên sáng giá cần đánh index để tối ưu hóa việc lọc theo thời gian và kết nối bảng.

2. So sánh EXPLAIN ANALYZE (Trước và Sau khi tạo Index)

Dưới đây là mô phỏng kết quả thực thi truy vấn tính tổng doanh thu theo khoảng thời gian trước và sau khi đánh index trên cột order_date:

Truy vấn mẫu:
SELECT SUM(oi.quantity \* oi.unit_price) AS total_revenue
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_date >= '2026-07-01' AND o.order_date < '2026-08-01';

- TRƯỚC khi tạo Index (Chưa có Index)
  Kế hoạch thực thi: Seq Scan on orders o (Quét tuần tự toàn bộ bảng orders) và Hash Join kết hợp với bảng order_items.
  Planning Time: 0.125 ms
  Execution Time: 145.230 ms
  Nhận xét: Hệ thống tốn nhiều thời gian đọc từng dòng dữ liệu trên đĩa cứng vì không biết chính xác các đơn hàng tháng 7/2026 nằm ở đâu.

- SAU khi tạo Index
  Lệnh tạo Index:
  CREATE INDEX idx_orders_order_date ON orders(order_date);
  CREATE INDEX idx_order_items_order_id ON order_items(order_id);

Kế hoạch thực thi: Bitmap Index Scan on idx_orders_order_date kết hợp Bitmap Heap Scan, sau đó Nested Loop / Hash Join qua index của bảng order_items.
Planning Time: 0.180 ms
Execution Time: 12.450 ms
Nhận xét: Thời gian thực thi giảm mạnh từ 145.230 ms xuống còn 12.450 ms (nhanh hơn gấp nhiều lần), do cơ sở dữ liệu chỉ truy xuất trực tiếp các trang dữ liệu chứa khoảng thời gian cần tìm thông qua cấu trúc cây của Index.
