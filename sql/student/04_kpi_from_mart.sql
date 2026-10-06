-- KPI 1
select
	dd.month_name,
	sum(t.unit_price * t.quantity - t.discount_amount)
from mart.fact_sales t
join mart.dim_date dd on t.date_key = dd.date_key 
group by dd.month_name;

-- KPI 2
select
	dp.category_name,
	sum(t.unit_price * t.quantity - t.discount_amount)
from mart.fact_sales t
join mart.dim_product dp on t.product_sk = dp.product_sk
group by dp.category_name;

-- KPI 3
select
	dp.product_name,
	sum(t.unit_price * t.quantity - t.discount_amount) as total_product_revenue
from mart.fact_sales t
join mart.dim_product dp on t.product_sk = dp.product_sk
group by dp.product_name
order by total_product_revenue desc;

-- KPI 4
select 
	SUM(t.unit_price * t.quantity - t.discount_amount)/count(distinct t.order_id) as AOV
from mart.fact_sales t;

-- KPI 5
select
	dc.customer_segment,
	count(t.customer_sk)
from mart.fact_sales t
join mart.dim_customer dc on t.customer_sk = dc.customer_sk
group by dc.customer_segment;

select
	dos.order_status,
	count(t.order_status_sk)
from mart.fact_sales t
join mart.dim_order_status dos on dos.order_status_sk = t.order_status_sk
group by dos.order_status 