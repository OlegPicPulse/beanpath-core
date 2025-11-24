-- Удаление таблицы, если она существует
DROP TABLE IF EXISTS public.date_dim;

-- Создание таблицы date_dim
CREATE TABLE public.date_dim (
    date_key INTEGER PRIMARY KEY, -- Уникальный ключ в формате YYYYMMDD
    date DATE NOT NULL, -- Фактическая дата
    day_of_month SMALLINT NOT NULL, -- День месяца (1-31)
    day_of_year SMALLINT NOT NULL, -- День года (1-366)
    day_of_week SMALLINT NOT NULL, -- День недели (0-6, 0 = воскресенье)
    day_of_week_iso SMALLINT NOT NULL, -- День недели по ISO (1-7, 1 = понедельник)
    day_name VARCHAR(10) NOT NULL, -- Полное название дня недели
    day_short_name VARCHAR(3) NOT NULL, -- Короткое название дня недели
    is_weekend BOOLEAN NOT NULL, -- Признак выходного дня
    week_number SMALLINT NOT NULL, -- Номер недели в году
    week_of_month SMALLINT NOT NULL, -- Номер недели в месяце
    week_start_date DATE NOT NULL, -- Начало недели (понедельник)
    month_number SMALLINT NOT NULL, -- Номер месяца (1-12)
    month_name VARCHAR(10) NOT NULL, -- Полное название месяца
    month_short_name VARCHAR(3) NOT NULL, -- Короткое название месяца
    first_day_of_month DATE NOT NULL, -- Первый день месяца
    last_day_of_month DATE NOT NULL, -- Последний день месяца
    quarter_number SMALLINT NOT NULL, -- Номер квартала (1-4)
    quarter_name VARCHAR(2) NOT NULL, -- Название квартала (Q1-Q4)
    first_day_of_quarter DATE NOT NULL, -- Первый день квартала
    last_day_of_quarter DATE NOT NULL, -- Последний день квартала
    year INTEGER NOT NULL, -- Год
    fiscal_year INTEGER NOT NULL, -- Финансовый год (пример: начинается с июля)
    decade INTEGER NOT NULL, -- Десятилетие
    century INTEGER NOT NULL, -- Век
    is_holiday BOOLEAN DEFAULT FALSE -- Признак праздничного дня
);

-- Заполнение таблицы данными
INSERT INTO public.date_dim
SELECT
    to_char(date, 'YYYYMMDD')::INTEGER AS date_key,
    date::DATE,
    EXTRACT(DAY FROM date)::SMALLINT AS day_of_month,
    EXTRACT(DOY FROM date)::SMALLINT AS day_of_year,
    EXTRACT(DOW FROM date)::SMALLINT AS day_of_week,
    EXTRACT(ISODOW FROM date)::SMALLINT AS day_of_week_iso,
    TRIM(TO_CHAR(date, 'Day')) AS day_name,
    TRIM(TO_CHAR(date, 'Dy')) AS day_short_name,
    EXTRACT(DOW FROM date) IN (0, 6) AS is_weekend,
    EXTRACT(WEEK FROM date)::SMALLINT AS week_number,
    TO_CHAR(date, 'W')::SMALLINT AS week_of_month,
    DATE_TRUNC('week', date)::DATE AS week_start_date,
    EXTRACT(MONTH FROM date)::SMALLINT AS month_number,
    TRIM(TO_CHAR(date, 'Month')) AS month_name,
    TRIM(TO_CHAR(date, 'Mon')) AS month_short_name,
    DATE_TRUNC('month', date)::DATE AS first_day_of_month,
    (DATE_TRUNC('month', date) + INTERVAL '1 month - 1 day')::DATE AS last_day_of_month,
    EXTRACT(QUARTER FROM date)::SMALLINT AS quarter_number,
    'Q' || EXTRACT(QUARTER FROM date)::TEXT AS quarter_name,
    DATE_TRUNC('quarter', date)::DATE AS first_day_of_quarter,
    (DATE_TRUNC('quarter', date) + INTERVAL '3 months - 1 day')::DATE AS last_day_of_quarter,
    EXTRACT(YEAR FROM date)::INTEGER AS year,
    CASE 
        WHEN EXTRACT(MONTH FROM date) >= 7 
        THEN EXTRACT(YEAR FROM date) + 1 
        ELSE EXTRACT(YEAR FROM date) 
    END AS fiscal_year, -- Финансовый год начинается с июля
    (EXTRACT(YEAR FROM date)::INTEGER / 10) * 10 AS decade,
    EXTRACT(CENTURY FROM date)::INTEGER AS century,
    FALSE AS is_holiday -- Праздники можно обновить позже
FROM generate_series('1770-01-01'::DATE, '2030-12-31'::DATE, INTERVAL '1 day') AS date;

-- Создание индексов для ускорения запросов
CREATE INDEX idx_date_dim_date ON public.date_dim (date);
CREATE INDEX idx_date_dim_year ON public.date_dim (year);
CREATE INDEX idx_date_dim_month ON public.date_dim (month_number);
CREATE INDEX idx_date_dim_quarter ON public.date_dim (quarter_number);
CREATE INDEX idx_date_dim_week ON public.date_dim (week_number);

-- Комментарии к столбцам для документации
COMMENT ON TABLE public.date_dim IS 'Dimension table for dates, used for time-based analysis in data warehousing';
COMMENT ON COLUMN public.date_dim.date_key IS 'Unique key in YYYYMMDD format';
COMMENT ON COLUMN public.date_dim.date IS 'Actual date';
COMMENT ON COLUMN public.date_dim.is_weekend IS 'TRUE if the day is Saturday or Sunday';
COMMENT ON COLUMN public.date_dim.fiscal_year IS 'Fiscal year starting from July';
