#!/usr/bin/env Rscript
# ==============================================================================
# P66 Industrial Metric Simulator — SQLite Seed Generator
# ==============================================================================
# Generates realistic time-series sensor data for a refinery environment.
# Each metric follows a distribution that varies across the day to simulate
# real operational patterns (e.g., higher throughput during day shifts).
# ==============================================================================

library(data.table)
library(DBI)
library(RSQLite)

DB_PATH <- Sys.getenv("DB_PATH", "data/metrics.db")

# --- Configuration -----------------------------------------------------------

METRICS <- list(

  list(
    name        = "Pump Pressure",
    unit        = "PSI",
    base        = 250,
    amplitude   = 30,
    noise_sd    = 8,
    peak_hour   = 14,
    description = "Main process pump discharge pressure"
  ),

  list(
    name        = "Turbine Vibration",
    unit        = "mm/s",
    base        = 4.5,
    amplitude   = 1.2,
    noise_sd    = 0.4,
    peak_hour   = 10,
    description = "Gas turbine bearing vibration level"
  ),
  list(
    name        = "Flow Rate",
    unit        = "bbl/hr",
    base        = 1200,
    amplitude   = 300,
    noise_sd    = 50,
    peak_hour   = 12,
    description = "Crude oil pipeline flow rate"
  ),

  list(
    name        = "Process Temperature",
    unit        = "°F",
    base        = 680,
    amplitude   = 40,
    noise_sd    = 12,
    peak_hour   = 15,
    description = "Catalytic cracker reactor temperature"
  ),
  list(
    name        = "Power Consumption",
    unit        = "MW",
    base        = 85,
    amplitude   = 20,
    noise_sd    = 5,
    peak_hour   = 13,
    description = "Total plant electrical power draw"
  ),
  list(
    name        = "Compressor RPM",
    unit        = "RPM",
    base        = 3600,
    amplitude   = 200,
    noise_sd    = 40,
    peak_hour   = 11,
    description = "Main gas compressor rotational speed"
  )
)

# --- Generator Functions ------------------------------------------------------

generate_daily_pattern <- function(metric, date, minutes = seq(0, 1439)) {
  n <- length(minutes)
  hours <- minutes / 60

  # Sinusoidal daily pattern centered at peak_hour

  trend <- metric$base + metric$amplitude * sin(pi * (hours - metric$peak_hour + 6) / 12)

  # Add realistic noise

  noise <- rnorm(n, mean = 0, sd = metric$noise_sd)

  # Add slight autocorrelation (smoothed noise for realism)
  smoothed_noise <- stats::filter(noise, rep(1 / 5, 5), sides = 2)
  smoothed_noise[is.na(smoothed_noise)] <- noise[is.na(smoothed_noise)]

  values <- round(trend + as.numeric(smoothed_noise), 2)

  # Ensure physical constraints (no negative values for these sensors)
  values[values < 0] <- abs(values[values < 0]) * 0.1


  data.table(
    metric_name = metric$name,
    date        = format(as.POSIXct(paste(date, "00:00:00")) + minutes * 60, "%Y-%m-%d %H:%M:%S"),
    minute      = minutes,
    value       = values
  )
}

inject_anomaly <- function(dt, start_minute, duration = 15L, severity = 2.5) {
  idx <- dt$minute >= start_minute & dt$minute < (start_minute + duration)
  baseline <- mean(dt$value[idx], na.rm = TRUE)
  dt$value[idx] <- dt$value[idx] + severity * abs(baseline - dt$value[idx]) * sign(runif(sum(idx), -1, 1))
  dt
}

# --- Main Execution -----------------------------------------------------------

dir.create(dirname(DB_PATH), showWarnings = FALSE, recursive = TRUE)

conn <- dbConnect(RSQLite::SQLite(), DB_PATH)
on.exit(dbDisconnect(conn))

# Create schema
dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS metrics (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT    NOT NULL,
    date        TEXT    NOT NULL,
    minute      INTEGER NOT NULL,
    value       REAL    NOT NULL
  )
")

dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS metric_catalog (
    metric_name TEXT PRIMARY KEY,
    unit        TEXT NOT NULL,
    description TEXT NOT NULL
  )
")

dbExecute(conn, "CREATE INDEX IF NOT EXISTS idx_metrics_name_date ON metrics(metric_name, date)")
dbExecute(conn, "CREATE INDEX IF NOT EXISTS idx_metrics_minute ON metrics(metric_name, minute)")

# Seed catalog
dbExecute(conn, "DELETE FROM metric_catalog")
for (m in METRICS) {
  dbExecute(conn, "INSERT INTO metric_catalog (metric_name, unit, description) VALUES (?, ?, ?)",
            params = list(m$name, m$unit, m$description))
}

# Generate 30 days of historical data
today <- Sys.Date()
dates <- seq(today - 29, today, by = "day")

message("Generating sensor data for ", length(dates), " days x ", length(METRICS), " metrics...")

dbExecute(conn, "DELETE FROM metrics")
dbBegin(conn)

set.seed(42L)

for (date in as.character(dates)) {
  weekday <- as.POSIXlt(date)$wday

  for (m in METRICS) {
    dt <- generate_daily_pattern(m, date)

    # Weekends have ~15% lower activity
    if (weekday %in% c(0L, 6L)) {
      dt$value <- dt$value * 0.85
    }

    # Inject a random anomaly on ~10% of days for demo purposes
    if (runif(1) < 0.10 && date != as.character(today)) {
      anomaly_start <- sample(360:1200, 1)
      dt <- inject_anomaly(dt, anomaly_start, duration = sample(10:30, 1), severity = runif(1, 2, 4))
    }

    dbExecute(conn,
      "INSERT INTO metrics (metric_name, date, minute, value) VALUES (?, ?, ?, ?)",
      params = list(dt$metric_name, dt$date, dt$minute, dt$value)
    )
  }

  message("  [OK] ", date)
}

dbCommit(conn)
message("\nDatabase seeded successfully at: ", DB_PATH)
message("Total records: ", dbGetQuery(conn, "SELECT COUNT(*) AS n FROM metrics")$n)
