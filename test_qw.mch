from "mocha-stats" import *;

function close(a: float, b: float, tol: float) -> bool {
    var d: float = a - b;
    if (d < 0.0) {
        d = 0.0 - d;
    };
    return d < tol;
};

function main(didLoad) -> null {
    var flat: float[] = [
        5.1, 3.5, 1.4, 0.2, 5.4, 3.7, 1.5, 0.2, 5.4, 3.4, 1.7, 0.2,
        4.8, 3.1, 1.6, 0.2, 5.0, 3.5, 1.3, 0.3, 7.0, 3.2, 4.7, 1.4,
        5.0, 2.0, 3.5, 1.0, 5.9, 3.2, 4.8, 1.8, 5.5, 2.4, 3.8, 1.1,
        5.5, 2.6, 4.4, 1.2, 6.3, 3.3, 6.0, 2.5, 6.5, 3.2, 5.1, 2.0,
        6.9, 3.2, 5.7, 2.3, 7.4, 2.8, 6.1, 1.9, 6.7, 3.1, 5.6, 2.4
    ];
    var vflat: float[] = [
        11.600134552533099, -10.700108404342991, -11.365858649528079, 13.207158089809758,
        -10.700108404342993, 17.088723793556234, 14.388891325706995, -19.45589854528606,
        -11.365858649528073, 14.388891325706986, 18.100592753407696, -26.78116866484115,
        13.20715808980975, -19.45589854528605, -26.781168664841147, 43.89967976131837
    ];

    var data: float[][] = alloc float[15][4];
    var i: int = 0;
    while (i < 15) {
        var j: int = 0;
        while (j < 4) {
            data[i][j] = flat[i * 4 + j];
            j++;
        };
        i++;
    };
    var vi: float[][] = alloc float[4][4];
    var ident: float[][] = alloc float[4][4];
    var p: int = 0;
    while (p < 4) {
        var q: int = 0;
        while (q < 4) {
            vi[p][q] = vflat[p * 4 + q];
            if (p == q) {
                ident[p][q] = 1.0;
            } else {
                ident[p][q] = 0.0;
            };
            q++;
        };
        p++;
    };

    var a: float[] = [5.0, 3.0, 4.0, 1.0];
    var b: float[] = [5.1, 3.5, 1.4, 0.2];
    var mean: float[] = [5.893333333333334, 3.08, 3.813333333333334, 1.2466666666666666];

    var d1: float = mahalanobis(a, b, vi);
    var d2: float = mahalanobis_data(a, data);
    var d3: float = mahalanobis(a, mean, vi);
    var d4: float = mahalanobis(a, a, vi);
    var d5: float = mahalanobis(a, b, ident);
    var e5: float = euclidean(a, b);
    var d6: float = mahalanobis(b, a, vi);

    print("mahalanobis(a, b, vi)   ", d1, newLine=true);
    print("mahalanobis_data(a)     ", d2, newLine=true);
    print("mahalanobis(a, mean, vi)", d3, newLine=true);
    print("mahalanobis(a, a, vi)   ", d4, newLine=true);
    print("identity vs euclidean   ", d5, " ", e5, newLine=true);
    print("swapped arguments       ", d6, newLine=true);

    if (close(d1, 4.931025700683013, 0.0000001)) { print("PASS matches scipy for two points", newLine=true); } else { print("FAIL two points", newLine=true); };
    if (close(d2, 4.692437231944752, 0.0000001)) { print("PASS mahalanobis_data matches scipy", newLine=true); } else { print("FAIL mahalanobis_data", newLine=true); };
    if (close(d3, d2, 0.0000001)) { print("PASS both functions agree", newLine=true); } else { print("FAIL functions disagree", newLine=true); };
    if (d4 == 0.0) { print("PASS distance to itself is 0", newLine=true); } else { print("FAIL self distance", newLine=true); };
    if (close(d5, e5, 0.000000000001)) { print("PASS identity matrix gives euclidean", newLine=true); } else { print("FAIL identity vs euclidean", newLine=true); };
    if (close(d1, d6, 0.000000000001)) { print("PASS symmetric", newLine=true); } else { print("FAIL symmetry", newLine=true); };
};