from "mocha-stats" import *;

function main(didLoad) -> null {
    var o1: float[] = [16.0, 18.0, 16.0, 14.0, 12.0, 12.0];
    var e1: float[] = [16.0, 16.0, 16.0, 16.0, 16.0, 8.0];
    print(chi(o1, e1), newLine=true);

    var o2: float[] = [44.0, 56.0, 102.0, 98.0];
    var e2: float[] = [50.0, 50.0, 100.0, 100.0];
    print(chi(o2, e2), newLine=true);

    var o3: float[] = [10.5, 20.25, 30.0];
    var e3: float[] = [12.0, 19.0, 29.75];
    print(chi(o3, e3), newLine=true);
};