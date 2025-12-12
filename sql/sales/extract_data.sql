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
  ROUND(upper_bound::NUMERIC, 0) AS upper_bound  
FROM outliers
ORDER BY check_amount DESC;
