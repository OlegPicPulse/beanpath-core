-- 1. FROM/JOIN (Собираем данные из таблиц)
-- 2. WHERE (Фильтруем строки)
-- 3. GROUP BY (Группируем строки)
-- 4. SELECT (Вычисляем агрегаты и выдаем результат)


WITH daily_sales AS (
    -- 1. Агрегируем сырые транзакции по дням
    SELECT 
        p.product_id,
        s.sale_date::date AS sale_date,
        SUM(s.quantity) AS daily_sales
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY p.product_id, s.sale_date::date
),
sales_metrics AS (
    -- 2. Считаем метрики (оконные функции)
    SELECT 
        product_id,
        sale_date,
        daily_sales,
        COALESCE(daily_sales - LAG(daily_sales) OVER (
            PARTITION BY product_id ORDER BY sale_date
        ), 0) AS diff,
        ROUND(AVG(daily_sales) OVER (
            PARTITION BY product_id 
            ORDER BY sale_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2) AS moving_avg_7d
    FROM daily_sales
)
-- 3. Фильтруем падения тренда
SELECT 
    product_id,
    sale_date,
    daily_sales,
    diff,
    moving_avg_7d
FROM sales_metrics
WHERE diff < 0 
  AND daily_sales < moving_avg_7d
ORDER BY sale_date DESC
LIMIT 100;



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


-- СОЗДАНИЕ ТЕСТОВОЙ БАЗЫ ДЫННЫХ

-- 1. ОЧИСТКА (на случай повторного запуска)
DROP TABLE IF EXISTS inventory_log CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS products CASCADE;

-- 2. СОЗДАНИЕ ТАБЛИЦ

-- Справочник товаров
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    category VARCHAR(50) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    cost_price NUMERIC(10, 2),
    sale_price NUMERIC(10, 2)
);

-- Таблица продаж (транзакции)
CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id),
    sale_date TIMESTAMP NOT NULL,
    quantity INT NOT NULL,
    customer_id INT -- Добавим для будущих примеров
);

-- Журнал остатков (снепшоты)
CREATE TABLE inventory_log (
    log_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id),
    date DATE NOT NULL,
    stock_on_hand INT NOT NULL,
    operation_type VARCHAR(20) -- 'in', 'out', 'adjustment'
);

-- 3. ГЕНЕРАЦИЯ ДАННЫХ

-- Вставляем 20 товаров (2 категории)
INSERT INTO products (category, model_name, cost_price, sale_price)
SELECT 
    CASE WHEN g % 2 = 0 THEN 'Electronics' ELSE 'Clothing' END,
    'Model_' || g,
    ROUND((random() * 50 + 10)::numeric, 2),
    ROUND((random() * 100 + 20)::numeric, 2)
FROM generate_series(1, 20) AS g;

-- Вставляем продажи за последние 2 года (примерно 50 000 записей)
-- generate_series генерирует даты, а случайное число выбирает товар
INSERT INTO sales (product_id, sale_date, quantity, customer_id)
SELECT 
    (random() * 19 + 1)::int AS product_id, -- Случайный ID от 1 до 20
    ts AS sale_date,
    (random() * 5 + 1)::int AS quantity,    -- Количество от 1 до 5
    (random() * 1000)::int AS customer_id
FROM generate_series(
    CURRENT_DATE - INTERVAL '2 years', 
    CURRENT_DATE, 
    INTERVAL '15 minutes' -- Продажа каждые 15 минут в среднем
) AS ts
WHERE random() > 0.3; -- Фильтр: не каждый интервал приводит к продаже (чтобы было реалистично)

-- Вставляем остатки (ежедневный срез на конец дня)
INSERT INTO inventory_log (product_id, date, stock_on_hand, operation_type)
SELECT 
    p.product_id,
    d::date,
    (random() * 100 + 10)::int, -- Случайный остаток от 10 до 110
    'snapshot'
