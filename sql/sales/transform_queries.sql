-- Создаём dim_coffee 
DROP TABLE IF EXISTS dim_coffee;

CREATE TABLE dim_coffee (
    coffee_id    SERIAL PRIMARY KEY,
    coffee_name  TEXT NOT NULL,
    base_weight  FLOAT NOT NULL  -- исходная доля от 0 до 1
);

-- Вставляем на основе твоих данных
INSERT INTO dim_coffee (coffee_name, base_weight) VALUES
('Cappuccino', 889.0 / 3547),
('Latte', 677.0 / 3547),
('Latte (with add: caramel, peanut paste, halva)', 486.0 / 3547),
('Batch brew', 564.0 / 3547),
('Flat white', 287.0 / 3547),
('Raf coffee', 276.0 / 3547),
('Warming drinks (tea)', 239.0 / 3547),
('Espresso', 129.0 / 3547);


Функция для случайного выбора кофе с учётом весов и шума

CREATE OR REPLACE FUNCTION random_coffee_name()
RETURNS TEXT AS $$
DECLARE
    r FLOAT;
    total_weight FLOAT;
    adjusted_weight FLOAT;
    coffee_rec RECORD;
BEGIN
    -- Генерируем случайное число от 0 до 1
    r := random();

    -- Применяем шум к весам и ищем, в какой интервал попали
    total_weight := 0.0;
    FOR coffee_rec IN 
        SELECT coffee_name, base_weight FROM dim_coffee ORDER BY coffee_id
    LOOP
        -- Добавляем ±15% шума к весу
        adjusted_weight := coffee_rec.base_weight * (1.0 + (random() - 0.5) * 0.3);
        adjusted_weight := GREATEST(0.01, adjusted_weight); -- избегаем нуля

        IF r < total_weight + adjusted_weight THEN
            RETURN coffee_rec.coffee_name;
        END IF;
        total_weight := total_weight + adjusted_weight;
    END LOOP;

    -- fallback (на случай ошибки)
    RETURN 'Latte';
END;
$$ LANGUAGE plpgsql;




CREATE TABLE drink_price_ref (
    coffee_name TEXT PRIMARY KEY,
    standard_price INT NOT NULL  -- в рублях
);

-- Заполняем её актуальными ценами
INSERT INTO drink_price_ref (coffee_name, standard_price)
VALUES
    ('Cappuccino', 320),
    ('Flat white', 340),
    ('Latte', 340),
    ('Latte with add', 440),  -- ваше унифицированное название
    ('Warming drinks (tea)', 400),
    ('Espresso', 230),
    ('Batch brew', 240),
    ('Raf coffee', 420)   
;
