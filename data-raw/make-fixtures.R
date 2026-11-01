# Builds the reference fixtures used by the tests. Each fixture holds the
# spec and data file that `seasonal::seas()` sends to X-13, plus the final
# seasonally adjusted series (table s11) that the X-13 binary returns.
# Requires seasonal, sidrar, metrosp, and an internet connection.

library(seasonal)

fixture_dir <- here::here("tests", "testthat", "fixtures")

# Fixture writer --------------------------------------------------------------

write_fixture <- function(x, name) {
  run_dir <- withr::local_tempdir()
  seas(x, dir = run_dir)

  out_dir <- file.path(fixture_dir, name)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  spc <- readLines(file.path(run_dir, "iofile.spc"))
  spc <- sub('file = ".*"', 'file = "@DATA@"', spc)
  writeLines(spc, file.path(out_dir, "iofile.spc"))

  file.copy(file.path(run_dir, "iofile.dta"), out_dir, overwrite = TRUE)
  file.copy(
    file.path(run_dir, "iofile.s11"),
    file.path(out_dir, "expected.s11"),
    overwrite = TRUE
  )
  cli::cli_alert_success("Wrote fixture {.val {name}}")
}

# AirPassengers ---------------------------------------------------------------

write_fixture(AirPassengers, "airpassengers")

# PIM-PF: general industry index (IBGE, table 8888) ---------------------------

pimpf <- sidrar::get_sidra(api = "/t/8888/n1/all/v/12606/p/all/c544/129314")
pimpf <- pimpf[order(pimpf[["Mês (Código)"]]), ]
first_month <- pimpf[["Mês (Código)"]][1]

pimpf_ts <- ts(
  pimpf[["Valor"]],
  start = c(as.integer(substr(first_month, 1, 4)), as.integer(substr(first_month, 5, 6))),
  frequency = 12
)

write_fixture(pimpf_ts, "pimpf")

# Metro SP: monthly entries at Paulista station (Line 4) ----------------------

paulista_daily <- metrosp::station_entries_daily |>
  subset(station_id == "consolacao-paulista" & line_number == 4)

paulista_daily$month <- format(paulista_daily$date, "%Y-%m")

paulista_monthly <- paulista_daily |>
  dplyr::summarise(
    entries = sum(value),
    days = dplyr::n(),
    .by = month
  ) |>
  dplyr::arrange(month)

days_in_month <- lubridate::days_in_month(as.Date(paste0(paulista_monthly$month, "-01")))
incomplete <- paulista_monthly$month[paulista_monthly$days != days_in_month]

if (length(incomplete) > 0) {
  cli::cli_abort("Paulista series has incomplete months: {.val {incomplete}}")
}

first_month <- paulista_monthly$month[1]
paulista_ts <- ts(
  paulista_monthly$entries / 1000,
  start = c(as.integer(substr(first_month, 1, 4)), as.integer(substr(first_month, 6, 7))),
  frequency = 12
)

write_fixture(paulista_ts, "metrosp-paulista")
