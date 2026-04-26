"""
Brokerage Intelligence System — Synthetic Data Generator

Generates 5,000 clients and ~1.7M trades across a 24-month simulation window.
Loads directly into PostgreSQL via SQLAlchemy.

Usage:
    pip install -r requirements.txt
    DATABASE_URL="postgresql://postgres:password@localhost:5433/brokerage_db" python generate_data.py
"""

import os
import random
import numpy as np
import pandas as pd
from datetime import date, timedelta
from faker import Faker
from sqlalchemy import create_engine, text

DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5433/brokerage_db")

SEED               = 42
N_CLIENTS          = 5_000
SIM_START          = date(2024, 1, 1)
SIM_END            = date(2025, 12, 31)
DORMANCY_RATE      = 0.30
EVENT_ACCOUNT_RATE = 0.15

random.seed(SEED)
np.random.seed(SEED)
fake = Faker("en_IN")
Faker.seed(SEED)

engine = create_engine(DB_URL, echo=False)

CITY_STATE_MAP = {
    "Mumbai": "Maharashtra", "Pune": "Maharashtra",
    "Bangalore": "Karnataka", "Mysore": "Karnataka",
    "Chennai": "Tamil Nadu", "Coimbatore": "Tamil Nadu",
    "New Delhi": "Delhi", "Noida": "Delhi",
    "Ahmedabad": "Gujarat", "Surat": "Gujarat",
    "Hyderabad": "Telangana", "Warangal": "Telangana",
    "Kolkata": "West Bengal",
    "Jaipur": "Rajasthan",
    "Lucknow": "Uttar Pradesh", "Kanpur": "Uttar Pradesh",
    "Kochi": "Kerala", "Thiruvananthapuram": "Kerala",
    "Bhopal": "Madhya Pradesh",
    "Chandigarh": "Punjab",
    "Gurugram": "Haryana",
    "Visakhapatnam": "Andhra Pradesh",
    "Patna": "Bihar",
}
CITIES = list(CITY_STATE_MAP.keys())


def random_date(start: date, end: date) -> date:
    return start + timedelta(days=random.randint(0, (end - start).days))


def brokerage_pct(segment: str) -> float:
    return np.random.uniform(0.003, 0.005) if segment == "Equity" else np.random.uniform(0.0003, 0.0005)


def txn_charge_pct(segment: str) -> float:
    return np.random.uniform(0.0001, 0.0003) if segment == "Equity" else np.random.uniform(0.00005, 0.0001)


# ---------------------------------------------------------------------------
print("Generating clients...")
onboarding_start = SIM_START - timedelta(days=730)
client_rows = []

for cid in range(1, N_CLIENTS + 1):
    city  = random.choice(CITIES)
    age   = random.randint(22, 72)
    if age < 35:
        risk = random.choices(["Conservative", "Moderate", "Aggressive"], weights=[15, 40, 45])[0]
    elif age < 50:
        risk = random.choices(["Conservative", "Moderate", "Aggressive"], weights=[25, 50, 25])[0]
    else:
        risk = random.choices(["Conservative", "Moderate", "Aggressive"], weights=[45, 40, 15])[0]

    client_rows.append({
        "client_id":       cid,
        "name":            fake.name(),
        "age":             age,
        "city":            city,
        "state":           CITY_STATE_MAP[city],
        "client_type":     "Retail",
        "risk_profile":    risk,
        "onboarding_date": random_date(onboarding_start, SIM_END - timedelta(days=30)),
        "kyc_status":      "Verified" if random.random() < 0.92 else "Pending",
    })

df_clients = pd.DataFrame(client_rows)

# ---------------------------------------------------------------------------
print("Generating trading accounts...")
account_rows = []
account_id = 1
client_account_map = {}

for _, cl in df_clients.iterrows():
    cid         = cl["client_id"]
    onboarding  = cl["onboarding_date"]
    n_accounts  = random.choices([1, 2, 3], weights=[55, 30, 15])[0]
    acct_list   = []

    for atype in random.sample(["Equity", "F&O", "Intraday", "Delivery"], k=min(n_accounts, 4)):
        created    = onboarding + timedelta(days=random.randint(0, 5))
        is_dormant = random.random() < DORMANCY_RATE

        if is_dormant:
            last_trade = random_date(SIM_START, SIM_END - timedelta(days=91)) if created < SIM_END - timedelta(days=91) else None
            status     = "Dormant"
        else:
            never_traded = random.random() < 0.05
            if never_traded or created > SIM_END - timedelta(days=10):
                last_trade, status = None, "Active"
            else:
                last_trade = random_date(max(created, SIM_END - timedelta(days=89)), SIM_END)
                status     = "Active"

        if random.random() < 0.02:
            status = "Suspended"

        account_rows.append({
            "account_id":      account_id,
            "client_id":       cid,
            "account_type":    atype,
            "status":          status,
            "created_date":    created,
            "last_trade_date": last_trade,
        })
        acct_list.append(account_id)
        account_id += 1

    client_account_map[cid] = acct_list

df_accounts = pd.DataFrame(account_rows)

# ---------------------------------------------------------------------------
print("Generating trades (this may take several minutes)...")
trade_rows, revenue_rows, trade_id = [], [], 1

tradeable = df_accounts[
    df_accounts["status"].isin(["Active", "Dormant"]) &
    df_accounts["last_trade_date"].notna()
].copy()

