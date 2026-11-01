# Imports the US Census Bureau X-13ARIMA-SEATS Fortran source into src/ and
# applies the patches that let R run the program in-process. Rerun this
# script to move to a new Census build: update `x13_build` and check that
# every patch still applies.
#
# Patches:
# 1. aaamain.f: PROGRAM x12a becomes SUBROUTINE x13main(Ifail). Every STOP
#    becomes a RETURN, so a failed run returns to R instead of ending the
#    R process. Ifail reports the number of failed series.
# 2. getxop.f: command-line arguments come from rgetarg(), which reads the
#    arguments that the C wrapper received from R.
#
# The script copies and patches the source in a staging directory. It
# replaces the vendored files in src/ only after every step succeeds, so a
# failed import leaves src/ untouched.

x13_build <- "v1-1-b61"
x13_url <- paste0(
  "https://www2.census.gov/software/x-13arima-seats/x13as/unix-linux/",
  "program-archives/x13as_asciisrc-", x13_build, ".tar.gz"
)

src_dir <- here::here("src")
vendored_pattern <- "\\.(f|i|cmn|prm|var)$"

# Download and unpack ---------------------------------------------------------

download_dir <- withr::local_tempdir()
tarball <- file.path(download_dir, "x13as.tar.gz")
utils::download.file(x13_url, tarball, mode = "wb", quiet = TRUE)
utils::untar(tarball, exdir = download_dir)

# List the files the Census makefile builds -----------------------------------

makefile <- readLines(file.path(download_dir, "makefile.gf"), warn = FALSE)
objs_start <- grep("^OBJS", makefile)
objs_end <- grep("^SRCS", makefile) - 1
objects <- unlist(strsplit(makefile[objs_start:objs_end], "[[:space:]\\\\=]+"))
objects <- grep("\\.o$", objects, value = TRUE)
fortran_files <- sub("\\.o$", ".f", objects)

missing <- fortran_files[!file.exists(file.path(download_dir, fortran_files))]
if (length(missing) > 0) {
  cli::cli_abort("The Census makefile lists sources missing from the archive: {.file {missing}}.")
}

include_files <- list.files(download_dir, pattern = "\\.(i|cmn|prm|var)$")

# Stage the source ------------------------------------------------------------

stage_dir <- withr::local_tempdir()
copied <- file.copy(file.path(download_dir, c(fortran_files, include_files)), stage_dir)

if (!all(copied)) {
  cli::cli_abort("Failed to stage {sum(!copied)} file{?s}.")
}

# Patch helpers ---------------------------------------------------------------

read_staged <- function(file) {
  readLines(file.path(stage_dir, file), warn = FALSE)
}

write_staged <- function(lines, file) {
  writeLines(lines, file.path(stage_dir, file))
}

patch_file <- function(file, pattern, replacement, expected = 1) {
  lines <- read_staged(file)
  hits <- grep(pattern, lines)

  if (length(hits) != expected) {
    cli::cli_abort(
      "Patch for {.file {file}} expected {expected} match{?es} of {.code {pattern}}, found {length(hits)}."
    )
  }

  lines[hits] <- sub(pattern, replacement, lines[hits])
  write_staged(lines, file)
}

insert_after <- function(file, pattern, new_lines) {
  lines <- read_staged(file)
  hit <- grep(pattern, lines)

  if (length(hit) != 1) {
    cli::cli_abort("Expected one match of {.code {pattern}} in {.file {file}}.")
  }

  write_staged(append(lines, new_lines, after = hit), file)
}

# Patch 1: main program becomes a subroutine ----------------------------------

patch_file("aaamain.f", "^      PROGRAM x12a$", "      SUBROUTINE x13main(Ifail)")

# The declaration must follow the IMPLICIT NONE that opens the unit.
lines <- read_staged("aaamain.f")
main_line <- grep("^      SUBROUTINE x13main\\(Ifail\\)$", lines)
if (lines[main_line + 1] != "      IMPLICIT NONE") {
  cli::cli_abort("Expected IMPLICIT NONE to open the main program in {.file aaamain.f}.")
}
write_staged(append(lines, "      INTEGER Ifail", after = main_line + 1), "aaamain.f")

insert_after("aaamain.f", "^      Lfatal=F$", "      Ifail=0")
patch_file("aaamain.f", "IF\\(Lfatal\\)STOP$", "IF(Lfatal)GOTO 30", expected = 2)

# The first remaining STOP ends a normal run; the second follows the
# log-file error branch and falls through to the failure label.
lines <- read_staged("aaamain.f")
stops <- grep("^      STOP$", lines)
if (length(stops) != 2) {
  cli::cli_abort("Expected two STOP statements in {.file aaamain.f}, found {length(stops)}.")
}
lines[stops[1]] <- "      Ifail=nfail\n      RETURN"
lines[stops[2]] <- "   30 Ifail=max(Ifail,1)\n      RETURN"
write_staged(lines, "aaamain.f")

# Patch 2: arguments come from R ----------------------------------------------

patch_file("getxop.f", "CALL getarg\\(", "CALL rgetarg(", expected = 7)

# Replace the vendored files --------------------------------------------------

old_files <- list.files(src_dir, pattern = vendored_pattern, full.names = TRUE)
old_files <- old_files[!grepl("^x13r_", basename(old_files))]
file.remove(old_files)

staged <- list.files(stage_dir, full.names = TRUE)
if (!all(file.copy(staged, src_dir))) {
  cli::cli_abort("Failed to copy the staged source into {.path {src_dir}}.")
}

cli::cli_alert_success(
  "Imported {length(fortran_files)} Fortran files and {length(include_files)} include files from X-13 build {x13_build}."
)
