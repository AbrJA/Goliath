page_navbar(
  title = tags$span(
    class = "d-flex align-items-center gap-2",
    icon("industry", class = "fa-lg"),
    tags$span("Goliath", style = "font-weight: 700; font-size: 1.2rem; letter-spacing: -0.5px;"),
    tags$span("|", style = "opacity: 0.3; margin: 0 4px;"),
    tags$span("Industrial Process Intelligence", style = "font-weight: 300; font-size: 0.85rem; opacity: 0.8;")
  ),
  theme = THEME,
  navbar_options = navbar_options(bg = "#0d1b2a"),
  nav_spacer(),
  nav_item(tags$span(class = "text-muted small", textOutput("clock", inline = TRUE))),

  # ─── Tab 1: Command Center ──────────────────────────────────────────────────
  nav_panel(
    title = "Command Center",
    icon = icon("satellite-dish"),
    div(
      class = "p-3",
      # KPI Row
      layout_column_wrap(
        width = 1/6,
        heights_equal = "row",
        !!!lapply(names(METRICS), function(name) {
          m <- METRICS[[name]]
          value_box(
            title = tags$span(class = "small", name),
            value = textOutput(paste0("kpi_", gsub(" ", "_", name)), inline = TRUE),
            showcase = icon(m$icon),
            showcase_layout = showcase_left_center(width = 0.3),
            theme = value_box_theme(bg = m$color, fg = "white"),
            class = "border-0 shadow-sm"
          )
        })
      ),
      # Summary charts
      tags$div(class = "mt-3",
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center py-2",
            style = "background: #152238; border-bottom: 1px solid #1e3a5f;",
            tags$h6(class = "mb-0 text-light", icon("chart-area", class = "me-2"), "Real-Time Sensor Monitoring"),
            tags$span(class = "badge bg-success", textOutput("status_badge", inline = TRUE))
          ),
          card_body(
            class = "p-2",
            style = "background: #0f1923;",
            plotlyOutput("summary", height = "580px")
          )
        )
      )
    )
  ),

  # ─── Tab 2: Deep Analysis ───────────────────────────────────────────────────
  nav_panel(
    title = "Deep Analysis",
    icon = icon("microscope"),
    div(
      class = "p-3",
      layout_columns(
        col_widths = c(3, 9),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("sliders"), " Controls")),
          card_body(
            style = "background: #1a2937;",
            selectInput("zoom_name", tags$small(class = "text-light fw-bold", "METRIC"),
                        choices = names(METRICS), width = "100%"),
            selectInput("zoom_by", tags$small(class = "text-light fw-bold", "INTERVAL (MIN)"),
                        choices = c(1, 5, 10, 15, 30), selected = 10, width = "100%"),
            hr(style = "border-color: #2a4a6b;"),
            actionButton("zoom_execute", "Analyze",
                         icon = icon("magnifying-glass-chart"),
                         class = "btn-primary w-100 btn-lg mt-2"),
            hr(style = "border-color: #2a4a6b;"),
            tags$h6(class = "text-light mt-3", icon("info-circle"), " Insight"),
            tags$div(
              class = "p-2 rounded small",
              style = "background: #0f1923; color: #8899aa;",
              uiOutput("zoom_insight")
            )
          )
        ),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("chart-line"), " Detailed View")),
          card_body(
            style = "background: #0f1923;",
            plotlyOutput("zoom", height = "560px")
          )
        )
      )
    )
  ),

  # ─── Tab 3: Historical Analysis ─────────────────────────────────────────────
  nav_panel(
    title = "History",
    icon = icon("clock-rotate-left"),
    div(
      class = "p-3",
      layout_columns(
        col_widths = c(3, 9),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("calendar-days"), " Time Machine")),
          card_body(
            style = "background: #1a2937;",
            dateInput("history_date", tags$small(class = "text-light fw-bold", "DATE"),
                      min = Sys.Date() - 29, max = Sys.Date() - 1, value = Sys.Date() - 1, width = "100%"),
            selectInput("history_name", tags$small(class = "text-light fw-bold", "METRIC"),
                        choices = names(METRICS), width = "100%"),
            selectInput("history_by", tags$small(class = "text-light fw-bold", "INTERVAL (MIN)"),
                        choices = c(1, 5, 10, 15, 30, 60), selected = 10, width = "100%"),
            hr(style = "border-color: #2a4a6b;"),
            actionButton("history_execute", "Load History",
                         icon = icon("rotate-left"),
                         class = "btn-primary w-100 btn-lg mt-2"),
            hr(style = "border-color: #2a4a6b;"),
            tags$h6(class = "text-light mt-3", icon("chart-column"), " Day Summary"),
            tags$div(
              class = "p-2 rounded small",
              style = "background: #0f1923; color: #8899aa;",
              uiOutput("history_stats")
            )
          )
        ),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("clock-rotate-left"), " Predicted vs Actual")),
          card_body(
            style = "background: #0f1923;",
            plotlyOutput("history", height = "560px")
          )
        )
      )
    )
  ),

  # ─── Tab 4: Model Studio ────────────────────────────────────────────────────
  nav_panel(
    title = "Model Studio",
    icon = icon("brain"),
    div(
      class = "p-3",
      layout_columns(
        col_widths = c(4, 8),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("gears"), " Model Configuration")),
          card_body(
            style = "background: #1a2937;",
            selectInput("model_metric", tags$small(class = "text-light fw-bold", "METRIC"),
                        choices = names(METRICS), width = "100%"),
            sliderInput("model_k", tags$small(class = "text-light fw-bold", "FOURIER HARMONICS (K)"),
                        min = 1, max = 5, value = 4, step = 1, width = "100%"),
            sliderInput("model_confidence", tags$small(class = "text-light fw-bold", "CONFIDENCE LEVEL (%)"),
                        min = 80, max = 99, value = 99, step = 1, width = "100%"),
            selectInput("model_by", tags$small(class = "text-light fw-bold", "AGGREGATION INTERVAL"),
                        choices = c("1 min" = 1, "5 min" = 5, "10 min" = 10, "15 min" = 15, "30 min" = 30),
                        selected = 10, width = "100%"),
            hr(style = "border-color: #2a4a6b;"),
            actionButton("model_train", "Train Model",
                         icon = icon("brain"),
                         class = "btn-success w-100 btn-lg mt-2"),
            hr(style = "border-color: #2a4a6b;"),
            tags$h6(class = "text-light mt-3", icon("circle-info"), " Model Info"),
            tags$div(
              class = "p-2 rounded small",
              style = "background: #0f1923; color: #8899aa;",
              uiOutput("model_info")
            )
          )
        ),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("chart-line"), " Model Prediction Preview")),
          card_body(
            style = "background: #0f1923;",
            plotlyOutput("model_preview", height = "560px")
          )
        )
      )
    )
  ),

  # ─── Tab 5: Data Explorer ───────────────────────────────────────────────────
  nav_panel(
    title = "Data Explorer",
    icon = icon("database"),
    div(
      class = "p-3",
      layout_columns(
        col_widths = c(5, 7),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("terminal"), " SQL Query Console")),
          card_body(
            style = "background: #1a2937;",
            textAreaInput(
              "sql_query", NULL,
              value = "SELECT metric_name, AVG(value) as avg_value, MIN(value) as min_value, MAX(value) as max_value\nFROM metrics\nWHERE date(date) = date('now', 'localtime')\nGROUP BY metric_name",
              rows = 7,
              placeholder = "SELECT * FROM metrics WHERE metric_name = 'Pump Pressure' LIMIT 100"
            ),
            tags$style(".shiny-input-container:has(#sql_query) { width: 100%; }
                        #sql_query { background: #0f1923; color: #66d9ef; border: 1px solid #2a4a6b; font-family: monospace; font-size: 0.85rem; }"),
            layout_column_wrap(
              width = 1/2,
              class = "mt-3",
              actionButton("sql_execute", "Execute Query",
                           icon = icon("play"), class = "btn-primary w-100"),
              actionButton("sql_plot", "Plot Results",
                           icon = icon("chart-simple"), class = "btn-info w-100")
            ),
            hr(style = "border-color: #2a4a6b;"),
            tags$h6(class = "text-light", icon("lightbulb"), " Quick Queries"),
            actionButton("sql_quick_1", "Today's Stats", class = "btn-outline-light btn-sm me-1 mb-1", icon = icon("calendar-day")),
            actionButton("sql_quick_2", "Anomalies", class = "btn-outline-warning btn-sm me-1 mb-1", icon = icon("triangle-exclamation")),
            actionButton("sql_quick_3", "Metric Catalog", class = "btn-outline-info btn-sm me-1 mb-1", icon = icon("list")),
            actionButton("sql_quick_4", "Last Hour", class = "btn-outline-success btn-sm mb-1", icon = icon("clock"))
          )
        ),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("table"), " Results")),
          card_body(
            style = "background: #0f1923; overflow: auto;",
            plotlyOutput("sql_chart", height = "250px"),
            hr(style = "border-color: #2a4a6b;"),
            div(style = "max-height: 300px; overflow-y: auto;",
              tableOutput("sql_results")
            )
          )
        )
      )
    )
  ),

  # ─── Tab 6: Anomaly Detection ─────────────────────────────────────────────
  nav_panel(
    title = "Anomaly Detection",
    icon = icon("magnifying-glass-chart"),
    div(
      class = "p-3",
      layout_columns(
        col_widths = c(3, 9),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("sliders"), " Parameters")),
          card_body(
            style = "background: #1a2937;",
            selectInput("anomaly_metric", "Metric",
                        choices = names(METRICS), selected = names(METRICS)[1]),
            sliderInput("anomaly_sensitivity", "Sensitivity (σ)", min = 1.5, max = 4, value = 2.5, step = 0.5),
            selectInput("anomaly_window", "Lookback Window",
                        choices = c("Today" = "0", "3 Days" = "3", "7 Days" = "7", "14 Days" = "14"),
                        selected = "7"),
            actionButton("anomaly_detect", "Run Detection",
                         icon = icon("search"), class = "btn-danger w-100 mt-2")
          )
        ),
        div(
          card(
            card_header(class = "py-2", style = "background: #152238;",
                        tags$h6(class = "mb-0 text-light", icon("chart-area"), " Anomaly Timeline")),
            card_body(style = "background: #0f1923;", plotlyOutput("anomaly_plot", height = "300px"))
          ),
          layout_column_wrap(
            width = 1/3, class = "mt-3",
            value_box(title = "Anomalies Detected", value = textOutput("anomaly_count"),
                      showcase = icon("circle-exclamation"),
                      theme = value_box_theme(bg = "#8b2020", fg = "white")),
            value_box(title = "Max Severity", value = textOutput("anomaly_severity"),
                      showcase = icon("bolt"),
                      theme = value_box_theme(bg = "#6b3a0a", fg = "white")),
            value_box(title = "Health Score", value = textOutput("anomaly_health"),
                      showcase = icon("heart-pulse"),
                      theme = value_box_theme(bg = "#1a5c2a", fg = "white"))
          ),
          card(
            class = "mt-3",
            card_header(class = "py-2", style = "background: #152238;",
                        tags$h6(class = "mb-0 text-light", icon("list"), " Anomaly Log")),
            card_body(
              style = "background: #0f1923; max-height: 200px; overflow-y: auto;",
              tableOutput("anomaly_table")
            )
          )
        )
      )
    )
  ),

  # ─── Tab 7: Correlations ────────────────────────────────────────────────────
  nav_panel(
    title = "Correlations",
    icon = icon("diagram-project"),
    div(
      class = "p-3",
      layout_columns(
        col_widths = c(3, 9),
        card(
          card_header(class = "py-2", style = "background: #152238;",
                      tags$h6(class = "mb-0 text-light", icon("sliders"), " Settings")),
          card_body(
            style = "background: #1a2937;",
            selectInput("corr_window", "Time Window",
                        choices = c("Today" = "0", "7 Days" = "7", "14 Days" = "14", "30 Days" = "30"),
                        selected = "7"),
            selectInput("corr_method", "Method",
                        choices = c("Pearson" = "pearson", "Spearman" = "spearman"),
                        selected = "pearson"),
            actionButton("corr_compute", "Compute",
                         icon = icon("calculator"), class = "btn-info w-100 mt-2"),
            hr(style = "border-color: #2a4a6b;"),
            tags$h6(class = "text-muted mt-3", "Pair Analysis"),
            selectInput("corr_x", "Metric X", choices = names(METRICS), selected = names(METRICS)[1]),
            selectInput("corr_y", "Metric Y", choices = names(METRICS), selected = names(METRICS)[2]),
            actionButton("corr_scatter", "Scatter Plot",
                         icon = icon("braille"), class = "btn-outline-info w-100 mt-2")
          )
        ),
        div(
          card(
            card_header(class = "py-2", style = "background: #152238;",
                        tags$h6(class = "mb-0 text-light", icon("table-cells"), " Correlation Matrix")),
            card_body(style = "background: #0f1923;", plotlyOutput("corr_matrix", height = "350px"))
          ),
          card(
            class = "mt-3",
            card_header(class = "py-2", style = "background: #152238;",
                        tags$h6(class = "mb-0 text-light", icon("arrows-left-right"), " Pair Scatter")),
            card_body(style = "background: #0f1923;", plotlyOutput("corr_scatter_plot", height = "300px"))
          )
        )
      )
    )
  ),

  # ─── Tab 8: System Health ───────────────────────────────────────────────────
  nav_panel(
    title = "Alerts",
    icon = icon("shield-halved"),
    div(
      class = "p-3",
      layout_column_wrap(
        width = 1/3,
        heights_equal = "row",
        value_box(
          title = "System Status",
          value = textOutput("sys_status", inline = TRUE),
          showcase = icon("heart-pulse"),
          theme = value_box_theme(bg = "#1a5c2a", fg = "white")
        ),
        value_box(
          title = "Active Alerts",
          value = textOutput("alert_count", inline = TRUE),
          showcase = icon("bell"),
          theme = value_box_theme(bg = "#8b4513", fg = "white")
        ),
        value_box(
          title = "Model Freshness",
          value = textOutput("model_age", inline = TRUE),
          showcase = icon("clock"),
          theme = value_box_theme(bg = "#2a4a6b", fg = "white")
        )
      ),
      tags$div(class = "mt-3",
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center py-2",
            style = "background: #152238;",
            tags$h6(class = "mb-0 text-light", icon("triangle-exclamation"), " Threshold Status"),
            actionButton("refresh_alerts", "Refresh", icon = icon("rotate"), class = "btn-outline-light btn-sm")
          ),
          card_body(
            style = "background: #0f1923;",
            tableOutput("alerts_table")
          )
        )
      )
    )
  )
)
