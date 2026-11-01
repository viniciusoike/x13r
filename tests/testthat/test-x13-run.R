fixtures <- c("airpassengers", "pimpf", "metrosp-paulista")

test_that("in-process X-13 matches the seasonal binary", {
  for (name in fixtures) {
    spec <- local_fixture(name)
    x13_run(spec)

    expect_equal(
      read_x13_table(paste0(spec, ".s11")),
      expected_s11(name),
      tolerance = 1e-8,
      label = name
    )
  }
})

test_that("repeated runs in one session give the same result", {
  run_s11 <- function(name) {
    spec <- local_fixture(name)
    x13_run(spec)
    read_x13_table(paste0(spec, ".s11"))
  }

  first <- run_s11("airpassengers")
  run_s11("pimpf")
  run_s11("metrosp-paulista")
  second <- run_s11("airpassengers")

  expect_identical(second, first)
})

test_that("an invalid spec raises an R error and keeps the session alive", {
  spec <- local_fixture("airpassengers")
  writeLines(c("series{", "  bogus = 1", "}"), paste0(spec, ".spc"))

  expect_error(x13_run(spec), class = "x13r_error")

  spec <- local_fixture("airpassengers")
  x13_run(spec)
  expect_equal(
    read_x13_table(paste0(spec, ".s11")),
    expected_s11("airpassengers"),
    tolerance = 1e-8
  )
})

test_that("paths too long for X-13 are rejected before the run", {
  spec <- file.path(tempdir(), strrep("a", 600), "iofile")
  expect_error(x13_run(spec), class = "x13r_path_too_long")

  spec <- local_fixture("airpassengers")
  expect_error(x13_run(spec, flags = strrep("-", 600)), class = "x13r_path_too_long")
})
