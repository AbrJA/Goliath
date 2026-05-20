library(healthr)

DB_PATH <- Sys.getenv("DB_PATH", "data/metrics.db")

PARAMS <- list(
  Parameter$new(name = "Pump Pressure", by = 1L, horizont = 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Pump Pressure'
                           AND date(date) = date('now', 'localtime')
                         ORDER BY minute"),
  Parameter$new(name = "Turbine Vibration", by = 1L, horizont = 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Turbine Vibration'
                           AND date(date) = date('now', 'localtime')
                         ORDER BY minute"),
  Parameter$new(name = "Flow Rate", by = 1L, horizont = 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Flow Rate'
                           AND date(date) = date('now', 'localtime')
                         ORDER BY minute"),
  Parameter$new(name = "Process Temperature", by = 1L, horizont = 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Process Temperature'
                           AND date(date) = date('now', 'localtime')
                         ORDER BY minute"),
  Parameter$new(name = "Power Consumption", by = 1L, horizont = 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Power Consumption'
                           AND date(date) = date('now', 'localtime')
                         ORDER BY minute"),
  Parameter$new(name = "Compressor RPM", by = 1L, horizont = 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Compressor RPM'
                           AND date(date) = date('now', 'localtime')
                         ORDER BY minute")
)

logger <- Logger$new()
db <- Connection$new(DB_PATH)
metric <- Metric$new()

for (param in PARAMS) {
  ok <- try({
    db$consult(param$query)
    metric$count(db$dt, param$validator, param$sequence)
    # Store metric results back into a results table
    conn <- pool::poolCheckout(db$pool)
    DBI::dbExecute(conn, sprintf("DELETE FROM metric_results WHERE metric_name = '%s'", param$name))
    results <- metric$dt
    results[, metric_name := param$name]
    DBI::dbWriteTable(conn, "metric_results", results, append = TRUE)
    pool::poolReturn(conn)
  }, silent = TRUE)
  if (inherits(ok, "try-error")) {
    logger$error(param$name, ok)
  } else {
    logger$info(param$name, "Metric saved!")
  }
}

db$close()
