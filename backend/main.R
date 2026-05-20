library(healthr)

DB_PATH <- Sys.getenv("DB_PATH", "data/metrics.db")

logger <- Logger$new()

# ── First-time initialization ─────────────────────────────────────────────────
# Runs automatically when the container starts with an empty data volume.
# No need to run setup.R manually for Docker deployments.
needs_init <- !file.exists(DB_PATH) || {
  conn <- DBI::dbConnect(RSQLite::SQLite(), DB_PATH)
  n <- DBI::dbGetQuery(conn,
    "SELECT COUNT(*) AS n FROM sqlite_master WHERE type='table' AND name='metrics'")$n
  DBI::dbDisconnect(conn)
  n == 0L
}

if (needs_init) {
  logger$info("Goliath", "First run — seeding database (30 days of sensor data)...")
  system("Rscript /app/generator/seed.R", wait = TRUE)
  logger$info("Goliath", "Training initial predictive models...")
  system("Rscript /app/models/database.R", wait = TRUE)
  logger$info("Goliath", "Initialization complete.")
}

# ── Event loop ────────────────────────────────────────────────────────────────
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
