# Process Monitor — User Guide

> **Audience:** Operations engineers and managers at P66 industrial facilities.
> **Purpose:** Real-time monitoring, predictive modelling, and anomaly detection for six key process metrics.

---

## Metrics monitored

| Metric | Unit | Typical range |
|---|---|---|
| Pump Pressure | PSI | ~250 ± 30 |
| Turbine Vibration | mm/s | ~4.5 ± 1.5 |
| Flow Rate | bbl/hr | ~1 200 ± 200 |
| Process Temperature | °F | ~680 ± 40 |
| Power Consumption | MW | ~85 ± 10 |
| Compressor RPM | RPM | ~3 600 ± 300 |

All metrics are collected every minute. Models are trained on same-weekday data from the last 28 days using Fourier decomposition, producing a predicted range (lower / mean / upper) for every 10-minute block of the day.

---

## Tab 1 — Command Center

**What it does**
Six-panel overview showing the current state of all metrics side-by-side. Each panel plots today's readings against the model's predicted range (shaded ribbon = 99% confidence interval).

**KPI cards** at the top show the most recent reading for each metric.

**How to use**
- Open this tab first when starting a shift for a quick health check.
- Red/orange readings poking outside the ribbon signal that a metric is behaving unexpectedly.
- Use the **Refresh** button to pull the latest data without reloading the page.

**Insights to look for**
- Consistent drift above or below the mean ribbon → possible calibration drift or process change.
- A spike followed by a rapid return to normal → transient event (pressure surge, brief vibration).
- All metrics flat-lining together → sensor or connectivity issue, not a process problem.

---

## Tab 2 — Deep Analysis

**What it does**
Single-metric deep-dive with an adjustable time resolution (1 min → 30 min aggregation window). Also shows a history window to inspect past days.

**Controls**
| Control | Effect |
|---|---|
| Metric selector | Which metric to focus on |
| Interval (min) | Aggregation granularity — 1 = raw per-minute, 10 = default model resolution |
| Date range | How many past days to include |

**How to use**
1. Select the metric that raised an alert or appears unusual.
2. Drop the interval to **1 min** to see minute-by-minute detail. The model ribbon is automatically interpolated to match the finer resolution.
3. Expand the date range to spot whether the anomaly is new or recurring.

**Insights to look for**
- Model ribbon narrowing at certain hours → predictable low-volatility windows; good for maintenance scheduling.
- Reading tracking the lower bound for several hours → gradual degradation, not a one-off spike.
- Wide confidence interval in the early morning → historically volatile period; tighter alert thresholds needed.

---

## Tab 3 — History

**What it does**
Multi-day trend view: compares the last *N* days of a chosen metric, with each day plotted as a separate line so cycle-to-cycle variation is visible.

**Controls**
| Control | Effect |
|---|---|
| Metric | Metric to review |
| Days | How many past days to include (1–28) |
| Interval | Aggregation window |

**How to use**
- Set **Days = 7** to compare the last full work-week.
- Overlay weekday patterns: if Monday is always higher, that is a legitimate cycle, not an alarm.
- Use together with **Model Studio** if you notice the model is not fitting a particular day well.

**Insights to look for**
- Same anomalous bump every Tuesday → scheduled upstream batch change; update model inputs.
- Gradual upward trend across all days → long-term drift that warrants engineering review.
- Random day-to-day variance with no pattern → sensor noise; consider increasing the aggregation window.

---

## Tab 4 — Model Studio

**What it does**
Interactive model trainer. You pick the metric, number of Fourier harmonics (K), confidence level, and resolution, and it trains a model on the fly, displaying the prediction with its R² goodness-of-fit.

**Controls**
| Control | Effect |
|---|---|
| Metric | Metric to model |
| K (harmonics) | Complexity: K=2 captures basic daily cycles, K=6 captures intraday detail |
| Confidence | Width of the prediction interval (90 % / 95 % / 99 %) |
| Interval | Aggregation window for training data |

**How to use**
1. Start with K=4 (the production default).
2. Increase K if the model ribbon is too wide and misses the actual shape.
3. Decrease K if the model is overfitting (wiggly ribbon that closely hugs every spike — spikes are noise, not cycle shape).
4. Compare R² values: anything above 0.85 is a good fit for industrial cycle data.
5. Use 90 % confidence for tighter alerts, 99 % for fewer false positives.

**Insights to look for**
- Low R² (< 0.6) → the metric does not follow a stable daily pattern; statistical alerts may be unreliable.
- R² improves significantly when K increases from 4 to 6 → there is a meaningful sub-hourly cycle.
- Wide interval even at 90 % → high inherent variability; manual thresholds may be more appropriate.

---

## Tab 5 — Data Explorer

**What it does**
Direct SQL interface to the underlying SQLite database. Run any custom query and see results as a table plus an automatically-chosen chart.

**Quick queries**
| Button | Query | Chart type |
|---|---|---|
| Today's Summary | AVG / MIN / MAX per metric for today | Grouped bar |
| Out-of-Bounds Readings | Readings outside model confidence bounds | Scatter (minute vs value) |
| Metric Catalog | Names, units, and descriptions of all metrics | Table only |
| Last 60 Minutes | Raw per-minute readings for all metrics | Line chart per metric |

**Chart auto-detection logic**
- If the result has a `minute`, `hour`, or `period` column → **line chart**
- If the result has a category column (e.g., `metric_name`) and ≤ 30 rows → **grouped bar chart**
- Otherwise → **box plot** showing the distribution of each numeric column

**How to use**
1. Click a quick query to pre-fill the SQL box, then hit **Run Query** (or press Ctrl+Enter).
2. Modify the SQL for custom ranges: e.g., change `'now','localtime'` to `'2026-04-20'` to inspect a historical date.
3. Hit **Plot** to visualise the current result set.