for _, acct in tradeable.iterrows():
    acct_id    = int(acct["account_id"])
    atype      = acct["account_type"]
    created    = acct["created_date"]
    last_trade = acct["last_trade_date"]

    if pd.isna(last_trade) or created >= last_trade:
        continue

    window_days = max((last_trade - created).days, 1)
    freq_map    = {"Intraday": 0.8, "Equity": 0.3, "F&O": 0.4, "Delivery": 0.1}
    n_trades    = max(1, min(int(window_days * freq_map.get(atype, 0.3) * np.random.uniform(0.5, 1.5)), 800))

    seg_weights = [0.2, 0.8] if atype == "F&O" else [0.85, 0.15]
    channels    = random.choices(["Mobile", "Web", "Dealer"], weights=[60, 30, 10], k=n_trades)
    segments    = random.choices(["Equity", "F&O"], weights=seg_weights, k=n_trades)
    trade_dates = sorted([random_date(max(created, SIM_START), last_trade) for _ in range(n_trades)])

    for i in range(n_trades):
        seg   = segments[i]
        price = round(np.random.lognormal(mean=5.5, sigma=0.9), 2) if seg == "Equity" else round(np.random.uniform(50, 800), 2)
        qty   = random.randint(1, 80) if seg == "Equity" else random.choice([25, 50, 75, 100, 150, 200])
        tv    = qty * price

        trade_rows.append({
            "trade_id":   trade_id,
            "account_id": acct_id,
            "trade_type": random.choice(["Buy", "Sell"]),
            "segment":    seg,
            "quantity":   qty,
            "price":      price,
            "trade_date": trade_dates[i],
            "channel":    channels[i],
        })
        revenue_rows.append({
            "trade_id":            trade_id,
            "brokerage_fee":       round(tv * brokerage_pct(seg), 4),
            "transaction_charges": round(tv * txn_charge_pct(seg), 4),
        })
        trade_id += 1

df_trades  = pd.DataFrame(trade_rows)
df_revenue = pd.DataFrame(revenue_rows)
print(f"  Generated {len(df_trades):,} trades")

# ---------------------------------------------------------------------------
print("Updating client_type based on cumulative trade value...")
df_trades["trade_value"] = df_trades["quantity"] * df_trades["price"]
acct_client = df_accounts[["account_id", "client_id"]]

trade_by_client = (
    df_trades.merge(acct_client, on="account_id")
    .groupby("client_id")["trade_value"].sum().reset_index()
)
hni_clients = set(trade_by_client[trade_by_client["trade_value"] >= 20_000_000]["client_id"])
df_clients["client_type"] = df_clients["client_id"].apply(lambda x: "HNI" if x in hni_clients else "Retail")
print(f"  HNI: {len(hni_clients):,} | Retail: {N_CLIENTS - len(hni_clients):,}")

# ---------------------------------------------------------------------------
print("Generating operational events...")
event_rows, event_id = [], 1
event_accounts = df_accounts.sample(frac=EVENT_ACCOUNT_RATE, random_state=SEED)
acct_client_type = (
    df_accounts.merge(df_clients[["client_id", "client_type"]], on="client_id")
    [["account_id", "client_type"]].set_index("account_id")["client_type"].to_dict()
)

for _, acct in event_accounts.iterrows():
    acct_id    = int(acct["account_id"])
    created    = acct["created_date"]
    ctype      = acct_client_type.get(acct_id, "Retail")
    limit_date = acct["last_trade_date"] if pd.notna(acct["last_trade_date"]) else SIM_END

    for _ in range(random.choices([1, 2, 3, 4], weights=[60, 25, 10, 5])[0]):
        edate_start = max(created, SIM_START)
        edate_end   = min(SIM_END, limit_date + timedelta(days=30))
        if edate_start > edate_end:
            continue

        etype     = random.choices(["Order Failure", "App Crash", "KYC Delay"], weights=[50, 35, 15])[0]
        res_hours = max(0.5, np.random.exponential(4.0)) if ctype == "HNI" else max(1.0, np.random.exponential(18.0))
        if etype == "KYC Delay":
            res_hours *= random.uniform(2.0, 5.0)

        event_rows.append({
            "event_id":               event_id,
            "account_id":             acct_id,
            "event_type":             etype,
            "event_date":             random_date(edate_start, edate_end),
            "resolution_time_hours":  round(res_hours, 2),
        })
        event_id += 1

df_events = pd.DataFrame(event_rows)
print(f"  Generated {len(df_events):,} operational events")

# ---------------------------------------------------------------------------
print("\nLoading into PostgreSQL...")

def load(df, table, chunk=2000):
    for i in range(0, len(df), chunk):
        df.iloc[i:i + chunk].to_sql(table, engine, if_exists="append", index=False, method="multi")
    print(f"  {len(df):,} rows → {table}")

with engine.connect() as conn:
    conn.execute(text("TRUNCATE operational_events, brokerage_revenue, trades, trading_accounts, clients RESTART IDENTITY CASCADE"))
    conn.commit()

for col in ["onboarding_date"]:
    df_clients[col] = pd.to_datetime(df_clients[col]).dt.date
for col in ["created_date", "last_trade_date"]:
    df_accounts[col] = pd.to_datetime(df_accounts[col]).dt.date
for col in ["trade_date"]:
    df_trades[col] = pd.to_datetime(df_trades[col]).dt.date
for col in ["event_date"]:
    df_events[col] = pd.to_datetime(df_events[col]).dt.date

load(df_clients, "clients")
load(df_accounts, "trading_accounts")
load(df_trades.drop(columns=["trade_value"], errors="ignore"), "trades")
load(df_revenue, "brokerage_revenue")
load(df_events[["account_id", "event_type", "event_date", "resolution_time_hours"]], "operational_events")

print(f"""
Done.
  Clients:            {len(df_clients):,}
  Trading accounts:   {len(df_accounts):,}
  Trades:             {len(df_trades):,}
  Revenue rows:       {len(df_revenue):,}
  Operational events: {len(df_events):,}
""")
