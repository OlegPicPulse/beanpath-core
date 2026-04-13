/*
Операционная эффективность (скорость, списания), ассортиментная матрица и геоаналитика.
"Топ-3" с самым высоким процентом заказов, где время сборки превысило 10 минут, за последнюю неделю.
Декомпозиция:
1. Отфильтровать заказы за последнюю неделю.
2. Для каждого заказа определить, был ли он "медленным" (сборка > 10 мин.)
3. Сгруппировать по "пунктам выдачи заказов", посчитать общий % медленных сборок.
4. Проранжировать по этому проценту.
Структура данных:
'orders': order_id, darkstore_id, created_at (время создания), assembled_at (время сборки).
'darkstores': darkstore_id, city_name.
*/
WITH OrderMetrics AS (
	-- 1.Подготовка данных и расчет длительности сборки
	SELECT
		o.darkstore_id,
		o.order_id,
		-- Считатаем разницу в минутах
		EXTRACT(EPOCH FROM (o.assembled_at - o.created_at)) / 60 AS assembly_minutes
	FROM orders o
	WHERE o.created_at >= CURRENT_DATE - INTERVAL '7 days'
	  AND o.assembled_at IS NOT NULL  -- Исключаем отмененные до сборки
),
DarkstoreStats AS (
	-- 2. Агрегация и расчет метрики (Bad Rate)
	SELECT
		om.darkstore_id,
		COUNT() AS total_orders,
		-- Считаем кол-во медленных заказов
		COUNT(*) FILTER (WHERE om.assembly_minutes > 10) AS slow_orders,
		ROUND(COUNT(*) FILTER (WHERE om.assembly_minutes > 10) * 100.0 / COUNT(*), 2) AS slow_pct
	FROM OrderMetrics om
	GROUP BY om.darkstore_id
	-- Отсекаем мелкие склады, чтобы избежать стат. выбросов (например, 1 заказ и он опоздал = 100%)
	HAVING COUNT(*) > 50
),
RankedStores AS (
-- 3. Ранжирование оконной функцией
	SELECT
		d.city_name,
		ds.darkstore_id,
		ds.slow_pct,
		ds.total_orders,
		-- DENSE_RANK, чтобы если у двух складов одинаковый %, они оба попали
		DENSE_RANK() OVER (ORDER BY ds.slow_pct DESC) AS rnk
	FROM DarkstoreStats ds
	JOIN darkstores d ON ds.darkstore_id = d.darkstore_id
)
SELECT 
	city_name,
	darkstore_id,
	slow_pct,
	total_orders,
	rnk
FROM RankedStores
WHERE rnk <= 3
ORDER BY slow_pct DESC

CREATE INDEX idx_orders_assembly 
ON orders (darkstore_id, created_at) 
WHERE assembled_at IS NOT NULL;

