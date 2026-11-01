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

x13_build <- "v1-1-b61"
x13_url <- paste0(
  "https://www2.census.gov/software/x-13arima-seats/x13as/unix-linux/",
  "program-archives/x13as_asciisrc-", x13_build, ".tar.gz"
)

src_dir <- here::here("src")

# Download and unpack ---------------------------------------------------------

download_dir <- withr::local_tempdir()
tarball <- file.path(download_dir, "x13as.tar.gz")
utils::download.file(x13_url, tarball, mode = "wb", quiet = TRUE)
utils::untar(tarball, exdir = download_dir)

# Copy the files the Census makefile builds -----------------------------------

makefile <- readLines(file.path(download_dir, "makefile.gf"))
objs_start <- grep("^OBJS", makefile)
objs_end <- grep("^SRCS", makefile) - 1
objects <- unlist(strsplit(makefile[objs_start:objs_end], "[[:space:]\\\\=]+"))
objects <- grep("\\.o$", objects, value = TRUE)
fortran_files <- sub("\\.o$", ".f", objects)
fortran_files <- fortran_files[file.exists(file.path(download_dir, fortran_files))]

include_files <- list.files(download_dir, pattern = "\\.(i|cmn|prm|var)$")

old_files <- list.files(src_dir, pattern = "\\.(f|i|cmn|prm|var)$", full.names = TRUE)
old_files <- old_files[!grepl("^x13r_", basename(old_files))]
file.remove(old_files)

file.copy(file.path(download_dir, c(fortran_files, include_files)), src_dir)

cli::cli_alert_success(
  "Copied {length(fortran_files)} Fortran files and {length(include_files)} include files."
)

# Patch helper ----------------------------------------------------------------

patch_file <- function(file, pattern, replacement, expected = 1) {
  path <- file.path(src_dir, file)
  lines <- readLines(path)
  hits <- grep(pattern, lines)

  if (length(hits) != expected) {
    cli::cli_abort(
      "Patch for {.file {file}} expected {expected} match{?es} of {.code {pattern}}, found {length(hits)}."
    )
  }

  lines[hits] <- sub(pattern, replacement, lines[hits])
  writeLines(lines, path)
}

insert_after <- function(file, pattern, new_lines) {
  path <- file.path(src_dir, file)
  lines <- readLines(path)
  hit <- grep(pattern, lines)

  if (length(hit) != 1) {
    cli::cli_abort("Expected one match of {.code {pattern}} in {.file {file}}.")
  }

  writeLines(append(lines, new_lines, after = hit), path)
}

# Patch 1: main program becomes a subroutine ----------------------------------

patch_file("aaamain.f", "^      PROGRAM x12a$", "      SUBROUTINE x13main(Ifail)")
# The declaration must follow the IMPLICIT NONE that opens the unit.
path <- file.path(src_dir, "aaamain.f")
lines <- readLines(path)
main_line <- grep("^      SUBROUTINE x13main", lines)
stopifnot(lines[main_line + 1] == "      IMPLICIT NONE")
writeLines(append(lines, "      INTEGER Ifail", after = main_line + 1), path)
insert_after("aaamain.f", "^      Lfatal=F$", "      Ifail=0")
patch_file("aaamain.f", "IF\\(Lfatal\\)STOP$", "IF(Lfatal)GOTO 30", expected = 2)

# The first remaining STOP ends a normal run; the second follows the
# log-file error branch and falls through to the failure label.
path <- file.path(src_dir, "aaamain.f")
lines <- readLines(path)
stops <- grep("^      STOP$", lines)
stopifnot(length(stops) == 2)
lines[stops[1]] <- "      Ifail=nfail\n      RETURN"
lines[stops[2]] <- "   30 Ifail=max(Ifail,1)\n      RETURN"
writeLines(lines, path)

# Patch 2: arguments come from R ----------------------------------------------

patch_file("getxop.f", "CALL getarg\\(", "CALL rgetarg(", expected = 7)

cli::cli_alert_success("Applied patches for X-13 build {x13_build}.")
