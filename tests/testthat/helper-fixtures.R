# Copies a fixture into a temporary directory, points its spec at the local
# data file, and returns the spec path without the .spc extension.
local_fixture <- function(name, env = parent.frame()) {
  run_dir <- withr::local_tempdir(.local_envir = env)
  src <- test_path("fixtures", name)

  file.copy(file.path(src, "iofile.dta"), run_dir)
  spc <- readLines(file.path(src, "iofile.spc"))
  spc <- sub("@DATA@", file.path(run_dir, "iofile.dta"), spc, fixed = TRUE)
  writeLines(spc, file.path(run_dir, "iofile.spc"))

  file.path(run_dir, "iofile")
}

read_x13_table <- function(path) {
  tbl <- utils::read.table(path, skip = 2, col.names = c("date", "value"))
  tbl$value
}

expected_s11 <- function(name) {
  read_x13_table(test_path("fixtures", name, "expected.s11"))
}
