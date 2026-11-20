// mocha-native: mocha_cvode_sys.c, -IC:\sundials\inst\include, -LC:\sundials\inst\lib, -lsundials_cvode, -lsundials_sunnonlinsolnewton, -lsundials_sunlinsoldense, -lsundials_sunmatrixdense, -lsundials_nvecserial, -lsundials_core

function cvode_solve(f: lambda, y0: float[], times: float[], rtol: float, atol: float) -> float[][] native mocha_cvode_solve;

local function unsafe_mul(a: float, b: float) -> float native mocha_unsafe_mul;
local function unsafe_div(a: float, b: float) -> float native mocha_unsafe_div;
local function unsafe_add(a: float, b: float) -> float native mocha_unsafe_add;
local function unsafe_sub(a: float, b: float) -> float native mocha_unsafe_sub;

function robertson(t: float, y: float[]) -> float[] {
    var d: float[] = alloc float[3];
    var r1: float = float(unsafe_mul(0.04, y[0]));
    var r2: float = float(unsafe_mul(float(unsafe_mul(10000.0, y[1])), y[2]));
    var r3: float = float(unsafe_mul(float(unsafe_mul(30000000.0, y[1])), y[1]));
    d[0] = float(unsafe_add(float(unsafe_sub(0.0, r1)), r2));
    d[1] = float(unsafe_sub(float(unsafe_sub(r1, r2)), r3));
    d[2] = r3;
    return d;
};

function main(didLoad) -> null {
    var y0: float[] = alloc float[3];
    y0[0] = 1.0;
    y0[1] = 0.0;
    y0[2] = 0.0;
    var times: float[] = alloc float[5];
    times[0] = 0.0;
    times[1] = 0.4;
    times[2] = 4.0;
    times[3] = 40.0;
    times[4] = 400.0;
    var out: float[][] = cvode_solve(lambda (t: float, y: float[]) -> float[]: robertson(t, y), y0, times, 1E-8, 1E-14);
    print(out[1][0], newLine=true);
    print(out[1][1], newLine=true);
    print(out[1][2], newLine=true);
    print(out[4][0], newLine=true);
    print(out[4][1], newLine=true);
    print(out[4][2], newLine=true);
    print(out[4][0] + out[4][1] + out[4][2], newLine=true);
};