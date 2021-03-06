context("run")

## This is an integration test really.  I need to carve more units out
## of this code still but this will let me know if I'm going along the
## right track and if I'm breaking things!
test_that("run", {
  path <- tempfile()
  on.exit({
    if (exists("con")) {
      ## flush any SQLite connections:
      rm(con)
      gc()
    }
    unlink(path, recursive = TRUE)
  })

  orderly_init(path)
  fake_db(DBI::dbConnect(RSQLite::SQLite(), file.path(path, "source.sqlite")))
  file.copy("example_config.yml", file.path(path, "orderly_config.yml"),
            overwrite = TRUE)

  path_example <- file.path(path, "src", "example")

  dir.create(path_example)
  file.copy("example_report.yml", file.path(path_example, "orderly.yml"))
  file.copy("example_script.R", file.path(path_example, "script.R"))

  parameters <- list(minvalue = 0.5)

  ## This probably all rolls together I think?  It's not totally clear
  ## what the run/commit workflow should look like (especially when
  ## developing a draft analysis)
  config <- orderly_config(path)
  info <- recipe_read(file.path(path, "src", "example"), config)
  expect_equal(info$name, basename(path_example))

  envir <- orderly_environment(NULL)
  p <- recipe_run(info, parameters, envir, config = path, echo = FALSE)
  expect_true(is_directory(p))
  expect_equal(normalizePath(dirname(dirname(p))),
               normalizePath(path_draft(path)))

  expect_true(file.exists(file.path(p, "mygraph.png")))
  expect_true(file.exists(file.path(p, "script.R")))
  expect_true(file.exists(file.path(p, "orderly.yml")))
  expect_true(file.exists(file.path(p, "orderly_run.yml")))
  expect_true(file.exists(file.path(p, "orderly_run.rds")))
  expect_equal(length(dir(p)), 5) # the above are _all_ files produced
  files <- dir(p)
  cmp <- set_names(hash_files(dir(p, full.names = TRUE), FALSE), files)

  ## These files are unmodified
  expect_equal(hash_files(file.path(path_example, "orderly.yml"), FALSE),
               hash_files(file.path(p, "orderly.yml"), FALSE))
  expect_equal(hash_files(file.path(path_example, "script.R"), FALSE),
               hash_files(file.path(p, "script.R"), FALSE))

  ## This needs to look reasonable:
  d <- readRDS(file.path(p, "orderly_run.rds"))
  expect_is(d$session_info, "sessionInfo")
  expect_is(d$time, "POSIXt")
  expect_is(d$env, "list")

  expect_identical(readBin(file.path(p, "mygraph.png"), raw(), 8),
                   MAGIC_PNG)

  run <- yaml_read(file.path(p, "orderly_run.yml"))
  expect_equal(run$id, basename(p))
  expect_equal(run$name, info$name)
  expect_identical(unname(unlist(run$hash_artefacts, use.names = FALSE)),
                   hash_files(file.path(p, "mygraph.png"), FALSE))
  expect_identical(run$hash_resources, list())
  expect_identical(run$parameters, parameters)
  expect_is(run$date, "character")
  ## I feel hash_orderly and hash_input have the wrong names here
  expect_identical(run$hash_orderly, info$hash)
  expect_identical(run$hash_input,
                   hash_files(file.path(p, "orderly.yml"), FALSE))

  expect_is(run$hash_data, "list")
  expect_equal(length(run$hash_data), 1)

  con <- orderly_connect(config)
  expect_identical(con$rds$list(), unlist(run$hash_data, use.names = FALSE))
  expect_identical(con$csv$list(), unlist(run$hash_data, use.names = FALSE))

  ## Confirm that things are OK:
  expect_equal(con$rds$get(run$hash_data),
               con$csv$get(run$hash_data))

  ## Confirm that the *format* is OK too by reading the files manually:
  expect_identical(con$rds$get(run$hash_data),
                   readRDS(con$rds$filename(run$hash_data)))
  expect_identical(con$csv$get(run$hash_data),
                   read_csv(con$csv$filename(run$hash_data)))

  ## Then we commit the results:
  q <- recipe_commit(p, path)
  expect_false(file.exists(p))
  expect_true(file.exists(q))

  ## Everything copied over ok:
  expect_equal(set_names(hash_files(dir(q, full.names = TRUE), FALSE), files),
               cmp)

  expect_equal(DBI::dbListTables(con$destination), "orderly")
  d <- DBI::dbReadTable(con$destination, "orderly")
  expect_true(all(vlapply(d[names(d) != "published"], is.character)))
  expect_true(is.numeric(d$published))

  expect_equal(d$id, basename(q))
})

