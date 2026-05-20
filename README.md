# Industrial Process Monitor

> Real-time anomaly detection and predictive analytics for industrial sensor data using time-series forecasting.

---

## Overview

This framework provides **end-to-end monitoring** for industrial processes by:

1. Collecting minute-level sensor data from production systems
2. Training predictive models using **Fourier decomposition** on historical patterns
3. Comparing real-time readings against statistical confidence intervals
4. Alerting operators when metrics deviate beyond expected thresholds
5. Visualizing everything in an interactive real-time dashboard

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Architecture                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────┐     ┌──────────┐     ┌──────────────────────────┐   │
│   │  Sensors │────▶│  SQLite  │────▶│  Backend Process Engine  │   │
│   │  (Data)  │     │    DB    │     │  • Metric aggregation    │   │
│   └──────────┘     └────┬─────┘     │  • Model training        │   │
│                          │           │  • Anomaly validation    │   │
│                          │           └──────────────────────────┘   │
│                          │                                           │
│                          ▼                                           │
│                    ┌───────────────────────────────────┐             │
│                    │      Shiny Dashboard              │             │
│                    │  • Real-time overview (6 panels)  │             │
│                    │  • Detailed zoom view             │             │
│                    │  • Historical analysis            │             │
│                    │  • Alert status                   │             │
│                    └───────────────────────────────────┘             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Monitored Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| **Pump Pressure** | PSI | Main process pump discharge pressure |
| **Turbine Vibration** | mm/s | Gas turbine bearing vibration level |
| **Flow Rate** | bbl/hr | Crude oil pipeline flow rate |
| **Process Temperature** | °F | Catalytic cracker reactor temperature |
| **Power Consumption** | MW | Total plant electrical power draw |
| **Compressor RPM** | RPM | Main gas compressor rotational speed |

---

## Quick Start

### Prerequisites

- R ≥ 4.3.0
- Required packages: `R6`, `data.table`, `checkmate`, `DBI`, `RSQLite`, `pool`, `forecast`, `shiny`, `plotly`, `bslib`

### 1. Install dependencies

```r
install.packages(c(
  "R6", "data.table", "checkmate", "DBI", "RSQLite",
  "pool", "forecast", "shiny", "plotly", "bslib", "httr", "yyjsonr"
))
```

### 2. Install the core package

```r
install.packages("core", repos = NULL, type = "source")
```

### 3. Run the setup (seeds database + trains models)

```r
source("setup.R")
```

This will:
- Generate **30 days** of realistic synthetic sensor data
- Store everything in `data/metrics.db` (SQLite)
- Train Fourier-based predictive models for each metric

### 4. Launch the dashboard

```r
shiny::runApp("dashboard", port = 8000)
```

Open [http://localhost:8000](http://localhost:8000) in your browser.

---

## Project Structure

```
├── core/                    # R package: R6 classes for the monitoring engine
│   ├── R/
│   │   ├── alert.R         # Slack alert notifications
│   │   ├── connection.R    # SQLite connection pool
│   │   ├── logger.R        # Structured logging
│   │   ├── metric.R        # Time-series metric aggregation
│   │   ├── model.R         # Fourier forecasting + confidence intervals
│   │   ├── parameter.R     # Metric configuration
│   │   └── time.R          # Time period utilities
│   └── DESCRIPTION
│
├── backend/                 # Process engine (automated pipeline)
│   ├── generator/seed.R    # Synthetic data generator (30 days)
│   ├── metrics/database.R  # Real-time metric collection
│   ├── models/database.R   # Model training pipeline
│   ├── validations/        # Threshold checking & alerting
│   └── main.R              # Event loop orchestrator
│
├── dashboard/               # Shiny interactive dashboard
│   ├── global.R            # App configuration & metric registry
│   ├── ui.R                # Bootstrap 5 UI layout
│   ├── server.R            # Reactive server logic
│   ├── constants/          # Plot annotations
│   └── functions/          # Plotly helper functions
│
├── setup.R                  # One-command project initialization
└── data/                    # SQLite database (auto-generated)
```

---

## How It Works

### Predictive Model

The forecasting engine uses **Fourier decomposition** on historical time-series data:

1. **Data collection**: Gathers same-weekday data from the past 28 days
2. **Normalization**: Removes extreme outliers using Q1/Q3 replacement
3. **Training**: Fits a linear model with Fourier terms (harmonics K=4)
4. **Prediction**: Generates point forecasts with 99% confidence intervals

When a real-time reading falls **below 90%** of the lower confidence bound, the system triggers an anomaly alert.

### Data Simulation

The generator creates realistic sensor patterns with:
- **Sinusoidal daily profiles** (each metric peaks at different hours)
- **Autocorrelated noise** (smoothed random variations for realism)
- **Weekend effects** (15% lower activity on Saturdays/Sundays)
- **Random anomalies** (~10% of days have injected deviations)

---

## Docker Deployment

```bash
# Build
docker build -f backend/Dockerfile -t process-monitor-backend .
docker build -f dashboard/Dockerfile -t process-monitor-dashboard .

# Run
docker run -d -v $(pwd)/data:/app/data process-monitor-backend
docker run -d -p 8000:8000 -v $(pwd)/data:/app/data process-monitor-dashboard
```

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `DB_PATH` | `data/metrics.db` | Path to SQLite database |
| `SLACK_URL` | — | Slack webhook URL (optional) |
| `SLACK_TOKEN` | — | Slack API token (optional) |
| `SLACK_CHANNEL` | — | Alert channel (optional) |

---

## License

MIT
