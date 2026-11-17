/* mocha_cvode_sys.c - CVODE (SUNDIALS) bridge for Mocha: SYSTEMS of equations.
   f is a Mocha lambda (t: float, y: float[]) -> float[] that returns a NEW array with the
   derivatives. Returns a 2D array: one row per entry of times (row 0 = y0). */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunmatrix/sunmatrix_dense.h>
#include <sunlinsol/sunlinsol_dense.h>

typedef struct MochaArray MochaArray;
typedef struct MochaArray2D MochaArray2D;
typedef struct MochaClosureBundle { void *fn; void *env; int32_t tag; } MochaClosureBundle;

extern int32_t mocha_array_length(MochaArray *arr);
extern void mocha_array_get(MochaArray *arr, int32_t index, void *out);
extern void mocha_array_set(MochaArray *arr, int32_t index, void *value);
extern void mocha_array_push(MochaArray *arr, void *value);
extern MochaArray *mocha_array_new(int32_t capacity, int32_t elem_size, int32_t fixed);
extern void mocha_array_release(MochaArray *arr, int32_t elem_is_str);
extern MochaArray2D *mocha_array2d_new(int32_t rows, int32_t cols, int32_t elem_size,
                                       int32_t fixed_r, int32_t fixed_c, int32_t elem_is_str);
extern void mocha_array2d_set(MochaArray2D *arr, int32_t row, int32_t col, void *value);

typedef MochaArray *(*RhsLambda)(void *t, void *y, void *env);
typedef struct { MochaClosureBundle *f; MochaArray *ycur; int n; } OdeCtx;

static int rhs_sys(sunrealtype t, N_Vector y, N_Vector ydot, void *user_data) {
    OdeCtx *c = (OdeCtx *)user_data;
    double tt = (double)t;
    for (int i = 0; i < c->n; i++) {
        double v = (double)NV_Ith_S(y, i);
        mocha_array_set(c->ycur, i, &v);
    }
    MochaArray *slot = c->ycur;
    MochaArray *res = ((RhsLambda)c->f->fn)(&tt, &slot, c->f->env);
    if (!res) return -1;
    if (mocha_array_length(res) != c->n) {
        mocha_array_release(res, 0);
        return -1;
    }
    for (int i = 0; i < c->n; i++) {
        double d;
        mocha_array_get(res, i, &d);
        NV_Ith_S(ydot, i) = (sunrealtype)d;
    }
    mocha_array_release(res, 0);
    return 0;
}

MochaArray2D *mocha_cvode_solve(MochaClosureBundle *f, MochaArray *y0, MochaArray *times,
                                double rtol, double atol) {
    int n = mocha_array_length(y0);
    int m = mocha_array_length(times);
    const char *why = "CVODE failed to solve the system";
    SUNContext ctx = NULL;
    N_Vector y = NULL;
    SUNMatrix A = NULL;
    SUNLinearSolver LS = NULL;
    void *cv = NULL;
    MochaArray *ycur = NULL;
    MochaArray2D *out = NULL;
    OdeCtx oc;
    sunrealtype tret = 0;
    double tprev = 0, tk = 0;

    if (n < 1 || m < 1) {
        fprintf(stderr, "MochaRuntimeError: cvode_solve needs a non-empty y0 and a non-empty times array\n");
        exit(2);
    }
    out = mocha_array2d_new(m, n, (int32_t)sizeof(double), 0, 0, 0);
    ycur = mocha_array_new(n, (int32_t)sizeof(double), 0);
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(y0, i, &v);
        mocha_array_push(ycur, &v);
        mocha_array2d_set(out, 0, i, &v);
    }
    oc.f = f; oc.ycur = ycur; oc.n = n;

    if (SUNContext_Create(SUN_COMM_NULL, &ctx) != 0) goto fail;
    y = N_VNew_Serial(n, ctx);
    if (!y) goto fail;
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(y0, i, &v);
        NV_Ith_S(y, i) = (sunrealtype)v;
    }
    mocha_array_get(times, 0, &tprev);
    cv = CVodeCreate(CV_BDF, ctx);
    if (!cv) goto fail;
    if (CVodeInit(cv, rhs_sys, (sunrealtype)tprev, y) != CV_SUCCESS) goto fail;
    if (CVodeSStolerances(cv, rtol, atol) != CV_SUCCESS) goto fail;
    if (CVodeSetUserData(cv, &oc) != CV_SUCCESS) goto fail;
    A = SUNDenseMatrix(n, n, ctx);
    LS = SUNLinSol_Dense(y, A, ctx);
    if (!A || !LS) goto fail;
    if (CVodeSetLinearSolver(cv, LS, A) != CV_SUCCESS) goto fail;
    CVodeSetMaxNumSteps(cv, 500000);

    for (int k = 1; k < m; k++) {
        mocha_array_get(times, k, &tk);
        if (!(tk > tprev)) { why = "cvode_solve: the times must be strictly increasing"; goto fail; }
        if (CVode(cv, (sunrealtype)tk, y, &tret, CV_NORMAL) < 0) goto fail;
        for (int i = 0; i < n; i++) {
            double v = (double)NV_Ith_S(y, i);
            mocha_array2d_set(out, k, i, &v);
        }
        tprev = tk;
    }
    goto done;
fail:
    fprintf(stderr, "MochaRuntimeError: %s\n", why);
    exit(2);
done:
    if (cv) CVodeFree(&cv);
    if (LS) SUNLinSolFree(LS);
    if (A) SUNMatDestroy(A);
    if (y) N_VDestroy(y);
    if (ctx) SUNContext_Free(&ctx);
    mocha_array_release(ycur, 0);
    return out;
}