## Same as in read; we generate a report and then break it
test_that("minimal", {
  path <- prepare_orderly_example("minimal")
  on.exit(unlink(path, recursive = TRUE))

  config <- orderly_config(path)
  src <- orderly_db("source", config)
  info <- recipe_read(file.path(path, "src/example"), config)
  data <- recipe_data(src, info, NULL, new.env(parent = .GlobalEnv))
  expect_is(data$dat, "data.frame")

  expect_error(
    recipe_data(src, info, list(a = 1), new.env(parent = .GlobalEnv)),
    "Extra parameters: 'a'")
  expect_error(
    recipe_data(src, info, NULL, NULL),
    "Invalid input for 'dest'")

  workdir <- tempfile()
  dir.create(workdir)
  expect_error(recipe_prepare_workdir(info, workdir),
               "'workdir' must not exist")
  unlink(workdir, recursive = TRUE)

  envir <- orderly_environment(NULL)
  res <- recipe_run(info, NULL, envir, config = config, echo = FALSE)
  files <- dir(res)
  expect_true(file.exists(file.path(res, "orderly.yml")))
  expect_true(file.exists(file.path(res, "orderly_run.yml")))
  expect_true(file.exists(file.path(res, "orderly_run.rds")))
  expect_true(file.exists(file.path(res, "script.R")))
  expect_true(file.exists(file.path(res, "mygraph.png")))

  recipe_commit(res, config)
})

test_that("orderly_data", {
  path <- prepare_orderly_example("minimal")
  on.exit(unlink(path, recursive = TRUE))

  d <- orderly_data("example", config = path)
  expect_is(d, "list")
  expect_is(d$dat, "data.frame")

  e1 <- new.env(parent = baseenv())
  e <- orderly_data("example", config = path, envir = e1)
  expect_identical(e, e1)

  expect_identical(e$dat, d$dat)
})

test_that("fail to create artefact", {
  path <- prepare_orderly_example("minimal")
  on.exit(unlink(path, recursive = TRUE))
  config <- orderly_config(path)
  writeLines("1 + 1", file.path(path, "src/example/script.R"))
  info <- recipe_read(file.path(path, "src/example"), config)
  envir <- orderly_environment(NULL)
  expect_error(recipe_run(info, NULL, envir, config = config, echo = FALSE),
               "Script did not produce expected artefacts: mygraph.png")
})

test_that("leave device open", {
  path <- prepare_orderly_example("minimal")
  on.exit(unlink(path, recursive = TRUE))
  config <- orderly_config(path)
  txt <- readLines(file.path(path, "src/example/script.R"))
  writeLines(txt[!grepl("dev.off()", txt, fixed = TRUE)],
             file.path(path, "src/example/script.R"))
  info <- recipe_read(file.path(path, "src/example"), config)
  envir <- orderly_environment(NULL)
  expect_error(recipe_run(info, NULL, envir, config = config, echo = FALSE),
               "Report left 1 device open")
})

test_that("close too many devices", {
  path <- prepare_orderly_example("minimal")
  png(tempfile())
  n <- length(dev.list())
  on.exit({
    unlink(path, recursive = TRUE)
    if (length(dev.list()) == n) {
      dev.off()
    }
  })

  config <- orderly_config(path)
  txt <- readLines(file.path(path, "src/example/script.R"))
  writeLines(c(txt, "dev.off()"), file.path(path, "src/example/script.R"))
  info <- recipe_read(file.path(path, "src/example"), config)
  envir <- orderly_environment(NULL)
  expect_error(recipe_run(info, NULL, envir, config = config, echo = FALSE),
               "Report closed 1 more devices than it opened")
})

test_that("included example", {
  path <- prepare_orderly_example("example")
  id <- orderly_run("example", list(cyl = 4), config = path, echo = FALSE)
  p <- orderly_commit(id, config = path)
  expect_true(is_directory(p))
  db <- orderly_db("destination", path)
  dat <- DBI::dbReadTable(db, "orderly")
  expect_equal(dat$description, NA_character_)
  expect_equal(dat$displayname, NA_character_)
})

test_that("included other", {
  path <- prepare_orderly_example("other")
  id <- orderly_run("other", list(nmin = 0), config = path, echo = FALSE)
  p <- orderly_commit(id, config = path)
  info <- recipe_read(file.path(path_src(path), "other"),
                      orderly_config(path))
  db <- orderly_db("destination", path)
  dat <- DBI::dbReadTable(db, "orderly")
  expect_equal(dat$description, info$description)
  expect_equal(dat$displayname, info$displayname)
})

