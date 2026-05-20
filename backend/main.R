library(healthr)

DB_PATH <- Sys.getenv("DB_PATH", "data/metrics.db")

logger <- Logger$new()
first <- TRUE
flag <- 0L

repeat {
  time <- Time$new(add = 0L)
  if (time$minute != flag) {
    flag <- time$minute
    if (time$minute == 5L || first) {
      logger$info("Running model training...")
      system(paste("Rscript /app/models/database.R"), wait = TRUE)
      first <- FALSE
    } else {
      logger$info("Running metric collection at minute", time$minute)
      system("Rscript /app/metrics/database.R", wait = TRUE)
      system(paste("Rscript /app/validations/database.R", time$minute, format(time$now, "%Y-%m-%d_%H:%M")), wait = TRUE)
    }
  }
  Sys.sleep(0.1)
}
