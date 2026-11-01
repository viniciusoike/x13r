# x13r

x13r runs the U.S. Census Bureau's
[X-13ARIMA-SEATS](https://www.census.gov/data/software/x13as.html) seasonal
adjustment program inside the R process. The package compiles the Census
Fortran source itself, so it needs no external executable, and X-13 errors
come back as R errors.

The package is experimental and exports no functions yet. Its internal
function `x13_run()` runs an X-13 spec file and writes the usual X-13 output
files next to it.

## Installation

``` r
# install.packages("pak")
pak::pak("viniciusoike/x13r")
```

Building from source requires gfortran. On macOS, install it from
<https://mac.r-project.org/tools/>; on Windows, it comes with Rtools.

## Example

``` r
spec <- file.path(tempdir(), "air")

writeLines(c(
  "series{",
  "  start = 1949.01",
  "  period = 12",
  "  data = (", strwrap(paste(AirPassengers, collapse = " "), width = 70), "  )",
  "}",
  "transform{ function = auto }",
  "regression{ aictest = (td easter) }",
  "outlier{ }",
  "automdl{ }",
  "x11{ save = (d11) }"
), paste0(spec, ".spc"))

x13r:::x13_run(spec)

adjusted <- read.table(paste0(spec, ".d11"), skip = 2, col.names = c("date", "value"))
head(adjusted)
#>     date    value
#> 1 194901 121.7202
#> 2 194902 124.5235
#> 3 194903 125.3989
```

## Relation to seasonal

[seasonal](https://github.com/christophsax/seasonal) and
[x13binary](https://github.com/x13org/x13binary) run the same Census program
as a separate executable. The x13r tests check that the final seasonally
adjusted series matches `seasonal::seas()` for several monthly series.

## License

The X-13ARIMA-SEATS Fortran source in `src/` is U.S. Government work
distributed under the Census Bureau's terms. The rest of the package is MIT.
See [LICENSE](LICENSE) and [inst/COPYRIGHTS](inst/COPYRIGHTS).
