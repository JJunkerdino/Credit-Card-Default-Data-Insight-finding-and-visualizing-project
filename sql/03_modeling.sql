-- Model evaluation on test_predictions(customer_id, default_flag, balance, is_student, prob_default).
-- $threshold = probability cutoff above which a customer is flagged as a likely defaulter.

-- name: confusion_matrix
WITH c AS (
    SELECT
        COUNT(*) FILTER (WHERE default_flag = 1 AND prob_default >= $threshold) AS caught_defaulters,
        COUNT(*) FILTER (WHERE default_flag = 1 AND prob_default <  $threshold) AS missed_defaulters,
        COUNT(*) FILTER (WHERE default_flag = 0 AND prob_default >= $threshold) AS false_alarms,
        COUNT(*) FILTER (WHERE default_flag = 0 AND prob_default <  $threshold) AS correct_no
    FROM test_predictions
)
SELECT
    *,
    ROUND(100.0 * caught_defaulters / (caught_defaulters + missed_defaulters), 1)       AS recall_pct,
    ROUND(100.0 * caught_defaulters / NULLIF(caught_defaulters + false_alarms, 0), 1)   AS precision_pct
FROM c;

-- name: risk_deciles
-- Decile 1 = the 10% of customers the model thinks are most risky.
WITH ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY prob_default DESC) AS decile
    FROM test_predictions
)
SELECT
    decile,
    COUNT(*)                                AS n,
    CAST(SUM(default_flag) AS INTEGER)      AS n_default,
    ROUND(100 * AVG(default_flag), 2)       AS actual_default_rate_pct,
    ROUND(100 * MIN(prob_default), 2)       AS min_predicted_pct,
    ROUND(100 * MAX(prob_default), 2)       AS max_predicted_pct,
    ROUND(100.0 * SUM(SUM(default_flag)) OVER (ORDER BY decile)
                / SUM(SUM(default_flag)) OVER (), 1) AS cum_pct_of_defaulters
FROM ranked
GROUP BY decile
ORDER BY decile;

-- name: risk_bands
SELECT
    CASE
        WHEN prob_default < 0.05 THEN '1. Low (<5%)'
        WHEN prob_default < 0.20 THEN '2. Medium (5-20%)'
        WHEN prob_default < 0.50 THEN '3. High (20-50%)'
        ELSE '4. Very high (50%+)'
    END                                                            AS risk_band,
    COUNT(*)                                                       AS n_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)             AS pct_of_customers,
    CAST(SUM(default_flag) AS INTEGER)                             AS n_default,
    ROUND(100 * AVG(prob_default), 1)                              AS avg_predicted_pct,
    ROUND(100 * AVG(default_flag), 1)                              AS actual_default_rate_pct,
    ROUND(100.0 * SUM(default_flag) / SUM(SUM(default_flag)) OVER (), 1) AS pct_of_all_defaulters
FROM test_predictions
GROUP BY risk_band
ORDER BY risk_band;
