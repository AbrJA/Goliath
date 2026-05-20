#' @title Metric
#'
#' @description
#' Creates a Metric class
#'
#' @export
#'
Metric <- R6::R6Class(
  classname = "Metric",
  public = list(
    count = function(dt, validator, sequence) {
      checkmate::assertDataTable(dt)
      checkmate::assertDataTable(validator)
      checkmate::assertInteger(sequence, len = nrow(validator))
      dt[nchar(as.character(date)) <= 10L, date := paste0(date, " 00:00:00")]
      dt[, date := as.POSIXct(date, format = "%Y-%m-%d %H:%M:%S")]
      data.table::setorder(dt, date)
      dt[, day := .GRP - 1L, by = .(data.table::yday(date))]
      dt[, period := 1440L * day + as.integer(format(date, "%H")) * 60L + as.integer(format(date, "%M"))]
      dt[, day := NULL]
      validator <- data.table::copy(validator)
      validator[dt, count := i.count, on = .(period)]
      private$.dt <- validator[, .(count = mean(count)), by = .(period = sequence)]
      data.table::setkey(private$.dt, period)
      invisible(self)
    }
  ),
  active = list(
    dt = function() private$.dt
  ),
  private = list(
    .dt = NULL
  )
)
