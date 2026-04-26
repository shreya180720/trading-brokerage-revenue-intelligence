-- Brokerage Intelligence System — Analytical Query Suite
-- PostgreSQL 17
-- Sections: A. Revenue  B. Trading Behaviour  C. Client Lifecycle  D. Operational Impact

-- ─── A. REVENUE ANALYSIS ────────────────────────────────────────────────────

-- A1: Monthly revenue trend with MoM % change
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', t.trade_date)::DATE   AS revenue_month,
        SUM(br.total_revenue)                      AS monthly_revenue
    FROM trades             t
    JOIN brokerage_revenue  br ON br.trade_id = t.trade_id
    GROUP BY 1
)
SELECT
    revenue_month,
    ROUND(monthly_revenue, 2)                                          AS monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY revenue_month)                AS prev_month_revenue,
    ROUND(
        100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY revenue_month))
              / NULLIF(LAG(monthly_revenue) OVER (ORDER BY revenue_month), 0),
        2
    )                                                                  AS mom_pct_change
FROM monthly
ORDER BY revenue_month;

-- A2: Revenue by segment — Equity vs F&O
SELECT
    t.segment,
    COUNT(t.trade_id)                                                  AS total_trades,
    ROUND(SUM(br.total_revenue), 2)                                    AS total_revenue,
    ROUND(100.0 * SUM(br.total_revenue) / SUM(SUM(br.total_revenue)) OVER (), 2)
                                                                       AS revenue_pct
FROM trades             t
JOIN brokerage_revenue  br ON br.trade_id = t.trade_id
GROUP BY t.segment
ORDER BY total_revenue DESC;

-- A3: Revenue by client type — Retail vs HNI
SELECT
    c.client_type,
    COUNT(DISTINCT c.client_id)                                        AS client_count,
    COUNT(t.trade_id)                                                  AS total_trades,
    ROUND(SUM(br.total_revenue), 2)                                    AS total_revenue,
    ROUND(SUM(br.total_revenue) / COUNT(DISTINCT c.client_id), 2)     AS avg_revenue_per_client,
    ROUND(100.0 * SUM(br.total_revenue) / SUM(SUM(br.total_revenue)) OVER (), 2)
                                                                       AS revenue_pct
FROM trades             t
JOIN brokerage_revenue  br ON br.trade_id = t.trade_id
JOIN trading_accounts   ta ON ta.account_id = t.account_id
JOIN clients             c ON c.client_id   = ta.client_id
GROUP BY c.client_type
ORDER BY total_revenue DESC;

-- A4: Top 10 traders by revenue
WITH client_rev AS (
    SELECT
        c.client_id,
        c.name,
        c.client_type,
        c.city,
        ROUND(SUM(br.total_revenue), 2)    AS total_revenue,
        COUNT(t.trade_id)                  AS total_trades
    FROM trades             t
    JOIN brokerage_revenue  br ON br.trade_id    = t.trade_id
    JOIN trading_accounts   ta ON ta.account_id  = t.account_id
    JOIN clients             c ON c.client_id    = ta.client_id
    GROUP BY c.client_id, c.name, c.client_type, c.city
),
grand_total AS (
    SELECT SUM(total_revenue) AS grand FROM client_rev
)
SELECT
    cr.client_id,
    cr.name,
    cr.client_type,
    cr.city,
    cr.total_revenue,
    cr.total_trades,
    ROUND(100.0 * cr.total_revenue / gt.grand, 3)   AS pct_of_total_revenue,
    RANK() OVER (ORDER BY cr.total_revenue DESC)     AS revenue_rank
FROM client_rev cr, grand_total gt
ORDER BY cr.total_revenue DESC
LIMIT 10;

