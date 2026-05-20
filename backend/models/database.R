library(healthr)

DB_PATH <- Sys.getenv("DB_PATH", "data/metrics.db")

PARAMS <- list(
  Parameter$new(name = "Pump Pressure", by = 10L, horizont = 4L * 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Pump Pressure'
                           AND date(date) < date('now', 'localtime')
                           AND date(date) >= date('now', 'localtime', '-28 days')
                           AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
                         ORDER BY date"),
  Parameter$new(name = "Turbine Vibration", by = 10L, horizont = 4L * 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Turbine Vibration'
                           AND date(date) < date('now', 'localtime')
                           AND date(date) >= date('now', 'localtime', '-28 days')
                           AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
                         ORDER BY date"),
  Parameter$new(name = "Flow Rate", by = 10L, horizont = 4L * 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Flow Rate'
                           AND date(date) < date('now', 'localtime')
                           AND date(date) >= date('now', 'localtime', '-28 days')
                           AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
                         ORDER BY date"),
  Parameter$new(name = "Process Temperature", by = 10L, horizont = 4L * 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Process Temperature'
                           AND date(date) < date('now', 'localtime')
                           AND date(date) >= date('now', 'localtime', '-28 days')
                           AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
                         ORDER BY date"),
  Parameter$new(name = "Power Consumption", by = 10L, horizont = 4L * 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Power Consumption'
                           AND date(date) < date('now', 'localtime')
                           AND date(date) >= date('now', 'localtime', '-28 days')
                           AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
                         ORDER BY date"),
  Parameter$new(name = "Compressor RPM", by = 10L, horizont = 4L * 1440L,
                query = "SELECT value AS count, date
                         FROM metrics
                         WHERE metric_name = 'Compressor RPM'
                           AND date(date) < date('now', 'localtime')
                           AND date(date) >= date('now', 'localtime', '-28 days')
                           AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
                         ORDER BY date")
)

logger <- Logger$new()
db <- Connection$new(DB_PATH)
metric <- Metric$new()
model <- Model$new()

# Ensure model_results table exists
conn <- pool::poolCheckout(db$pool)
DBI::dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS model_results (
    metric_name TEXT NOT NULL,
    period      INTEGER NOT NULL,
    lower       REAL NOT NULL,
    mean        REAL NOT NULL,
    upper       REAL NOT NULL
  )
")
DBI::dbExecute(conn, "CREATE INDEX IF NOT EXISTS idx_model_name ON model_results(metric_name)")
pool::poolReturn(conn)

for (param in PARAMS) {
  ok <- try({
    db$consult(param$query)
    metric$count(db$dt, param$validator, param$sequence)
    model$normalize(metric$dt, param$period)$train()$predict(param$period)

    # Persist model predictions
    conn <- pool::poolCheckout(db$pool)
    DBI::dbExecute(conn, sprintf("DELETE FROM model_results WHERE metric_name = '%s'", param$name))
    results <- data.table::data.table(
      metric_name = param$name,
      period      = seq_len(param$period),
      lower       = model$prediction$lower,
      mean        = model$prediction$mean,
      upper       = model$prediction$upper
    )
    DBI::dbWriteTable(conn, "model_results", results, append = TRUE)
    pool::poolReturn(conn)
  }, silent = TRUE)
  if (inherits(ok, "try-error")) {
    logger$error(param$name, ok)
  } else {
    logger$info(param$name, "Model trained!")
  }
}

db$close()
