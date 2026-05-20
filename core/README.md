# healthr

Core R package providing R6 classes for industrial process monitoring:

- **Connection** — SQLite database pool management
- **Metric** — Time-series metric aggregation and counting
- **Model** — Fourier-based time-series forecasting with confidence intervals
- **Parameter** — Metric configuration (name, interval, query, horizon)
- **Time** — Time utilities for period scaling and series generation
- **Logger** — Structured logging (INFO/WARNING/ERROR)
- **Alert** — Slack webhook integration for anomaly notifications

## Installation

```r
install.packages("./core", repos = NULL, type = "source")
```
