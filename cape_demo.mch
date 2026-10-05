from "mocha-meteoro" import *;

function cape_demo(t_sfc: float, td_sfc: float) -> float {
    var p: float[] = [890.0, 875.0, 850.0, 825.0, 800.0, 750.0, 700.0, 600.0, 500.0];
    var t: float[] = [t_sfc, 27.0, 26.0, 23.0, 20.0, 14.0, 8.0, -6.0, -19.0];
    var td: float[] = [td_sfc, 17.5, 16.0, 15.0, 13.0, 8.0, 2.0, -12.0, -25.0];
    var r: float[] = cape_cin(p, t, td);
    return r[0];
};

function main(didLoad) -> null {
    print(cape_demo(28.0, 18.0), newLine=true);
};