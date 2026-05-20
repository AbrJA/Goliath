#' @title Time
#'
#' @description
#' Creates a Time class
#'
#' @export
#'
Time <- R6::R6Class(
  classname = "Time",
  public = list(
    initialize = function(add = 6L * 60L * 60L, date) {
      checkmate::assertInt(add, lower = 0L)
      if (!missing(date)) {
        checkmate::assertString(date, pattern = "^\\d{4}-\\d{2}-\\d{2}$")
        private$.now <- as.POSIXct(paste(date, "00:00"))
        private$.minute <- 1440L
      } else {
        private$.now <- Sys.time() - add
        private$.minute <- 60L * as.integer(format(private$.now, "%H")) + as.integer(format(private$.now, "%M"))
      }
      invisible(self)
    },
    scale = function(by = 1L, horizont = 1440L) {
      checkmate::assertInt(by, lower = 1L, upper = 60L)
      checkmate::assertInt(horizont / by, lower = 1L)
      private$.period <- floor(private$.minute / by)
      date <- as.POSIXct(paste(format(private$.now, "%Y-%m-%d"), "00:00"))
      private$.serie <- seq.POSIXt(date, by = paste(by, "min"), length.out = horizont / by)
      invisible(self)
    }
  ),
  active = list(
    minute = function() private$.minute,
    now = function() private$.now,
    period = function() private$.period,
    serie = function() private$.serie
  ),
  private = list(
    .minute = NULL,
    .now = NULL,
    .period = NULL,
    .serie = NULL
  )
)
