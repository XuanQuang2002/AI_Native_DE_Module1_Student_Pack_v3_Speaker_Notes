-- CTE 1
with total_spending as (
	select c.customer_id , SUM(oi.unit_price * oi.quantity) as total_spend
	from customers c
	join orders o on o.customer_id = c.customer_id
	join order_items oi on oi.order_id = o.order_id 
	group by c.customer_id
)
select *
from total_spending ts
order by ts.total_spend desc
limit 10;

-- CTE 2
with total_spend_tier as (
	select 
		c.customer_id, 
		c.customer_id, 
		SUM(oi.unit_price * oi.quantity) as total_spend,
		case
			when SUM(oi.unit_price * oi.quantity) > 200000000 then 'High'
			when SUM(oi.unit_price * oi.quantity) <= 200000000 and SUM(oi.unit_price * oi.quantity) > 50000000 then 'Medium'
			else 'Low'
		end
	from customers c
	join orders o on o.customer_id = c.customer_id
	join order_items oi on oi.order_id = o.order_id
	group by c.customer_id
)
select *
from total_spend_tier tpt
order by tpt.total_spend desc;


-- CTE 3
with orders_per_customer as (
	select c.customer_id, count(o.order_id) as total_orders
	from customers c
	join orders o using(customer_id)
	group by c.customer_id
),
customer_stats as (
	select max(opc.total_orders) as max_total_orders, avg(opc.total_orders) as avg_total_orders
	from orders_per_customer opc
)
select *
from customer_stats;

-- CTE 4
with customer_summary as(
	select 
		o.customer_id,
		SUM(oi.quantity * oi.unit_price) as total_spending,
		count(*) as order_count
	from order_items oi
	join orders o using (order_id)
	group by o.customer_id
)
select *,
	case 
		when cs.order_count > 0 then cs.total_spending / cs.order_count
		else 0
	end as aov
from customer_summary cs;

-- CTE 5 
with cohort_table as (
	select
		c.customer_id,
		date_trunc('month', min(order_date)) as first_order_month
	from customers c
	join orders o using (customer_id)
	group by c.customer_id
),
subsequent_orders as (
	select 
		o.customer_id,
		ct.first_order_month,
		date_trunc('month', o.order_date) as order_month
	from orders o
	join cohort_table ct on o.customer_id = ct.customer_id
)
select 
	first_order_month,
	order_month,
	count(distinct customer_id) as returning_customer
from subsequent_orders
group by first_order_month , order_month;

-- Window Function 1
with total_spending as (
	select c.customer_id , SUM(oi.unit_price * oi.quantity) as total_spend
	from customers c
	join orders o on o.customer_id = c.customer_id
	join order_items oi on oi.order_id = o.order_id 
	group by c.customer_id
)
select *, ROW_NUMBER() OVER (ORDER BY total_spend DESC) as ranking
from total_spending;

-- Window Function 2
with total_spending as (
	select c.customer_id , SUM(oi.unit_price * oi.quantity) as total_spend
	from customers c
	join orders o on o.customer_id = c.customer_id
	join order_items oi on oi.order_id = o.order_id 
	group by c.customer_id
)
select *, DENSE_RANK() OVER (ORDER BY total_spend DESC) as ranking
from total_spending;

with total_spending as (
	select c.customer_id , SUM(oi.unit_price * oi.quantity) as total_spend
	from customers c
	join orders o on o.customer_id = c.customer_id
	join order_items oi on oi.order_id = o.order_id 
	group by c.customer_id
)
select *, RANK() OVER (ORDER BY total_spend DESC) as ranking
from total_spending;


-- Window Function 3
WITH ranked_orders AS (
    SELECT 
        customer_id,
        order_id,
        order_total,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_sequence
    FROM 
        orders
),
filtered_orders AS (
    SELECT 
        customer_id,
        order_id,
        order_total,
        order_sequence
    FROM 
        ranked_orders
),
customer_summary AS (
    SELECT 
        customer_id,
        SUM(order_total) AS total_spending,
        COUNT(order_id) AS order_count,
        MAX(order_sequence) AS max_sequence
    FROM 
        filtered_orders
    GROUP BY 
        customer_id
)
SELECT 
    customer_id,
    total_spending,
    order_count,
    CASE 
        WHEN order_count > 0 THEN total_spending / order_count 
        ELSE 0 
    END AS aov
FROM 
    customer_summary;

-- Window Funtion 4
WITH order_comparison AS (
    SELECT 
        customer_id,
        order_id,
        order_date,
        order_total,
        LAG(order_total, 1) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_amount,
        LEAD(order_total, 1) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order_amount
    FROM 
        orders
)
SELECT 
    customer_id,
    order_id,
    order_date,
    order_total,
    prev_order_amount,
    order_total - prev_order_amount AS diff_from_prev,
    CASE 
        WHEN prev_order_amount > 0 THEN ROUND((order_total - prev_order_amount) * 100.0 / prev_order_amount, 2)
        ELSE NULL 
    END AS percent_change_from_prev
