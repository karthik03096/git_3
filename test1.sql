
--My 1st check is date, and payment status to calculate revenue in march moth which not include cancelled order

select * from src_orders 
where date(ordered_at_utc) >='2026-03-01' and date(ordered_at_utc)<'2026-04-01' and status in ('paid', 'partially_refunded');

select COUNT(*) total_count,count(DISTINCT(order_id)) total_distinct_order_id,
sum(shipping_amount) total_ship_amount, sum(tax_amount) total_tax_amt from src_orders
where date(ordered_at_utc) >='2026-03-01' and date(ordered_at_utc)<'2026-04-01' and status in ('paid', 'partially_refunded');


--now iam going to calculate the revenue of source by joining table with sr_orders 

with qualified_orders as(
    select * from src_orders 
    where date(ordered_at_utc) >='2026-03-01' and date(ordered_at_utc)<'2026-04-01' and status in ('paid', 'partially_refunded')),
line_total as(
    select order_id, sum(amount) gross_sale from src_lines GROUP BY order_id),
refund_total as (
    select order_id,sum(refund_amount)refunds from src_refunds GROUP BY order_id)
select o.order_id,l.gross_sale,o.shipping_amount shipping,o.tax_amount tax,COALESCE(r.refunds, 0) refund,
    l.gross_sale+o.shipping_amount-COALESCE(r.refunds, 0) net_revenue
    from qualified_orders o left join line_total l on o.order_id=l.order_id
    left join refund_total r on o.order_id=r.order_id
order by order_id;

--taking count and sum of total for see revenue
with qualified_orders as(
    select * from src_orders 
    where date(ordered_at_utc) >='2026-03-01' and date(ordered_at_utc)<'2026-04-01' and status in ('paid', 'partially_refunded')),
line_total as(
    select order_id, sum(amount) gross_sale from src_lines GROUP BY order_id),
refund_total as (
    select order_id,sum(refund_amount)refunds from src_refunds GROUP BY order_id)
select count(*)qualified_orders,sum(gross_sale),sum(shipping),sum(tax),sum(refund),sum(net_revenue)from(
select o.order_id,l.gross_sale,o.shipping_amount shipping,o.tax_amount tax,COALESCE(r.refunds, 0) refund,
    l.gross_sale+o.shipping_amount-COALESCE(r.refunds, 0) net_revenue
    from qualified_orders o left join line_total l on o.order_id=l.order_id
    left join refund_total r on o.order_id=r.order_id
order by order_id)revenue_order;

--now entering raw and mart

-- comparing table source and raw for total no of rows and unique order id in order table
SELECT 'src_orders' tables,count(*) AS row_count,COUNT(DISTINCT order_id) AS distinct_orders from src_orders
UNION ALL
SELECT'raw_orders',count(*),count(DISTINCT order_id) from raw_orders
union all
-- comparing table source and raw for total no of rows and unique order id in order line 
SELECT 'src_lines' tables,count(*),count(DISTINCT order_id) from src_lines
UNION ALL
SELECT 'raw_lines',count(*),count(DISTINCT order_id) from raw_lines
union all
-- comparing table source and raw(which i created as empty) for total no of rows and unique order id in refund 
SELECT 'src_refunds' tables,count(*),count(DISTINCT order_id) FROM src_refunds
UNION ALL
SELECT'raw_refunds',count(*),count(DISTINCT order_id)from raw_refunds
union all
-- comparing table source and mart for total no of rows and unique order id in payment 
SELECT
    'src_payments' tables,count(*),count(DISTINCT order_id) from src_payments
UNION ALL
SELECT'mart_revenue',count(*),count(DISTINCT order_id)from mart_revenue;

-- find the same order repeated in raw_order table
SELECT order_id,count(*) AS row_count from raw_orders
GROUP BY order_id
HAVING count(*)>1;

--finding the order that is missing in raw_ordertable by comparing with src_order table

SELECT s.order_id from src_orders s
LEFT JOIN raw_orders r ON s.order_id = r.order_id
WHERE r.order_id IS NULL

--finding missuing row in raw order
SELECT s.order_id, COUNT(*) missing_line from src_lines s LEFT JOIN raw_lines r
ON s.order_id = r.order_id
where r.order_id IS NULL
GROUP BY s.order_id;
--finding the order that is missing in raw_ordertable by comparing with src_line table

SELECT s.order_id from src_lines s
LEFT JOIN raw_lines r
    ON s.order_id = r.order_id
WHERE r.order_id IS NULL;

-- finding the missing refunds in raw by 
--comparing raw_refunds and src_refunds table
SELECT s.order_id,s.refund_amount from src_refunds s
LEFT JOIN raw_refunds r ON s.order_id = r.order_id
WHERE r.order_id IS NULL;

--shippeing amount check any null in raw_order
select order_id from raw_orders
where shipping_amount IS NULL;

--finding cancel orders in mart_revenue
SELECT order_id, status, net_revenue from mart_revenue 
where m.status = 'cancelled';
   
--finding the revenue of mart is corect camparing with actual revenue
SELECT order_id,gross_sales,shipping,refunds,net_revenue,
    gross_sales + shipping - refunds as recalculated_net from mart_revenue
