## The bulk of this is validating the yaml; that turns out to be quite
## unpleasant unfortunately.
recipe_read <- function(path, config) {
  assert_is(config, "orderly_config")
  filename <- file.path(path, "orderly.yml")
  if (!file.exists(filename)) {
    stop("Did not find file 'orderly.yml' at path ", path)
  }
  info <- yaml_read(filename)

  required <- c("script", # filename
                "artefacts",
                "data",
                config$fields$name[config$fields$required])
  optional <- c("parameters", # character >= 1
                "views",
                "packages",
                "resources",
                config$fields$name[!config$fields$required])
  check_fields(info, filename, required, optional)

  ## Fill any any missing optional fields:
  i <- !(config$fields$name %in% names(info))
  if (any(i)) {
    info[config$fields$name[i]] <-
      lapply(config$fields$type[i], set_mode, x = NA)
  }

  fieldname <- function(name) {
    sprintf("%s:%s", filename, name)
  }

  info$artefacts <- recipe_read_check_artefacts(info$artefacts, filename)
  info$resources <- recipe_read_check_resources(info$resources, filename, path)

  assert_scalar_character(info$script, fieldname("script"))

  if (!is.null(info$parameters)) {
    assert_character(info$parameters, fieldname("parameters"))
  }
  if (!is.null(info$packages)) {
    assert_character(info$packages, fieldname("packages"))
  }

  ## Then some processing:
  assert_named(info$data, TRUE, fieldname("data"))
  info$data <- string_or_filename(info$data, path, fieldname("data"))
  info$resources <- c(info$resources, attr(info$data, "files"))

  if (!is.null(info$views)) {
    assert_named(info$data, TRUE, fieldname("data"))
    info$views <- string_or_filename(info$views, path, fieldname("views"))
    info$resources <- c(info$resources, attr(info$views, "files"))
  }

  assert_scalar_character(info$script, fieldname("script"))
  if (!file.exists(file.path(path, info$script))) {
    stop(sprintf("script file %s does not exist", info$script))
  }

  for (i in seq_len(nrow(config$fields))) {
    el <- config$fields[i, ]
    x <- info[[el$name]]
    if (!is.null(x)) {
      assert_type(x, el$type, fieldname(el$name))
    }
  }

  info$name <- basename(normalizePath(path))

  ## TODO: we probably need to reference any additional on-disk
  ## resources here too
  info$script_hash <- unname(tools::md5sum(file.path(path, info$script)))
  info$hash <- digest::digest(info)

  ## Must add this after hashing
  info$path <- path

  info
}

## TODO: this whole thing needs thought: this is not really the
## *format* (which we can get from the extension) but an intent of
## use.
valid_formats <- function() {
  c("staticgraph", "interactivegraph", "data")
}

string_or_filename <- function(x, path, name) {
  if (is.list(x)) {
    if (all(vlapply(x, is.character))) {
      x <- vcapply(x, identity)
    }
  }
  assert_character(x, name)
  i <- grepl("\\.sql$", x)
  if (any(i)) {
    files <- x[i]
    msg <- !file.exists(file.path(path, files))
    if (any(msg)) {
      stop(sprintf("File for %s does not exist: %s",
                   name, paste(files[msg], collapse = ", ")))
    }
    x[i] <- vcapply(file.path(path, files), read_lines, USE.NAMES = FALSE)
    attr(x, "files") <- unname(files)
  }
  x
}

recipe_read_check_artefacts <- function(x, filename) {
  check_artefact <- function(nm) {
    v <- c("format", "description")
    x <- x[[nm]]
    check_fields(x, sprintf("%s:artefacts:%s", filename, nm), v, NULL)
    for (i in v) {
      assert_character(x[[i]], sprintf("artefacts:%s:%s", nm, i))
    }
    match_value(x$format, valid_formats())
    c(filename = nm, unlist(x[v]))
  }
  if (length(x) == 0L) {
    stop("At least one artefact required")
  }
  assert_named(x, TRUE)
  x <-
    t(vapply(names(x), check_artefact, character(3)))
  rownames(x) <- NULL
  x
}

recipe_read_check_resources <- function(x, filename, path) {
  if (is.null(x)) {
    return(NULL)
  }
  assert_character(x, sprintf("%s:%s", filename, "resouces"))
  msg <- x[!file.exists(file.path(path, x))]
  if (length(msg) > 0L) {
    stop("Declared resources missing: ", paste(msg, collapse = ", "))
  }
  ## TODO: this is not quite right because the files need to be
  ## tested (as done here) with names within that directory.
  err <- x[!is_within_dir(file.path(path, x), path)]
  if (length(err) > 0L) {
    stop("Declared resources not in right place: ",
         paste(err, collapse = ", "))
  }
  ## TODO: At this point we should also return the normalised
  ## *relative* path perhaps to prevent valid, but absolute, paths
  ## being used.
  x
}