test_that("connection", {
  path <- prepare_orderly_example("minimal")
  on.exit(unlink(path, recursive = TRUE))

  path_example <- file.path(path, "src", "example")
  yml <- file.path(path_example, "orderly.yml")
  txt <- readLines(yml)
  writeLines(c(txt, "connection: con"), yml)

  config <- orderly_config(path)
  info <- recipe_read(path_example, config)
  expect_identical(info$connection, "con")

  data <- orderly_data("example",
                       envir = new.env(parent = .GlobalEnv),
                       config = path)
  expect_is(data$con, "SQLiteConnection")
  expect_is(DBI::dbReadTable(data$con, "data"), "data.frame")
})

test_that("no data", {
  path <- prepare_orderly_example("minimal")
  yml <- c("data: ~",
           "script: script.R",
           "artefacts:",
           "  data:",
           "    filename: data.rds",
           "    description: the data")
  script <- "saveRDS(mtcars, 'data.rds')"
  path_example <- file.path(path, "src", "example")
  writeLines(yml, file.path(path_example, "orderly.yml"))
  writeLines(script, file.path(path_example, "script.R"))

  data <- orderly_data("example",
                       envir = new.env(parent = .GlobalEnv),
                       config = path)
  expect_equal(ls(data, all.names = TRUE), character(0))

  id <- orderly_run("example", config = path, echo = FALSE)
  p <- file.path(path_draft(path), "example", id, "data.rds")
  expect_true(file.exists(p))
  expect_equal(readRDS(p), mtcars)
})

test_that("use artefact", {
  path <- prepare_orderly_example("depends")

  path_example <- file.path(path, "src", "example")
  path_depend <- file.path(path, "src", "depend")
  id1 <- orderly_run("example", config = path, echo = FALSE)
  orderly_log_break()
  path_orig <- file.path(path_draft(path), "example", id1, "data.rds")
  expect_true(file.exists(path_orig))

  data <- orderly_data("depend",
                       envir = new.env(parent = .GlobalEnv),
                       config = path)
  expect_identical(ls(data), character(0))
  id2 <- orderly_run("depend", config = path, echo = FALSE)
  orderly_log_break()
  path_previous <- file.path(path_draft(path), "depend", id2, "previous.rds")
  expect_true(file.exists(path_previous))
  expect_equal(hash_files(path_previous, FALSE),
               hash_files(path_orig, FALSE))

  d <-
    yaml_read(path_orderly_run_yml(file.path(path_draft(path), "depend", id2)))
  expect_equal(d$depends[[1]]$hash, hash_files(path_previous, FALSE))

  ## Then rebuild the original:
  id3 <- orderly_run("example", config = path, echo = FALSE)
  orderly_log_break()
  id4 <- orderly_run("depend", config = path, echo = FALSE)
  orderly_log_break()
  path_orig2 <- file.path(path_draft(path), "example", id3, "data.rds")
  path_previous2 <- file.path(path_draft(path), "depend", id4, "previous.rds")

  expect_equal(hash_files(path_previous2, FALSE),
               hash_files(path_orig2, FALSE))
  expect_true(hash_files(path_previous2, FALSE) !=
              hash_files(path_previous, FALSE))

  ## Then we need to commit things and check that it all still works OK.
  expect_error(orderly_commit(id2, config = path),
               "Report uses draft id - commit first")
  p1 <- orderly_commit(id1, config = path)
  p2 <- orderly_commit(id2, config = path)
  expect_error(orderly_commit(id4, config = path), id3)
  p3 <- orderly_commit(id3, config = path)
  p4 <- orderly_commit(id4, config = path)
})

test_that("resources", {
  path <- prepare_orderly_example("resources")
  id <- orderly_run("use_resource", config = path, echo = FALSE)
  p <- file.path(path, "draft", "use_resource", id)
  expect_true(file.exists(file.path(p, "meta/data.csv")))
  con <- orderly_db("destination", config = path)
  p <- orderly_commit(id, config = path)
  d <- DBI::dbReadTable(con, "orderly")
  expect_identical(d$resources, '["meta/data.csv"]')
  expect_identical(d$hash_resources,
                   '{"meta/data.csv":"0bec5bf6f93c547bc9c6774acaf85e1a"}')
  expect_true(file.exists(file.path(p, "meta/data.csv")))
})

test_that("watermarking", {
  skip("watermarking currenty disabled")
  path <- prepare_orderly_example("minimal")
  id <- orderly_run("example", config = path, echo = FALSE)
  file <- file.path(path, "draft", "example", id, "mygraph.png")
  expect_equal(watermark_read(file), id)
})

test_that("markdown", {
  skip_if_not_installed("rmarkdown")
  path <- prepare_orderly_example("knitr")

  id <- orderly_run("example", config = path, echo = FALSE)

  report <- file.path(path, "draft", "example", id, "report.html")
  expect_true(file.exists(report))
  expect_true(any(grepl("ANSWER:2", readLines(report))))
})
