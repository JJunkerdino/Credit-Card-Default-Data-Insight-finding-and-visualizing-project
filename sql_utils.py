import re
from pathlib import Path


def load_queries(path):
    """Split a .sql file into {name: query} using '-- name: <name>' header lines."""
    text = Path(path).read_text(encoding="utf-8")
    parts = re.split(r"^--\s*name:\s*(\w+)\s*$", text, flags=re.M)
    return {name: sql.strip() for name, sql in zip(parts[1::2], parts[2::2])}


def run_sql_file(con, path):
    """Run every named query in order, print SELECT results, and return them as DataFrames."""
    results = {}
    for name, query in load_queries(path).items():
        print(f"\n=== {name} ===")
        rel = con.sql(query)
        if rel is None:
            print("done")
            continue
        df = rel.df()
        print(df.to_string(index=False))
        results[name] = df
    return results
