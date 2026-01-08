-- Общие метрики бизнеса
WITH tx AS (
    SELECT transaction_id, MAX(total_cost) AS total_cost
    FROM third_wave_coffee_shop 
    GROUP BY transaction_id
)
SELECT
    COUNT(*) AS total_orders,
    ROUND(SUM(total_cost), 2) AS total_revenue,
    ROUND(AVG(total_cost), 2) AS avg_ticket
FROM tx;


-- Динамика по дням недели
WITH tx AS (
    SELECT transaction_id, MAX(total_cost) AS total_cost, MIN(day_name) AS day_name
    FROM third_wave_coffee_shop
    GROUP BY transaction_id
)
SELECT
    day_name,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_cost), 2) AS revenue,
    ROUND(AVG(total_cost), 2) AS avg_ticket
FROM tx
GROUP BY day_name
ORDER BY revenue DESC;


-- Заказы: будни vs выходные
WITH tx AS (
    SELECT 
        transaction_id, 
        MAX(total_cost) AS total_cost, 
        BOOL_OR(is_weekend) AS is_weekend
    FROM third_wave_coffee_shop 
    GROUP BY transaction_id
)
SELECT
    is_weekend,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_cost), 2) AS revenue,
    ROUND(AVG(total_cost), 2) AS avg_ticket
FROM tx
GROUP BY is_weekend;


-- Популярность напитков
SELECT
    coffee_name,
    COUNT(*) AS drinks_sold,
    ROUND(SUM(drink_price), 2) AS revenue
FROM third_wave_coffee_shop
GROUP BY coffee_name
ORDER BY revenue DESC
LIMIT 8;


-- Распределение заказов по времени дня
WITH tx AS (
    SELECT transaction_id, MAX(total_cost) AS total_cost, MIN(time_of_day) AS time_of_day
    FROM coffee_shop_sales
    GROUP BY transaction_id
)
SELECT
    time_of_day,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_cost), 2) AS total_revenue,
    ROUND(AVG(total_cost), 2) AS avg_ticket
FROM tx
GROUP BY time_of_day
ORDER BY total_revenue DESC;


-- Динамика по часам
WITH tx AS (
    SELECT 
        transaction_id,
        MAX(total_cost) AS total_cost,
        EXTRACT(HOUR FROM MIN(datetime)) AS hour
    FROM third_wave_coffee_shop
    GROUP BY transaction_id
)
SELECT
    hour::INT AS hour,
    COUNT(*) AS num_tx,
    ROUND(SUM(total_cost), 2) AS total_revenue,
    ROUND(AVG(total_cost), 2) AS avg_check
FROM tx
GROUP BY hour
ORDER BY hour;


-- Среднее количество напитков в заказе
SELECT 
    ROUND(AVG(drinks_per_tx), 2) AS avg_drinks_per_order
FROM (
    SELECT transaction_id, COUNT(*) AS drinks_per_tx
    FROM third_wave_coffee_shop
    GROUP BY transaction_id
) sub;


-- Концентрация выручки на топ-напитках
WITH drink_revenue AS (
    SELECT coffee_name, SUM(drink_price) AS revenue
    FROM third_wave_coffee_shop
    GROUP BY coffee_name
),
top3 AS (
    SELECT coffee_name FROM drink_revenue ORDER BY revenue DESC LIMIT 3
)
SELECT
    CASE WHEN coffee_name IN (SELECT coffee_name FROM top3) THEN coffee_name ELSE 'Other' END AS category,
    ROUND(SUM(drink_price), 2) AS revenue,
    ROUND(100.0 * SUM(drink_price) / (SELECT SUM(drink_price) FROM coffee_shop_sales), 2) AS share_percent
FROM third_wave_coffee_shop
GROUP BY category
ORDER BY revenue DESC;


-- Структура оплат
WITH tx AS (
    SELECT transaction_id, MAX(total_cost) AS total_cost, MIN(payment_method) AS payment_method
    FROM third_wave_coffee_shop
    GROUP BY transaction_id
)
SELECT
    payment_method,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_cost), 2) AS revenue,
    ROUND(100.0 * SUM(total_cost) / (SELECT SUM(total_cost) FROM tx), 2) AS percent_of_total
FROM tx
GROUP BY payment_method
ORDER BY revenue DESC;


