#!/usr/bin/env Rscript
# ==============================================================================
# Setup Script — Run this once to seed the database and train initial models
# ==============================================================================

cat("
╔══════════════════════════════════════════════════════════════════╗
║       Industrial Process Monitor — Initial Setup                ║
╚══════════════════════════════════════════════════════════════════╝
\n")

# --- Step 1: Generate synthetic sensor data ---
cat("[1/3] Generating synthetic sensor data...\n")
source("backend/generator/seed.R")

# --- Step 2: Create results tables ---
cat("\n[2/3] Creating results tables...\n")
conn <- DBI::dbConnect(RSQLite::SQLite(), DB_PATH)

DBI::dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS metric_results (
    metric_name TEXT NOT NULL,
    period      INTEGER NOT NULL,
    count       REAL NOT NULL
  )
")

DBI::dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS model_results (
    metric_name TEXT NOT NULL,
    period      INTEGER NOT NULL,
    lower       REAL NOT NULL,
    mean        REAL NOT NULL,
    upper       REAL NOT NULL
  )
")

DBI::dbExecute(conn, "CREATE INDEX IF NOT EXISTS idx_metric_results_name ON metric_results(metric_name)")
DBI::dbExecute(conn, "CREATE INDEX IF NOT EXISTS idx_model_name ON model_results(metric_name)")
DBI::dbDisconnect(conn)
cat("  [OK] Tables created\n")

# --- Step 3: Train initial models ---
cat("\n[3/3] Training predictive models (this may take a moment)...\n")
source("backend/models/database.R")

cat("\n
╔══════════════════════════════════════════════════════════════════╗
║  Setup complete! Run the dashboard with:                        ║
║    shiny::runApp('dashboard', port = 8000)                      ║
╚══════════════════════════════════════════════════════════════════╝
\n")
