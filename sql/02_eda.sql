-- Exploratory analysis on default_clean.

-- name: target_distribution
SELECT
    default_flag,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM default_clean
GROUP BY default_flag
ORDER BY default_flag;

-- name: summary_by_default
SELECT
    default_flag,
    COUNT(*)                     AS n,
    ROUND(AVG(balance), 1)       AS avg_balance,
    ROUND(MEDIAN(balance), 1)    AS median_balance,
    ROUND(AVG(income), 0)        AS avg_income,
    ROUND(MEDIAN(income), 0)     AS median_income,
    ROUND(100 * AVG(is_student), 1) AS pct_student
FROM default_clean
GROUP BY default_flag
ORDER BY default_flag;

-- name: summary_by_student
SELECT
    is_student,
    COUNT(*)                          AS n,
    CAST(SUM(default_flag) AS INTEGER) AS n_default,
    ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
    ROUND(AVG(balance), 0)            AS avg_balance,
    ROUND(AVG(income), 0)             AS avg_income
FROM default_clean
GROUP BY is_student
ORDER BY is_student;

-- name: default_rate_by_balance_band
SELECT
    CAST(FLOOR(balance / 500) * 500 AS INTEGER)       AS balance_from,
    CAST(FLOOR(balance / 500) * 500 + 500 AS INTEGER) AS balance_to,
    COUNT(*)                                          AS n,
    CAST(SUM(default_flag) AS INTEGER)                AS n_default,
    ROUND(100 * AVG(default_flag), 2)                 AS default_rate_pct
FROM default_clean
GROUP BY balance_from, balance_to
ORDER BY balance_from;

-- name: student_paradox
-- Same balance band, student vs non-student default rate.
SELECT
    CAST(FLOOR(balance / 500) * 500 AS INTEGER) AS balance_from,
    COUNT(*) FILTER (WHERE is_student = 0)      AS n_non_student,
    COUNT(*) FILTER (WHERE is_student = 1)      AS n_student,
    ROUND(100 * AVG(default_flag) FILTER (WHERE is_student = 0), 2) AS non_student_rate_pct,
    ROUND(100 * AVG(default_flag) FILTER (WHERE is_student = 1), 2) AS student_rate_pct
FROM default_clean
GROUP BY balance_from
ORDER BY balance_from;

-- name: default_rate_by_income_band
SELECT
    CAST(FLOOR(income / 10000) * 10000 AS INTEGER) AS income_from,
    COUNT(*)                                       AS n,
    CAST(SUM(default_flag) AS INTEGER)             AS n_default,
    ROUND(100 * AVG(default_flag), 2)              AS default_rate_pct
FROM default_clean
GROUP BY income_from
ORDER BY income_from;

-- name: zero_balance
SELECT
    COUNT(*)                           AS n_zero_balance,
    CAST(SUM(default_flag) AS INTEGER) AS n_default,
    CAST(SUM(is_student) AS INTEGER)   AS n_student
FROM default_clean
WHERE balance = 0;

-- name: correlations
SELECT
    ROUND(CORR(balance, default_flag), 3)    AS balance_vs_default,
    ROUND(CORR(income, default_flag), 3)     AS income_vs_default,
    ROUND(CORR(is_student, default_flag), 3) AS student_vs_default,
    ROUND(CORR(balance, income), 3)          AS balance_vs_income,
    ROUND(CORR(is_student, balance), 3)      AS student_vs_balance,
    ROUND(CORR(is_student, income), 3)       AS student_vs_income
FROM default_clean;