WITH tx_sizes AS (
    -- Считаем количество позиций (напитков) в каждой транзакции
    SELECT
        transaction_id,
        COUNT(*) AS n_items_per_tx
    FROM third_wave_coffee_shop
    GROUP BY transaction_id
),
dist AS (
    -- Считаем частоту каждого значения n_items_per_tx
    SELECT
        n_items_per_tx AS n_items,
        COUNT(*) AS orders_count
    FROM tx_sizes
    GROUP BY n_items_per_tx
),
total AS (
    SELECT SUM(orders_count) AS total_orders FROM dist
)
SELECT
    d.n_items,
    d.orders_count,
    ROUND((d.orders_count::NUMERIC / t.total_orders) * 100, 2) AS percent,
    ROUND(
        (SUM(d.orders_count) OVER (ORDER BY d.n_items))::NUMERIC
        / t.total_orders * 100,
        2
    ) AS cumulative_percent
FROM dist d
CROSS JOIN total t
ORDER BY d.n_items;


-- Топ-10 клиентов по общим тратам
WITH unique_tx AS (
    SELECT DISTINCT ON (transaction_id)
        customer_id,
        total_cost
    FROM third_wave_coffee_shop
    ORDER BY transaction_id
)
SELECT
    customer_id,
    SUM(total_cost) AS total_spent,
    COUNT(*) AS num_transactions,
    ROUND(AVG(total_cost), 2) AS avg_check
FROM unique_tx
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 10;

-- Анализ распределения сумм чеков
WITH check_summary AS (
  SELECT
    transaction_id,
    MAX(total_cost) AS check_amount
  FROM public.third_wave_coffee_shop
  GROUP BY transaction_id
  HAVING MAX(total_cost) = MIN(total_cost)  
),
stats AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY check_amount) AS q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY check_amount) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY check_amount) AS q3,
    MAX(check_amount) AS max_amount
  FROM check_summary
)
SELECT
  q1,
  median,
  q3,
  q3 - q1 AS iqr,
  q3 + 1.5 * (q3 - q1) AS upper_bound,
  max_amount
FROM stats;

-- Инсайдеры: самые большие чеки, попавшие под удаление
WITH check_summary AS (
  SELECT
    transaction_id,
    MAX(total_cost) AS check_amount,
    COUNT(*) AS items_count,
    STRING_AGG(coffee_name, ', ') AS items_list,
    MIN(sale_date) AS sale_date,
    MIN(time_of_day) AS time_of_day
  FROM public.third_wave_coffee_shop
  GROUP BY transaction_id
  HAVING MAX(total_cost) = MIN(total_cost)
),
iqr AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY check_amount) AS q1,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY check_amount) AS q3
  FROM check_summary
),
outliers AS (
  SELECT
    cs.*,
    i.q3 + 1.5 * (i.q3 - i.q1) AS upper_bound
  FROM check_summary cs
  CROSS JOIN iqr i
  WHERE cs.check_amount > i.q3 + 1.5 * (i.q3 - i.q1)
)
SELECT
  transaction_id,
  check_amount,
  items_count,
  items_list,
  sale_date,
  time_of_day,
  ROUND(upper_bound::NUMERIC) AS upper_bound  
FROM outliers
ORDER BY check_amount DESC;

-- Управлюющий кофейни хочет понять: насколько стабильно работает утренняя смена.
-- Oтчёт по ежедневной выручке только за Morning (1)
SELECT 
    sale_date,
    COUNT(*) AS unique_transactions,
    SUM(total_cost) AS total_revenue,
    ROUND(AVG(total_cost), 2) AS avg_check
FROM (
    SELECT DISTINCT ON (transaction_id)
        sale_date,
        transaction_id,
        total_cost
    FROM third_wave_coffee_shop
    WHERE time_of_day = 'Morning'
    ORDER BY transaction_id 
) AS unique_checks
GROUP BY sale_date
ORDER BY sale_date;

-- Oтчёт по ежедневной выручке только за Morning (2)
SELECT 
    sale_date,
    COUNT(*) AS unique_transactions,
    SUM(max_total_cost) AS total_revenue,
    ROUND(AVG(max_total_cost), 2) AS avg_check
FROM (
    SELECT 
        sale_date,
        transaction_id,
        MAX(total_cost) AS max_total_cost
    FROM third_wave_coffee_shop
    WHERE time_of_day = 'Morning'
    GROUP BY sale_date, transaction_id
) AS daily_transactions
GROUP BY sale_date
ORDER BY sale_date;

