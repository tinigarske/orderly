## This gives a list of the source report names known to the system.
## This will not include things that have been deleted in source but
## are present in the database, because I want this to be useful for
## getting targets that one can run.

##' List the \emph{names} of reports known to orderly.  These are the
##' \emph{source} names, not the results of running reports.
##'
##' @title List orderly reports
##'
##' @param config An orderly configuration, or the path to one (or
##'   \code{NULL} to locate one if \code{locate} is \code{TRUE}).
##'
##' @param locate Logical, indicating if the configuration should be
##'   searched for.  If \code{TRUE} and \code{config} is not given,
##'   then orderly looks in the working directory and up through its
##'   parents until it finds an \code{orderly_config.yml} file.
##'
##' @export
orderly_list <- function(config = NULL, locate = TRUE) {
  config <- orderly_config_get(config, locate)
  basename(list_dirs(path_src(config$path)))
}

##' List draft and archived reports.  This returns a data.frame with
##' columns \code{name} (see \code{\link{orderly_list}} and \code{id}.
##' It will expand in future.
##'
##' @title List draft and archived reports
##' @inheritParams orderly_list
##' @export
orderly_list_drafts <- function(config = NULL, locate = TRUE) {
  orderly_list2(TRUE, config, locate)
}

##' @export
##' @rdname orderly_list_drafts
orderly_list_archive <- function(config = NULL, locate = TRUE) {
  orderly_list2(FALSE, config, locate)
}

##' Find most recent version of an orderly report
##' @title Find most recent report
##'
##' @param name Name of the report to find
##'
##' @param draft Find most recent \emph{draft} report
##'
##' @param must_work Throw an error if no report is found.  If FALSE,
##'   returns \code{NA_character_}.
##'
##' @inheritParams orderly_list
##' @export
orderly_latest <- function(name, config = NULL, locate = TRUE,
                           draft = FALSE, must_work = TRUE) {
  config <- orderly_config_get(config, locate)
  path <-
    file.path((if (draft) path_draft else path_archive)(config$path), name)

  ids <- dir(path)
  if (length(ids) == 0L) {
    if (must_work) {
      stop(sprintf("Did not find any %s reports for %s",
                   if (draft) "draft" else "archive", name))
    } else {
      return(NA_character_)
    }
  }

  ids <- latest_id(ids)
  if (length(ids) > 1L) {
    ## We have no choice here but to look at the actual times to
    ## determine which is the most recent report.
    times <- lapply(path_orderly_run_rds(file.path(path, ids)),
                    function(x) readRDS(x)$time)
    ids <- ids[[which_max_time(times)]]
  }

  ids
}

orderly_list2 <- function(draft, config = NULL, locate = TRUE) {
  config <- orderly_config_get(config, locate)
  path <- if (draft) path_draft else path_archive
  check <- list_dirs(path(config$path))
  res <- lapply(check, dir)
  data.frame(name = rep(basename(check), lengths(res)),
             id = as.character(unlist(res)),
             stringsAsFactors = FALSE)
}

orderly_find_name <- function(id, config, locate = FALSE, draft = TRUE,
                              must_work = FALSE) {
  config <- orderly_config_get(config, locate)
  path <- (if (draft) path_draft else path_archive)(config$path)
  for (name in orderly_list(config)) {
    if (file.exists(file.path(path, name, id))) {
      return(name)
    }
  }
  ## Error case:
  if (must_work) {
    stop(sprintf("Did not find %s report %s",
                 if (draft) "draft" else "archive", id))
  } else {
    NULL
  }
}

orderly_find_report <- function(id, name, config, locate = FALSE,
                                draft = TRUE, must_work = FALSE) {
  config <- orderly_config_get(config, locate)
  ## TODO: I don't think that the treatment of draft is OK here - we
  ## should allow reports to roll over into archive gracefully.
  path <-
    file.path((if (draft) path_draft else path_archive)(config$path), name)
  if (id == "latest") {
    id <- orderly_latest(name, config, FALSE,
                         draft = draft, must_work = must_work)
  }
  path_report <- file.path(path, id)
  if (!is.na(id) && file.exists(path_report)) {
    return(path_report)
  }
  if (must_work) {
    stop(sprintf("Did not find %s report %s:%s",
                 if (draft) "draft" else "archived", name, id))
  } else {
    NULL
  }
}

latest_id <- function(ids) {
  if (length(ids) == 0L) {
    return(NA_character_)
  }

  ids <- sort_c(unique(ids))

  re <- "^([0-9]{8}-[0-9]{6})-([[:xdigit:]]{4})([[:xdigit:]]{4})$"
  stopifnot(all(grepl(re, ids)))

  isodate <- sub(re, "\\1", ids)
  ids <- ids[isodate == last(isodate)]

  if (length(ids) > 1L) {
    ms <- sub(re, "\\2", ids)
    ids <- ids[ms == last(ms)]
  }

  ids
}
