library(healthr)

source("./constants/server.R")
source("./functions/server.R")

DB_PATH <- Sys.getenv("DB_PATH", file.path(getwd(), "data", "metrics.db"))
if (!file.exists(DB_PATH)) {
  DB_PATH <- file.path(dirname(getwd()), "data", "metrics.db")
}
db <- Connection$new(DB_PATH)

onStop(function() {
  db$close()
})

function(input, output, session) {

  # ═══════════════════════════════════════════════════════════════════════════════
  # SHARED REACTIVES
  # ═══════════════════════════════════════════════════════════════════════════════

  invalidateSummary <- reactiveTimer(30L * 1000L)

  output$clock <- renderText({
    invalidateLater(1000)
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  })

  output$status_badge <- renderText({
    invalidateSummary()
    "\U25CF LIVE"
  })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 1: COMMAND CENTER — KPIs + Summary
  # ═══════════════════════════════════════════════════════════════════════════════

  observe({
    invalidateSummary()
    for (name in names(METRICS)) {
      local({
        n <- name
        m <- METRICS[[n]]
        query <- sprintf(
          "SELECT value FROM metrics WHERE metric_name = '%s' AND date(date) = date('now', 'localtime') ORDER BY minute DESC LIMIT 1", n
        )
        ok <- try(db$consult(query), silent = TRUE)
        val <- if (!inherits(ok, "try-error") && nrow(db$dt) > 0L) {
          paste(round(db$dt$value[1L], 1), m$unit)
        } else {
          "\U2014"
        }
        output[[paste0("kpi_", gsub(" ", "_", n))]] <- renderText(val)
      })
    }
  })

  summary <- reactive({
    invalidateSummary()
    time <- Time$new(add = 0L)
    plots <- vector("list", length(METRICS))
    i <- 1L

    for (name in names(METRICS)) {
      by <- METRICS[[name]]$by
      unit <- METRICS[[name]]$unit
      color <- METRICS[[name]]$color

      query <- sprintf("SELECT lower, mean, upper FROM model_results WHERE metric_name = '%s' ORDER BY period", name)
      db$consult(query)
      pred <- db$dt

      query <- sprintf(
        "SELECT minute, value AS count FROM metrics
         WHERE metric_name = '%s' AND date(date) = date('now', 'localtime')
         ORDER BY minute", name
      )
      db$consult(query)
      actual <- db$dt

      if (nrow(pred) > 0L && nrow(actual) > 0L) {
        param <- Parameter$new(name = name, by = by, horizont = 1440L)
        actual_agg <- data.table::data.table(period = param$sequence[seq_len(nrow(actual))],
                                             count = actual$count)
        actual_agg <- actual_agg[, .(count = mean(count)), by = .(period)]
        time$scale(by)

        n_pred <- min(nrow(pred), length(time$serie))
        n_actual <- min(nrow(actual_agg), time$period)

        plots[[i]] <- plot_ly() %>%
          plot_ribbons(time$serie[seq_len(n_pred)], pred$lower[seq_len(n_pred)], pred$upper[seq_len(n_pred)]) %>%
          plot_lines(time$serie, pred$mean, n_pred, "predicted", "#546e7a", c(1L, 1L)) %>%
          plot_lines(time$serie, actual_agg$count, n_actual, "actual", color, c(2L, 2L)) %>%
          plot_layout(actual_agg$count, n_actual, paste0(name, " (", unit, ")"), showgrid = FALSE)
      } else {
        plots[[i]] <- plot_ly() %>%
          layout(title = list(text = paste(name, "\U2014 Awaiting data"), font = list(color = "#8899aa")),
                 paper_bgcolor = "transparent", plot_bgcolor = "transparent")
      }
      i <- i + 1L
    }

    subplot(plots, nrows = 2L, margin = c(0.04, 0.04, 0.08, 0.08), titleX = TRUE, titleY = TRUE) %>%
      layout(
        annotations = ANNOTATIONS_SUMMARY,
        showlegend = FALSE,
        paper_bgcolor = "transparent",
        plot_bgcolor = "transparent"
      )
  })

  output$summary <- renderPlotly({ summary() })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 2: DEEP ANALYSIS
  # ═══════════════════════════════════════════════════════════════════════════════

  zoom_data <- eventReactive(input$zoom_execute, {
    name <- input$zoom_name
    by <- as.integer(input$zoom_by)
    unit <- METRICS[[name]]$unit
    color <- METRICS[[name]]$color
    time <- Time$new(add = 0L)

    query <- sprintf("SELECT lower, mean, upper FROM model_results WHERE metric_name = '%s' ORDER BY period", name)
    db$consult(query)
    pred <- db$dt

    query <- sprintf(
      "SELECT minute, value AS count FROM metrics
       WHERE metric_name = '%s' AND date(date) = date('now', 'localtime')
       ORDER BY minute", name
    )
    db$consult(query)
    actual <- db$dt

    if (nrow(pred) > 0L && nrow(actual) > 0L) {
      # Interpolate stored 10-min model predictions to the chosen resolution
      n_out <- 1440L / by
      if (nrow(pred) != n_out) {
        x_src <- seq_len(nrow(pred))
        x_dst <- seq(1, nrow(pred), length.out = n_out)
        pred <- data.table::data.table(
          lower = stats::approx(x_src, pred$lower, xout = x_dst)$y,
          mean  = stats::approx(x_src, pred$mean,  xout = x_dst)$y,
          upper = stats::approx(x_src, pred$upper, xout = x_dst)$y
        )
      }

      param <- Parameter$new(name = name, by = by, horizont = 1440L)
      actual_agg <- data.table::data.table(period = param$sequence[seq_len(nrow(actual))],
                                           count = actual$count)
      actual_agg <- actual_agg[, .(count = mean(count)), by = .(period)]
      time$scale(by)

      n_pred <- min(nrow(pred), length(time$serie))
      n_actual <- min(nrow(actual_agg), time$period)

      p <- plot_ly() %>%
        plot_ribbons(time$serie[seq_len(n_pred)], pred$lower[seq_len(n_pred)], pred$upper[seq_len(n_pred)]) %>%
        plot_lines(time$serie, pred$mean, n_pred, "predicted", "#546e7a", c(2L, 2L)) %>%
        plot_lines(time$serie, actual_agg$count, n_actual, "actual", color, c(2L, 3L)) %>%
        plot_layout(actual_agg$count, n_actual, paste0(name, " (", unit, ")"))

      list(plot = p, actual = actual_agg, pred = pred, n_actual = n_actual)
    } else {
      list(plot = plot_ly() %>% layout(title = "No data available"), actual = NULL, pred = NULL, n_actual = 0)
    }
  })

  output$zoom <- renderPlotly({ zoom_data()$plot })

  output$zoom_insight <- renderUI({
    data <- zoom_data()
    if (is.null(data$actual)) return(tags$p("Run an analysis to see insights."))

    current_val <- data$actual$count[data$n_actual]
    avg_val <- mean(data$actual$count, na.rm = TRUE)
    max_val <- max(data$actual$count, na.rm = TRUE)
    min_val <- min(data$actual$count, na.rm = TRUE)

    n <- min(data$n_actual, nrow(data$pred))
    breaches <- sum(data$actual$count[seq_len(n)] < data$pred$lower[seq_len(n)] |
                    data$actual$count[seq_len(n)] > data$pred$upper[seq_len(n)], na.rm = TRUE)

    tags$div(
      tags$p(icon("circle-dot", class = "text-info"), sprintf(" Current: %.2f", current_val)),
      tags$p(icon("arrows-left-right", class = "text-warning"), sprintf(" Range: %.2f \U2014 %.2f", min_val, max_val)),
      tags$p(icon("chart-bar", class = "text-success"), sprintf(" Average: %.2f", avg_val)),
      tags$p(icon("triangle-exclamation", class = "text-danger"),
             sprintf(" Threshold breaches: %d", breaches))
    )
  })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 3: HISTORY
  # ═══════════════════════════════════════════════════════════════════════════════

  history_result <- eventReactive(input$history_execute, {
    name <- input$history_name
    by <- as.integer(input$history_by)
    date <- as.character(input$history_date)
    unit <- METRICS[[name]]$unit
    color <- METRICS[[name]]$color
    time <- Time$new(date = date)

    weekday <- as.POSIXlt(date)$wday
    query <- sprintf(
      "SELECT value AS count, date FROM metrics
       WHERE metric_name = '%s'
         AND date(date) < '%s'
         AND date(date) >= date('%s', '-28 days')
         AND CAST(strftime('%%w', date) AS INTEGER) = %d
       ORDER BY date",
      name, date, date, weekday
    )
    db$consult(query)
    model_data <- db$dt

    query <- sprintf(
      "SELECT value AS count, date FROM metrics
       WHERE metric_name = '%s' AND date(date) = '%s'
       ORDER BY minute", name, date
    )
    db$consult(query)
    actual_data <- db$dt

    if (nrow(model_data) > 0L && nrow(actual_data) > 0L) {
      model <- Model$new()

      model_data[nchar(as.character(date)) <= 10L, date := paste0(date, " 00:00:00")]
      model_data[, date := as.POSIXct(date, format = "%Y-%m-%d %H:%M:%S")]
      data.table::setorder(model_data, date)
      model_data[, day := .GRP - 1L, by = .(data.table::yday(date))]
      n_days <- model_data[, max(day) + 1L]
      model_data[, period := 1440L * day + as.integer(format(date, "%H")) * 60L + as.integer(format(date, "%M"))]
      model_data[, day := NULL]
      horizont_model <- n_days * 1440L
      param <- Parameter$new(name = name, by = by, horizont = horizont_model)
      validator_model <- data.table::data.table(period = seq_len(horizont_model) - 1L, count = 0.0)
      validator_model[model_data, count := i.count, on = .(period)]
      dt_model <- validator_model[, .(count = mean(count)), by = .(period = param$sequence)]
      data.table::setkey(dt_model, period)

      model$normalize(dt_model, param$period)$train()$predict(param$period)

      actual_data[nchar(as.character(date)) <= 10L, date := paste0(date, " 00:00:00")]
      actual_data[, date := as.POSIXct(date, format = "%Y-%m-%d %H:%M:%S")]
      data.table::setorder(actual_data, date)
      actual_data[, period := as.integer(format(date, "%H")) * 60L + as.integer(format(date, "%M"))]
      validator_actual <- data.table::data.table(period = seq_len(1440L) - 1L, count = 0.0)
      validator_actual[actual_data, count := i.count, on = .(period)]
      param_day <- Parameter$new(name = name, by = by, horizont = 1440L)
      dt_actual <- validator_actual[, .(count = mean(count)), by = .(period = param_day$sequence)]
      data.table::setkey(dt_actual, period)

      time$scale(by)
      p <- plot_ly() %>%
        plot_ribbons(time$serie, model$prediction$lower, model$prediction$upper) %>%
        plot_lines(time$serie, model$prediction$mean, length(time$serie), "predicted", "#546e7a", c(2L, 2L)) %>%
        plot_lines(time$serie, dt_actual$count, time$period, "actual", color, c(2L, 3L)) %>%
        plot_layout(dt_actual$count, time$period, paste0(name, " (", unit, ") \U2014 ", date))

      list(plot = p, actual = dt_actual, prediction = model$prediction)
    } else {
      list(plot = plot_ly() %>% layout(title = "Insufficient historical data"),
           actual = NULL, prediction = NULL)
    }
  })

  output$history <- renderPlotly({ history_result()$plot })

  output$history_stats <- renderUI({
    data <- history_result()
    if (is.null(data$actual)) return(tags$p("Select a date and load history."))
    tags$div(
      tags$p(icon("chart-bar", class = "text-info"), sprintf(" Mean: %.2f", mean(data$actual$count, na.rm = TRUE))),
      tags$p(icon("arrow-up", class = "text-danger"), sprintf(" Max: %.2f", max(data$actual$count, na.rm = TRUE))),
      tags$p(icon("arrow-down", class = "text-success"), sprintf(" Min: %.2f", min(data$actual$count, na.rm = TRUE))),
      tags$p(icon("wave-square", class = "text-warning"), sprintf(" Std Dev: %.2f", sd(data$actual$count, na.rm = TRUE)))
    )
  })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 4: MODEL STUDIO
  # ═══════════════════════════════════════════════════════════════════════════════

  model_result <- eventReactive(input$model_train, {
    name <- input$model_metric
    k <- as.integer(input$model_k)
    level <- as.integer(input$model_confidence)
    by <- as.integer(input$model_by)
    unit <- METRICS[[name]]$unit
    color <- METRICS[[name]]$color

    query <- sprintf(
      "SELECT value AS count, date FROM metrics
       WHERE metric_name = '%s'
         AND date(date) < date('now', 'localtime')
         AND date(date) >= date('now', 'localtime', '-28 days')
         AND CAST(strftime('%%w', date) AS INTEGER) = CAST(strftime('%%w', 'now', 'localtime') AS INTEGER)
       ORDER BY date", name
    )
    db$consult(query)
    model_data <- db$dt

    if (nrow(model_data) > 0L) {
      horizont <- 4L * 1440L
      param <- Parameter$new(name = name, by = by, horizont = horizont)
      model <- Model$new()

      model_data[nchar(as.character(date)) <= 10L, date := paste0(date, " 00:00:00")]
      model_data[, date := as.POSIXct(date, format = "%Y-%m-%d %H:%M:%S")]
      data.table::setorder(model_data, date)
      model_data[, day := .GRP - 1L, by = .(data.table::yday(date))]
      model_data[, period := 1440L * day + as.integer(format(date, "%H")) * 60L + as.integer(format(date, "%M"))]
      model_data[, day := NULL]
      validator <- data.table::data.table(period = seq_len(horizont) - 1L, count = 0.0)
      validator[model_data, count := i.count, on = .(period)]
      dt_model <- validator[, .(count = mean(count)), by = .(period = param$sequence)]
      data.table::setkey(dt_model, period)

      model$normalize(dt_model, param$period)$train(k = k)$predict(param$period, level = level, k = k)

      time <- Time$new(add = 0L)
      time$scale(by)
      n <- min(length(model$prediction$mean), length(time$serie))

      p <- plot_ly() %>%
        plot_ribbons(time$serie[seq_len(n)], model$prediction$lower[seq_len(n)], model$prediction$upper[seq_len(n)]) %>%
        plot_lines(time$serie, model$prediction$mean, n, "predicted", color, c(2L, 2L)) %>%
        plot_layout(model$prediction$mean, n, paste0(name, " \U2014 Model Preview (K=", k, ", ", level, "% CI)"))

      lm_fit <- model$model
      r_sq <- if (!is.null(lm_fit)) tryCatch(summary.lm(lm_fit)$r.squared, error = function(e) NA_real_) else NA_real_
      list(plot = p, model = model, r_squared = r_sq,
           k = k, level = level, periods = n)
    } else {
      list(plot = plot_ly() %>% layout(title = "No training data available"),
           model = NULL, r_squared = NA, k = k, level = level, periods = 0)
    }
  })

  output$model_preview <- renderPlotly({ model_result()$plot })

  output$model_info <- renderUI({
    data <- model_result()
    if (is.null(data$model)) return(tags$p("Train a model to see info."))
    tags$div(
      tags$p(icon("brain", class = "text-success"), sprintf(" R\U00B2: %.4f", data$r_squared)),
      tags$p(icon("wave-square", class = "text-info"), sprintf(" Harmonics: K=%d", data$k)),
      tags$p(icon("shield-halved", class = "text-warning"), sprintf(" Confidence: %d%%", data$level)),
      tags$p(icon("timeline", class = "text-primary"), sprintf(" Periods: %d", data$periods)),
      tags$p(icon("check-circle", class = "text-success"), " Status: Trained")
    )
  })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 5: DATA EXPLORER
  # ═══════════════════════════════════════════════════════════════════════════════

  sql_result <- reactiveVal(NULL)

  observeEvent(input$sql_quick_1, {
    updateTextAreaInput(session, "sql_query", value =
      "SELECT metric_name, COUNT(*) as readings, ROUND(AVG(value), 2) as avg_value,\n  ROUND(MIN(value), 2) as min_value, ROUND(MAX(value), 2) as max_value\nFROM metrics\nWHERE date(date) = date('now', 'localtime')\nGROUP BY metric_name")
  })
  observeEvent(input$sql_quick_2, {
    updateTextAreaInput(session, "sql_query", value =
      "SELECT m.metric_name, m.minute, ROUND(m.value, 2) as actual,\n  ROUND(r.lower, 2) as lower_bound, ROUND(r.upper, 2) as upper_bound,\n  CASE WHEN m.value < r.lower THEN 'BELOW' WHEN m.value > r.upper THEN 'ABOVE' ELSE 'NORMAL' END as status\nFROM metrics m\nJOIN model_results r ON r.metric_name = m.metric_name AND r.period = (m.minute / 10) + 1\nWHERE date(m.date) = date('now', 'localtime')\n  AND (m.value < r.lower OR m.value > r.upper)\nORDER BY m.minute DESC\nLIMIT 50")
  })
  observeEvent(input$sql_quick_3, {
    updateTextAreaInput(session, "sql_query", value = "SELECT * FROM metric_catalog")
  })
  observeEvent(input$sql_quick_4, {
    updateTextAreaInput(session, "sql_query", value =
      "SELECT metric_name, minute, ROUND(value, 2) as value\nFROM metrics\nWHERE date(date) = date('now', 'localtime')\n  AND minute >= (CAST(strftime('%H', 'now', 'localtime') AS INTEGER) * 60 + CAST(strftime('%M', 'now', 'localtime') AS INTEGER) - 60)\nORDER BY metric_name, minute")
  })

  observeEvent(input$sql_execute, {
    query <- input$sql_query
    if (nchar(trimws(query)) == 0L) return()
    # Only allow SELECT queries (read-only safety)
    if (!grepl("^\\s*(SELECT|WITH)", query, ignore.case = TRUE)) {
      sql_result(data.frame(Error = "Only SELECT queries are allowed for safety."))
      return()
    }
    ok <- try({ db$consult(query); db$dt }, silent = TRUE)
    if (inherits(ok, "try-error")) {
      sql_result(data.frame(Error = as.character(ok)))
    } else {
      sql_result(as.data.frame(ok))
    }
  })

  output$sql_results <- renderTable({
    req(sql_result())
    head(sql_result(), 100)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", rownames = FALSE)

  output$sql_chart <- renderPlotly({
    input$sql_plot
    data <- isolate(sql_result())
    req(data)
    if ("Error" %in% names(data)) {
      return(plot_ly() %>% layout(title = "Fix query errors first",
                                  paper_bgcolor = "transparent", plot_bgcolor = "transparent"))
    }

    numeric_cols <- names(data)[sapply(data, is.numeric)]
    if (length(numeric_cols) == 0L) {
      return(plot_ly() %>% layout(
        title = list(text = "No numeric columns — table view only", font = list(color = "#8899aa")),
        paper_bgcolor = "transparent", plot_bgcolor = "transparent"))
    }

    colors <- c("#3498db", "#e74c3c", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c")

    # Detect best chart type from data shape
    time_col  <- intersect(c("minute", "hour", "period", "day"), names(data))[1]
    group_col <- intersect(c("metric_name", "name", "group"), names(data))[1]
    p <- plot_ly()

    if (!is.na(time_col)) {
      # Time-series data → line chart
      if (!is.na(group_col)) {
        groups <- unique(data[[group_col]])
        for (j in seq_along(groups)) {
          gd <- data[data[[group_col]] == groups[j], ]
          p <- p %>% add_trace(x = gd[[time_col]], y = gd[[numeric_cols[1L]]],
                               type = "scatter", mode = "lines", name = groups[j],
                               line = list(color = colors[((j - 1L) %% 6L) + 1L]))
        }
      } else {
        for (j in seq_along(numeric_cols)) {
          p <- p %>% add_trace(x = data[[time_col]], y = data[[numeric_cols[j]]],
                               type = "scatter", mode = "lines", name = numeric_cols[j],
                               line = list(color = colors[((j - 1L) %% 6L) + 1L]))
        }
      }
      p %>% layout(
        xaxis = list(title = time_col, color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        yaxis = list(title = "Value",  color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font = list(color = "#8899aa"), legend = list(font = list(color = "#ccc")))
    } else if (!is.na(group_col) && nrow(data) <= 30L) {
      # Aggregate stats per category → grouped bar chart
      for (j in seq_along(numeric_cols)) {
        p <- p %>% add_trace(x = data[[group_col]], y = data[[numeric_cols[j]]],
                             type = "bar", name = numeric_cols[j],
                             marker = list(color = colors[((j - 1L) %% 6L) + 1L]))
      }
      p %>% layout(
        barmode = "group",
        xaxis = list(title = group_col, color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        yaxis = list(title = "Value",   color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font = list(color = "#8899aa"), legend = list(font = list(color = "#ccc")))
    } else {
      # Raw / many rows → box plot grouped by metric category when available
      if (!is.na(group_col)) {
        groups <- unique(data[[group_col]])
        for (j in seq_along(groups)) {
          gd <- data[data[[group_col]] == groups[j], ]
          p <- p %>% add_trace(y = gd[[numeric_cols[1L]]], type = "box",
                               name = groups[j], boxpoints = "outliers",
                               marker = list(color = colors[((j - 1L) %% 6L) + 1L]),
                               line  = list(color = colors[((j - 1L) %% 6L) + 1L]))
        }
      } else {
        for (j in seq_along(numeric_cols)) {
          p <- p %>% add_trace(y = data[[numeric_cols[j]]], type = "box",
                               name = numeric_cols[j], boxpoints = "outliers",
                               marker = list(color = colors[((j - 1L) %% 6L) + 1L]),
                               line  = list(color = colors[((j - 1L) %% 6L) + 1L]))
        }
      }
      p %>% layout(
        xaxis = list(color = "#8899aa"),
        yaxis = list(title = "Value", color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font = list(color = "#8899aa"), legend = list(font = list(color = "#ccc")))
    }
  })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 6: ALERTS
  # ═══════════════════════════════════════════════════════════════════════════════

  alerts_data <- eventReactive(input$refresh_alerts, {
    time <- Time$new(add = 0L)
    alerts <- data.frame(
      Metric = character(), Status = character(), Current = numeric(),
      Lower = numeric(), Upper = numeric(), Deviation = character(),
      stringsAsFactors = FALSE
    )

    for (name in names(METRICS)) {
      period <- min(144L, floor(time$minute / 10L) + 1L)
      query <- sprintf(
        "SELECT lower, mean, upper FROM model_results WHERE metric_name = '%s' AND period = %d", name, period
      )
      ok <- try(db$consult(query), silent = TRUE)
      if (inherits(ok, "try-error") || nrow(db$dt) == 0L) next
      pred <- db$dt

      query <- sprintf(
        "SELECT value FROM metrics WHERE metric_name = '%s' AND date(date) = date('now', 'localtime') AND minute = %d",
        name, time$minute
      )
      ok <- try(db$consult(query), silent = TRUE)
      if (inherits(ok, "try-error") || nrow(db$dt) == 0L) next
      current <- db$dt

      val <- current$value[1L]
      deviation <- ((val - pred$mean[1L]) / pred$mean[1L]) * 100

      status <- if (val < pred$lower[1L]) {
        "\U26A0\UFE0F BELOW"
      } else if (val > pred$upper[1L]) {
        "\U26A0\UFE0F ABOVE"
      } else {
        "\U2705 NORMAL"
      }

      alerts <- rbind(alerts, data.frame(
        Metric = name, Status = status,
        Current = round(val, 2),
        Lower = round(pred$lower[1L], 2),
        Upper = round(pred$upper[1L], 2),
        Deviation = paste0(ifelse(deviation >= 0, "+", ""), round(deviation, 1), "%"),
        stringsAsFactors = FALSE
      ))
    }
    alerts
  }, ignoreNULL = FALSE)

  output$alerts_table <- renderTable({
    alerts_data()
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", rownames = FALSE)

  output$sys_status <- renderText({
    invalidateSummary()
    "Operational"
  })

  output$alert_count <- renderText({
    data <- alerts_data()
    n <- sum(grepl("ABOVE|BELOW", data$Status))
    paste(n, "active")
  })

  output$model_age <- renderText({
    query <- "SELECT MAX(period) as last_period FROM model_results LIMIT 1"
    ok <- try(db$consult(query), silent = TRUE)
    if (!inherits(ok, "try-error") && nrow(db$dt) > 0L) "Current" else "Stale"
  })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 6: ANOMALY DETECTION
  # ═══════════════════════════════════════════════════════════════════════════════

  anomaly_data <- eventReactive(input$anomaly_detect, {
    name <- input$anomaly_metric
    sigma <- input$anomaly_sensitivity
    window <- as.integer(input$anomaly_window)
    color <- METRICS[[name]]$color
    unit <- METRICS[[name]]$unit

    date_filter <- if (window == 0L) {
      "date(date) = date('now', 'localtime')"
    } else {
      sprintf("date(date) >= date('now', 'localtime', '-%d days')", window)
    }

    query <- sprintf("SELECT date, minute, value FROM metrics WHERE metric_name = '%s' AND %s ORDER BY date", name, date_filter)
    ok <- try(db$consult(query), silent = TRUE)
    if (inherits(ok, "try-error") || nrow(db$dt) == 0L) {
      return(list(anomalies = data.frame(), n = 0L, max_sev = 0, health = 100, plot_data = NULL))
    }
    dt <- db$dt

    # Compute rolling statistics (window of 60 minutes)
    # as.numeric() required: stats::filter returns a ts object which breaks pmax/xtable
    dt$rolling_mean <- as.numeric(stats::filter(dt$value, rep(1/60, 60), sides = 1))
    dt$rolling_sd   <- as.numeric(sqrt(abs(as.numeric(stats::filter(
      (dt$value - ifelse(is.na(dt$rolling_mean), mean(dt$value, na.rm=TRUE), dt$rolling_mean))^2,
      rep(1/60, 60), sides = 1)))))
    dt$rolling_mean[is.na(dt$rolling_mean)] <- mean(dt$value, na.rm = TRUE)
    dt$rolling_sd[is.na(dt$rolling_sd)]     <- sd(dt$value, na.rm = TRUE)
    dt$rolling_sd[dt$rolling_sd < 1e-6]     <- sd(dt$value, na.rm = TRUE)

    # Detect anomalies: points beyond sigma standard deviations
    dt$z_score <- as.numeric(abs(dt$value - dt$rolling_mean)) / pmax(as.numeric(dt$rolling_sd), 0.001)
    dt$is_anomaly <- dt$z_score > sigma

    anomalies <- dt[dt$is_anomaly, ]
    n_anomalies <- nrow(anomalies)
    max_severity <- if (n_anomalies > 0L) round(max(anomalies$z_score, na.rm = TRUE), 1) else 0
    health <- round(100 * (1 - n_anomalies / nrow(dt)), 1)

    # Build plot
    p <- plot_ly() %>%
      add_trace(x = seq_len(nrow(dt)), y = dt$value, type = "scatter", mode = "lines",
                name = "Value", line = list(color = color, width = 1)) %>%
      add_trace(x = seq_len(nrow(dt)), y = dt$rolling_mean + sigma * dt$rolling_sd,
                type = "scatter", mode = "lines", name = paste0("+", sigma, "\U03C3"),
                line = list(color = "#e74c3c", width = 0.8, dash = "dash")) %>%
      add_trace(x = seq_len(nrow(dt)), y = dt$rolling_mean - sigma * dt$rolling_sd,
                type = "scatter", mode = "lines", name = paste0("-", sigma, "\U03C3"),
                line = list(color = "#e74c3c", width = 0.8, dash = "dash"))

    if (n_anomalies > 0L) {
      anom_idx <- which(dt$is_anomaly)
      p <- p %>% add_trace(x = anom_idx, y = anomalies$value, type = "scatter", mode = "markers",
                           name = "Anomaly", marker = list(color = "#e74c3c", size = 6, symbol = "x"))
    }

    p <- p %>% layout(
      xaxis = list(title = "Reading", color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
      yaxis = list(title = paste0(name, " (", unit, ")"), color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
      paper_bgcolor = "transparent", plot_bgcolor = "transparent",
      font = list(color = "#8899aa"),
      legend = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.15, font = list(color = "#ccc"))
    )

    # Top anomalies table (all columns must be plain atomic types for xtable)
    tbl <- if (n_anomalies > 0L) {
      top <- head(anomalies[order(-as.numeric(anomalies$z_score)), ], 20)
      data.frame(
        Time     = as.character(top$date),
        Value    = as.numeric(round(top$value, 2)),
        Expected = as.numeric(round(top$rolling_mean, 2)),
        Sigma    = as.numeric(round(top$z_score, 2)),
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(Message = "No anomalies detected", stringsAsFactors = FALSE)
    }

    list(plot = p, table = tbl, n = n_anomalies, max_sev = max_severity, health = health)
  })

  output$anomaly_plot <- renderPlotly({ anomaly_data()$plot })
  output$anomaly_table <- renderTable({ anomaly_data()$table },
    striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", rownames = FALSE)
  output$anomaly_count <- renderText({ paste(anomaly_data()$n) })
  output$anomaly_severity <- renderText({ paste0(anomaly_data()$max_sev, "\U03C3") })
  output$anomaly_health <- renderText({ paste0(anomaly_data()$health, "%") })

  # ═══════════════════════════════════════════════════════════════════════════════
  # TAB 7: CORRELATIONS
  # ═══════════════════════════════════════════════════════════════════════════════

  corr_data <- eventReactive(input$corr_compute, {
    window <- as.integer(input$corr_window)
    method <- input$corr_method

    date_filter <- if (window == 0L) {
      "date(date) = date('now', 'localtime')"
    } else {
      sprintf("date(date) >= date('now', 'localtime', '-%d days')", window)
    }

    # Get hourly averages for each metric
    query <- sprintf(
      "SELECT metric_name, CAST(minute / 60 AS INTEGER) as hour, AVG(value) as avg_value
       FROM metrics WHERE %s GROUP BY metric_name, hour ORDER BY metric_name, hour", date_filter)
    ok <- try(db$consult(query), silent = TRUE)
    if (inherits(ok, "try-error") || nrow(db$dt) == 0L) return(NULL)
    dt <- db$dt

    # Pivot to wide format
    metric_names <- names(METRICS)
    wide <- data.table::dcast(data.table::as.data.table(dt), hour ~ metric_name, value.var = "avg_value", fun.aggregate = mean)
    cols <- intersect(metric_names, names(wide))
    if (length(cols) < 2L) return(NULL)

    mat <- cor(wide[, ..cols], use = "pairwise.complete.obs", method = method)

    # Heatmap
    p <- plot_ly(z = mat, x = cols, y = cols, type = "heatmap",
                 colorscale = list(c(0, "#2c3e50"), c(0.5, "#34495e"), c(1, "#3498db")),
                 zmin = -1, zmax = 1) %>%
      layout(
        xaxis = list(color = "#8899aa", tickangle = -30),
        yaxis = list(color = "#8899aa"),
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font = list(color = "#8899aa")
      )

    list(plot = p, matrix = mat)
  })

  output$corr_matrix <- renderPlotly({
    data <- corr_data()
    if (is.null(data)) {
      plot_ly() %>% layout(title = list(text = "Click Compute to generate", font = list(color = "#8899aa")),
                           paper_bgcolor = "transparent", plot_bgcolor = "transparent")
    } else {
      data$plot
    }
  })

  scatter_data <- eventReactive(input$corr_scatter, {
    window <- as.integer(input$corr_window)
    x_metric <- input$corr_x
    y_metric <- input$corr_y

    date_filter <- if (window == 0L) {
      "date(date) = date('now', 'localtime')"
    } else {
      sprintf("date(date) >= date('now', 'localtime', '-%d days')", window)
    }

    query_x <- sprintf("SELECT minute, AVG(value) as value FROM metrics WHERE metric_name = '%s' AND %s GROUP BY minute", x_metric, date_filter)
    query_y <- sprintf("SELECT minute, AVG(value) as value FROM metrics WHERE metric_name = '%s' AND %s GROUP BY minute", y_metric, date_filter)

    ok_x <- try(db$consult(query_x), silent = TRUE)
    if (inherits(ok_x, "try-error") || nrow(db$dt) == 0L) return(NULL)
    dt_x <- db$dt

    ok_y <- try(db$consult(query_y), silent = TRUE)
    if (inherits(ok_y, "try-error") || nrow(db$dt) == 0L) return(NULL)
    dt_y <- db$dt

    merged <- merge(dt_x, dt_y, by = "minute", suffixes = c("_x", "_y"))
    r <- cor(merged$value_x, merged$value_y, use = "complete.obs")

    p <- plot_ly(x = merged$value_x, y = merged$value_y, type = "scatter", mode = "markers",
                 marker = list(color = METRICS[[x_metric]]$color, size = 4, opacity = 0.6)) %>%
      layout(
        xaxis = list(title = paste0(x_metric, " (", METRICS[[x_metric]]$unit, ")"),
                     color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        yaxis = list(title = paste0(y_metric, " (", METRICS[[y_metric]]$unit, ")"),
                     color = "#8899aa", gridcolor = "rgba(255,255,255,0.05)"),
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font = list(color = "#8899aa"),
        annotations = list(list(x = 0.05, y = 0.95, xref = "paper", yref = "paper",
                                text = sprintf("r = %.3f", r), showarrow = FALSE,
                                font = list(size = 14, color = "#3498db")))
      )
    list(plot = p)
  })

  output$corr_scatter_plot <- renderPlotly({
    data <- scatter_data()
    if (is.null(data)) {
      plot_ly() %>% layout(title = list(text = "Select metrics and click Scatter Plot", font = list(color = "#8899aa")),
                           paper_bgcolor = "transparent", plot_bgcolor = "transparent")
    } else {
      data$plot
    }
  })
}
