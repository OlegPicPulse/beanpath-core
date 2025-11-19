# src/db/connection.py
from sqlalchemy import create_engine
from dotenv import load_dotenv
import os

load_dotenv()  # загружает переменные из .env

def get_db_engine():
    host = os.getenv("DB_HOST")
    port = os.getenv("DB_PORT")
    db = os.getenv("DB_NAME")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")

    url = f"postgresql://{user}:{password}@{host}:{port}/{db}"
    return create_engine(url)
