import pandas as pd
from loguru import logger

def validate_data(df):
    """Validate DataFrame for missing values, duplicates, and data types."""
    logger.info("Validating data...")
    validation_results = {
        "missing_values": df.isnull().sum().to_dict(),
        "duplicates": df.duplicated().sum(),
        "row_count": len(df),
        "column_types": df.dtypes.to_dict()
    }
    logger.info(f"Validation results: {validation_results}")
    return validation_results


'''Usage:
from src.confirm import validate_data

# Validate DataFrame
results = validate_data(df)
print(results)'''
