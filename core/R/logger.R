#' @title Logger
#'
#' @description
#' Creates a Logger class
#'
#' @export
#'
Logger <- R6::R6Class(
  classname = "Logger",
  public = list(
    write = function(level, ...) message(paste(level, "[", format(Sys.time()), "]", ..., "\n", collapse = "")),
    info = function(...) self$write("INFO", ...),
    warning = function(...) self$write("WARNING", ...),
    error = function(...) self$write("ERROR", ...)
  )
)
