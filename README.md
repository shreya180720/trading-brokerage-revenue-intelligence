# Brokerage Intelligence System

End-to-end analytics project simulating the data infrastructure and business intelligence output of a mid-size Indian brokerage firm. Built to demonstrate production-quality SQL, Python data engineering, and Power BI dashboard design.

---

## Business Problem

Four operational questions drive this project:

1. Where is brokerage revenue actually coming from — segment, client type, channel?
2. Which traders drive disproportionate revenue, and how dependent are we on them?
3. How do we identify and re-engage dormant accounts before they churn permanently?
4. Are operational failures (app crashes, order failures, KYC delays) suppressing trading activity?

---

## Dataset

| Metric | Value |
|---|---|
| Clients | 5,000 |
| Trading accounts | 7,972 |
| Trades | 1,690,788 |
| Revenue rows | 1,690,788 |
| Operational events | 1,795 |
| Simulation period | January 2024 – December 2025 |
| Total brokerage revenue | ₹82,198,666 |

All data is synthetic, generated using Faker and NumPy to reflect Aditya Birla market behaviour.

---

## Schema

```
clients (5,000 rows)
  ├── client_id, name, age, city, state
  ├── client_type      [Retail | HNI]
  ├── risk_profile     [Conservative | Moderate | Aggressive]
  ├── onboarding_date
  └── kyc_status       [Pending | Verified]
          │ 1:N
          ▼
trading_accounts (7,972 rows)
  ├── account_id, client_id
  ├── account_type     [Equity | F&O | Intraday | Delivery]
  ├── status           [Active | Dormant | Suspended]
  ├── created_date
  └── last_trade_date
          │ 1:N                    │ 1:N
          ▼                        ▼
trades (1,690,788 rows)     operational_events (1,795 rows)
  ├── trade_id                ├── event_id
  ├── account_id              ├── account_id
  ├── segment [Equity | F&O]  ├── event_type
  ├── trade_value (computed)  ├── event_date
  ├── trade_date              └── resolution_time_hours
  └── channel
          │ 1:1
          ▼
brokerage_revenue (1,690,788 rows)
  ├── trade_id (UNIQUE)
  ├── brokerage_fee
  ├── transaction_charges
  └── total_revenue (computed)
```

**Design notes:**
- `trade_value` and `total_revenue` use PostgreSQL `GENERATED ALWAYS AS STORED` — computed at write time, physically stored for fast aggregation
- `brokerage_revenue` enforces a `UNIQUE` constraint on `trade_id` — strict 1:1 mapping prevents double-counting
- `vw_trade_full` is a denormalised view joining all five tables — used as the primary Power BI data source

---

## Tech Stack

| Layer | Tool |
|---|---|
| Database | PostgreSQL 17 |
| Data generation | Python 3.13 · Faker · Pandas · NumPy · SQLAlchemy |
| Visualisation | Power BI Desktop |
| Version control | GitHub |

---

## Project Structure

```
brokerage-intelligence-system/
├── schema.sql           PostgreSQL DDL — tables, indexes, computed columns, view
├── generate_data.py     Synthetic data generator — 5,000 clients, 1.7M trades
├── analysis.sql         20 analytical queries across 4 business sections
├── insights.md          10 business insights backed by actual query results
├── dashboard_design.md  Power BI dashboard specification — 4 pages, 20 visuals
├── dashboard.pbix       Power BI report file
├── requirements.txt     Python dependencies
└── README.md
```

---

## Analysis Sections

### A — Revenue Analysis
| Query | Business Question |
|---|---|
| Monthly trend + MoM % | Is revenue growing or declining? |
| Equity vs F&O split | Which segment is the revenue engine? |
| Retail vs HNI | How concentrated is revenue in premium clients? |
| Top 10 traders | Who are the highest-value clients? |
| Pareto — decile analysis | Does 80/20 hold? Where exactly? |
| Channel breakdown | Where should product investment go? |

### B — Trading Behaviour
| Query | Business Question |
|---|---|
| Dormancy buckets (30/60/90d) | How many accounts are drifting toward churn? |
| Avg trades per active user/month | How engaged is the active base? |
| Channel × segment breakdown | Which channel serves which segment? |
| Trade frequency trend | Is trading growing in each segment? |

### C — Client Lifecycle
| Query | Business Question |
|---|---|
| Days to first trade | How fast do clients activate post-onboarding? |
| Never-traded clients | What % of the base never engaged? |
| Cohort retention — 1/3/6 months | Where does the retention cliff occur? |
| KYC status impact | Does pending KYC suppress trading? |

### D — Operational Impact
| Query | Business Question |
|---|---|
| Event vs no-event trade frequency | Do platform failures reduce trading? |
| Pre-dormancy event window | Are failures a leading churn indicator? |
| Resolution time — HNI vs Retail | How differentiated is our SLA in practice? |
| Pre/post event trade delta | What is the per-event-type suppression effect? |
| Event → dormancy rate | Which failure type most reliably causes churn? |

---

## Key Findings

| # | Finding |
|---|---|
| 1 | Equity is 67.6% of trades but **86.56% of revenue (₹71.15M)** — F&O fee rates are ~10× lower |
| 2 | HNI clients (10.5% of base) average **₹47,035 revenue/client** vs ₹14,190 for Retail — a 3.3× gap |
| 3 | Top 10% of clients contribute **31.98% of revenue**; top 40% account for 79.47% |
| 4 | Mobile drives **59.92% of revenue** (1,014,306 trades); Dealer handles the highest-value F&O orders |
| 5 | Monthly revenue peaked at **₹4.6M (Jan 2024)** and stabilised at ₹3.5–3.7M through mid-2025 |
| 6 | Avg trades per active user fell from **37.58 (Jan 2024) to 9.61 (Dec 2025)** — engagement declining despite client growth |
| 7 | Top trader: Zilmil Raja (HNI, Kanpur) — **₹89,428 revenue, 1,860 trades**, 0.109% of total |
| 8 | Operational events correlate with reduced post-event trading — Order Failure has the highest dormancy rate |
| 9 | HNI resolution time: **~4 hours median** vs **~18 hours for Retail** — 4.5× difference, not formalised as SLA |
| 10 | KYC-Pending clients generate significantly less revenue than Verified clients in the same onboarding cohort |

---

## How to Run

### Prerequisites
- PostgreSQL 17 running on port 5433
- Python 3.10+

### Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Create database
createdb -U postgres -p 5433 brokerage_db

# Load schema
psql -U postgres -p 5433 -d brokerage_db -f schema.sql

# Generate and load data (~90 seconds)
DATABASE_URL="postgresql://postgres:password@localhost:5433/brokerage_db" python generate_data.py

# Run analysis queries
psql -U postgres -p 5433 -d brokerage_db -f analysis.sql
```

### Power BI
1. Open `dashboard.pbix` in Power BI Desktop
2. Update data source credentials if needed: **Home → Transform data → Data source settings**
3. Click **Refresh**

---

## Dashboard Pages

| Page | Focus |
|---|---|
| Revenue Intelligence | Monthly trend, segment split, top traders, Pareto, channel breakdown |
| Trading Activity | Dormancy funnel, engagement trend, channel × segment heatmap |
| Client Lifecycle | Cohort retention heatmap, days to first trade, never-traded analysis |
| Operational Intelligence | Event impact, resolution time comparison, churn risk scatter |
