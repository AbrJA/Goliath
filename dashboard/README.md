# Dashboard — Real-Time Monitoring UI

Interactive Shiny dashboard with four views:

| Tab | Description |
|-----|-------------|
| **Overview** | 6-panel grid showing all metrics with predictions vs actuals in real-time |
| **Zoom** | Detailed single-metric view with configurable time intervals |
| **History** | Historical analysis — select any past date, trains a model on-the-fly |
| **Alerts** | Current anomaly status for all sensors |

## Run locally

```r
shiny::runApp("dashboard", port = 8000)
```

## Tech Stack

- **Shiny** + `bslib` (Bootstrap 5, Flatly theme)
- **Plotly** for interactive time-series charts
- **healthr** core package for forecasting engine
