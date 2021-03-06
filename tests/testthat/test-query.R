context("query")

test_that("empty", {
  path <- tempfile()
  orderly_init(path, quiet = TRUE)
  file_copy(orderly_file("examples/minimal/orderly_config.yml"),
            file.path(path, "orderly_config.yml"),
            overwrite = TRUE)
  expect_equal(orderly_list(path), character(0))
  expect_equal(orderly_list_drafts(path),
               data.frame(name = character(0),
                          id = character(0),
                          stringsAsFactors = FALSE))
})

test_that("non-empty", {
  path <- prepare_orderly_example("minimal")
  expect_equal(orderly_list(path), "example")
})

test_that("query through lifecycle", {
  path <- prepare_orderly_example("minimal")
  expect_equal(orderly_list(config = path), "example")

  empty <- data.frame(name = character(0), id = character(0),
                      stringsAsFactors = FALSE)
  expect_equal(orderly_list_drafts(path), empty)
  expect_equal(orderly_list_archive(path), empty)

  id <- orderly_run("example", config = path, echo = FALSE)

  r <- orderly_list_drafts(path)
  expect_equal(r$name, "example")
  expect_equal(names(r), c("name", "id"))
  expect_equal(r$id, id)
  expect_equal(dir(file.path(path_draft(path), "example")), r$id)
  expect_equal(orderly_list_archive(path), empty)

  expect_equal(orderly_find_name(id, path, FALSE, TRUE, TRUE), "example")

  expect_error(orderly_find_name(id, path, FALSE, FALSE, TRUE),
               "Did not find archive report")
  expect_null(orderly_find_name(id, path, FALSE, FALSE, FALSE))

  expect_error(orderly_find_name("id", path, FALSE, TRUE, TRUE),
               "Did not find draft report")
  expect_null(orderly_find_name("id", path, FALSE, TRUE, FALSE))

  orderly_commit(id, config = path)

  expect_equal(orderly_list_drafts(path), empty)
  expect_equal(orderly_list_archive(path), r)
})

test_that("latest_ids", {
  expect_equal(latest_id(character(0)), NA_character_)

  t <- Sys.time()
  t <- structure(as.numeric(t) %/% 1, class = class(t))

  id <- new_report_id(t)
  expect_identical(latest_id(id), id)
  expect_identical(latest_id(c(id, id)), id)

  ## Differ at the second level
  id_s <- vcapply(t - 5:0, new_report_id)
  expect_identical(latest_id(id_s), last(id_s))
  expect_identical(latest_id(sample(id_s)), last(id_s))

  ## Differ at the subsecond level
  id_ms <- vcapply(t + (1:9) / 10, new_report_id)
  expect_identical(latest_id(id_ms), last(id_ms))
  expect_identical(latest_id(sample(id_ms)), last(id_ms))

  ## Differ below the subsecond level
  id_same <- replicate(5, new_report_id(t + 1))
  expect_identical(latest_id(id_same), sort_c(id_same))
  expect_identical(latest_id(sample(id_same)), sort_c(id_same))

  id_both <- c(id_s, id_ms)
  expect_identical(latest_id(id_both), last(id_both))
  expect_identical(latest_id(sample(id_both)), last(id_both))

  id_all <- c(id_both, id_same)
  expect_identical(latest_id(id_all), sort_c(id_same))
  expect_identical(latest_id(sample(id_all)), sort_c(id_same))
})

test_that("latest", {
  path <- prepare_orderly_example("minimal")

  expect_equal(orderly_latest("example", config = path, must_work = FALSE),
               NA_character_)
  expect_equal(orderly_latest("example", config = path, must_work = FALSE,
                              draft = TRUE),
               NA_character_)
  expect_error(orderly_latest("example", config = path),
               "Did not find any archive reports for example")
  expect_error(orderly_latest("example", config = path, draft = TRUE),
               "Did not find any draft reports for example")

  id1 <- orderly_run("example", config = path, echo = FALSE)
  Sys.sleep(0.1)
  id2 <- orderly_run("example", config = path, echo = FALSE)
  expect_equal(orderly_latest("example", config = path, draft = TRUE), id2)

  orderly_commit(id2, config = path)
  expect_equal(orderly_latest("example", config = path, draft = TRUE), id1)
  expect_equal(orderly_latest("example", config = path), id2)
  orderly_commit(id1, config = path)
  expect_equal(orderly_latest("example", config = path), id2)
})
