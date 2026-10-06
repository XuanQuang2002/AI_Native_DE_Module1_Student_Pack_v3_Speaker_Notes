-- Buổi 4
-- TODO: Xác định grain trước khi viết DDL.
-- TODO: Tạo dim_date, dim_customer, dim_product, dim_payment_method, dim_order_status.
-- TODO: Tạo fact_sales và script load.
-- TODO: Viết 5 query đối soát OLTP ↔ Data Mart.

-- GRAIN: one row per order_item
/*
 * Giữ nguyên chi tiết tối đa: 
 * Đảm bảo không làm thất thoát dữ liệu gốc về sản phẩm, 
 * số lượng, đơn giá hay số tiền giảm giá của từng dòng hàng.
 * 
 * Linh hoạt phân tích đa chiều: 
 * Cho phép kết hợp sâu và chính xác giữa các chiều dữ liệu 
 * (sản phẩm, danh mục, thời gian, khách hàng) mà không bị giới hạn.
 * 
 * Dễ dàng tổng hợp (Roll-up): 
 * Từ mức chi tiết này, hệ thống có thể dễ dàng cộng dồn lên các cấp độ cao hơn 
 * (cấp đơn hàng, cấp khách hàng, cấp tháng) khi cần thiết.
*/

CREATE SCHEMA IF NOT EXISTS mart;

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'mart';

-- =========================================================================
-- 1. DIMENSION: dim_date
-- =========================================================================
CREATE TABLE IF NOT EXISTS mart.dim_date (
    date_key INTEGER PRIMARY KEY, -- khoa chinh dang YYYYMMDD
    full_date DATE NOT NULL UNIQUE, -- Ngay thuc te, unique de 1 ngay chi co 1 ban ghi
    day_of_month SMALLINT NOT NULL, -- ngay trong thang
    month_num SMALLINT NOT NULL, -- thang 1-12
    month_name VARCHAR(20) NOT NULL, -- ten thang
    quarter_num SMALLINT NOT NULL, -- quy 1-4
    year_num SMALLINT NOT NULL, -- nam
    is_weekend BOOLEAN NOT null -- True neu thu 7/chu nhat
);

COMMENT ON TABLE mart.dim_date IS 'Business Logic: Bảng chiều thời gian (Calendar Dimension) phục vụ phân tích xu hướng, doanh thu theo thời gian và tính toán Cohort. 
Source: Sinh tự động từ dải ngày (Date Spine) của hệ thống. 
Transformation: Trích xuất các thuộc tính thời gian từ cột ngày chuẩn (Extract Year, Month, Day, Quarter, xác định ngày cuối tuần Is_Weekend).';


-- =========================================================================
-- 2. DIMENSION: dim_customer
-- =========================================================================
CREATE TABLE IF NOT EXISTS mart.dim_customer (
    customer_sk BIGSERIAL PRIMARY KEY, -- surrogate key dung BIGSERIAL de PostgreSQL tang dan
    customer_id VARCHAR(12) NOT NULL UNIQUE, -- natural key tu bang customers, unique de ko bi trung
    full_name VARCHAR(150) NOT NULL, -- ten day du
    city VARCHAR(100), -- ten thanh pho
    customer_segment VARCHAR(30), -- loai khach hang
    status VARCHAR(20) -- trang thai khach hang
);

COMMENT ON TABLE mart.dim_customer IS 'Business Logic: Lưu trữ thông tin chi tiết và phân khúc của khách hàng. 
Source: Bảng `raw_customers` hoặc `staging_customers`. 
Transformation: Giữ nguyên khóa tự nhiên `customer_id`, làm sạch tên khách hàng, ánh xạ thông tin thành phố, phân khúc (`customer_segment`) và trạng thái tài khoản.';


-- =========================================================================
-- 3. DIMENSION: dim_product
-- =========================================================================
CREATE TABLE IF NOT EXISTS mart.dim_product (
    product_sk BIGSERIAL PRIMARY KEY, -- surrogate keydung trong fact
    product_id VARCHAR(12) NOT NULL UNIQUE, -- natural key tu bang products
    product_name VARCHAR(200) NOT NULL, -- ten san pham
    category_id VARCHAR(10),-- chu dong dua thong tin vao
    category_name VARCHAR(120) -- ten loai san pham
);