**Example ad-hoc queries**
```sql
-- Hourly average for Flow Rate yesterday
SELECT CAST(minute / 60 AS INT) AS hour, AVG(value) AS avg_flow
FROM metrics
WHERE metric_name = 'Flow Rate'
  AND date(date) = date('now', 'localtime', '-1 day')
GROUP BY hour
ORDER BY hour;
```

```sql
-- Minutes where Pump Pressure exceeded 280 PSI today
SELECT minute, value
FROM metrics
WHERE metric_name = 'Pump Pressure'
  AND date(date) = date('now', 'localtime')
  AND value > 280
ORDER BY minute;
```

**Insights to look for**
- The *Out-of-Bounds* query shows how many and which readings fell outside the model envelope — a daily count above 5 % warrants investigation.
- The *Today's Summary* bar chart lets you instantly compare MAX vs AVG: a large gap means at least one significant spike.

---

## Tab 6 — Anomaly Detection

**What it does**
Statistical anomaly detection using a rolling z-score over a 60-minute window. Points that deviate more than *σ* standard deviations from the rolling mean are flagged as anomalies.

**Controls**
| Control | Effect |
|---|---|
| Metric | Metric to scan |
| Sensitivity (σ) | Detection threshold: lower = more sensitive (more alerts), higher = fewer but more severe |
| Window | How many days of data to analyse |

**Value boxes**
- **Anomaly Count** — total flagged readings in the selected window
- **Max Severity** — highest z-score observed (multiples of σ)
- **Health Score** — percentage of readings that were *not* anomalous (100 % = perfect)

**How to use**
1. Set σ = 2.5 for day-to-day monitoring (flags ~1 % of normally-distributed readings).
2. Drop to σ = 1.5 when commissioning new equipment to catch subtle deviations.
3. Raise to σ = 3.5 for mature, stable processes to reduce alert fatigue.
4. The **anomaly table** at the bottom lists the worst offenders with exact timestamp, value, expected value, and severity.

**Insights to look for**
- A cluster of anomalies at the same hour every day → cyclical event not captured by the model.
- Health score below 95 % → metric is behaving erratically; escalate.
- Isolated high-severity spikes (> 4σ) → sensor faults or process upsets; cross-check with operator logs.

---

## Tab 7 — Correlations

**What it does**
Pearson or Spearman correlation heatmap across all six metrics, plus a scatter plot for any pair you choose.

**Controls**
| Control | Effect |
|---|---|
| Method | Pearson (linear) or Spearman (rank-based, more robust to outliers) |
| Window | Today only, or last 3 / 7 / 30 days |
| Scatter: X / Y metric | Pair for the scatter plot |

**How to use**
1. Click **Compute** to generate the heatmap.
2. Look for unexpected strong correlations (|r| > 0.7).
3. Select a correlated pair in the scatter controls and click **Scatter** to see the relationship visually; the Pearson r and regression line are annotated.

**Insights to look for**
- **Pump Pressure ↔ Flow Rate** strongly positive → expected; system is working normally.
- **Turbine Vibration ↔ Compressor RPM** strongly positive when it was not before → possible mechanical coupling issue.
- **Process Temperature ↔ Power Consumption** high correlation during winter → efficiency loss in cold ambient; normal.
- Correlation sign reversal between two windows → regime change in the process; review recent maintenance records.

---

## Tab 8 — Alerts

**What it does**
Real-time alert table that compares each metric's most recent reading against the model-predicted confidence interval for the current 10-minute block of the day.

**Columns**
| Column | Meaning |
|---|---|
| Metric | Sensor name |
| Status | ✅ NORMAL / ⚠️ ABOVE / ⚠️ BELOW |
| Current | Latest recorded value |
| Lower / Upper | 99 % confidence interval from the trained model |
| Deviation | % difference from the model mean |

**How to use**
1. Click **Refresh Alerts** to pull the latest reading. In production, refresh every 10–15 minutes.
2. Any row showing ⚠️ should be cross-referenced in **Deep Analysis** to determine if it is a transient spike or a sustained deviation.
3. A positive deviation on *Pump Pressure* at the same time as a negative deviation on *Flow Rate* is operationally significant — possible blockage.

**Insights to look for**
- Multiple metrics in alert simultaneously → systemic event (e.g., power dip, feed-stock change).
- Only one metric in alert repeatedly → localised sensor issue or equipment fault.
- Deviations within ±5 % but status ABOVE/BELOW → confidence interval is too tight for this time of day; re-train model with higher K or wider confidence level in Model Studio.

---

## Quick-reference: recommended workflow

```
Shift start
  └─ Command Center  → overall health snapshot
       ├─ All clear?       → Done, revisit next shift
       └─ Metric flagged?
            ├─ Deep Analysis (1-min interval)  → confirm spike vs. trend
            ├─ Anomaly Detection               → quantify and list events
            ├─ Alerts                          → check against model bounds
            └─ Correlations                    → look for co-movement with other metrics

Weekly review
  └─ History (7 days)  → compare day-to-day patterns
       └─ Unexpected pattern?
            └─ Model Studio → retune K / confidence for that metric
```

---

## Data architecture

```
SQLite database  (process_monitor.db)
├── metrics          — raw per-minute readings (metric_name, date, minute, value)
├── metric_results   — today's 10-min aggregates (metric_name, period, count)
├── model_results    — Fourier predictions (metric_name, period, lower, mean, upper)
└── metric_catalog   — metric metadata (name, unit, description)
```

The **backend** container runs a loop every minute: it aggregates today's readings into `metric_results`, and every 10 minutes it re-trains the Fourier model on the last 28 days of same-weekday data, updating `model_results`.

---

*Process Monitor v1.0 — built on R / Shiny / SQLite / Docker.*
