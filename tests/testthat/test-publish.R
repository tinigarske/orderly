context("publish")

test_that("included example", {
  path <- prepare_orderly_example("example")
  expect_equal(read_orderly_db(path)$published, numeric(0))

  id <- orderly_run("example", list(cyl = 4), config = path, echo = FALSE)
  p <- orderly_commit(id, config = path)

  yml <- path_orderly_published_yml(p)
  expect_false(file.exists(yml))
  expect_equal(read_orderly_db(path)$published, 0)

  orderly_publish(id, config = path)
  expect_equal(read_orderly_db(path)$published, 1)
  expect_true(file.exists(yml))
  expect_equal(yaml_read(yml), list(published = TRUE))

  expect_message(orderly_publish(id, config = path),
                 "Report is already published")
  expect_equal(read_orderly_db(path)$published, 1)
  expect_true(file.exists(yml))
  expect_equal(yaml_read(yml), list(published = TRUE))

  orderly_publish(id, value = FALSE, config = path)
  expect_equal(read_orderly_db(path)$published, 0)
  expect_true(file.exists(yml))
  expect_equal(yaml_read(yml), list(published = FALSE))

  expect_message(orderly_publish(id, value = FALSE, config = path),
                 "Report is already unpublished")
  expect_equal(read_orderly_db(path)$published, 0)
  expect_true(file.exists(yml))
  expect_equal(yaml_read(yml), list(published = FALSE))
})
