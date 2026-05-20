#' @title Connection
#'
#' @description
#' Creates a Connection class for database access (SQLite)
#'
#' @export
#'
Connection <- R6::R6Class(
  classname = "Connection",
  public = list(
    initialize = function(dbname, ...) {
      self$open(dbname, ...)
    },
    open = function(dbname, ...) {
      checkmate::assertString(dbname)
      private$.pool <- pool::dbPool(RSQLite::SQLite(),
                                    dbname = dbname,
                                    ...)
      invisible(self)
    },
    close = function() {
      pool::poolClose(private$.pool)
      invisible(self)
    },
    consult = function(query) {
      checkmate::assertString(query)
      private$.dt <- pool::dbGetQuery(private$.pool, query)
      data.table::setDT(private$.dt)
      invisible(self)
    },
    execute = function(query, params = NULL) {
      checkmate::assertString(query)
      conn <- pool::poolCheckout(private$.pool)
      on.exit(pool::poolReturn(conn))
      DBI::dbExecute(conn, query, params = params)
      invisible(self)
    }
  ),
  active = list(
    dt = function() private$.dt,
    pool = function() private$.pool
  ),
  private = list(
    .dt = NULL,
    .pool = NULL
  )
)
