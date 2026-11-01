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
  check_arg_length(c(spec, flags))
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

# X-13 stores each argument in a 512-character buffer (PFILCR in stdio.i)
# and appends extensions such as ".spc" and ".log" to the spec path in
# place. Longer arguments would be truncated or overflow, so reject them.
x13_max_arg_bytes <- 500L

check_arg_length <- function(args, call = rlang::caller_env()) {
  too_long <- nchar(args, type = "bytes") > x13_max_arg_bytes
  if (any(too_long)) {
    cli::cli_abort(
      c(
        "X-13 arguments must be at most {x13_max_arg_bytes} bytes.",
        "x" = "{.val {args[too_long]}} {?is/are} too long."
      ),
      class = c("x13r_path_too_long", "x13r_error"),
      call = call
    )
  }
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
