# Power BI Dashboard Design Specification
## Brokerage Intelligence System

**Tool:** Power BI Desktop (free) / Power BI Service
**Data source:** PostgreSQL — `brokerage_db` on localhost:5433
**Primary table:** `vw_trade_full` view + supplemental tables
**Audience:** Leadership team — weekly Monday review

---

## 1. Connect Power BI to PostgreSQL

1. Open Power BI Desktop
2. **Home → Get Data → PostgreSQL database**
3. Fill in:
   - Server: `localhost:5433`
   - Database: `brokerage_db`
4. Click **OK** → enter username `postgres`, password `postgres123`
5. In the Navigator, select these tables/views:
   - `vw_trade_full` (primary)
   - `trading_accounts` (for dormancy analysis)
   - `operational_events` (for ops analysis)
   - `clients` (for cohort analysis)
6. Click **Transform Data** to open Power Query

---

## 2. Power Query Transformations

In Power Query Editor, apply these steps:

**On `vw_trade_full`:**
- Set `trade_date` column type → Date
- Set `onboarding_date` column type → Date
- Set `total_revenue`, `brokerage_fee`, `trade_value` → Decimal Number
- Add custom column: `Trade Month` = `Date.StartOfMonth([trade_date])`
- Add custom column: `Cohort Month` = `Date.StartOfMonth([onboarding_date])`

**On `trading_accounts`:**
- Set `last_trade_date` → Date
- Add custom column `Inactivity Days` =
  `if [last_trade_date] = null then null else Duration.Days(DateTime.LocalNow() - DateTime.From([last_trade_date]))`
- Add custom column `Inactivity Bucket` =
  ```
  if [last_trade_date] = null then "Never Traded"
  else if [Inactivity Days] <= 30 then "Active (<30 days)"
  else if [Inactivity Days] <= 60 then "Inactive 30-60 days"
  else if [Inactivity Days] <= 90 then "Inactive 60-90 days"
  else "Dormant (>90 days)"
  ```

Click **Close & Apply**.

---

## 3. Data Model (Relationships)

In **Model view**, set these relationships (all single direction):

```
clients (client_id) ──────────── trading_accounts (client_id)
trading_accounts (account_id) ── vw_trade_full (account_id)
trading_accounts (account_id) ── operational_events (account_id)
```

- All relationships: Many-to-One, Single direction
- Cross-filter direction: Single (default)

---

## 4. DAX Measures

Create a dedicated **Measures Table** (Home → Enter Data → name it `_Measures`, load empty table).

Paste each measure into the table:

```dax
// Core revenue
Total Revenue = SUM(vw_trade_full[total_revenue])

Total Trades = COUNTROWS(vw_trade_full)

Active Clients =
CALCULATE(
    DISTINCTCOUNT(vw_trade_full[client_id]),
    trading_accounts[Inactivity Bucket] = "Active (<30 days)"
)

Avg Revenue Per Client =
DIVIDE([Total Revenue], DISTINCTCOUNT(vw_trade_full[client_id]))

// MoM Revenue Change
MoM Revenue % =
VAR CurrentMonth = [Total Revenue]
VAR PrevMonth =
    CALCULATE(
        [Total Revenue],
        DATEADD(vw_trade_full[trade_date], -1, MONTH)
    )
RETURN
    DIVIDE(CurrentMonth - PrevMonth, PrevMonth)

// Revenue concentration
HNI Revenue % =
CALCULATE([Total Revenue], vw_trade_full[client_type] = "HNI")
/ [Total Revenue]

// Never traded clients
Never Traded % =
VAR TotalClients = COUNTROWS(clients)
VAR TradedClients = DISTINCTCOUNT(vw_trade_full[client_id])
RETURN DIVIDE(TotalClients - TradedClients, TotalClients)

// Avg trades per active user per month
Avg Trades Per User Per Month =
DIVIDE(
    [Total Trades],
    DISTINCTCOUNT(vw_trade_full[client_id])
)

// Revenue rank (for top N analysis)
Client Revenue Rank =
RANKX(
    ALL(vw_trade_full[client_id]),
    [Total Revenue],
    ,
    DESC,
    DENSE
)

// Cumulative revenue % (for Pareto chart)
Cumulative Revenue % =
VAR CurrentRev = [Total Revenue]
VAR AllRevSorted =
    TOPN(
        [Client Revenue Rank],
        ALL(vw_trade_full[client_id]),
        [Total Revenue]
    )
RETURN
    DIVIDE(
        SUMX(AllRevSorted, [Total Revenue]),
        CALCULATE([Total Revenue], ALL(vw_trade_full))
    )

// Post-event trade drop (use in card visuals)
Avg Resolution Hours =
AVERAGE(operational_events[resolution_time_hours])
```

