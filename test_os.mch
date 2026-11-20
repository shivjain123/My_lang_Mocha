// mocha-native: mocha_cvode_sys.c, -IC:\sundials\inst\include, -LC:\sundials\inst\lib, -lsundials_cvode, -lsundials_sunnonlinsolnewton, -lsundials_sunlinsoldense, -lsundials_sunmatrixdense, -lsundials_nvecserial, -lsundials_core

function cvode_solve(f: lambda, y0: float[], times: float[], rtol: float, atol: float) -> float[][] native mocha_cvode_solve;

// y[1] is the middle species multiplied by 10000, so every term stays far above Mocha's resolution
function robertson_scaled(t: float, y: float[]) -> float[] {
    var d: float[] = alloc float[3];
    d[0] = 0.0 - 0.04 * y[0] + y[1] * y[2];
    d[1] = 400.0 * y[0] - 10000.0 * y[1] * y[2] - 3000.0 * y[1] * y[1];
    d[2] = 0.3 * y[1] * y[1];
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
    var out: float[][] = cvode_solve(lambda (t: float, y: float[]) -> float[]: robertson_scaled(t, y), y0, times, 1E-8, 1E-10);
    print(out[1][0], newLine=true);
    print(out[1][1] / 10000.0, newLine=true);
    print(out[1][2], newLine=true);
    print(out[4][0], newLine=true);
    print(out[4][1] / 10000.0, newLine=true);
    print(out[4][2], newLine=true);
    print(out[4][0] + out[4][1] / 10000.0 + out[4][2], newLine=true);
};