-- Выручка в час (Revenue per Hour), жестко фиксируя временные интервалы.
WITH hourly_stats AS (
    SELECT 
        sale_date,
        transaction_id,
        MAX(total_cost) AS check_cost, -- Дедупликация суммы чека
        -- Сегментация по 3-часовым слотам (только будни)
        CASE 
            WHEN sale_time::time BETWEEN '11:00:00' AND '13:59:59' THEN '1. Lunch_Rush (11–14)'
            WHEN sale_time::time BETWEEN '14:00:00' AND '16:59:59' THEN '2. Dead_Hours (14–17)'
            WHEN sale_time::time >= '17:00:00' THEN '3. Evening_Peak (17–20)'
        END AS real_segment
    FROM third_wave_coffee_shop
    WHERE is_weekend = FALSE      -- Исключаем выходные
      AND sale_time >= '11:00:00' -- Исключаем утро
    GROUP BY sale_date, transaction_id, real_segment
)
SELECT 
    real_segment,
    COUNT(DISTINCT sale_date) AS unique_days,       -- Количество рабочих дней
    COUNT(*) AS total_checks,                       -- Всего чеков
    ROUND(AVG(check_cost), 2) AS avg_check_rub,     -- Средний чек
    SUM(check_cost) AS total_revenue,               -- Общая выручка за всё время
    
    -- KPI: Эффективность одного часа работы 
    ROUND(
        SUM(check_cost) / (COUNT(DISTINCT sale_date) * 3.0), 
        0
    ) AS revenue_per_hour
FROM hourly_stats
WHERE real_segment IS NOT NULL
GROUP BY real_segment
ORDER BY real_segment;

-- KPI кофейни
select
	sum(total_cost) as "Total Revenue",
	count(*) as "Transactions",
	round(avg(total_cost), 2) as "Avg Ticket"
from (
	select distinct
		transaction_id,
		total_cost
	from third_wave_coffee_shop
) as unique_tickets;

-- Анализ продаж по продуктам (Menu Engineering)
-- Топ и анти-топ продуктов
select
	coffee_name,
	sum(drink_price) as revenue,
	count(*) as quantity,
	count(distinct transaction_id) as transactions
from third_wave_coffee_shop
group by coffee_name
order by revenue desc
limit 10;

-- ABC-анализ (фокус на выручку)
WITH product_revenue AS (
    SELECT
        coffee_name,
        SUM(drink_price) AS revenue
    FROM third_wave_coffee_shop
    GROUP BY coffee_name
),
total_revenue AS (
    SELECT SUM(revenue) AS total_rev
    FROM product_revenue
),
abc_prep AS (
    SELECT
        pr.coffee_name,
        pr.revenue,
        round((pr.revenue::NUMERIC / tr.total_rev), 6) AS revenue_share  -- приведение к NUMERIC для точности
    FROM product_revenue pr
    CROSS JOIN total_revenue tr
),
abc_final AS (
    SELECT
        coffee_name,
        revenue,
        revenue_share,
        round(SUM(revenue_share) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING), 6) AS cumulative_share
    FROM abc_prep
)
SELECT
    coffee_name,
    revenue,
    revenue_share,
    cumulative_share,
    CASE
        WHEN cumulative_share <= 0.8 THEN 'A'
        WHEN cumulative_share <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM abc_final
ORDER BY revenue DESC;

-- Временной анализ (нагрузка и планирование персонала)
select
	extract(hour from datetime)::int as hour,
	sum(drink_price) as revenue,
	count(distinct transaction_id) as transactions,
	count(*) as items_sold
from third_wave_coffee_shop
group by hour
order by hour;

--  Анализ дней недели
SELECT
    day_name,
    SUM(drink_price) AS revenue,
    COUNT(DISTINCT transaction_id) AS transactions,
    COUNT(*) AS items_sold
FROM third_wave_coffee_shop
GROUP BY day_name, EXTRACT(DOW FROM datetime)  -- DOW: 0=Sun, 1=Mon, ..., 6=Sat
ORDER BY 
    CASE day_name
        WHEN 'Monday'    THEN 1
        WHEN 'Tuesday'   THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday'  THEN 4
        WHEN 'Friday'    THEN 5
        WHEN 'Saturday'  THEN 6
        WHEN 'Sunday'    THEN 7
    END;