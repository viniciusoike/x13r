#' Run X-13ARIMA-SEATS on a spec file
#'
#' Runs the X-13ARIMA-SEATS program inside the R process. X-13 reads
#' `<spec>.spc` and writes its output files next to it, using `spec` as the
#' file prefix.
#'
#' @param spec Path to the spec file, without the `.spc` extension.
#' @param flags Command-line flags passed to X-13. The default matches
#'   `seasonal::seas()`: `-n` skips the printed tables and `-s` writes the
#'   diagnostics summary.
#'
#' @return `spec`, invisibly.
#' @keywords internal
x13_run <- function(spec, flags = c("-n", "-s")) {
  spec <- normalizePath(spec, mustWork = FALSE)
  spc_file <- paste0(spec, ".spc")

  if (!file.exists(spc_file)) {
    cli::cli_abort("Spec file {.file {spc_file}} does not exist.")
  }

  ifail <- .Call(x13r_run, c(spec, flags))

  if (ifail > 0) {
    cli::cli_abort(
      c("X-13 failed to process {.file {spc_file}}.", x13_errors(spec)),
      class = "x13r_error"
    )
  }

  invisible(spec)
}

# Returns the ERROR lines that X-13 wrote to `<spec>.err`, named for
# cli::cli_abort() bullets.
x13_errors <- function(spec) {
  err_file <- paste0(spec, ".err")
  if (!file.exists(err_file)) {
    return(character())
  }

  lines <- trimws(readLines(err_file, warn = FALSE))
  errors <- grep("^ERROR", lines, value = TRUE)
  errors <- gsub("([{}])", "\\1\\1", errors)
  rlang::set_names(errors, rep("x", length(errors)))
}
