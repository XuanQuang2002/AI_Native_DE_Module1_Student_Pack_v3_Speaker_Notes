-- Buổi 3
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

-- AD2 Tỷ trọng doanh thu từng category (revenue / SUM(revenue) OVER () * 100)
with category_revenue as (
    select 
        c.category_id,
        c.category_name,
        sum(oi.quantity * oi.unit_price) as revenue
    from categories c
    join products p on c.category_id = p.category_id
    join order_items oi on p.product_id = oi.product_id
    group by c.category_id, c.category_name
)
select 
    category_id,
    category_name,
    revenue,
    round((revenue / sum(revenue) over ()) * 100, 2) as revenue_percentage
from category_revenue
order by revenue desc;

-- AD3 Tìm customers "churn" (không có order trong 30 ngày qua so với MAX(order_date))
with max_system_date as (
    select max(order_date) as latest_date
    from orders
),
customer_last_order as (
    select 
        c.customer_id,
        c.full_name,
        max(o.order_date) AS last_order_date
    from customers c
    join orders o ON c.customer_id = o.customer_id
    group by c.customer_id, c.full_name
)
select
    clo.customer_id,
    clo.full_name,
    clo.last_order_date
from customer_last_order clo
cross join max_system_date msd
where clo.last_order_date < (msd.latest_date - interval '30 days')
order by clo.last_order_date ASC;

-- TODO 1: Refactor business report bằng CTE nhiều bước.
-- TODO 2: Running revenue theo ngày.
-- TODO 3: DENSE_RANK product trong từng category.
-- TODO 4: first_purchase, recency, frequency, monetary.
-- TODO 5: cohort_month × activity_month.
