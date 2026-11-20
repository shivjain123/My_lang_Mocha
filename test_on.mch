// mocha-native: mocha_cvode_sys.o, C:\sundials\inst\lib\libsundials_cvode.a, C:\sundials\inst\lib\libsundials_sunnonlinsolnewton.a, C:\sundials\inst\lib\libsundials_sunlinsoldense.a, C:\sundials\inst\lib\libsundials_sunmatrixdense.a, C:\sundials\inst\lib\libsundials_nvecserial.a, C:\sundials\inst\lib\libsundials_core.a

function cvode_solve(f: lambda, y0: float[], times: float[], rtol: float, atol: float) -> float[][] native mocha_cvode_solve;

function oscillator(t: float, y: float[]) -> float[] {
    var d: float[] = alloc float[2];
    d[0] = y[1];
    d[1] = 0.0 - y[0];
    return d;
};

function main(didLoad) -> null {
    var y0: float[] = alloc float[2];
    y0[0] = 1.0;
    y0[1] = 0.0;
    var times: float[] = alloc float[3];
    times[0] = 0.0;
    times[1] = 1.5707963267948966;
    times[2] = 3.141592653589793;
    var out: float[][] = cvode_solve(lambda (t: float, y: float[]) -> float[]: oscillator(t, y), y0, times, 1E-10, 1E-12);
    print(out.rows, newLine=true);
    print(out[0][0], newLine=true);
    print(out[1][1], newLine=true);
    print(out[2][0], newLine=true);
};