WHERE (net_revenue - (gross_sales + shipping - refunds)) > 0.01;

--finding any null in order_id of mart_revenue
SELECT count(*) total_rows,count(DISTINCT order_id) distinct_orders,
    sum(CASE when order_id IS NULL then 1 ELSE 0 END) AS null_keys
from mart_revenue;



--comparing 3 tables to find the differance btw the value and to find the problem
--source section
with s_qualified_orders as(
    select * from src_orders 
    where date(ordered_at_utc) >='2026-03-01' and date(ordered_at_utc)<'2026-04-01' and status in ('paid', 'partially_refunded')),
s_line_total as(
    select order_id, sum(amount) gross_sale from src_lines GROUP BY order_id),
s_refund_total as (
    select order_id,sum(refund_amount)refunds from src_refunds GROUP BY order_id),
revenue_order as(
select o.order_id,l.gross_sale,o.shipping_amount shipping,o.tax_amount tax,COALESCE(r.refunds, 0) refund,
    l.gross_sale+o.shipping_amount-COALESCE(r.refunds, 0) net_revenue
    from s_qualified_orders o left join s_line_total l on o.order_id=l.order_id
    left join s_refund_total r on o.order_id=r.order_id
order by order_id),

rank_raw as (select *,ROW_NUMBER()over(partition by order_id order by loaded_at desc)rn from raw_orders),
qualified_raw_orders as(select * from rank_raw where rn=1 
and date(ordered_at_utc) >='2026-03-01' and date(ordered_at_utc)<'2026-04-01' and status in ('paid', 'partially_refunded')),
line_total as(
    select order_id, sum(amount) gross_sale from raw_lines GROUP BY order_id),
refund_total as (
    select  order_id,sum(refund_amount)refunds from raw_refunds GROUP BY order_id),
raw_revenue as(
select o.order_id,l.gross_sale,coalesce(o.shipping_amount,0) shipping,o.tax_amount tax,COALESCE(r.refunds, 0) refund,
    l.gross_sale+coalesce(o.shipping_amount,0)-COALESCE(r.refunds, 0) net_revenue
    from qualified_raw_orders o left join line_total l on o.order_id=l.order_id
    left join refund_total r on o.order_id=r.order_id)

select 'source' layers,count(*)qualified_orders,sum(gross_sale)gross_sale,
        sum(shipping)shipping,sum(tax)tax,sum(refund)refund,sum(net_revenue)net_revenue from revenue_order

union all

select 'raw' layers,count(*)qualified_orders,sum(gross_sale),sum(shipping),
        sum(tax),sum(refund),sum(net_revenue) from raw_revenue

union all
select 'qualified mart' layes,count(*)order_count,SUM(gross_sales) gross_sales,SUM(shipping) shipping,
    SUM(tax) tax,SUM(refunds)refunds,SUM(net_revenue) net_revenue from mart_revenue 
where status IN ('paid', 'partially_refunded')
union all
select 'full mart' layes,count(*)order_count,SUM(gross_sales) gross_sales,SUM(shipping) shipping,
    SUM(tax) tax,SUM(refunds)refunds,SUM(net_revenue) net_revenue from mart_revenue;


--comparing order by order for source and mart table to analizays the problem
WITH source_lines AS (select order_id, SUM(amount)gross_sales from src_lines
    GROUP BY order_id),
source_refunds AS (select order_id, SUM(refund_amount)refunds from src_refunds
    GROUP BY order_id),
order_comparison AS (select s.order_id,s.status,COALESCE(l.gross_sales, 0) source_gross_sales,s.shipping_amount source_shipping,
        COALESCE(r.refunds,0) source_refunds,
        CASE
            WHEN s.ordered_at_utc >= '2026-03-01'
             AND s.ordered_at_utc <  '2026-04-01'
             AND s.status IN ('paid', 'partially_refunded')
            THEN l.gross_sales
                 + s.shipping_amount
                 - COALESCE(r.refunds, 0)
            ELSE 0
        END AS source_net,
        m.net_revenue AS mart_net,
        CASE
            WHEN m.order_id IS NULL THEN 'Missing from mart'
            WHEN s.status = 'cancelled' THEN 'Ineligible order included'
            WHEN m.gross_sales <> l.gross_sales
                THEN 'Gross sales mismatch'
            WHEN m.shipping <> s.shipping_amount
                THEN 'Shipping mismatch'
            WHEN m.refunds <> COALESCE(r.refunds, 0)
                THEN 'Refund mismatch'
            WHEN m.net_revenue <>
                 l.gross_sales
                 + s.shipping_amount
                 - COALESCE(r.refunds, 0)
                THEN 'Net revenue calculation mismatch'
            ELSE 'No detected mismatch'
        END  issue
    FROM src_orders s LEFT JOIN source_lines l ON s.order_id = l.order_id
    LEFT JOIN source_refunds r ON s.order_id = r.order_id LEFT JOIN mart_revenue m ON s.order_id = m.order_id
)
SELECT
    order_id,
    source_net,
    COALESCE(mart_net, 0) mart_contribution,
    COALESCE(mart_net, 0) - source_net gap,
    issue
from order_comparison 
ORDER BY order_id;

