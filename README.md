<div align="center">

# 📊 Brokerage Intelligence System

**End-to-end analytics simulation of a mid-size Indian brokerage firm**

*Production-quality SQL · Python data engineering · Power BI dashboard*

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Python](https://img.shields.io/badge/Python-3.13-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)
[![GitHub](https://img.shields.io/badge/GitHub-Portfolio-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/shreya180720/trading-brokerage-revenue-intelligence)

</div>

---

## 🎯 Business Problem

Four operational questions drive this project:

| # | Question |
|---|---|
| 💰 | Where is brokerage revenue actually coming from — segment, client type, channel? |
| 📈 | Which traders drive disproportionate revenue, and how dependent are we on them? |
| 😴 | How do we identify and re-engage dormant accounts before they churn permanently? |
| ⚠️ | Are operational failures (app crashes, order failures, KYC delays) suppressing trading activity? |

---

## 📦 Dataset

<div align="center">

| Metric | Value |
|:---|---:|
| 👥 Clients | 5,000 |
| 🏦 Trading Accounts | 7,972 |
| 🔄 Trades | 1,690,788 |
| 💵 Revenue Rows | 1,690,788 |
| 🚨 Operational Events | 1,795 |
| 📅 Simulation Period | January 2024 – December 2025 |
| 💰 Total Brokerage Revenue | **₹82,198,666** |

</div>

> All data is synthetic, generated using Faker and NumPy to reflect Aditya Birla market behaviour.

---

## 🗂️ Schema

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

**⚙️ Design notes:**
- `trade_value` and `total_revenue` use PostgreSQL `GENERATED ALWAYS AS STORED` — computed at write time, physically stored for fast aggregation
- `brokerage_revenue` enforces a `UNIQUE` constraint on `trade_id` — strict 1:1 mapping prevents double-counting
- `vw_trade_full` is a denormalised view joining all five tables — used as the primary Power BI data source

---

## 🛠️ Tech Stack

<div align="center">

| Layer | Tool |
|:---|:---|
| 🗄️ Database | PostgreSQL 17 |
| 🐍 Data Generation | Python 3.13 · Faker · Pandas · NumPy · SQLAlchemy |
| 📊 Visualisation | Power BI Desktop |
| 🔧 Version Control | GitHub |

</div>

---

## 📁 Project Structure

```
trading-brokerage-revenue-intelligence/
│
├── 📂 data/
│   └── generate_data.py        Synthetic data generator — 5,000 clients, 1.7M trades
│
├── 📂 sql/
│   ├── schema.sql               PostgreSQL DDL — tables, indexes, computed columns, view
│   └── analysis.sql             20 analytical queries across 4 business sections
│
├── 📂 dashboard/
│   └── dashboard.pbix           Power BI report — 4 pages, 20+ visuals
│
├── 📂 docs/
│   ├── insights.md              10 business insights backed by actual query results
│   └── dashboard_design.md      Full Power BI specification — DAX measures, layouts, slicers
│
├── requirements.txt
└── README.md
```

---

## 🔍 Analysis Sections

<details>
<summary><b>💰 A — Revenue Analysis</b></summary>

| Query | Business Question |
|---|---|
| Monthly trend + MoM % | Is revenue growing or declining? |
| Equity vs F&O split | Which segment is the revenue engine? |
| Retail vs HNI | How concentrated is revenue in premium clients? |
| Top 10 traders | Who are the highest-value clients? |
| Pareto — decile analysis | Does 80/20 hold? Where exactly? |
| Channel breakdown | Where should product investment go? |

</details>

<details>
<summary><b>📈 B — Trading Behaviour</b></summary>

| Query | Business Question |
|---|---|
| Dormancy buckets (30/60/90d) | How many accounts are drifting toward churn? |
| Avg trades per active user/month | How engaged is the active base? |
| Channel × segment breakdown | Which channel serves which segment? |
| Trade frequency trend | Is trading growing in each segment? |

</details>

<details>
<summary><b>🔄 C — Client Lifecycle</b></summary>

| Query | Business Question |
|---|---|
| Days to first trade | How fast do clients activate post-onboarding? |
| Never-traded clients | What % of the base never engaged? |
| Cohort retention — 1/3/6 months | Where does the retention cliff occur? |
| KYC status impact | Does pending KYC suppress trading? |

</details>

<details>
<summary><b>⚠️ D — Operational Impact</b></summary>

| Query | Business Question |
|---|---|
| Event vs no-event trade frequency | Do platform failures reduce trading? |
| Pre-dormancy event window | Are failures a leading churn indicator? |
| Resolution time — HNI vs Retail | How differentiated is our SLA in practice? |
| Pre/post event trade delta | What is the per-event-type suppression effect? |
| Event → dormancy rate | Which failure type most reliably causes churn? |

</details>

---

## 💡 Key Findings

| # | Finding |
|:---:|---|
| 1️⃣ | Equity is 67.6% of trades but **86.56% of revenue (₹71.15M)** — F&O fee rates are ~10× lower |
| 2️⃣ | HNI clients (10.5% of base) average **₹47,035 revenue/client** vs ₹14,190 for Retail — a **3.3× gap** |
| 3️⃣ | Top 10% of clients contribute **31.98% of revenue**; top 40% account for **79.47%** |
| 4️⃣ | Mobile drives **59.92% of revenue** (1,014,306 trades); Dealer handles the highest-value F&O orders |
| 5️⃣ | Monthly revenue peaked at **₹4.6M (Jan 2024)** and stabilised at ₹3.5–3.7M through mid-2025 |
| 6️⃣ | Avg trades per active user fell from **37.58 → 9.61** — engagement declining despite client growth |
| 7️⃣ | Top trader: Zilmil Raja (HNI, Kanpur) — **₹89,428 revenue, 1,860 trades** |
| 8️⃣ | Operational events correlate with reduced post-event trading — Order Failure has the highest dormancy rate |
| 9️⃣ | HNI resolution: **~4 hours median** vs **~18 hours Retail** — 4.5× difference, not formalised as SLA |
| 🔟 | KYC-Pending clients generate significantly less revenue than Verified clients in the same onboarding cohort |

---

## 🚀 How to Run

### Prerequisites
- PostgreSQL 17 running on port 5433
- Python 3.10+

### Setup

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Create database
createdb -U postgres -p 5433 brokerage_db

# 3. Load schema
psql -U postgres -p 5433 -d brokerage_db -f sql/schema.sql

# 4. Generate and load data (~90 seconds)
DATABASE_URL="postgresql://postgres:postgres123@localhost:5433/brokerage_db" python data/generate_data.py

# 5. Run analysis queries
psql -U postgres -p 5433 -d brokerage_db -f sql/analysis.sql
```

### 📊 Power BI
1. Open `dashboard/dashboard.pbix` in Power BI Desktop
2. Update credentials if needed: **Home → Transform data → Data source settings**
3. Click **Refresh**

---

## 📋 Dashboard Pages

### 💰 Revenue Intelligence
![Revenue Intelligence](screenshots/dashboard-revenue-overview.png)
Monthly trend, segment split, top traders, Pareto analysis, channel breakdown

---

### 📈 Trading Activity
![Trading Activity](screenshots/dashboard-trading-behavior.png)
Dormancy funnel, engagement trend, channel × segment heatmap

---

### 🔄 Client Lifecycle
![Client Lifecycle](screenshots/dashboard-client-lifecycle.png)
Cohort retention heatmap, days to first trade, never-traded analysis

---

### ⚠️ Operational Intelligence
![Operational Intelligence](screenshots/dashboard-operational-intelligence.png)
Event impact on trading, resolution time comparison, churn risk scatter

---

<div align="center">

*Built to demonstrate production-quality analytics across SQL, Python, and Power BI*

</div>