FROM 
    order_comparison;

-- window function 5
WITH customer_running_total AS (
    SELECT 
        customer_id,
        order_id,
        order_date,
        order_total,
        SUM(order_total) OVER (
            PARTITION BY customer_id 
            ORDER BY order_date, order_id
        ) AS running_revenue_per_customer
    FROM 
        orders
)
SELECT * 
FROM customer_running_total;


-- 1.3
select 
	o.customer_id,
	extract(day from (now() - max(o.order_date))) as recency_days,
	count(o.order_id) as frequecy,
	sum(o.order_total) as monetary
from orders o
group by o.customer_id
order by monetary desc;

-- 1.4 cohort analysis
with cohort_setup as (
    select o.customer_id,
        date_trunc('month', MIN(o.order_date)) as cohort_month
    from orders o
    where o.status = 'completed'
    group by o.customer_id
),
cohort_activity as (
    select 
        c.cohort_month,
        o.customer_id,
        (EXTRACT(YEAR FROM o.order_date) * 12 + EXTRACT(MONTH FROM o.order_date))
      - (EXTRACT(YEAR FROM c.cohort_month) * 12 + EXTRACT(MONTH FROM c.cohort_month)) AS month_no
    from orders o
    join cohort_setup c on o.customer_id = c.customer_id
    where o.status = 'completed'
),
cohort_counts as (
    select 
        cohort_month,
        month_no,
        count(distinct customer_id) as active_customers
    from cohort_activity
    group by cohort_month, month_no
),
cohort_sizes as (
    select cohort_month, active_customers as initial_size
    from cohort_counts where month_no = 0
)
select 
    cc.cohort_month,
    max(cs.initial_size) as M0_customers,
    -- Tính % retention cho từng tháng tiếp theo (Ví dụ đến M3)
    ROUND(MAX(CASE WHEN cc.month_no = 0 THEN cc.active_customers END) * 100.0 / max(cs.initial_size), 2) AS m0_pct,
    ROUND(MAX(CASE WHEN cc.month_no = 1 THEN cc.active_customers END) * 100.0 / max(cs.initial_size), 2) AS m1_pct,
    ROUND(MAX(CASE WHEN cc.month_no = 2 THEN cc.active_customers END) * 100.0 / max(cs.initial_size), 2) AS m2_pct,
    ROUND(MAX(CASE WHEN cc.month_no = 3 THEN cc.active_customers END) * 100.0 / max(cs.initial_size), 2) AS m3_pct
from cohort_counts cc
join cohort_sizes cs on cc.cohort_month = cs.cohort_month
group by cc.cohort_month
order by cc.cohort_month;

-- 2.1 RFM 
with rfm as (
	select
		o.customer_id,
		extract(day from (now()  - max(o.order_date))) as recency,
		count(*) as frequency,
		sum(o.order_total) as monetary
	from orders o
	group by o.customer_id
),
rfm_scores as (
	select
		customer_id,
		recency, frequency, monetary,
	CASE WHEN recency <= 30 THEN 5
         WHEN recency <= 90 THEN 4
         WHEN recency <= 180 THEN 3
         WHEN recency <= 365 THEN 2
         ELSE 1 END AS r_score,
    CASE WHEN frequency >= 10 THEN 5
         WHEN frequency >= 5 THEN 4
         WHEN frequency >= 3 THEN 3
         WHEN frequency >= 2 THEN 2
         ELSE 1 END AS f_score,
    CASE WHEN monetary >= 5000 THEN 5
         WHEN monetary >= 2500 THEN 4
         WHEN monetary >= 1000 THEN 3
         WHEN monetary >= 500 THEN 2
         ELSE 1 END AS m_score
	from rfm
)
select 
	customer_id,
	concat(r_score, f_score, m_score) as rfm_segment,
	monetary as ltv_simple,
	(monetary / NULLIF(frequency, 0)) * frequency AS ltv_aov_x_freq 
from rfm_scores 
order by monetary desc
limit 20;

-- bonus timesies MOM + moving average
WITH daily AS (
  SELECT order_date::DATE AS d, SUM(order_total) AS revenue
  FROM core.orders
  GROUP BY 1
)
SELECT
  d,
  revenue,
  ROUND((revenue - LAG(revenue) OVER (ORDER BY d))
    / NULLIF(LAG(revenue) OVER (ORDER BY d), 0) * 100, 1) AS mom_growth_pct,
  ROUND(AVG(revenue) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS ma_7d,
  ROUND(AVG(revenue) OVER (ORDER BY d ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS ma_30d
FROM daily
ORDER BY d;
