import os
from pathlib import Path
from kaggle.api.kaggle_api_extended import KaggleApi
from config import KAGGLE_USERNAME, KAGGLE_KEY, RAW_DATA_DIR
from loguru import logger

def download_kaggle_dataset(dataset_slug, output_dir=RAW_DATA_DIR):
    """Download a Kaggle dataset to the specified directory."""
    try:
        os.environ["KAGGLE_USERNAME"] = KAGGLE_USERNAME
        os.environ["KAGGLE_KEY"] = KAGGLE_KEY
        api = KaggleApi()
        api.authenticate()
        logger.info(f"Downloading dataset {dataset_slug} to {output_dir}")
        api.dataset_download_files(dataset_slug, path=output_dir, unzip=True)
        logger.info("Download completed successfully")
    except Exception as e:
        logger.error(f"Failed to download dataset: {e}")
        raise


if __name__ == "__main__":
    download_kaggle_dataset("minahilfatima12328/daily-coffee-transactions")
    
    ''' Run the script:
python -m src.utils.01_data_acquisition''' 


# https://www.kaggle.com/datasets/minahilfatima12328/daily-coffee-transactions
