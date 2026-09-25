-- Data quality checks on raw_default, then build the clean table default_clean.
-- Note: "default" is a SQL keyword, so it must be written in double quotes.

-- name: row_count
SELECT
    COUNT(*)                 AS n_rows,
    COUNT(DISTINCT rownames) AS n_unique_ids
FROM raw_default;

-- name: missing_values
SELECT
    COUNT(*) - COUNT(rownames)  AS missing_rownames,
    COUNT(*) - COUNT("default") AS missing_default,
    COUNT(*) - COUNT(student)   AS missing_student,
    COUNT(*) - COUNT(balance)   AS missing_balance,
    COUNT(*) - COUNT(income)    AS missing_income
FROM raw_default;

-- name: duplicate_rows
SELECT CAST(COALESCE(SUM(n - 1), 0) AS INTEGER) AS duplicate_rows
FROM (
    SELECT COUNT(*) AS n
    FROM raw_default
    GROUP BY "default", student, balance, income
    HAVING COUNT(*) > 1
);

-- name: category_values
SELECT 'default' AS column_name, "default" AS value, COUNT(*) AS n
FROM raw_default GROUP BY "default"
UNION ALL
SELECT 'student', student, COUNT(*)
FROM raw_default GROUP BY student
ORDER BY column_name, value;

-- name: numeric_ranges
SELECT
    'balance'                                AS column_name,
    ROUND(MIN(balance), 2)                   AS min,
    ROUND(MAX(balance), 2)                   AS max,
    ROUND(AVG(balance), 2)                   AS mean,
    COUNT(*) FILTER (WHERE balance < 0)      AS n_negative,
    COUNT(*) FILTER (WHERE balance = 0)      AS n_zero
FROM raw_default
UNION ALL
SELECT
    'income',
    ROUND(MIN(income), 2),
    ROUND(MAX(income), 2),
    ROUND(AVG(income), 2),
    COUNT(*) FILTER (WHERE income < 0),
    COUNT(*) FILTER (WHERE income = 0)
FROM raw_default;

-- name: outliers_iqr
WITH q AS (
    SELECT
        QUANTILE_CONT(balance, 0.25) AS b_q1, QUANTILE_CONT(balance, 0.75) AS b_q3,
        QUANTILE_CONT(income, 0.25)  AS i_q1, QUANTILE_CONT(income, 0.75)  AS i_q3
    FROM raw_default
)
SELECT
    COUNT(*) FILTER (WHERE balance > b_q3 + 1.5 * (b_q3 - b_q1)
                        OR balance < b_q1 - 1.5 * (b_q3 - b_q1)) AS balance_outliers,
    COUNT(*) FILTER (WHERE balance > b_q3 + 1.5 * (b_q3 - b_q1)
                       AND "default" = 'Yes')                    AS balance_outliers_defaulted,
    COUNT(*) FILTER (WHERE income > i_q3 + 1.5 * (i_q3 - i_q1)
                        OR income < i_q1 - 1.5 * (i_q3 - i_q1))  AS income_outliers
FROM raw_default, q;

-- name: create_clean_table
-- Unexpected category values become NULL so the validation step below catches them.
CREATE OR REPLACE TABLE default_clean AS
SELECT
    CAST(rownames AS INTEGER) AS customer_id,
    CASE UPPER(TRIM("default")) WHEN 'YES' THEN 1 WHEN 'NO' THEN 0 END AS default_flag,
    CASE UPPER(TRIM(student))   WHEN 'YES' THEN 1 WHEN 'NO' THEN 0 END AS is_student,
    CAST(balance AS DOUBLE) AS balance,
    CAST(income  AS DOUBLE) AS income
FROM raw_default;

-- name: validate_clean
SELECT
    COUNT(*) AS n_rows,
    COUNT(*) FILTER (WHERE default_flag IS NULL OR is_student IS NULL
                        OR balance IS NULL OR income IS NULL) AS n_null,
    CAST(SUM(default_flag) AS INTEGER) AS n_default,
    CAST(SUM(is_student) AS INTEGER)   AS n_student
FROM default_clean;
