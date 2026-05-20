library(healthr)

DB_PATH <- Sys.getenv("DB_PATH", "data/metrics.db")

METRIC_NAMES <- c("Pump Pressure", "Turbine Vibration", "Flow Rate",
                  "Process Temperature", "Power Consumption", "Compressor RPM")

args <- commandArgs(trailingOnly = TRUE)
minute <- as.integer(args[1])
time <- args[2]

logger <- Logger$new()
alert <- Alert$new()
db <- Connection$new(DB_PATH)

by <- 10L
if (minute %% by == 0L) {
  period <- round(minute / by)

  for (name in METRIC_NAMES) {
    ok <- try({
      # Get model prediction
      query <- sprintf(
        "SELECT lower, mean, upper FROM model_results WHERE metric_name = '%s' AND period = %d",
        name, period
      )
      db$consult(query)
      pred <- db$dt

      if (nrow(pred) == 0L) next

      # Get current metric value
      query <- sprintf(
        "SELECT value AS count FROM metrics
         WHERE metric_name = '%s'
           AND date(date) = date('now', 'localtime')
           AND minute = %d",
        name, minute
      )
      db$consult(query)
      current <- db$dt

      if (nrow(current) == 0L) next

      # Check if real value is below 90% of lower bound
      if (current$count[1L] < 0.9 * pred$lower[1L]) {
        section <- sprintf(
          "@here\n*%s at %s*\nConfidence: (%.1f, %.1f) vs Real: %.1f",
          name, time, pred$lower[1L], pred$upper[1L], current$count[1L]
        )
        alert$build(paste("ALERT:", name), section, "#FF0000")
        logger$warning(name, "Below lower bound!", "Real:", current$count[1L], "Expected:", pred$lower[1L])
      }
    }, silent = TRUE)

    if (inherits(ok, "try-error")) {
      logger$error(name, ok)
    }
  }
}

db$close()
