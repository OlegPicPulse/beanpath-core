import pandas as pd
from sklearn.preprocessing import OneHotEncoder, OrdinalEncoder
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from loguru import logger
from config import RAW_DATA_DIR, PROCESSED_DATA_DIR

def build_preprocessing_pipeline(num_cols, cat_cols):
    num_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy='mean')),
        ('scaler', StandardScaler())
    ])
    cat_transformer = Pipeline(steps=[
        ('imputer', SimpleImputer(strategy='most_frequent')),
        ('encoder', OneHotEncoder(handle_unknown='ignore'))
    ])
    preprocessor = ColumnTransformer(transformers=[
        ('num', num_transformer, num_cols),
        ('cat', cat_transformer, cat_cols)
    ])
    return preprocessor
'''
# Usage in notebook
num_cols = ['pm25', 'pm10']
cat_cols = ['city']
pipeline = build_preprocessing_pipeline(num_cols, cat_cols)
processed_data = pipeline.fit_transform(df)

# Пример данных
df = pd.DataFrame({
    'pm25': [10, 20, None, 40],
    'pm10': [15, None, 35, 45],
    'city': ['Moscow', 'SPB', None, 'Moscow']
})

num_cols = ['pm25', 'pm10']
cat_cols = ['city']

pipeline = build_preprocessing_pipeline(num_cols, cat_cols)
processed_data = pipeline.fit_transform(df)

print(processed_data)
'''

