from "mocha-processing" import *;

function main(didLoad) -> null {
    var data: float[] = [5.1, 4.9, 4.7, 4.6, 5.0, 5.4, 4.6, 5.0, 4.4, 4.9, 5.4, 4.8, 4.8, 4.3, 5.8, 5.7, 5.4, 5.1, 5.7, 5.1, 5.4, 5.1, 4.6, 5.1, 4.8, 5.0, 5.0, 5.2, 5.2, 4.7, 4.8, 5.4, 5.2, 5.5, 4.9, 5.0, 5.5, 4.9, 4.4, 5.1];

    var sc: RobustScaler = RobustScaler();
    var t: float[] = sc.fit_transform(data);

    // fitted median and IQR
    print(sc.median_val, newLine=true);
    print(sc.iqr_val, newLine=true);

    // transformed values at index 0, 1, 2, 3, 4, 14, 22, 39
    print(t[0], newLine=true);
    print(t[1], newLine=true);
    print(t[2], newLine=true);
    print(t[3], newLine=true);
    print(t[4], newLine=true);
    print(t[14], newLine=true);
    print(t[22], newLine=true);
    print(t[39], newLine=true);

    // new data
    var fresh: float[] = [4.0, 5.0, 7.5];
    var u: float[] = sc.transform(fresh);
    print(u[0], newLine=true);
    print(u[1], newLine=true);
    print(u[2], newLine=true);
};