-- A5: Revenue concentration by decile — Pareto analysis
WITH client_rev AS (
    SELECT
        c.client_id,
        SUM(br.total_revenue) AS total_revenue
    FROM trades             t
    JOIN brokerage_revenue  br ON br.trade_id    = t.trade_id
    JOIN trading_accounts   ta ON ta.account_id  = t.account_id
    JOIN clients             c ON c.client_id    = ta.client_id
    GROUP BY c.client_id
),
ranked AS (
    SELECT
        client_id,
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue DESC)   AS decile
    FROM client_rev
)
SELECT
    decile,
    COUNT(client_id)                                           AS clients_in_decile,
    ROUND(SUM(total_revenue), 2)                               AS decile_revenue,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2)
                                                               AS pct_of_total_revenue,
    ROUND(100.0 * SUM(SUM(total_revenue)) OVER (ORDER BY decile
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          / SUM(SUM(total_revenue)) OVER (), 2)                AS cumulative_pct
FROM ranked
GROUP BY decile
ORDER BY decile;

-- A6: Revenue by channel
SELECT
    t.channel,
    COUNT(t.trade_id)                                                  AS total_trades,
    ROUND(SUM(t.trade_value), 2)                                       AS total_trade_value,
    ROUND(SUM(br.total_revenue), 2)                                    AS total_revenue,
    ROUND(AVG(br.total_revenue), 4)                                    AS avg_revenue_per_trade,
    ROUND(100.0 * SUM(br.total_revenue) / SUM(SUM(br.total_revenue)) OVER (), 2)
                                                                       AS revenue_pct
FROM trades             t
JOIN brokerage_revenue  br ON br.trade_id = t.trade_id
GROUP BY t.channel
ORDER BY total_revenue DESC;

-- ─── B. TRADING BEHAVIOUR ───────────────────────────────────────────────────

-- B1: Account dormancy buckets — 30/60/90 day inactivity
SELECT
    status,
    CASE
        WHEN last_trade_date IS NULL                                    THEN 'Never Traded'
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '30 days'      THEN 'Active (<30 days)'
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '60 days'      THEN 'Inactive 30–60 days'
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '90 days'      THEN 'Inactive 60–90 days'
        ELSE                                                             'Dormant (>90 days)'
    END                                AS inactivity_bucket,
    COUNT(*)                           AS account_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
                                       AS pct_of_total
FROM trading_accounts
GROUP BY status,
    CASE
        WHEN last_trade_date IS NULL                               THEN 'Never Traded'
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active (<30 days)'
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '60 days' THEN 'Inactive 30–60 days'
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '90 days' THEN 'Inactive 60–90 days'
        ELSE                                                        'Dormant (>90 days)'
    END
ORDER BY
    CASE
        WHEN last_trade_date IS NULL                               THEN 5
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '60 days' THEN 2
        WHEN last_trade_date >= CURRENT_DATE - INTERVAL '90 days' THEN 3
        ELSE                                                        4
    END;

-- B2: Average trades per active user per month
WITH monthly_active AS (
    SELECT
        DATE_TRUNC('month', t.trade_date)::DATE   AS trade_month,
        ta.client_id,
        COUNT(t.trade_id)                          AS trades_in_month
    FROM trades           t
    JOIN trading_accounts ta ON ta.account_id = t.account_id
    GROUP BY 1, 2
)
SELECT
    trade_month,
    COUNT(DISTINCT client_id)                          AS active_clients,
    SUM(trades_in_month)                               AS total_trades,
    ROUND(SUM(trades_in_month)::NUMERIC / COUNT(DISTINCT client_id), 2)
                                                       AS avg_trades_per_active_user
FROM monthly_active
GROUP BY trade_month
ORDER BY trade_month;

-- B3: Channel × segment trade volume and revenue
-- Already covered in A6 — extended here with segment breakdown
SELECT
    t.channel,
    t.segment,
    COUNT(t.trade_id)                                   AS total_trades,
    ROUND(SUM(t.trade_value), 2)                        AS total_trade_value,
    ROUND(SUM(br.total_revenue), 2)                     AS total_revenue,
    ROUND(AVG(t.trade_value), 2)                        AS avg_trade_value
FROM trades            t
JOIN brokerage_revenue br ON br.trade_id = t.trade_id
GROUP BY t.channel, t.segment
ORDER BY t.channel, total_revenue DESC;

-- B4: Trade frequency trend by segment over time (monthly)
SELECT
    DATE_TRUNC('month', trade_date)::DATE   AS trade_month,
    segment,
    COUNT(trade_id)                          AS total_trades,
    COUNT(DISTINCT account_id)               AS unique_accounts,
    ROUND(COUNT(trade_id)::NUMERIC / COUNT(DISTINCT account_id), 2)
                                             AS trades_per_account
FROM trades
GROUP BY 1, 2
ORDER BY 1, 2;

-- B5: Top 10 most active accounts
WITH acct_stats AS (
    SELECT
        t.account_id,
        ta.account_type,
        ta.status,
        c.client_id,
        c.name,
        c.client_type,
        COUNT(t.trade_id)             AS total_trades,
        ROUND(SUM(br.total_revenue), 2) AS total_revenue
    FROM trades            t
    JOIN brokerage_revenue br ON br.trade_id    = t.trade_id
    JOIN trading_accounts  ta ON ta.account_id  = t.account_id
    JOIN clients            c ON c.client_id    = ta.client_id
    GROUP BY t.account_id, ta.account_type, ta.status, c.client_id, c.name, c.client_type
)
SELECT
    account_id,
    account_type,
    client_id,
    name,
    client_type,
    total_trades,
    total_revenue,
    RANK() OVER (ORDER BY total_trades DESC)   AS activity_rank
FROM acct_stats
ORDER BY total_trades DESC
LIMIT 10;

-- ─── C. CLIENT LIFECYCLE ────────────────────────────────────────────────────

-- C1: Days from onboarding to first trade
WITH first_trade AS (
    SELECT
        ta.client_id,
        MIN(t.trade_date)   AS first_trade_date
    FROM trades            t
    JOIN trading_accounts  ta ON ta.account_id = t.account_id
    GROUP BY ta.client_id
),
lag_days AS (
    SELECT
        c.client_id,
        c.client_type,
        c.onboarding_date,
        ft.first_trade_date,
        (ft.first_trade_date - c.onboarding_date)   AS days_to_first_trade
    FROM clients c
    JOIN first_trade ft ON ft.client_id = c.client_id
)
SELECT
    client_type,
    COUNT(*)                                                       AS clients_with_first_trade,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_first_trade)
                                                                   AS median_days_to_first_trade,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY days_to_first_trade)
                                                                   AS p25_days,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY days_to_first_trade)
                                                                   AS p75_days,
    ROUND(AVG(days_to_first_trade), 1)                             AS avg_days_to_first_trade
