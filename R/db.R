##' Connect to the orderly databases.  \code{orderly_connect} returns
##' a list with all four connections (source, destination, csv and
##' rds) while \code{orderly_db} returns a single connection to one of
##' these.  These should be treated as as \emph{read only} (with the
##' exception of \code{source}).
##'
##' @title Connect to orderly databases
##' @inheritParams orderly_list
##' @export
orderly_connect <- function(config = NULL, locate = TRUE) {
  config <- orderly_config_get(config, locate)
  types <- c("source", "destination", "csv", "rds")
  set_names(lapply(types, orderly_db, config), types)
}

##' @export
##' @rdname orderly_connect
##'
##' @param type The type of connection to make (\code{source},
##'   \code{destination}, \code{csv} or \code{rds}).
orderly_db <- function(type, config = NULL, locate = TRUE) {
  config <- orderly_config_get(config, locate)
  if (type == "rds") {
    file_store_rds(path_rds(config$path))
  } else if (type == "csv") {
    file_store_csv(path_csv(config$path))
  } else if (type %in% c("source", "destination")) {
    x <- config[[type]]
    driver <- getExportedValue(x$driver[[1L]], x$driver[[2L]])
    con <- do.call(DBI::dbConnect, c(list(driver()), x$args))
    if (type == "destination") {
      report_db_init(con, config)
    }
    con
  } else {
    stop(sprintf("Invalid db type '%s'", type))
  }
}

## Reports database needs special initialisation:
report_db_init <- function(con, config, must_create = FALSE) {
  orderly_table <- "orderly"
  if (!DBI::dbExistsTable(con, orderly_table)) {
    ## TODO: we'll need some postgres translation here
    ## TODO: dumping json columns in as text for now
    ##
    ## TODO: the door is open here for the table name to be
    ## configurable, but defaulting to 'orderly', but I do not know
    ## that that is good thing, really.
    cols <- report_db_cols()
    col_types <- sprintf("  %s %s",
                         c(names(cols), config$fields$name),
                         c(unname(cols), config$fields$type_sql))

    sql <- sprintf("CREATE TABLE %s (\n%s\n)",
                   orderly_table,
                   paste(col_types, collapse = ",\n"))
    DBI::dbExecute(con, sql)
  } else if (must_create) {
    stop(sprintf("Table '%s' already exists", orderly_table))
  } else {
    sql <- sprintf("SELECT * FROM %s LIMIT 0", orderly_table)
    d <- DBI::dbGetQuery(con, sql)
    custom_name <- config$fields$name
    msg <- setdiff(custom_name, names(d))
    if (length(msg) > 0L) {
      stop(sprintf("custom fields %s not present in existing database",
                   paste(squote(msg), collapse = ", ")))
    }
    extra <- setdiff(setdiff(names(d), names(report_db_cols())), custom_name)
    if (length(extra) > 0L) {
      stop(sprintf("custom fields %s in database not present in config",
                   paste(squote(extra), collapse = ", ")))
    }
  }
  orderly_table
}

report_db_rebuild <- function(config) {
  assert_is(config, "orderly_config")
  root <- config$path
  con <- orderly_db("destination", config)
  on.exit(DBI::dbDisconnect(con))
  ## TODO: this assumes name known
  tbl <- "orderly"
  if (DBI::dbExistsTable(con, "orderly")) {
    DBI::dbExecute(con, "DELETE FROM orderly")
  } else {
    tbl <- report_db_init(con, config, TRUE)
  }
  reports <- unlist(lapply(list_dirs(path_archive(root)), list_dirs))
  if (length(reports) > 0L) {
    dat <- rbind_df(lapply(reports, report_read_data, config))
    DBI::dbWriteTable(con, tbl, dat, append = TRUE)
  }
}

report_db_cols <- function() {
  c(## INPUTS:
    id = "TEXT PRIMARY KEY NOT NULL",
    name = "TEXT",
    displayname = "TEXT",
    description = "TEXT",
    views = "TEXT",          # should be json (dict)
    data = "TEXT",           # should be json (dict)
    packages = "TEXT",       # should be json (array)
    script = "TEXT",
    artefacts = "TEXT",      # should be json (array)
    resources = "TEXT",      # should be json (array)
    hash_script = "TEXT",
    ## OUTPUTS
    parameters = "TEXT",     # should be json (dict with values)
    date = "DATETIME",
    hash_orderly = "TEXT",
    hash_input = "TEXT",
    hash_resources = "TEXT", # should be json (dict)
    hash_data = "TEXT",      # should be json (dict)
    hash_artefacts = "TEXT", # should be json (dict)
    depends = "TEXT",        # should be json (array of dicts)
    ## PUBLISHING
    published = "BOOLEAN")
}

##' Rebuild the report database
##' @title Rebuild the report database
##' @inheritParams orderly_list
##' @export
orderly_rebuild <- function(config = NULL, locate = TRUE) {
  config <- orderly_config_get(config, locate)
  report_db_rebuild(config)
  invisible(NULL)
}
