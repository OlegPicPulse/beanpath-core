-- 1. Вспомогательные функции 
CREATE OR REPLACE FUNCTION distribute_orders(total_orders INT, is_weekend BOOLEAN)
RETURNS INT[] AS $$
DECLARE
    base_morning   FLOAT;
    base_afternoon FLOAT;
    base_evening   FLOAT;
    noise_morning   FLOAT;
    noise_afternoon FLOAT;
    noise_evening   FLOAT;
    raw_morning     FLOAT;
    raw_afternoon   FLOAT;
    raw_evening     FLOAT;
    total_raw       FLOAT;
    morning_cnt     INT;
    afternoon_cnt   INT;
    evening_cnt     INT;
    remainder       INT;
BEGIN
    IF is_weekend THEN
        base_morning := 0.20; base_afternoon := 0.60; base_evening := 0.20;
    ELSE
        base_morning := 0.40; base_afternoon := 0.50; base_evening := 0.10;
    END IF;

    noise_morning   := (random() - 0.5) * 0.5;
    noise_afternoon := (random() - 0.5) * 0.5;
    noise_evening   := (random() - 0.5) * 0.5;

    raw_morning     := GREATEST(0.0, LEAST(1.0, base_morning   + noise_morning));
    raw_afternoon   := GREATEST(0.0, LEAST(1.0, base_afternoon + noise_afternoon));
    raw_evening     := GREATEST(0.0, LEAST(1.0, base_evening   + noise_evening));

    total_raw := raw_morning + raw_afternoon + raw_evening;
    IF total_raw = 0 THEN
        raw_morning := 1.0/3; raw_afternoon := 1.0/3; raw_evening := 1.0/3;
        total_raw := 1.0;
    END IF;

    raw_morning     := raw_morning / total_raw;
    raw_afternoon   := raw_afternoon / total_raw;
    raw_evening     := raw_evening / total_raw;

    morning_cnt     := FLOOR(total_orders * raw_morning)::INT;
    afternoon_cnt   := FLOOR(total_orders * raw_afternoon)::INT;
    evening_cnt     := FLOOR(total_orders * raw_evening)::INT;

    remainder := total_orders - (morning_cnt + afternoon_cnt + evening_cnt);
    WHILE remainder > 0 LOOP
        CASE (random() * 3)::INT
            WHEN 0 THEN morning_cnt := morning_cnt + 1;
            WHEN 1 THEN afternoon_cnt := afternoon_cnt + 1;
            ELSE        evening_cnt := evening_cnt + 1;
        END CASE;
        remainder := remainder - 1;
    END LOOP;

    RETURN ARRAY[morning_cnt, afternoon_cnt, evening_cnt];
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_time_in_period(period TEXT)
RETURNS TIME AS $$
DECLARE
    t_sec INT;
    base_sec INT;
    peak_bias_sec FLOAT;
BEGIN
    IF period = 'morning' THEN
        base_sec := 30600;
        peak_bias_sec := (random() - 0.5) * 7200 * 0.7;
        t_sec := base_sec + peak_bias_sec + (random() - 0.5) * 3600;
        t_sec := GREATEST(28800, LEAST(43199, t_sec));
    ELSIF period = 'afternoon' THEN
        base_sec := 45000;
        peak_bias_sec := (random() - 0.5) * 10800 * 0.6;
        t_sec := base_sec + peak_bias_sec + (random() - 0.5) * 7200;
        t_sec := GREATEST(39600, LEAST(57599, t_sec));
    ELSIF period = 'evening' THEN
        base_sec := 61200;
        peak_bias_sec := (random() - 0.5) * 7200 * 0.8;
        t_sec := base_sec + peak_bias_sec + (random() - 0.5) * 3600;
        t_sec := GREATEST(57600, LEAST(71999, t_sec));
    ELSE
        t_sec := 28800;
    END IF;
    RETURN (t_sec || ' seconds')::INTERVAL::TIME;
END;
$$ LANGUAGE plpgsql;

-- 2. Справочник напитков с реальными весами
DROP TABLE IF EXISTS dim_coffee;
CREATE TABLE dim_coffee (
    coffee_id    SERIAL PRIMARY KEY,
    coffee_name  TEXT NOT NULL,
    base_weight  FLOAT NOT NULL
);

INSERT INTO dim_coffee (coffee_name, base_weight) VALUES
('Cappuccino', 889.0 / 3547),
('Latte', 677.0 / 3547),
('Latte (with add: caramel, peanut paste, halva)', 486.0 / 3547),
('Batch brew', 564.0 / 3547),
('Flat white', 287.0 / 3547),
('Raf coffee', 276.0 / 3547),
('Warming drinks (tea)', 239.0 / 3547),
('Espresso', 129.0 / 3547);

