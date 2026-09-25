from pathlib import Path

import duckdb
import pandas as pd

from sql_utils import run_sql_file

ROOT = Path(__file__).parent
DATA_DIR = ROOT / "data"
DATA_DIR.mkdir(exist_ok=True)

raw = pd.read_excel(ROOT / "Default.xlsx", sheet_name="Default")

con = duckdb.connect(str(DATA_DIR / "default.duckdb"))
con.register("raw_df", raw)
con.execute("CREATE OR REPLACE TABLE raw_default AS SELECT * FROM raw_df")

results = run_sql_file(con, ROOT / "01_cleaning.sql")

assert results["validate_clean"].loc[0, "n_null"] == 0, "Clean table has NULLs - check category values"

clean = con.sql("SELECT * FROM default_clean ORDER BY customer_id").df()
clean.to_csv(DATA_DIR / "default_clean.csv", index=False)
print(f"\nSaved {len(clean):,} rows to data/default_clean.csv and table default_clean in data/default.duckdb")

con.close()