FROM lag_days
GROUP BY client_type;

-- C2: Clients who never traded post-onboarding
WITH ever_traded AS (
    SELECT DISTINCT ta.client_id
    FROM trades           t
    JOIN trading_accounts ta ON ta.account_id = t.account_id
)
SELECT
    c.client_type,
    COUNT(c.client_id)                                                 AS total_clients,
    COUNT(et.client_id)                                                AS clients_who_traded,
    COUNT(c.client_id) - COUNT(et.client_id)                           AS clients_never_traded,
    ROUND(100.0 * (COUNT(c.client_id) - COUNT(et.client_id))
                / COUNT(c.client_id), 2)                               AS never_traded_pct
FROM clients c
LEFT JOIN ever_traded et ON et.client_id = c.client_id
GROUP BY c.client_type;

-- C3: Cohort retention at 1 / 3 / 6 months
WITH cohort AS (
    SELECT
        client_id,
        DATE_TRUNC('month', onboarding_date)::DATE   AS cohort_month
    FROM clients
),
cohort_trades AS (
    SELECT
        c.client_id,
        c.cohort_month,
        DATE_TRUNC('month', t.trade_date)::DATE      AS trade_month
    FROM cohort            c
    JOIN trading_accounts  ta ON ta.client_id   = c.client_id
    JOIN trades             t ON t.account_id   = ta.account_id
    GROUP BY c.client_id, c.cohort_month, DATE_TRUNC('month', t.trade_date)::DATE
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT client_id) AS cohort_clients
    FROM cohort
    GROUP BY cohort_month
)
SELECT
    ct.cohort_month,
    cs.cohort_clients,
    COUNT(DISTINCT CASE
        WHEN ct.trade_month = ct.cohort_month + INTERVAL '1 month' THEN ct.client_id
    END)                                                                         AS retained_m1,
    COUNT(DISTINCT CASE
        WHEN ct.trade_month = ct.cohort_month + INTERVAL '3 months' THEN ct.client_id
    END)                                                                         AS retained_m3,
    COUNT(DISTINCT CASE
        WHEN ct.trade_month = ct.cohort_month + INTERVAL '6 months' THEN ct.client_id
    END)                                                                         AS retained_m6,
    ROUND(100.0 * COUNT(DISTINCT CASE
        WHEN ct.trade_month = ct.cohort_month + INTERVAL '1 month' THEN ct.client_id
    END) / NULLIF(cs.cohort_clients, 0), 1)                                      AS retention_pct_m1,
    ROUND(100.0 * COUNT(DISTINCT CASE
        WHEN ct.trade_month = ct.cohort_month + INTERVAL '3 months' THEN ct.client_id
    END) / NULLIF(cs.cohort_clients, 0), 1)                                      AS retention_pct_m3,
    ROUND(100.0 * COUNT(DISTINCT CASE
        WHEN ct.trade_month = ct.cohort_month + INTERVAL '6 months' THEN ct.client_id
    END) / NULLIF(cs.cohort_clients, 0), 1)                                      AS retention_pct_m6
