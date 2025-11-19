import argparse
import logging
from pathlib import Path
import pandas as pd
import sys


def setup_logging(verbose: bool):
    """Настройка логирования."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )


def safe_filename(name: str) -> str:
    """Заменяем недопустимые символы в именах файлов."""
    return "".join(c if (c.isalnum() or c in " _-") else "_" for c in name).strip()


def xlsx_to_csv(input_file: Path, output_file: Path, sheet: str | None = None):
    """Конвертирует Excel (все листы или один) в CSV."""

    try:
        sheets = pd.read_excel(input_file, sheet_name=None)
    except Exception as e:
        logging.error(f"Не удалось загрузить файл {input_file}: {e}")
        sys.exit(1)

    if sheet:
        # Пользователь указал конкретный лист
        if sheet not in sheets:
            logging.error(f"Лист '{sheet}' не найден в {input_file}. Доступные листы: {list(sheets.keys())}")
            sys.exit(1)

        df = sheets[sheet].dropna(how="all")
        out_path = output_file
        out_path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(out_path, index=False, encoding="utf-8-sig")
        logging.info(f"Сохранён лист '{sheet}' в {out_path}")
    else:
        # Если лист не указан
        if len(sheets) == 1:
            # Всего один лист
            df = next(iter(sheets.values())).dropna(how="all")
            out_path = output_file
            out_path.parent.mkdir(parents=True, exist_ok=True)
            df.to_csv(out_path, index=False, encoding="utf-8-sig")
            logging.info(f"Сохранён единственный лист в {out_path}")
        else:
            # Несколько листов → сохраняем в папку
            output_file.mkdir(parents=True, exist_ok=True)
            for sheet_name, df in sheets.items():
                safe_name = safe_filename(sheet_name)
                out_path = output_file / f"{safe_name}.csv"
                df = df.dropna(how="all")
                df.to_csv(out_path, index=False, encoding="utf-8-sig")
                logging.info(f"Сохранён лист '{sheet_name}' в {out_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Конвертация XLSX → CSV с помощью pandas"
    )
    parser.add_argument("--in", dest="input", required=True,
                        help="Путь к входному Excel-файлу (.xlsx)")
    parser.add_argument("--out", dest="output", required=True,
                        help="Путь к выходному CSV-файлу или папке")
    parser.add_argument("--sheet", dest="sheet", default=None,
                        help="Имя листа (если нужно конвертировать только один)")
    parser.add_argument("--verbose", action="store_true",
                        help="Включить подробные логи (DEBUG)")

    args = parser.parse_args()

    setup_logging(args.verbose)

    input_file = Path(args.input)
    output_file = Path(args.output)

    if not input_file.exists():
        logging.error(f"Файл {input_file} не найден")
        sys.exit(1)

    xlsx_to_csv(input_file, output_file, args.sheet)


if __name__ == "__main__":
    main()

'''python3 src/utils/xlsx_parsing_prod_pd.py \
  --in "data/raw/Coffee_shop_sales.xlsx" \
  --out "data/processed/coffee_sales.csv"'''
