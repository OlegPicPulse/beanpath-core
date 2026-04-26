WITH daily_revenue AS (
	SELECT
		sale_date,
		SUM(total_cost) AS revenue
	FROM (
		SELECT DISTINCT ON (transaction_id)
			transaction_id,
			sale_date,
			total_cost
		FROM third_wave_coffee_shop
		ORDER BY transaction_id 
	) AS unique_tx 
	GROUP BY sale_date  
	ORDER BY sale_date
)
SELECT
	sale_date,
	revenue,
	LAG(revenue, 1) OVER (ORDER BY sale_date) AS prev_day_revenue,
	ROUND(
		(revenue - LAG(revenue, 1) OVER (ORDER BY sale_date))
		/ NULLIF(LAG(revenue, 1) OVER (ORDER BY sale_date), 0) * 100,
		2
	) AS revenue_change_pct
FROM daily_revenue;


-- 1. Базовая проверка: стало ли ровно 1 строка на transaction_id
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT transaction_id) AS unique_tx
FROM (
	SELECT DISTINCT ON (transaction_id)
		transaction_id,
		sale_date,
		total_cost			
	FROM third_wave_coffee_shop
	ORDER BY transaction_id
);


--  2. Найти оставшиеся дубликаты (если есть)
SELECT
	transaction_id,
	COUNT(*) AS cnt
FROM (
	SELECT DISTINCT ON (transaction_id)
		transaction_id,
		sale_date,
		total_cost			
	FROM third_wave_coffee_shop
	ORDER BY transaction_id
	) t
GROUP BY transaction_id
HAVING COUNT(*) > 1;


-- 3. Проверка до/после
-- до дедупа
SELECT COUNT(*) FROM third_wave_coffee_shop;

-- после
SELECT COUNT(*) 
FROM (
	SELECT DISTINCT ON (transaction_id)
		transaction_id,
		sale_date,
		total_cost
	FROM third_wave_coffee_shop
	ORDER BY transaction_id 
) AS unique_tx; 

-- И отдельно:
SELECT COUNT(DISTINCT transaction_id) FROM third_wave_coffee_shop; 


-- 4. Контроль “что именно удалилось”
SELECT * 
FROM third_wave_coffee_shop s 
WHERE transaction_id IN (
  SELECT transaction_id
  FROM third_wave_coffee_shop
  GROUP BY transaction_id
  HAVING COUNT(*) > 1
)
ORDER BY transaction_id;

-- 5. Аудит: сравнение DISTINCT ON vs ROW_NUMBER
WITH d1 AS (
	SELECT DISTINCT ON (transaction_id)
	  transaction_id,
	  sale_date,
	  total_cost
	FROM third_wave_coffee_shop
	ORDER BY transaction_id, sale_date DESC
),
d2 AS (
	SELECT
	  transaction_id,
	  sale_date,
	  total_cost
	FROM (
		SELECT *,
			ROW_NUMBER() OVER (
			PARTITION BY transaction_id
			ORDER BY sale_date DESC
			) rn
		FROM third_wave_coffee_shop
	) t
	WHERE rn = 1
)
SELECT *
FROM d1
FULL JOIN d2 USING (transaction_id)
WHERE d1.sale_date IS DISTINCT FROM d2.sale_date
  OR d1.total_cost IS DISTINCT FROM d2.total_cost;
  

-- 7. Проверка агрегатов
-- до дедупа
SELECT SUM(total_cost) FROM third_wave_coffee_shop;

-- после 
SELECT SUM(total_cost) 
FROM (
	SELECT DISTINCT ON (transaction_id)
		transaction_id,
		sale_date,
		total_cost			
	FROM third_wave_coffee_shop
	ORDER BY transaction_id
	) t;


-- МОНИТОРИНГ ВОЗВРАТОВ (когортный анализ)
SELECT 
    category,
    COUNT(*) AS total_orders,
    -- Считаем только те строки, где статус 'returned'
    COUNT(*) FILTER (WHERE status = 'returned') AS returned_orders,
    -- Рассчитываем процент
    ROUND(
        COUNT(*) FILTER (WHERE status = 'returned')::numeric / COUNT(*) * 100, 
        2
    ) AS return_rate_percent
FROM orders
GROUP BY category
ORDER BY return_rate_percent DESC;

/*
GROUP BY: Позволяет моментально переключить аналитику. 
Просто замените category на brand или region, чтобы получить срез по другим признакам.
*/	

-- Добавим фильтрацию по дате (только последний месяц)
`WHERE order_date >= CURRENT_DATE - INTERVAL '1 month'`

`WHERE status IN ('returned', 'delivered', 'in_transit')`

SELECT 
    category,
    COUNT(*) AS total_orders,
    -- Заменяем FILTER на CASE WHEN
    SUM(
        CASE 
            WHEN status = 'returned' THEN 1 
            ELSE 0 
        END
    ) AS returned_orders,
    -- Процент возвратов 
    ROUND(
        SUM(
            CASE 
                WHEN status = 'returned' THEN 1 
                ELSE 0 
            END
        )::numeric / COUNT(*) * 100, 
        2
    ) AS return_rate_percent
FROM orders
WHERE status IN ('returned', 'delivered', 'in_transit')  
GROUP BY category
ORDER BY return_rate_percent DESC;

