import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

# Параметры 
np.random.seed(42)
n_transactions = 3547

# Даты 3 квартала 
dates = pd.date_range("2025-07-01", "2025-09-30", freq="D")

# Распределение напитков с шумом 
drinks = {
    "Cappuccino": {"p": 0.251, "price": 320},
    "Latte": {"p": 0.191, "price": 340},
    "Latte with add": {"p": 0.137, "price": 440},
    "Batch brew": {"p": 0.159, "price": 240},
    "Flat white": {"p": 0.081, "price": 340},
    "Raf coffee": {"p": 0.078, "price": 420},
    "Warming drinks (tea)": {"p": 0.067, "price": 400},
    "Espresso": {"p": 0.036, "price": 230},
}

# Добавим случайный шум ±15%
for d in drinks:
    drinks[d]["p"] *= np.random.uniform(0.85, 1.15)

# Нормализация вероятностей
total_p = sum(v["p"] for v in drinks.values())
for d in drinks:
    drinks[d]["p"] /= total_p

# Функция для случайного времени
def random_time_interval(start_hour, end_hour, n):
    base = np.random.normal(loc=(start_hour + end_hour) / 2, scale=0.8, size=n)
    base = np.clip(base, start_hour, end_hour)
    hours = [int(h) for h in base]
    minutes = [int((h % 1) * 60) for h in base]
    times = [f"{h:02d}:{m:02d}:{np.random.randint(0,60):02d}" for h,m in zip(hours, minutes)]
    return times

# Создание транзакций
records = []
customer_counter = 1

for i in range(n_transactions):
    # Дата и день недели
    date = pd.Timestamp(np.random.choice(dates))
    is_weekend = date.weekday() >= 5
    day_name = date.strftime("%A")
    
    # Распределение времени в зависимости от дня недели
    r = np.random.rand()
    if not is_weekend:  # будни
        if r < 0.4:
            time = random_time_interval(8, 11, 1)[0]
        elif r < 0.9:
            time = random_time_interval(11, 16, 1)[0]
        else:
            time = random_time_interval(16, 20, 1)[0]
    else:  # выходные
        if r < 0.2:
            time = random_time_interval(8, 11, 1)[0]
        elif r < 0.8:
            time = random_time_interval(11, 16, 1)[0]
        else:
            time = random_time_interval(16, 20, 1)[0]
    
    # Клиент
    customer_id = f"CUST_{random.randint(1000, 9999)}"
    
    # Количество напитков в заказе
    n_items = np.random.choice([1,2,3], p=[0.7, 0.2, 0.1])
    
    order = []
    total_cost = 0
    for _ in range(n_items):
        drink = np.random.choice(list(drinks.keys()), p=[v["p"] for v in drinks.values()])
        price = drinks[drink]["price"]
        order.append((drink, price))
        total_cost += price
    
    # Способ оплаты 
    payment = np.random.choice(["card", "cash"], p=[0.7, 0.3])
    
    # Сохраняем каждую позицию как отдельную строку
    for drink, price in order:
        records.append({
            "transaction_id": f"TX_{i+1:04d}",
            "customer_id": customer_id,
            "date": date.strftime("%Y-%m-%d"),
            "sale_time": time,
            "day_of_week": date.weekday() + 1,
            "day_name": day_name,
            "is_weekend": is_weekend,
            "coffee_name": drink,
            "drink_price": price,
            "total_cost": total_cost,
            "payment_method": payment
        })

# Сбор в DataFrame
synthetic_df = pd.DataFrame(records)
synthetic_df["datetime"] = pd.to_datetime(synthetic_df["date"] + " " + synthetic_df["sale_time"])
synthetic_df.sort_values("datetime", inplace=True)

# Сохранение
synthetic_df.to_csv("synthetic_third_wave_q3.csv", index=False)

print(f"Сгенерировано {len(synthetic_df)} строк (включая составные заказы)")
synthetic_df.head(10)
