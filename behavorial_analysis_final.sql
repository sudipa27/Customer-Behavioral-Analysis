CREATE DATABASE dannys_diner;

USE dannys_diner;

CREATE TABLE sales(
	customer_id VARCHAR(1),
	order_date DATE,
	product_id INTEGER
);

INSERT INTO sales
	(customer_id, order_date, product_id)
VALUES
	('A', '2021-01-01', 1),
	('A', '2021-01-01', 2),
	('A', '2021-01-07', 2),
	('A', '2021-01-10', 3),
	('A', '2021-01-11', 3),
	('A', '2021-01-11', 3),
	('B', '2021-01-01', 2),
	('B', '2021-01-02', 2),
	('B', '2021-01-04', 1),
	('B', '2021-01-11', 1),
	('B', '2021-01-16', 3),
	('B', '2021-02-01', 3),
	('C', '2021-01-01', 3),
	('C', '2021-01-01', 3),
	('C', '2021-01-07', 3);

CREATE TABLE menu(
	product_id INTEGER,
	product_name VARCHAR(5),
	price INTEGER
);

INSERT INTO menu
	(product_id, product_name, price)
VALUES
	(1, 'sushi', 10),
    (2, 'curry', 15),
    (3, 'ramen', 12);

CREATE TABLE members(
	customer_id VARCHAR(1),
	join_date DATE
);

-- Still works without specifying the column names explicitly
INSERT INTO members
	(customer_id, join_date)
VALUES
	('A', '2021-01-07'),
    ('B', '2021-01-09');

-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(m.price) as total_spent
FROM sales as s
JOIN
menu as m
on s.product_id = m.product_id
group by s.customer_id; 


-- 2. How many days has each customer visited the restaurant?
select s.customer_id, count(DISTINCT s.order_date) as visited_days
FROM sales as s
group by s.customer_id;



-- 3. What was the first item from the menu purchased by each customer?
with customer_first_purchase as(select s.customer_id , min(s.order_date) as first_purchase
from sales as s
group by s.customer_id)
select cfp.customer_id, cfp.first_purchase,m.product_name
from customer_first_purchase as cfp
join sales as s on cfp.first_purchase=s.order_date
and cfp.customer_id=s.customer_id
join menu as m on s.product_id=m.product_id;



-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select  m.product_name, count(*) as total_purchase
from sales as s
join menu as m where s.product_id=m.product_id
group by m.product_name
order by total_purchase DESC
limit 1;
 


-- 5. Which item was the most popular for each customer?
with customer_purchased as (select s.customer_id,m.product_name, count(*) as purchase_count,
dense_rank() over (partition by s.customer_id order by count(*) desc) as rnk
from sales as s
join menu as m on s.product_id=m.product_id
group by customer_id, product_name)
select cp.customer_id,  cp.product_name, cp.purchase_count
from customer_purchased as cp
where rnk=1;



-- 6. Which item was purchased first by the customer after they became a member?
WITH first_purchase_after_membership AS (
    SELECT s.customer_id, MIN(s.order_date) as first_purchase_date
    FROM sales s
    JOIN members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date >= mb.join_date
    GROUP BY s.customer_id
)
SELECT fpam.customer_id, m.product_name
FROM first_purchase_after_membership fpam
JOIN sales s ON fpam.customer_id = s.customer_id 
AND fpam.first_purchase_date = s.order_date
JOIN menu m ON s.product_id = m.product_id;


-- 7. Which item was purchased just before the customer became a member?
WITH first_purchase_before_membership AS (
    SELECT s.customer_id, MAX(s.order_date) as first_purchase_date
    FROM sales s
    JOIN members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date < mb.join_date
    GROUP BY s.customer_id
)
SELECT fpbm.customer_id, m.product_name
FROM first_purchase_before_membership fpbm
JOIN sales s ON fpbm.customer_id = s.customer_id 
AND fpbm.first_purchase_date = s.order_date
JOIN menu m ON s.product_id = m.product_id;



-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(*) as total_items, sum(m.price) as total_spent
from sales as s 
join menu m on s.product_id = m.product_id
join members mb on s.customer_id=mb.customer_id
where s.order_date < mb.join_date
group by s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select s.customer_id, sum(
case
 when m.product_name='sushi'
 then m.price*20
else m.price*10 end) as total_points
from sales as s
join menu as m on s.product_id= m.product_id
group by customer_id;


/* 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/
 SELECT s.customer_id, SUM(
    CASE 
        WHEN s.order_date BETWEEN mb.join_date  AND DATE_ADD(current_date(), interval 7 day)  THEN m.price*20
        WHEN m.product_name = 'sushi' THEN m.price*20 
        ELSE m.price*10 
    END) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id
WHERE s.customer_id = mb.customer_id AND s.order_date <= '2021-01-31'
GROUP BY s.customer_id;

-- 11. Recreate the table output using the available data
select s.customer_id, s.order_date, m.product_name, m.price,
(case when s.order_date>=mb.join_date then 'Y'
else 'N' end) as member
from sales s
join menu m on s.product_id = m.product_id
left join members mb on s.customer_id = mb.customer_id
order by s.customer_id, s.order_date;


-- 12. Rank all the things:
with customers_data as
(SELECT s.customer_id, s.order_date, m.product_name, m.price,
	(CASE
		WHEN s.order_date < mb.join_date THEN 'N'
		WHEN s.order_date >= mb.join_date THEN 'Y'
		ELSE 'N' END) AS member
	FROM sales s
	LEFT JOIN members mb ON s.customer_id = mb.customer_id
	JOIN menu m ON s.product_id = m.product_id
)
SELECT *,
CASE WHEN member = 'N' THEN NULL
ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date)
END AS ranking
FROM customers_data
ORDER BY customer_id, order_date;