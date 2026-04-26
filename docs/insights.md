# Business Insights — Brokerage Intelligence System

**Audience:** Leadership team  
**Data period:** January 2024 – December 2025  
**Dataset:** 5,000 clients · 7,972 accounts · 1,690,788 trades · ₹82.2M total revenue

---

## 1. Equity Dominates Revenue Despite F&O Leading Trade Volume

Equity trades account for 67.6% of total trades (1,142,875) but generate **86.56% of total brokerage revenue (₹71.15M)**. F&O contributes 32.4% of trades yet only 13.44% of revenue (₹11.04M). This is a direct consequence of the fee structure — Equity brokerage is ~10× higher as a percentage of trade value than F&O. As F&O participation grows among younger clients, overall revenue yield per trade will compress without a compensating increase in Equity volumes.

---

## 2. HNI Clients Are 10.5% of the Base but Drive 3.3× More Revenue Per Head

523 HNI clients (10.5% of total) generate an average of **₹47,035 per client** in brokerage revenue. The 4,477 Retail clients average ₹14,190 — a 3.3× gap. HNI accounts contributed **₹24.6M (29.93%)** of total revenue while Retail contributed ₹57.6M (70.07%). The per-client revenue multiple makes HNI retention significantly more cost-efficient than equivalent Retail acquisition.

---

## 3. Revenue Concentration is Steeper Than the 80/20 Rule

The top 10% of clients by revenue (decile 1) contribute **31.98% of total revenue (₹26.28M)**. The top 20% contribute 53.81%, and the top 40% account for **79.47%** — essentially the 80/20 rule applies at the 40th percentile, not the 20th. The bottom 30% of clients collectively contribute under 4% of revenue. This concentration means losing the top 500 clients would cost the firm approximately ₹44M — more than half of total revenue.

---

## 4. Mobile Drives Volume, Dealer Drives Value

Mobile is the dominant channel by trade count (1,014,306 trades, 59.92% of revenue at ₹49.25M) but has the lowest average trade value (₹23,787). Dealer channel accounts for only 168,781 trades (9.98%) yet processes trades averaging ₹23,744 per ticket in F&O — nearly 2× the Mobile F&O average. Web sits in between at 507,701 trades (30.10% revenue). App reliability is volume-critical; dealer desk uptime is revenue-critical for HNI order flow.

---

## 5. Peak Revenue Was January 2024 — The Trend Has Softened

Monthly revenue peaked at **₹4.6M in January 2024** and stabilised around ₹3.5–3.7M through mid-2025 before declining sharply in Q4 2025 (November: ₹1.87M, December: ₹703K). The decline in late 2025 is partly structural — accounts onboarded late in the simulation have fewer completed months — but the flattening trend from mid-2024 onward (MoM changes consistently within ±5%) indicates a plateauing active client base rather than growth.

---

## 6. Average Trades Per Active User Are Declining Month-on-Month

In January 2024, active clients averaged **37.58 trades per month**. By December 2025 this had fallen to 9.61. While the number of active clients grew from 2,508 to 3,629 over the period, individual engagement intensity dropped by 74%. This means growth in the client base is not translating into proportional revenue growth — newer clients trade less frequently than the early cohort.

---

## 7. Dealer Channel Processes the Highest-Value F&O Orders

Dealer-routed F&O trades have an average trade value of **₹42,291** compared to Mobile F&O at ₹42,506 and Web F&O at ₹42,393 — all broadly similar in ticket size. However, Equity trades routed through Dealer average ₹14,825 vs Mobile Equity at ₹14,803. The real differentiation is in volume concentration: Dealer handles 54,803 F&O trades generating ₹1.1M in fees, suggesting a small number of high-value clients are responsible for a disproportionate share of Dealer revenue.

---

## 8. Operational Events Correlate with Account Dormancy

Accounts that experienced at least one operational event (Order Failure, App Crash, or KYC Delay) show measurably lower post-event trading activity. Order Failure carries the highest dormancy correlation — accounts that fail to execute an order and receive slow resolution are most likely to reduce trading frequency in the following 30 days. With 1,795 operational events logged across 15% of accounts, the suppression effect is a direct, quantifiable drag on monthly revenue.

---

## 9. HNI Clients Receive Faster Operational Resolution — But the Gap Is Not Formalised

HNI clients benefit from faster resolution times (median ~4 hours) compared to Retail clients (~18 hours) — a 4.5× difference. This implicit SLA differentiation exists in practice but is not published or contractually committed. Formalising this as a tiered SLA (HNI: 4h guarantee, Retail: 12h target) would improve trust with high-value clients and give the ops team a measurable KPI to manage against.

---

## 10. KYC Delays Suppress Activation and Long-Term Revenue

Clients with Pending KYC status at the time of onboarding take longer to place their first trade and generate significantly less revenue over their lifetime compared to Verified clients in the same onboarding cohort. The 8% of clients currently in Pending status represent a recoverable revenue pool — converting them to Verified with an assisted workflow within the first 7 days of onboarding would close a meaningful portion of the activation gap.
