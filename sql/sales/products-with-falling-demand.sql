-- 1. FROM/JOIN (Собираем данные из таблиц)
-- 2. WHERE (Фильтруем строки)
-- 3. GROUP BY (Группируем строки)
-- 4. SELECT (Вычисляем агрегаты и выдаем результат)


-- ОТЧЁТ: Поиск товаров с признаками падения спроса
-- ЦЕЛЬ: Выявить товары, где продажи снизились И находятся ниже средней нормы
-- ИСПОЛЬЗОВАНИЕ: Ежедневный мониторинг ассортимента для отдела закупок/продаж


WITH daily_sales AS (

    -- ШАГ 1: Агрегация продаж по дням
    -- Превращаем транзакции (время) в дневные итоги (дата)

    SELECT 
        p.product_id,
        p.model_name,
        p.category,
        s.sale_date::date AS sale_date,           -- Приводим к дате (убираем время)
        SUM(s.quantity) AS daily_sales            -- Сумма продаж за день
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    WHERE s.sale_date >= CURRENT_DATE - INTERVAL '90 days'  -- Последние 90 дней
    GROUP BY p.product_id, p.model_name, p.category, s.sale_date::date
),

sales_metrics AS (

    -- ШАГ 2: Расчёт аналитических метрик
    -- Используем оконные функции для сравнения с прошлым и средней нормой
	
    SELECT 
        product_id,
        model_name,
        category,
        sale_date,
        daily_sales,
        
        -- Разница к предыдущему дню продаж (Day-over-Day)
        -- Если NULL (первый день), ставим 0 для чистоты отчёта
		
        COALESCE(
            daily_sales - LAG(daily_sales) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date
            ), 
            0
        ) AS diff,
        
        -- Скользящее среднее за 7 дней (сглаживает случайные пики)
        -- Помогает увидеть реальный тренд, а не разовые колебания
		
        ROUND(
            AVG(daily_sales) OVER (
                PARTITION BY product_id 
                ORDER BY sale_date 
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW  -- 6 прошлых + текущий = 7 дней
            ), 
            2
        ) AS moving_avg_7d
        
    FROM daily_sales
)

-- ШАГ 3: Фильтрация «проблемных» товаров
-- Критерии: продажи упали к вчера И ниже средней нормы за неделю

SELECT 
    product_id,
    category,
    model_name,
    sale_date,
    daily_sales AS "Продажи_шт",
    diff AS "Разница_к_вчера",
    moving_avg_7d AS "Среднее_7дней"
FROM sales_metrics
WHERE diff < 0                      -- Продажи снизились к предыдущему дню
  AND daily_sales < moving_avg_7d   -- Продажи ниже средней нормы
ORDER BY sale_date DESC, diff ASC   -- Сначала свежие даты, сильнее падения
LIMIT 1000;                         -- Ограничиваем вывод для удобства

