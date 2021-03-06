##' Create new report
##' @title Create new report
##' @param name Name of the new report (will be a directory name).
##' @param quiet Logical, indicating if informational messages should
##'   be suppressed.
##' @inheritParams orderly_list
##' @export
orderly_new <- function(name, config = NULL, locate = TRUE, quiet = FALSE) {
  config <- orderly_config_get(config, locate)
  assert_scalar_character(name)
  if (grepl("[[:space:]]", name)) {
    stop("'name' cannot contain spaces")
  }
  dest <- file.path(path_src(config$path), name)
  if (file.exists(dest)) {
    stop(sprintf("A report already exists called '%s'", name))
  }
  dir.create(dest)
  yml <- file.path(dest, "orderly.yml")
  file.copy(orderly_file("orderly_example.yml"), yml)
  if (!quiet) {
    message(sprintf("Created report at '%s'", dest))
    message("Edit the file 'orderly.yml' within this directory")
  }
  invisible(dest)
}