---

## 5. Dashboard Pages

### Page 1 — Revenue Intelligence

**Layout:** 3 KPI cards across top, 3 charts below, 1 wide chart at bottom

---

**KPI Cards (top strip — 4 cards):**

| Card | Measure | Format |
|---|---|---|
| Total Revenue | `Total Revenue` | ₹#,##0 |
| Total Trades | `Total Trades` | #,##0 |
| MoM Growth | `MoM Revenue %` | +0.0%; conditional color red/green |
| HNI Revenue Share | `HNI Revenue %` | 0.0% |

---

**Visual 1A — Monthly Revenue Trend (Line + Clustered Column)**
- X-axis: `Trade Month`
- Column values: `Total Revenue`
- Line values: `MoM Revenue %`
- Secondary Y-axis for the line
- Data labels on: last month only
- Analytics pane: add Average line

---

**Visual 1B — Revenue by Segment (Donut Chart)**
- Legend: `segment`
- Values: `Total Revenue`
- Colors: Equity = #F4A261, F&O = #E76F51
- Data labels: percentage + category

---

**Visual 1C — Revenue by Client Type (Donut Chart)**
- Legend: `client_type`
- Values: `Total Revenue`
- Colors: HNI = #1F3A5F, Retail = #2BBCAD

---

**Visual 1D — Top 10 Traders (Horizontal Bar)**
- Y-axis: `name` (client name)
- X-axis: `Total Revenue`
- Filter: `Client Revenue Rank <= 10` (visual-level filter)
- Data labels: on (show revenue value)
- Color: by `client_type`
- Sort: descending by Total Revenue

---

**Visual 1E — Revenue by Channel (Clustered Bar)**
- Y-axis: `channel`
- X-axis: `Total Revenue`
- Small multiples or legend: `segment`
- Data labels: on

---

**Visual 1F — Pareto Chart (Revenue Concentration)**
- Use a Line and Stacked Column chart
- X-axis: Client decile (create a calculated column: `NTILE` equivalent using RANKX bucketed into 10 groups)
- Column: `Total Revenue` per decile
- Line: `Cumulative Revenue %`
- Reference line at 80% on secondary axis

---

### Page 2 — Trading Activity

**Layout:** 2 KPI cards, 4 charts in 2×2 grid

---

**KPI Cards:**

| Card | Value |
|---|---|
| Avg Trades/User/Month | `Avg Trades Per User Per Month` |
| Mobile Trade Share | `DIVIDE(CALCULATE([Total Trades], vw_trade_full[channel]="Mobile"), [Total Trades])` |

---

**Visual 2A — Dormancy Funnel (Stacked Bar)**
- Data source: `trading_accounts`
- Y-axis: `status`
- X-axis: Count of `account_id`
- Legend: `Inactivity Bucket`
- Colors: Active = green, 30-60 = yellow, 60-90 = orange, Dormant = red, Never = grey
- Sort by inactivity severity

---

**Visual 2B — Avg Trades per User Over Time (Line Chart)**
- X-axis: `Trade Month`
- Y-axis: `Avg Trades Per User Per Month`
- Analytics pane: Trend line + 3-month moving average (use DAX: `AVERAGEX(DATESINPERIOD(...))`)

---

**Visual 2C — Channel Split Over Time (100% Stacked Area)**
- X-axis: `Trade Month`
- Y-axis: `Total Trades` (shown as %)
- Legend: `channel`
- Colors: Mobile = #264653, Web = #457B9D, Dealer = #A8DADC

---

**Visual 2D — Trade Frequency by Segment (Line Chart)**
- X-axis: `Trade Month`
- Y-axis: `Total Trades`
- Legend: `segment`
- Analytics pane: Add trend lines per series

---

### Page 3 — Client Lifecycle

**Layout:** 1 wide cohort heatmap on top, 3 charts below

---

**Visual 3A — Cohort Retention Heatmap (Matrix visual)**
- Rows: `Cohort Month`
- Columns: Months since onboarding (0, 1, 2, 3, 6, 12)
  - Create a calculated column on `vw_trade_full`:
    `Months Since Onboarding = DATEDIFF([onboarding_date], [trade_date], MONTH)`
