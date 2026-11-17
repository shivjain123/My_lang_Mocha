/* mocha_cvode.c - CVODE (SUNDIALS) bridge for Mocha.
   Solves one equation y' = f(t, y). f is a Mocha lambda with two float arguments (t, y)
   that returns a float. Returns y(t1), or NaN if CVODE fails. */
#include <math.h>
#include <stdio.h>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

typedef struct MochaClosureBundle MochaClosureBundle;
extern double mocha_call_lambda_float(MochaClosureBundle *b, void *a, void *c);

static int rhs1(sunrealtype t, N_Vector y, N_Vector ydot, void *user_data) {
    MochaClosureBundle *f = (MochaClosureBundle *)user_data;
    double tt = (double)t;
    double yy = (double)NV_Ith_S(y, 0);
    NV_Ith_S(ydot, 0) = (sunrealtype)mocha_call_lambda_float(f, &tt, &yy);
    return 0;
}

double mocha_cvode_solve1(MochaClosureBundle *f, double y0, double t0, double t1,
                          double rtol, double atol) {
    SUNContext ctx = NULL;
    N_Vector y = NULL;
    SUNMatrix A = NULL;
    SUNLinearSolver LS = NULL;
    void *cv = NULL;
    double result = NAN;
    sunrealtype tret = 0;

    if (SUNContext_Create(SUN_COMM_NULL, &ctx) != 0) {
        fprintf(stderr, "MochaRuntimeError: could not create a SUNDIALS context\n");
        return NAN;
    }
    y = N_VNew_Serial(1, ctx);
    if (!y) goto fail;
    NV_Ith_S(y, 0) = (sunrealtype)y0;
    cv = CVodeCreate(CV_BDF, ctx);
    if (!cv) goto fail;
    if (CVodeInit(cv, rhs1, (sunrealtype)t0, y) != CV_SUCCESS) goto fail;
    if (CVodeSStolerances(cv, rtol, atol) != CV_SUCCESS) goto fail;
    if (CVodeSetUserData(cv, f) != CV_SUCCESS) goto fail;
    A = SUNDenseMatrix(1, 1, ctx);
    LS = SUNLinSol_Dense(y, A, ctx);
    if (!A || !LS) goto fail;
    if (CVodeSetLinearSolver(cv, LS, A) != CV_SUCCESS) goto fail;
    CVodeSetMaxNumSteps(cv, 200000);
    if (CVode(cv, (sunrealtype)t1, y, &tret, CV_NORMAL) < 0) goto fail;
    result = (double)NV_Ith_S(y, 0);
    goto done;
fail:
    fprintf(stderr, "MochaRuntimeError: CVODE failed to solve the equation\n");
done:
    if (cv) CVodeFree(&cv);
    if (LS) SUNLinSolFree(LS);
    if (A) SUNMatDestroy(A);
    if (y) N_VDestroy(y);
    if (ctx) SUNContext_Free(&ctx);
    return result;
}