FROM products p
CROSS JOIN generate_series(
    CURRENT_DATE - INTERVAL '2 years', 
    CURRENT_DATE, 
    INTERVAL '1 day'
) AS d;

-- 4. СОЗДАНИЕ ИНДЕКСОВ (для ускорения будущих запросов)

-- Индекс на дату продаж. Ускорит поиск продаж за период 
-- (например, WHERE sale_date > '2026-01-01').
CREATE INDEX idx_sales_date ON sales(sale_date);

-- Индекс на товар в продажах (критично для JOIN).
-- Ускорит соединение таблиц, когда мы хотим узнать детали товара по его ID.
CREATE INDEX idx_sales_product ON sales(product_id);

-- Индекс на дату и товар в остатках (критично для JOIN по дате)
-- Полезен, когда мы фильтруем и по дате, и по товару одновременно. 
-- Порядок колонок в индексе важен.
CREATE INDEX idx_inventory_date_product ON inventory_log(date, product_id);

-- 5. ПРОВЕРКА (быстрые запросы)
SELECT 'Products' as table_name, count(*) as rows FROM products
UNION ALL
SELECT 'Sales', count(*) FROM sales
UNION ALL
SELECT 'Inventory', count(*) FROM inventory_log;

-- Объединение всех таблиц перед экспортом 
SELECT 
    p.product_id,
    p.category,
    p.model_name,
    p.cost_price,
    p.sale_price,
    s.sale_id,
    s.sale_date::DATE AS sale_date,          -- Приводим к дате для удобства
    s.sale_date::TIME AS sale_time,          -- Выделяем время отдельно
    s.quantity,
    (s.quantity * p.sale_price) AS revenue,  -- Выручка по строке
    s.customer_id,
    inv.stock_on_hand,
    inv.operation_type
FROM sales s
JOIN products p ON s.product_id = p.product_id
LEFT JOIN inventory_log inv 
    ON s.product_id = inv.product_id 
    AND s.sale_date::DATE = inv.date
ORDER BY s.sale_date DESC;


-- ОБОРАЧИВАЕМОСТЬ 
WITH sales_90d AS (
    -- ШАГ 1: Продажи за последние 90 дней
    SELECT
        p.product_id,
        p.category,
        p.model_name,
        COALESCE(SUM(s.quantity), 0) AS total_sold_90d,
        ROUND(COALESCE(SUM(s.quantity), 0) / 90.0, 2) AS avg_daily_sales
    FROM products p
    LEFT JOIN sales s ON p.product_id = s.product_id
        AND s.sale_date >= (SELECT MAX(sale_date) - INTERVAL '90 days' FROM sales)
    GROUP BY p.product_id, p.category, p.model_name    
),

inventory_avg AS (
    -- ШАГ 2: Средний запас за 90 дней
    SELECT 
        product_id,
        ROUND(AVG(stock_on_hand), 2) AS avg_stock_90d
    FROM inventory_log
    WHERE date >= (SELECT MAX(date) - INTERVAL '90 days' FROM inventory_log)
      AND operation_type = 'snapshot'
    GROUP BY product_id 
),

inventory_current AS (
    -- ШАГ 3: Текущий остаток
    SELECT DISTINCT ON (product_id)
        product_id,
        stock_on_hand AS current_stock
    FROM inventory_log
    WHERE operation_type = 'snapshot'
    ORDER BY product_id, date DESC
),

metrics AS (
    -- ШАГ 4: Объединение и предварительные расчеты
    SELECT 
        s.*,
        ic.current_stock,
        ia.avg_stock_90d,
        ROUND(ic.current_stock / NULLIF(s.avg_daily_sales, 0), 0) AS days_of_supply_calc
    FROM sales_90d s
    LEFT JOIN inventory_avg ia ON s.product_id = ia.product_id
    LEFT JOIN inventory_current ic ON s.product_id = ic.product_id
)

