#' @title Parameter
#'
#' @description
#' Creates a Parameter class
#'
#' @export
#'
Parameter <- R6::R6Class(
  classname = "Parameter",
  public = list(
    initialize = function(name, query = "", by = 1L, horizont = 1440L) {
      self$set(name, query, by, horizont)
    },
    set = function(name, query = "", by = 1L, horizont = 1440L) {
      checkmate::assertString(name)
      checkmate::assertString(query)
      checkmate::assertInt(by, lower = 1L, upper = 60L)
      checkmate::assertInt(horizont / by, lower = 1L)
      private$.name <- name
      private$.query <- query
      private$.by <- by
      private$.horizont <- horizont
      private$.period <- checkmate::asInt(1440L / by)
      private$.sequence <- rep(seq_len(horizont / by), each = by)
      private$.validator <- data.table::data.table(period = seq_len(horizont) - 1L, count = 0.0)
      invisible(self)
    }
  ),
  active = list(
    by = function() private$.by,
    horizont = function() private$.horizont,
    name = function() private$.name,
    period = function() private$.period,
    query = function() private$.query,
    sequence = function() private$.sequence,
    validator = function() private$.validator
  ),
  private = list(
    .by = NULL,
    .horizont = NULL,
    .name = NULL,
    .period = NULL,
    .query = NULL,
    .sequence = NULL,
    .validator = NULL
  )
)
