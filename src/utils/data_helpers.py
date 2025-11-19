import pandas as pd
from sklearn.impute import SimpleImputer
from loguru import logger
from config import RAW_DATA_DIR, PROCESSED_DATA_DIR

def load_csv(file_name, directory=RAW_DATA_DIR):
    """Load a CSV file into a pandas DataFrame.""" 
    try:
        file_path = directory / file_name
        logger.info(f"Loading CSV from {file_path}")
        df = pd.read_csv(file_path)
        logger.info(f"Loaded {len(df)} rows and {len(df.columns)} columns")
        return df
    except Exception as e:
        logger.error(f"Failed to load CSV: {e}")
        raise

def handle_missing_values(df, strategy='mean', columns=None):
    """Handle missing values using imputation or dropping."""
    if columns is None:
        columns = df.columns
    if strategy in ['mean', 'median', 'most_frequent']:
        imputer = SimpleImputer(strategy=strategy)
        df[columns] = imputer.fit_transform(df[columns])
    elif strategy == 'drop':
        df = df.dropna(subset=columns)
    elif strategy == 'interpolate':
        df[columns] = df[columns].interpolate(method='linear')
    logger.info(f"Handled missing values with {strategy}")
    return df

def remove_duplicates(df):
    initial_rows = len(df)
    df = df.drop_duplicates()
    logger.info(f"Removed {initial_rows - len(df)} duplicates")
    return df

def handle_outliers(df, column, method='iqr', threshold=1.5):
    if method == 'iqr':
        Q1 = df[column].quantile(0.25)
        Q3 = df[column].quantile(0.75)
        IQR = Q3 - Q1
        lower = Q1 - threshold * IQR
        upper = Q3 + threshold * IQR
        df[column] = df[column].clip(lower, upper)
    logger.info(f"Handled outliers in {column} using {method}")
    return df


if __name__ == "__main__":
    # Пример 1: Использование пути по умолчанию
    try:
        data = load_csv("third_wave_coffee_shop.csv")
        print("Данные успешно загружены!")
        print(f"Первые 5 строк:\n{data.head()}")
    except Exception as e:
        print(f"Ошибка при загрузке: {e}")

'''
Run the script:
python -m src.utils.data_helpers
'''
