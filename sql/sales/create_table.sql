CREATE TABLE coffee_shop_sales (
    transaction_id VARCHAR(10),
    customer_id VARCHAR(10),
    sale_date DATE,
    sale_time TIME,
    day_of_week INTEGER,
    day_name VARCHAR(20),
    is_weekend BOOLEAN,
    coffee_name VARCHAR(100),
    drink_price NUMERIC(10, 2),
    total_cost NUMERIC(10, 2),
    payment_method VARCHAR(10),
    datetime TIMESTAMP  


-- Добавлен столбец "time_of_day"
ALTER TABLE coffee_shop_sales
ADD COLUMN time_of_day VARCHAR(20);

UPDATE coffee_shop_sales
SET time_of_day = 
    CASE
        WHEN sale_time >= '08:00:00' AND sale_time < '11:00:00' THEN 'Morning'
        WHEN sale_time >= '11:00:00' AND sale_time < '16:00:00' THEN 'Afternoon'
        WHEN sale_time >= '16:00:00' AND sale_time <= '20:00:00' THEN 'Evening'
        ELSE 'Outside hours'
    END;

-- Загрузка данных 
-- COPY coffee_shop_sales FROM '/beanpath/data/raw/third_wave_coffee_shop.csv' WITH CSV HEADER;


-- Полная версия
DROP TABLE IF EXISTS third_wave_coffee_shop;

CREATE TABLE third_wave_coffee_shop (
    transaction_id  TEXT,
    customer_id     TEXT,
    sale_date       DATE,
    sale_time       TIME,
    day_of_week     INTEGER,
    day_name        TEXT,
    is_weekend      BOOLEAN,
    coffee_name     TEXT,
    drink_price     NUMERIC(10,2),
    total_cost      NUMERIC(10,2),
    payment_method  TEXT,
    datetime        TIMESTAMP,
    time_of_day     TEXT
);

COPY third_wave_coffee_shop FROM '/beanpath/data/raw/third_wave_coffee_shop.csv'
WITH (
    FORMAT csv,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    HEADER true   
);

