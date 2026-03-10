import pandas as pd
from sqlalchemy import create_engine
from config import DB_CONFIG
from loguru import logger

def load_csv_to_postgres(file_path, table_name):
    """Load a CSV file into a PostgreSQL table."""
    try:
        engine = create_engine(
            f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
            f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
        )
        df = pd.read_csv(file_path)
        df.to_sql(table_name, engine, if_exists="append", index=False)
        logger.info(f"Loaded {len(df)} rows into {table_name}")
    except Exception as e:
        logger.error(f"Failed to load CSV to PostgreSQL: {e}")
        raise

def run_query(query):
    """Execute a SQL query and return results as a DataFrame."""
    try:
        engine = create_engine(
            f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
            f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
        )
        df = pd.read_sql(query, engine)
        logger.info(f"Query returned {len(df)} rows")
        return df
    except Exception as e:
        logger.error(f"Failed to execute query: {e}")
        raise


if __name__ == "__main__":
    # Путь к CSV-файлу 
    csv_file = "data/raw/third_wave_coffee_shop.csv"
    table = "third_wave_coffee_shop"

    # Загружаем данные
    load_csv_to_postgres(csv_file, table)


    # Пример запроса: проверим, что данные загрузились
    sample_query = f"SELECT * FROM {table} LIMIT 5;"
    result = run_query(sample_query)
    print(result)