COMMENT ON TABLE mart.dim_product IS 'Business Logic: Quản lý danh mục sản phẩm phục vụ phân tích doanh thu theo ngành hàng. 
Source: Kết hợp từ bảng `raw_products` và `raw_categories`. 
Transformation: Thực hiện lệnh JOIN giữa sản phẩm và danh mục tương ứng để đồng bộ `category_id` và `category_name`, sinh `product_sk` làm khóa surrogate cho Fact.';


-- =========================================================================
-- 4. DIMENSION: dim_payment_method
-- =========================================================================
CREATE TABLE IF NOT EXISTS mart.dim_payment_method (
    payment_method_sk SMALLSERIAL PRIMARY KEY, -- surrogate key payment method
    payment_method VARCHAR(30) NOT NULL unique -- ten payment method
);

COMMENT ON TABLE mart.dim_payment_method IS 'Business Logic: Bảng chiều phương thức thanh toán (COD, Chuyển khoản, Thẻ...). 
Source: Trích xuất các giá trị duy nhất từ cột `payment_method` trong bảng đơn hàng gốc (`raw_orders`). 
Transformation: Dùng lệnh `SELECT DISTINCT` để lọc ra các phương thức thanh toán hợp lệ và sinh khóa surrogate tương ứng.';


-- =========================================================================
-- 5. DIMENSION: dim_order_status
-- =========================================================================
CREATE TABLE IF NOT EXISTS mart.dim_order_status (
    order_status_sk SMALLSERIAL PRIMARY KEY, -- surrogate key order status
    order_status VARCHAR(20) NOT NULL unique -- ten order status
);

COMMENT ON TABLE mart.dim_order_status IS 'Business Logic: Quản lý các trạng thái đơn hàng (completed, cancelled, pending...). 
Source: Trích xuất các giá trị duy nhất từ cột `status` trong bảng `raw_orders`. 
Transformation: Lọc danh mục trạng thái độc lập (`SELECT DISTINCT status`) để phân tích tỷ lệ hoàn thành hoặc hủy đơn.';


-- =========================================================================
-- 6. FACT: fact_sales
-- =========================================================================
CREATE TABLE IF NOT EXISTS mart.fact_sales (
    sales_key BIGSERIAL PRIMARY KEY, -- surrogate PK cua fact
    order_item_id VARCHAR(16) NOT NULL UNIQUE, -- key chinh trong bang binh thuong
    order_id VARCHAR(12) NOT NULL, -- Giu lai COUNT(DISTINCT order_id) va trace ve giao dich nguon
    date_key INTEGER NOT null REFERENCES mart.dim_date(date_key),
    customer_sk BIGINT NOT NULL
        REFERENCES mart.dim_customer(customer_sk),
    product_sk BIGINT NOT NULL
        REFERENCES mart.dim_product(product_sk),
    payment_method_sk SMALLINT
        REFERENCES mart.dim_payment_method(payment_method_sk),
    order_status_sk SMALLINT NOT NULL
        REFERENCES mart.dim_order_status(order_status_sk),
    quantity INTEGER NOT NULL, -- additive measure
    unit_price NUMERIC(14,2) NOT NULL,
    discount_amount NUMERIC(14,2) NOT NULL, -- tong gia cua itek
    gross_amount NUMERIC(14,2) NOT NULL, -- gross_amount quantity * unit_price
    net_amount NUMERIC(14,2) NOT null -- gross_amount - discount_amount
);

COMMENT ON TABLE mart.fact_sales IS 'Business Logic: Bảng sự kiện trung tâm (Fact Table) ghi nhận chi tiết từng dòng sản phẩm trong đơn hàng (Grain: One row per order_item). 
Source: Tích hợp từ bảng nguồn `raw_order_items`, `raw_orders` kết hợp lookup sang các bảng Dimension (`dim_date`, `dim_customer`, `dim_product`, `dim_payment_method`, `dim_order_status`).
Transformation: 
- Map các khóa ngoại thông qua Surrogate Key của các Dimension.
- Tính toán các chỉ số đo lường (Measures):
  + gross_amount = quantity * unit_price (Thành tiền trước giảm giá)
  + net_amount = gross_amount - discount_amount (Doanh thu thực nhận)';

  -- LOAD dim_date
