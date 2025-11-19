import pandas as pd
from sklearn.preprocessing import OneHotEncoder, OrdinalEncoder
from loguru import logger
from config import RAW_DATA_DIR, PROCESSED_DATA_DIR

def encode_categorical(df, columns, method='onehot', handle_unknown='ignore'):
    if method == 'onehot':
        encoder = OneHotEncoder(sparse_output=False, handle_unknown=handle_unknown)
        encoded = pd.DataFrame(encoder.fit_transform(df[columns]), columns=encoder.get_feature_names_out(columns))
        df = pd.concat([df.drop(columns, axis=1), encoded], axis=1)
    elif method == 'ordinal':
        encoder = OrdinalEncoder(handle_unknown='use_encoded_value', unknown_value=-1)
        df[columns] = encoder.fit_transform(df[columns])
    logger.info(f"Encoded {columns} using {method}")
    return df

''' 
Encoding Categorical Variables:

* Categorical data like city needs encoding:
 Use OneHotEncoder for nominal data or
 OrdinalEncoder for ordered categories. 
 Handle missing or unknown values 
 with parameters like handle_unknown='infrequent_if_exist
 
 Usage: df = encode_categorical(df, columns=['city'], method='onehot')

One-Hot Encoding — создаёт отдельный бинарный столбец (0/1) для каждой категории.

Ordinal Encoding — присваивает каждой категории порядковый номер (0, 1, 2...).

* Создаём объект OneHotEncoder.

* sparse_output=False 

По умолчанию OneHotEncoder возвращает разреженную матрицу (sparse matrix), 
которая экономит память, но не совместима напрямую с pandas DataFrame. 
Чтобы получить обычный массив чисел (dense array), нужно явно указать sparse_output=False
 '''
