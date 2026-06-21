from "mocha-processing" import *;

function test_pca_real(didLoad) -> null {
    var n: int = 200;
    var data_blob: float[][] = alloc float[n][2];
    var i: int = 0;
    while (i < n) {
        data_blob[i][0] = float(i) * 0.05;
        data_blob[i][1] = float(i) * 0.05;
        i++;
    };
    var pca: PCAReducer = PCAReducer(2);
    pca.fit(data_blob);
};