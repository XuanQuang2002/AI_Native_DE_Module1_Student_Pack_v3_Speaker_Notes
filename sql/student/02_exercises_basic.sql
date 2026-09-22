-- Buổi 2: 10 business questions
-- TODO 1: Tổng số khách hàng active theo city
select c.city, count(*) as total_customer from customers c
where c.status = 'active'
group by c.city;

-- 1Q1 tất cả orders có total_amount > 100
select *
from orders o
where o.order_total > 100;

-- 1Q2 customers chưa có order nào
select *
from customers c
left join orders o 
on c.customer_id = o.customer_id
where o.order_id is null;

-- 1Q3 top 10 customers theo tổng chi tiêu
select *
from customers c
join orders o 
on c.customer_id = o.customer_id 
order by o.order_total DESC
limit 10;

-- 1Q4 đếm số customers khác nhau có đơn hàng 
SELECT COUNT(DISTINCT c.customer_id) AS total_customers_with_orders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id;

-- 1Q5 5 orders mới nhất theo order_date
select *
from orders o 
order by o.order_date desc 
limit 10;

-- TODO 2: Top 10 sản phẩm có unit_price cao nhất
select *
from products p
order by p.unit_price desc
limit 10;

-- 2Q1 Tổng doanh thu theo từng tháng
select extract(month from o.order_date) as month, sum(oi.quantity * oi.unit_price) as revenue
from orders o
join order_items oi using(order_id)
group by 1
order by 1;

-- 2Q2 Trung bình giá trị đơn hàng theo từng customer
select o.customer_id , round(avg(o.order_total),2) as avg_amount
from orders o
group by o.customer_id;

-- 2Q3 Số lượng đơn hàng theo từng order_status
select o.status , sum(o.order_total) as total_status_order
from orders o
group by o.status;

-- 2Q4 Tổng doanh thu theo category
select c.category_name,
	sum(oi.quantity * oi.unit_price - oi.discount_amount) as revenue
from order_items oi 
join products p using(product_id)
join categories c using(category_id)
group by c.category_id
order by revenue DESC;

-- 2Q5 categories có tổng doanh thu > 1000
select c.category_name,
	sum(oi.quantity * oi.unit_price - oi.discount_amount) as revenue
from order_items oi 
join products p using(product_id)
join categories c using(category_id)
group by c.category_id
having sum(oi.quantity * oi.unit_price - oi.discount_amount) > 40000000
order by revenue desc;

-- 3Q1 Liệt kê orders kèm customer_name, customer_email 
select c.full_name , c.email, o.*
from orders o 
join customers c using(customer_id);

-- 3Q2 Chi tiết từng order_item kèm product_name, price
select p.product_name, oi.*
from order_items oi 
join products p using(product_id);

-- 3Q3 Orders có payments nhưng chưa có order_items (hoặc ngược lại) - dùng LEFT JOIN + IS NULL 1 phía.
select *
from orders o
left join payments p on o.order_id = p.order_id
left join order_items oi on o.order_id = oi.order_id
where (p.payment_id is null and oi.order_id is not null)
   or (oi.order_id is null and p.payment_id is not null);

-- 3Q4 Products chưa từng được bán
select p.*
from products p
left join order_items oi on p.product_id = oi.product_id
where oi.product_id is null;

-- 3Q5 Đối soát: total order value = SUM(order_items quantity*price) theo từng order (GROUP BY order_id), so với orders.total_amount
select 
    o.order_id,
    o.order_total AS orders_total,
    coalesce(sum(oi.quantity * oi.unit_price), 0) AS calculated_total,
    (o.order_total - coalesce(sum(oi.quantity * oi.unit_price), 0)) AS difference
from orders o
left join order_items oi on o.order_id = oi.order_id
group by o.order_id, o.order_total
having o.order_total <> coalesce(sum(oi.quantity * oi.unit_price), 0);

-- 4Q1 Total revenue tháng 7/2026 là bao nhiêu?
select sum(oi.quantity * oi.unit_price) as total_revenue
from order_items oi
join orders o on o.order_id = oi.order_id
where o.order_date >= '2026-06-01' 
  and o.order_date < '2026-07-01';

-- 4Q2 Customer nào có tổng chi tiêu cao nhất (id + tên + số tiền)
select 
    c.customer_id, 
    c.full_name ,
    SUM(oi.quantity * oi.unit_price) AS total_spent
from customers c
join orders o ON c.customer_id = o.customer_id
join order_items oi ON o.order_id = oi.order_id
group by c.customer_id, c.full_name
order by total_spent desc
limit 1;

-- 4Q3 Category nào có số lượng orders cao nhất?
select
    cat.category_id,
    cat.category_name,
    COUNT(distinct o.order_id) AS total_orders
from categories cat
join products p on cat.category_id = p.category_id
join order_items oi on p.product_id = oi.product_id
join orders o on oi.order_id = o.order_id
group by cat.category_id, cat.category_name
order by total_orders desc
limit 1;

-- 4Q4 Average order value (AOV) là bao nhiêu
select 
    sum(oi.quantity * oi.unit_price) / count(distinct o.order_id) as average_order_value
from orders o
join order_items oi on o.order_id = oi.order_id;

-- 4Q5 Có bao nhiêu customers có hơn 3 orders?
select count(*) as number_of_customers
from (
    select c.customer_id
    from customers c
    join orders o on c.customer_id = o.customer_id
    group by c.customer_id
    having COUNT(o.order_id) > 3
) as filtered_customers;

-- AD1 Query cumulative revenue theo thời gian (SUM(revenue) OVER (ORDER BY month))
with monthly_revenue as (
    select 
        date_trunc('month', o.order_date)::date as month,
        sum(oi.quantity * oi.unit_price) as revenue
    from orders o
    join order_items oi on o.order_id = oi.order_id
    group by date_trunc('month', o.order_date)::date
)
select 
    month,
    revenue as monthly_revenue,
    SUM(revenue) over (order by month) as cumulative_revenue
from monthly_revenue
order by month;

-- TODO 3: Số đơn theo ngày và status
-- TODO 4: Revenue/AOV của completed orders theo tháng
-- TODO 5: Revenue theo category
-- TODO 6: Top 10 customers theo revenue
-- TODO 7: Top 10 products theo quantity
-- TODO 8: Payment success rate
-- TODO 9: Revenue theo channel
-- TODO 10: Đối soát SUM(order_total) với tổng item net amount
