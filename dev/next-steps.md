# Next steps

Internal working notes. Last updated 2026-11-01.

## Where the package stands

x13r compiles the Census X-13ARIMA-SEATS source (Version 1.1, Build 61) and
runs it in-process through `x13_run()`. `tools/import-x13-source.R` downloads
the source and applies two patches: `aaamain.f` turns the main program into
the subroutine `x13main(Ifail)`, and `getxop.f` reads its arguments from R.
`src/x13r_init.c` applies gfortran's `-std=legacy` runtime settings when the
package loads. Without them, libgfortran rejects some runtime format strings
in `ansub4.f` and ends the R process.

The tests cover three fixtures: AirPassengers, PIM-PF (IBGE table 8888), and
monthly entries at Paulista station on Line 4 (`metrosp`). For all three, the
s11 table is byte-identical to `seasonal::seas()` output. Repeated runs in one
session give identical results, and an invalid spec raises an `x13r_error`.

The package is not faster than seasonal. A PIM-PF run takes about 1.15 s
against 1.20 s, because X-13's model search and SEATS dominate the run time.

## Known problems

- X-13 writes its banner and progress messages to Fortran unit 6, which goes
  to the process stdout instead of the R console.
- Two paths still end the R process. `ABORTA` in `polynom.f` calls `STOP`
  when internal polynomial or string buffers overflow, and any gfortran
  runtime error exits the process.
- Global `COMMON` state makes concurrent runs in one process unsafe.
- X-13 results depend on how the Fortran is compiled. Built at `-O0`, the
  PIM-PF s11 table differs from the `-O2` build by up to 3%, because small
  floating-point differences flip X-13's discrete choices. `src/Makevars`
  pins `-O2` with a GNU make pattern rule. Other platforms and compilers
  can still differ, for example x86_64 without fused multiply-add, so the
  byte-identical fixture comparison may fail on CI runners.
- `R CMD check` reports five warnings: Fortran I/O in compiled code,
  non-portable `PKG_FFLAGS`, non-standard file extensions in `src/`, a
  `STOP` call in `polynom.o`, and a clang header warning from the local
  toolchain.
- Local builds on this Mac need `R_MAKEVARS_USER` pointing at Homebrew
  gfortran, because R expects CRAN's gfortran at `/opt/gfortran`. Installing
  the CRAN toolchain from <https://mac.r-project.org/tools/> removes the need.

## Next steps, in order

1. Route X-13's console output away from stdout. The candidates are the
   quiet flag in `getxop.f` and opening unit 6 on a log file inside
   `x13main`.
2. Handle the remaining exit paths. Inspect each `ABORTA` caller and decide
   whether it can return safely through `abend`. If it cannot, give
   `x13_run()` an option to run in a child process.
3. Set up GitHub Actions `R CMD check` on Linux, macOS, and Windows. Then
   rename the include files to a standard extension in the import script,
   and find out which files actually need `-fallow-argument-mismatch`.
   Compare each platform's fixture output with the `seasonal` binary on
   the same platform, and decide which tolerance the tests should use.
4. Design the user-facing interface in a separate planning round. The
   priorities are setting regressors (trading days, Easter, Carnival,
   user-defined series), setting outliers by date and type, and replacing
   seasonal's list-of-specs syntax. Output should come back as tidy data
   frames instead of files.
5. Add fixtures for a quarterly series, an X-11 spec, a user-defined
   regressor, and a series where SEATS fails.
6. Publish to the EKIO r-universe once CI passes, then test the webR build.
7. For batches of many series, run X-13 in separate worker processes
   (`mirai` or `callr`), because the global state rules out threads.

## Out of scope

X-13 adjusts only monthly and quarterly series. Daily data, such as the
`metrosp` station entries, needs a different method, for example MSTL or
`rjd3highfreq`.

The package uses the Census ASCII source. seasonal uses the HTML build, which
differs only in the format of the main `.out` file.
