library(shiny)
library(plotly)
library(bslib)
library(DBI)
library(RSQLite)
library(data.table)

METRICS <- list(
  "Pump Pressure"       = list(unit = "PSI",    icon = "gauge-high",          color = "#3498db", by = 10L),
  "Turbine Vibration"   = list(unit = "mm/s",   icon = "wave-square",         color = "#e74c3c", by = 10L),
  "Flow Rate"           = list(unit = "bbl/hr", icon = "droplet",             color = "#2ecc71", by = 10L),
  "Process Temperature" = list(unit = "°F",     icon = "temperature-high",    color = "#f39c12", by = 10L),
  "Power Consumption"   = list(unit = "MW",     icon = "bolt",                color = "#9b59b6", by = 10L),
  "Compressor RPM"      = list(unit = "RPM",    icon = "fan",                 color = "#1abc9c", by = 10L)
)

THEME <- bs_theme(
  version = 5,
  bootswatch = "superhero",
  primary = "#1a73e8",
  secondary = "#5f6368",
  success = "#34a853",
  danger = "#ea4335",
  warning = "#fbbc04",
  info = "#4285f4",
  "body-bg" = "#0f1923",
  "card-bg" = "#1a2937",
  "navbar-bg" = "#0d1b2a",
  base_font = font_google("Inter"),
  heading_font = font_google("Inter"),
  font_scale = 0.9
)
