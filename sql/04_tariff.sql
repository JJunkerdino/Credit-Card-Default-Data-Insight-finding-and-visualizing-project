-- Risk grades and tariff (pricing) table.
-- Tables: scored(customer_id, default_flag, balance, is_student, prob_default)
--         grade_bands(grade, label, pd_range, pd_from, pd_to)
-- Money assumptions come in as $parameters (all are yearly rates, e.g. 0.03 = 3%).

-- name: grade_summary
SELECT
    g.grade,
    g.label,
    g.pd_range,
    COUNT(*)                                                    AS n_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_of_customers,
    CAST(SUM(s.default_flag) AS INTEGER)                        AS n_default,
    ROUND(100 * AVG(s.prob_default), 2)                         AS predicted_pd_pct,
    ROUND(100 * AVG(s.default_flag), 2)                         AS actual_default_pct,
    ROUND(AVG(s.balance), 0)                                    AS avg_balance,
    ROUND($lgd * SUM(s.prob_default * s.balance), 0)            AS expected_loss,
    ROUND($lgd * SUM(s.default_flag * s.balance), 0)            AS actual_loss,
    ROUND(100.0 * SUM(s.prob_default * s.balance)
                / SUM(SUM(s.prob_default * s.balance)) OVER (), 1) AS pct_of_expected_loss
FROM scored AS s
JOIN grade_bands AS g
  ON s.prob_default >= g.pd_from AND s.prob_default < g.pd_to
GROUP BY g.grade, g.label, g.pd_range
ORDER BY g.grade;

-- name: tariff_table
-- Required rate = cost of funds + operating cost + expected loss rate (PD x LGD) + target margin.
-- The bank can charge at most $rate_cap, so risky grades are managed with limits, not price.
WITH by_grade AS (
    SELECT
        g.grade,
        g.label,
        g.pd_range,
        COUNT(*)            AS n_customers,
        AVG(s.prob_default) AS pd,
        SUM(s.balance)      AS total_balance
    FROM scored AS s
    JOIN grade_bands AS g
      ON s.prob_default >= g.pd_from AND s.prob_default < g.pd_to
    GROUP BY g.grade, g.label, g.pd_range
),
priced AS (
    SELECT
        *,
        pd * $lgd                                                      AS el_rate,
        $cost_of_funds + $operating_cost + pd * $lgd + $target_margin  AS required_rate
    FROM by_grade
),
capped AS (
    SELECT
        *,
        LEAST(required_rate, $rate_cap)                                AS offered_rate,
        LEAST(required_rate, $rate_cap) - $cost_of_funds - $operating_cost - el_rate AS profit_rate
    FROM priced
)
SELECT
    grade,
    label,
    pd_range,
    n_customers,
    ROUND(100 * pd, 2)                   AS predicted_pd_pct,
    ROUND(100 * el_rate, 2)              AS expected_loss_rate_pct,
    ROUND(100 * required_rate, 1)        AS required_rate_pct,
    ROUND(100 * offered_rate, 1)         AS offered_rate_pct,
    ROUND(100 * profit_rate, 1)          AS profit_rate_pct,
    ROUND(total_balance * profit_rate, 0) AS expected_profit,
    CASE
        WHEN required_rate <= $rate_cap AND pd < 0.01 THEN 'Lower rate; can offer limit increase'
        WHEN required_rate <= $rate_cap              THEN 'Risk-based rate; keep standard limit'
        WHEN profit_rate >= 0                        THEN 'Charge the cap; no limit increase; monitor monthly'
        WHEN pd < 0.50                               THEN 'Freeze limit; early reminder; offer payment plan'
        ELSE                                              'Block new spending; collections or restructuring'
    END AS action
FROM capped
ORDER BY grade;