WITH date_bounds AS (
    -- Lấy mốc ngày nhỏ nhất và lớn nhất từ bảng orders nguồn (OLTP)
    SELECT 
        MIN(order_date)::date AS min_date,
        MAX(order_date)::date AS max_date
    FROM core.orders -- Thay đổi tên schema/bảng nếu cần (ví dụ: core.orders)
)
INSERT INTO mart.dim_date(
    date_key,
    full_date,
    day_of_month,
    month_num,
    month_name,
    quarter_num,
    year_num,
    is_weekend
)
SELECT
    to_char(d,'YYYYMMDD')::int,
    d::date,
    extract(day from d),
    extract(month from d),
    trim(to_char(d,'Month')),
    extract(quarter from d),
    extract(year from d),
    extract(isodow from d) IN (6,7)
FROM date_bounds,
     generate_series(
         -- Dùng COALESCE để phòng hờ trường hợp bảng orders bị trống (tránh lỗi NULL)
         COALESCE(date_bounds.min_date, '2025-01-01'::date),
         COALESCE(date_bounds.max_date, '2027-12-31'::date),
         '1 day'::interval
     ) d
ON CONFLICT (date_key) DO NOTHING;

SELECT COUNT(*) FROM mart.dim_date;

SELECT *
FROM mart.dim_date
WHERE full_date = DATE '2026-09-24';

-- LOAD customer
INSERT INTO mart.dim_customer(
    customer_id,
    full_name,
    city,
    customer_segment,
    status
)
SELECT
    customer_id,
    full_name,
    city,
    customer_segment,
    status
FROM core.customers;

SELECT COUNT(*) FROM mart.dim_customer;

SELECT *
FROM mart.dim_customer
ORDER BY customer_sk
LIMIT 10;


-- LOAD product
INSERT INTO mart.dim_product(
    product_id,
    product_name,
    category_id,
    category_name
)
SELECT
    p.product_id,
    p.product_name,
    p.category_id,
    c.category_name
FROM core.products p
JOIN core.categories c
USING(category_id);

SELECT COUNT(*) FROM mart.dim_product;

SELECT *
FROM mart.dim_product
ORDER BY product_sk
LIMIT 10;

-- LOAD PAYMENT METHOD
INSERT INTO mart.dim_payment_method(payment_method)
VALUES
    ('cash'),
    ('bank_transfer'),
    ('card'),
    ('e_wallet')
ON CONFLICT DO NOTHING;

--LOAD ORDER STATUS
INSERT INTO mart.dim_order_status(order_status)
VALUES
    ('pending'),
    ('confirmed'),
    ('shipped'),
    ('completed'),
    ('cancelled')
ON CONFLICT DO NOTHING;

SELECT * FROM mart.dim_payment_method ORDER BY payment_method_sk;

SELECT * FROM mart.dim_order_status ORDER BY order_status_sk;

-- LOAD FACT_SALE
INSERT INTO mart.fact_sales(
    order_item_id,
    order_id,
    date_key,
    customer_sk,
    product_sk,
    payment_method_sk,
    order_status_sk,
    quantity,
    unit_price,
    discount_amount,
    gross_amount,
    net_amount
)
SELECT
    oi.order_item_id,
    o.order_id,
    to_char(o.order_date,'YYYYMMDD')::int,
    dc.customer_sk,
    dp.product_sk,
    dpm.payment_method_sk,
    dos.order_status_sk,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.quantity * oi.unit_price AS gross_amount,
    oi.quantity * oi.unit_price
        - oi.discount_amount AS net_amount
FROM core.order_items oi
JOIN core.orders o
USING(order_id)
JOIN mart.dim_customer dc
ON dc.customer_id = o.customer_id
JOIN mart.dim_product dp
ON dp.product_id = oi.product_id
JOIN mart.dim_order_status dos
ON dos.order_status = o.status
LEFT JOIN LATERAL (
    SELECT payment_method
    FROM core.payments p
    WHERE p.order_id = o.order_id
    ORDER BY payment_date DESC
    LIMIT 1
) lp
ON true
LEFT JOIN mart.dim_payment_method dpm
ON dpm.payment_method = lp.payment_method
ON CONFLICT (order_item_id) DO NOTHING;