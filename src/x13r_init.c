// x13r glue code. Not part of the Census Bureau source.
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <string.h>

void F77_NAME(x13main)(int *ifail);

// A Fortran main program compiled by gfortran calls _gfortran_set_options
// before anything else. X-13 relies on the settings that -std=legacy
// passes there; without them, libgfortran rejects some of X-13's runtime
// format strings and ends the R process. The symbol is weak so the package
// still loads with a Fortran runtime that lacks it.
extern void _gfortran_set_options(int num, int options[]) __attribute__((weak));

static void x13r_set_fortran_options(void) {
  if (_gfortran_set_options == NULL) return;
  // warn_std, allow_std, pedantic, backtrace, sign_zero, bounds_check,
  // fpe_summary: the -std=legacy values, with backtraces turned off.
  int options[] = {0, 16383, 0, 0, 1, 0, 31};
  _gfortran_set_options(7, options);
}

// Arguments for the current run. Fortran argument 1 is x13_args[0].
static SEXP x13_args = NULL;

// Called from rgetarg in x13r_glue.f. Fills buf with the characters of
// argument n, padded with blanks. Missing arguments come back blank, which
// tells getxop that the argument list has ended.
void F77_NAME(x13rarg)(int *n, int *buf, int *nchr) {
  const char *arg = "";
  if (x13_args != NULL && *n >= 1 && *n <= XLENGTH(x13_args)) {
    arg = CHAR(STRING_ELT(x13_args, *n - 1));
  }
  size_t len = strlen(arg);
  for (int i = 0; i < *nchr; i++) {
    buf[i] = (i < (int) len) ? (unsigned char) arg[i] : ' ';
  }
}

SEXP x13r_run(SEXP args) {
  if (!isString(args)) error("`args` must be a character vector.");
  int ifail = 0;
  x13_args = args;
  F77_CALL(x13main)(&ifail);
  x13_args = NULL;
  return ScalarInteger(ifail);
}

static const R_CallMethodDef call_methods[] = {
  {"x13r_run", (DL_FUNC) &x13r_run, 1},
  {NULL, NULL, 0}
};

void R_init_x13r(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  x13r_set_fortran_options();
}