-- ШАГ 5: Финальная презентация
SELECT 
    category AS "Категория",
    model_name AS "Товар",
    COALESCE(current_stock, 0) AS "Текущий_остаток",
    COALESCE(avg_stock_90d, 0) AS "Средний_запас_90дн",
    total_sold_90d AS "Продано_шт",
    avg_daily_sales AS "Средние_продажи_в_день",
    
    -- Оборачиваемость
    CASE 
        WHEN avg_stock_90d > 0 
        THEN ROUND(total_sold_90d / avg_stock_90d, 2)
        ELSE 0 
    END AS "Оборачиваемость",
    
    -- Дней запаса
    CASE 
        WHEN avg_daily_sales > 0 
        THEN days_of_supply_calc 
        ELSE 999 
    END AS "Дней_запаса",
    
    -- Статус
    CASE 
        WHEN COALESCE(current_stock, 0) = 0 THEN 'Out of Stock'
        WHEN COALESCE(avg_daily_sales, 0) = 0 THEN 'Нет продаж'
        WHEN days_of_supply_calc <= 7 THEN 'Дефицит'
        WHEN days_of_supply_calc > 90 THEN 'Затоваривание'
        ELSE 'Норма'
    END AS "Статус"
    
FROM metrics
ORDER BY "Дней_запаса" ASC;


--

-- ABC-анализ + Оборачиваемость = Приоритеты закупок 
-- 
WITH sales_period AS (
    -- Определяем период: последние 90 дней от последней продажи
    SELECT MAX(sale_date) - INTERVAL '90 days' AS period_start
    FROM sales
),

product_revenue AS (
    -- Шаг 1: Выручка за период
    SELECT 
        p.product_id,
        p.model_name,
        p.category,
        SUM(s.quantity * p.sale_price) AS total_revenue,
        SUM(s.quantity) AS total_quantity,
        COUNT(DISTINCT s.sale_date::date) AS active_days
    FROM products p
    JOIN sales s ON p.product_id = s.product_id
    CROSS JOIN sales_period sp
    WHERE s.sale_date >= sp.period_start
    GROUP BY p.product_id, p.model_name, p.category
),

ranked AS (
    -- Шаг 2: Ранжирование и кумулятивные суммы
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS rank,
        SUM(total_revenue) OVER () AS grand_total,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue
    FROM product_revenue
),

with_pct AS (
    -- Шаг 3: Расчет процентов
    SELECT 
        *,
        ROUND(total_revenue / NULLIF(grand_total, 0) * 100, 2) AS revenue_share_pct,
        ROUND(cumulative_revenue / NULLIF(grand_total, 0) * 100, 2) AS cumulative_pct
    FROM ranked
)

-- Шаг 4: Финальный отчет 
SELECT 
    rank AS "Ранг",
    product_id AS "ID",
    model_name AS "Товар",
    category AS "Категория",
    total_revenue AS "Выручка_руб",
    revenue_share_pct AS "Доля_%",
    cumulative_pct AS "Накопленная_%",
    CASE 
        WHEN cumulative_pct <= 80 THEN 'A'
        WHEN cumulative_pct <= 95 THEN 'B'
        ELSE 'C'
    END AS "ABC_категория",
    total_quantity AS "Продано_шт",
    active_days AS "Дней_с_продажами",
    CASE 
        WHEN cumulative_pct <= 80 THEN 'ЕЖЕДНЕВНО'
        WHEN cumulative_pct <= 95 THEN 'Еженедельно'
        ELSE 'ежемесячно'
    END AS "Рекомендация_по_контролю",
    -- Дополнительная рекомендация по управлению запасами
    CASE 
        WHEN cumulative_pct <= 80 THEN 'Высокий приоритет, страховой запас +50%'
        WHEN cumulative_pct <= 95 THEN 'Средний приоритет, страховой запас +30%'
        ELSE 'Низкий приоритет, страховой запас +15%'
    END AS "Рекомендация_по_запасам"
FROM with_pct
ORDER BY rank;