FROM cohort_trades  ct
JOIN cohort_size    cs ON cs.cohort_month = ct.cohort_month
GROUP BY ct.cohort_month, cs.cohort_clients
ORDER BY ct.cohort_month;

-- C4: KYC status impact on activation and revenue
WITH ever_traded AS (
    SELECT
        ta.client_id,
        MIN(t.trade_date)     AS first_trade_date,
        COUNT(t.trade_id)     AS total_trades,
        SUM(br.total_revenue) AS total_revenue
    FROM trades            t
    JOIN brokerage_revenue br ON br.trade_id    = t.trade_id
    JOIN trading_accounts  ta ON ta.account_id  = t.account_id
    GROUP BY ta.client_id
)
SELECT
    c.kyc_status,
    COUNT(c.client_id)                                                  AS total_clients,
    COUNT(et.client_id)                                                 AS clients_who_traded,
    ROUND(AVG(et.first_trade_date - c.onboarding_date), 1)             AS avg_days_to_first_trade,
    ROUND(AVG(et.total_trades), 1)                                      AS avg_trades_per_client,
    ROUND(AVG(et.total_revenue), 2)                                     AS avg_revenue_per_client
FROM clients c
LEFT JOIN ever_traded et ON et.client_id = c.client_id
GROUP BY c.kyc_status;

-- ─── D. OPERATIONAL IMPACT ──────────────────────────────────────────────────

-- D1: Trade frequency — accounts with events vs without
WITH event_accounts AS (
    SELECT DISTINCT account_id FROM operational_events
),
monthly_trades AS (
    SELECT
        account_id,
        DATE_TRUNC('month', trade_date)::DATE   AS trade_month,
        COUNT(trade_id)                          AS monthly_trade_count
    FROM trades
    GROUP BY account_id, DATE_TRUNC('month', trade_date)::DATE
),
account_avg AS (
    SELECT
        mt.account_id,
        ROUND(AVG(mt.monthly_trade_count), 2)    AS avg_monthly_trades,
        CASE WHEN ea.account_id IS NOT NULL THEN 'Had Events' ELSE 'No Events' END
                                                 AS event_group
    FROM monthly_trades     mt
    LEFT JOIN event_accounts ea ON ea.account_id = mt.account_id
    GROUP BY mt.account_id, ea.account_id
)
SELECT
    event_group,
    COUNT(account_id)                                   AS account_count,
    ROUND(AVG(avg_monthly_trades), 2)                   AS avg_monthly_trades,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
          (ORDER BY avg_monthly_trades)::NUMERIC, 2)    AS median_monthly_trades
FROM account_avg
GROUP BY event_group;

-- D2: Operational events in 30 days pre-dormancy
WITH dormant_accounts AS (
    SELECT
        account_id,
        last_trade_date
    FROM trading_accounts
    WHERE status = 'Dormant'
      AND last_trade_date IS NOT NULL
),
pre_dormancy_events AS (
    SELECT
        da.account_id,
        da.last_trade_date,
        COUNT(oe.event_id)          AS events_in_30d_pre_dormancy
    FROM dormant_accounts da
    LEFT JOIN operational_events oe
           ON oe.account_id = da.account_id
          AND oe.event_date BETWEEN da.last_trade_date - INTERVAL '30 days'
                                AND da.last_trade_date
    GROUP BY da.account_id, da.last_trade_date
)
SELECT
    CASE
        WHEN events_in_30d_pre_dormancy = 0 THEN 'No events before dormancy'
        WHEN events_in_30d_pre_dormancy = 1 THEN '1 event'
        WHEN events_in_30d_pre_dormancy = 2 THEN '2 events'
        ELSE '3+ events'
    END                                     AS event_bucket,
    COUNT(account_id)                       AS dormant_accounts,
    ROUND(100.0 * COUNT(account_id) /
          SUM(COUNT(account_id)) OVER (), 2) AS pct_of_dormant
