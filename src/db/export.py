# src/db/export.py
import pandas as pd
from pathlib import Path
from loguru import logger

# Импортируем функцию
from src.db.queries import run_query

# Определяем пути
PROJECT_ROOT = Path(__file__).parent.parent.parent
CSV_PATH = PROJECT_ROOT / "data" / "processed" / "products-with-falling-demand.csv"

QUERY_FALLING_DEMAND = """
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
ORDER BY sale_date DESC, diff ASC;   -- Сначала свежие даты, сильнее падения



"""

def export_falling_demand_to_csv(output_path: Path = None) -> Path:
    """
    Выгружает товары с падающим спросом из PostgreSQL в CSV.
    
    Args:
        output_path: Путь для сохранения (по умолчанию: data/processed/products-with-falling-demand.csv)
    
    Returns:
        Path: Путь к созданному файлу
    """
    # Используем дефолтный путь, если не передан свой
    target_path = output_path or CSV_PATH
    
    try:
        # 1. Выполняем запрос 
        logger.info("Выполняем SQL-запрос к базе данных...")
        df = run_query(QUERY_FALLING_DEMAND)
        
        # 2. Создаем директорию, если её нет
        target_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 3. Сохраняем в CSV
        df.to_csv(target_path, index=False, encoding='utf-8')
        
        logger.success(f"✅ Экспорт завершён: {target_path}")
        logger.info(f"📊 Выгружено строк: {len(df)}")
        logger.info(f"📦 Колонки: {df.columns.tolist()}")
        
        return target_path
        
    except Exception as e:
        logger.error(f"❌ Ошибка при экспорте: {e}")
        raise


from src.db.export import export_falling_demand_to_csv

if __name__ == "__main__":
    csv_file = export_falling_demand_to_csv()
    
    # Сразу можно загрузить в pandas для анализа
    import pandas as pd
    df = pd.read_csv(csv_file)
    print(df.head())


# ЗАПУСК ЧЕРЕЗ ТЕРМИНАЛ

# 1. Убедись, что ты в корне проекта
# cd 

# 2. Активируй окружение
# source .venv/bin/activate

# 3. Запусти как модуль (через точку, без .py в конце)
# python -m src.db.export

