// mocha-native: mocha_cvode.o, C:\sundials\inst\lib\libsundials_cvode.a, C:\sundials\inst\lib\libsundials_sunnonlinsolnewton.a, C:\sundials\inst\lib\libsundials_sunlinsoldense.a, C:\sundials\inst\lib\libsundials_sunmatrixdense.a, C:\sundials\inst\lib\libsundials_nvecserial.a, C:\sundials\inst\lib\libsundials_core.a

function cvode_solve(f: lambda, y0: float, t0: float, t1: float, rtol: float, atol: float) -> float native mocha_cvode_solve1;

function main(didLoad) -> null {
    var a: float = cvode_solve(lambda (t: float, y: float) -> float: 0.0 - y, 1.0, 0.0, 1.0, 1E-8, 1E-10);
    print(a, newLine=true);

    var b: float = cvode_solve(lambda (t: float, y: float) -> float: t, 1.0, 0.0, 2.0, 1E-8, 1E-10);
    print(b, newLine=true);

    var k: float = 0.5;
    var c: float = cvode_solve(lambda (t: float, y: float) -> float: k * y, 2.0, 0.0, 2.0, 1E-8, 1E-10);
    print(c, newLine=true);
};