FROM pre_dormancy_events
GROUP BY event_bucket
ORDER BY dormant_accounts DESC;

-- D3: Resolution time quartiles — HNI vs Retail
WITH resolution_stats AS (
    SELECT
        c.client_type,
        oe.event_type,
        ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP
              (ORDER BY oe.resolution_time_hours)::NUMERIC, 2)  AS p25_hours,
        ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP
              (ORDER BY oe.resolution_time_hours)::NUMERIC, 2)  AS median_hours,
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP
              (ORDER BY oe.resolution_time_hours)::NUMERIC, 2)  AS p75_hours,
        ROUND(AVG(oe.resolution_time_hours)::NUMERIC, 2)        AS avg_hours,
        COUNT(oe.event_id)                                       AS total_events
    FROM operational_events oe
    JOIN trading_accounts   ta ON ta.account_id = oe.account_id
    JOIN clients             c ON c.client_id   = ta.client_id
    GROUP BY c.client_type, oe.event_type
)
SELECT * FROM resolution_stats
ORDER BY client_type, event_type;

-- D4: Trade volume 30 days before vs after each event
WITH event_windows AS (
    SELECT
        oe.event_id,
        oe.account_id,
        oe.event_date,
        oe.event_type,
        c.client_type,
        -- trades in 30 days before event
        COUNT(t_pre.trade_id)    AS trades_before,
        -- trades in 30 days after event
        COUNT(t_post.trade_id)   AS trades_after
    FROM operational_events oe
    JOIN trading_accounts   ta   ON ta.account_id = oe.account_id
    JOIN clients             c   ON c.client_id   = ta.client_id
    LEFT JOIN trades t_pre
           ON t_pre.account_id = oe.account_id
          AND t_pre.trade_date BETWEEN oe.event_date - INTERVAL '30 days'
                                   AND oe.event_date - INTERVAL '1 day'
    LEFT JOIN trades t_post
           ON t_post.account_id = oe.account_id
          AND t_post.trade_date BETWEEN oe.event_date + INTERVAL '1 day'
                                    AND oe.event_date + INTERVAL '30 days'
    GROUP BY oe.event_id, oe.account_id, oe.event_date, oe.event_type, c.client_type
)
SELECT
    event_type,
    client_type,
    COUNT(event_id)                                             AS total_events,
    ROUND(AVG(trades_before), 2)                               AS avg_trades_30d_before,
    ROUND(AVG(trades_after), 2)                                AS avg_trades_30d_after,
    ROUND(AVG(trades_after) - AVG(trades_before), 2)           AS avg_trade_delta,
    ROUND(100.0 * (AVG(trades_after) - AVG(trades_before))
                / NULLIF(AVG(trades_before), 0), 1)            AS pct_change
FROM event_windows
GROUP BY event_type, client_type
ORDER BY event_type, client_type;

-- D5: Event type → dormancy rate within 60 days
WITH event_to_dormancy AS (
    SELECT
        oe.account_id,
        oe.event_type,
        oe.event_date,
        ta.last_trade_date,
        ta.status,
        CASE
            WHEN ta.status = 'Dormant'
             AND ta.last_trade_date IS NOT NULL
             AND ta.last_trade_date BETWEEN oe.event_date
                                        AND oe.event_date + INTERVAL '60 days'
            THEN 1 ELSE 0
        END AS went_dormant_post_event
    FROM operational_events oe
    JOIN trading_accounts   ta ON ta.account_id = oe.account_id
)
SELECT
    event_type,
    COUNT(*)                                                    AS total_events,
    SUM(went_dormant_post_event)                                AS accounts_went_dormant,
    ROUND(100.0 * SUM(went_dormant_post_event) / COUNT(*), 2)  AS dormancy_rate_pct
FROM event_to_dormancy
GROUP BY event_type
ORDER BY dormancy_rate_pct DESC;