- Values: `DIVIDE(DISTINCTCOUNT(client_id), cohort size)` → format as %
- Conditional formatting on values: 0% = dark red → 100% = dark green
- This is the **signature visual** of the dashboard

---

**Visual 3B — Days to First Trade (Box Plot)**
- Power BI doesn't have a native box plot — use the **Box and Whisker chart** from AppSource (free, by DataScenarios)
- Category: `client_type`
- Sampling: Days from `onboarding_date` to first `trade_date` per client
  - Add a calculated column in `clients` table:
    `Days To First Trade = DATEDIFF([onboarding_date], CALCULATE(MIN(vw_trade_full[trade_date]), RELATEDTABLE(vw_trade_full)), DAY)`

---

**Visual 3C — Never Traded Clients (Stacked Bar)**
- X-axis: `client_type`
- Values: Count of clients split by traded / never traded
- Create calculated column on `clients`:
  `Ever Traded = IF(CALCULATE(COUNTROWS(vw_trade_full), RELATEDTABLE(vw_trade_full)) > 0, "Traded", "Never Traded")`

---

**Visual 3D — State-Level Revenue Map (Filled Map)**
- Location: `state`
- Color saturation: `Total Revenue`
- Tooltips: State, Client Count, Total Revenue, Avg Revenue per Client
- Set geographic data category on `state` column → State or Province → India

---

### Page 4 — Operational Intelligence

**Layout:** 2 KPI cards, 4 charts in 2×2 grid

---

**KPI Cards:**

| Card | Value |
|---|---|
| Avg Resolution Time (Retail) | `CALCULATE([Avg Resolution Hours], clients[client_type]="Retail")` |
| Avg Resolution Time (HNI) | `CALCULATE([Avg Resolution Hours], clients[client_type]="HNI")` |

---

**Visual 4A — Event Volume Over Time (Clustered Bar)**
- Data: `operational_events`
- X-axis: `MONTH(event_date)` (Trade Month equivalent)
- Y-axis: Count of `event_id`
- Legend: `event_type`
- Colors: Order Failure = #E63946, App Crash = #F4A261, KYC Delay = #457B9D

---

**Visual 4B — Resolution Time by Client Type (Box Plot)**
- AppSource Box and Whisker visual
- Category: `client_type`
- Subcategory: `event_type`
- Sampling: `resolution_time_hours`
- Add reference lines: 8h (Retail SLA), 2h (HNI SLA)

---

**Visual 4C — Pre vs Post Event Trade Volume (Clustered Bar)**
- Use a custom SQL query as data source (import as a separate query in Power Query):
  Paste the **D4 query** from `analysis.sql` into:
  Home → Get Data → PostgreSQL → Advanced options → paste SQL
- X-axis: `event_type`
- Clustered bars: `avg_trades_30d_before` vs `avg_trades_30d_after`
- Color before = blue, after = red
- Data label: `pct_change` %

---

**Visual 4D — Churn Risk Scatter Plot**
- X-axis: Days since last trade (`Inactivity Days` from `trading_accounts`)
- Y-axis: Count of operational events per account
  - Create measure: `Events Per Account = COUNTROWS(operational_events)`
- Size: `Total Revenue` (bubble size = revenue at risk)
- Color: `client_type`
- Add reference line: X = 90 (dormancy threshold)
- Quadrant annotation: top-right = highest churn risk

---

## 6. Slicers (Global Filters)

Add these slicers to every page using **Sync Slicers** (View → Sync Slicers):

| Slicer | Field | Type |
|---|---|---|
| Date Range | `trade_date` | Between (date picker) |
| Client Type | `client_type` | Dropdown |
| Segment | `segment` | Dropdown |
| Channel | `channel` | Dropdown |
| State | `state` | Dropdown |


---

## 7. Formatting Standards

| Element | Value |
|---|---|
| Canvas size | 1400 × 900 px |
| Background | #F8F9FA (light grey) |
| Card background | White with subtle shadow |
| Font — titles | Segoe UI Semibold, 14px |
| Font — labels | Segoe UI, 11px |
| HNI color | #1F3A5F |
| Retail color | #2BBCAD |
| Equity color | #F4A261 |
| F&O color | #E76F51 |
| Mobile color | #264653 |
| Web color | #457B9D |
| Dealer color | #A8DADC |
| Alert/risk | #E63946 |
| Safe/positive | #2A9D8F |

---