-- 3. Функция выбора кофе с шумом
CREATE OR REPLACE FUNCTION random_coffee_name()
RETURNS TEXT AS $$
DECLARE
    r FLOAT;
    total_weight FLOAT := 0.0;
    adjusted_weight FLOAT;
    coffee_rec RECORD;
BEGIN
    r := random();
    FOR coffee_rec IN 
        SELECT coffee_name, base_weight FROM dim_coffee ORDER BY coffee_id
    LOOP
        adjusted_weight := coffee_rec.base_weight * (1.0 + (random() - 0.5) * 0.3);
        adjusted_weight := GREATEST(0.01, adjusted_weight);
        IF r < total_weight + adjusted_weight THEN
            RETURN coffee_rec.coffee_name;
        END IF;
        total_weight := total_weight + adjusted_weight;
    END LOOP;
    RETURN 'Latte';
END;
$$ LANGUAGE plpgsql;

-- 4. Факт-таблица
DROP VIEW IF EXISTS sales_q3_2025;
DROP TABLE IF EXISTS fact_coffee_sales_q3;
CREATE TABLE fact_coffee_sales_q3 (
    date_key      INT NOT NULL,
    hour_of_day   SMALLINT NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
    time_of_day   TEXT NOT NULL,
    cash_type     TEXT NOT NULL,
    coffee_name   TEXT NOT NULL,
    cost          NUMERIC(10, 2) NOT NULL,
    sale_time     TIME NOT NULL
);
CREATE INDEX idx_fact_date_key ON fact_coffee_sales_q3 (date_key);

-- 5. Генерация данных (исправленная версия)
INSERT INTO fact_coffee_sales_q3
SELECT
    date_key,
    EXTRACT(HOUR FROM sale_time)::SMALLINT AS hour_of_day,
    INITCAP(period) AS time_of_day,
    CASE WHEN random() < 0.5 THEN 'card' ELSE 'cash' END AS cash_type,  
    random_coffee_name() AS coffee_name,
    ROUND((25 + random() * 20 + (random() - 0.5) * 5)::NUMERIC, 2) AS cost,
    sale_time
FROM (
    WITH q3_days AS (
        SELECT date_key, date, is_weekend
        FROM date_dim
        WHERE date BETWEEN DATE '2025-07-01' AND DATE '2025-09-30'
    ),
    daily_order_counts AS (
        SELECT
            date_key,
            date,
            is_weekend,
            GREATEST(10, (CASE WHEN is_weekend THEN 28 ELSE 42 END) + ((random() - 0.5) * 10)::INT) AS total_orders
        FROM q3_days
    ),
    period_distribution AS (
        SELECT
            date_key,
            date,
            is_weekend,
            total_orders,
            (distribute_orders(total_orders, is_weekend))[1] AS morning_cnt,
            (distribute_orders(total_orders, is_weekend))[2] AS afternoon_cnt,
            (distribute_orders(total_orders, is_weekend))[3] AS evening_cnt
        FROM daily_order_counts
    ),
    expanded_orders AS (
        SELECT date_key, 'morning' AS period FROM period_distribution, generate_series(1, morning_cnt)
        UNION ALL
        SELECT date_key, 'afternoon' FROM period_distribution, generate_series(1, afternoon_cnt)
        UNION ALL
        SELECT date_key, 'evening' FROM period_distribution, generate_series(1, evening_cnt)
    ),
    all_orders AS (
        SELECT
            date_key,
            period,
            generate_time_in_period(period) AS sale_time
        FROM expanded_orders
    )
    SELECT * FROM all_orders
    LIMIT 4000  -- генерируем с запасом
) AS sub
LIMIT 3547; 


WITH user_cohorts AS (
    SELECT useer_id, DATE_TRUNC('month', MIN(order_date)
) AS cohort_month
FROM orders GROUP BY 1
),
order_margings AS (
    SELECT
        o.user_id,
        o.order_date,
        (o.amount - (p.unit_cost *.quantity)) AS net_margin
    FROM order o
    JOIN products p ON o.product_id = p.id
),
cumulative_margin AS (
    SELECT
        u.cohort_month,
        DATE_TRUNC('month', om.order_date) AS margin_month,
        SUM(om.net_margin) AS monthly_net_profit,
        COUNT(DISTINCT u.user_id) OVER(PARTITION BY u.cohort_month) AS cohort_size
    FROM order_margins om
    JOIN user_cohorts u ON om.user_id = u.user_id
    GROUP BY 1, 2, user_id    
)
SELECT
    cohort_month,
    margin_month,
    ROUND(SUM(SUM(monthly_net_profit)) OVER (
        PARTITION BY cohort_month ORDER BY marging_month
    ) / MAX(cohort_size), 2) AS ltv_margin
FROM cumulative_margin
GROUP B 1, 2
ORDER BY 1, 2;
