WITH hourly_stats AS (
    SELECT
        DATE(datetime) AS tx_date,
        CASE
            WHEN EXTRACT(DOW FROM datetime) = 0 THEN 7
            ELSE EXTRACT(DOW FROM datetime)
        END AS day_of_week_num,
        EXTRACT(HOUR FROM datetime) AS tx_hour,
        COUNT(DISTINCT transaction_id) AS transaction_count
    FROM third_wave_coffee_shop
    WHERE datetime >= '2025-07-01' AND datetime < '2025-10-01'
    GROUP BY 1, 2, 3  
)
SELECT
    -- Ось Х: часы с ведущим нулем для сортировки


SELECT
    category,
    COUNT(*) AS total_orders,
    -- Считаем только те строки, где статус 'returned'
    COUNT(*) FILTER (WHERE status = 'returned') AS returned_orders,
    -- Расчитываем процент
    ROUND(
        COUNT(*) FILTER (WHERE status = 'returned')::numeric / COUNT(*) * 100,
        2
    ) AS returned_rate_percent
FROM orders
GROUP BY category
ORDER BY return_rate_percent DESC;


SELECT
    category,
    COUNT(*) AS total_orders,
    -- Заменяяем  FILTER на CASE WHEN
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


