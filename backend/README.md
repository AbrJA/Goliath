# Backend — Process Engine

Automated pipeline that runs continuously to:

1. **Collect metrics** from the SQLite sensor database every minute
2. **Train predictive models** using Fourier decomposition on historical data
3. **Validate thresholds** and trigger alerts when anomalies are detected

## Scripts

| Script | Purpose |
|--------|---------|
| `main.R` | Event loop — orchestrates metric collection and model retraining |
| `generator/seed.R` | Generates 30 days of synthetic sensor data |
| `metrics/database.R` | Reads current-day sensor values and aggregates them |
| `models/database.R` | Trains time-series models and stores predictions |
| `validations/database.R` | Compares real values vs predictions, triggers alerts |

## Metrics

| Metric | Unit | Description |
|--------|------|-------------|
| Pump Pressure | PSI | Main process pump discharge pressure |
| Turbine Vibration | mm/s | Gas turbine bearing vibration level |
| Flow Rate | bbl/hr | Crude oil pipeline flow rate |
| Process Temperature | °F | Catalytic cracker reactor temperature |
| Power Consumption | MW | Total plant electrical power draw |
| Compressor RPM | RPM | Main gas compressor rotational speed |

