from "mocha-forge" import *;

function main(didLoad) -> null {
    var x3: float[][] = [[1.5, 2.0, 0.5], [3.0, 1.0, 2.0]];
    var x2: float[][] = [[1.5, 2.0], [3.0, 1.0]];

    // degree 2, 3 features: output width, then row 0
    var a: PolynomialFeatures = PolynomialFeatures(2);
    var ra: float[][] = a.fit_transform(x3);
    print(a.n_output_features, newLine=true);
    var i: int = 0;
    while (i < ra.cols) {
        print(ra[0][i], newLine=true);
        i++;
    };

    // degree 3, 2 features: output width, then row 1
    var b: PolynomialFeatures = PolynomialFeatures(3);
    var rb: float[][] = b.fit_transform(x2);
    print(b.n_output_features, newLine=true);
    var j: int = 0;
    while (j < rb.cols) {
        print(rb[1][j], newLine=true);
        j++;
    };

    // degree 3, 3 features, interaction terms only: output width, then row 1
    var c: PolynomialFeatures = PolynomialFeatures(3);
    c.inter_only();
    var rc: float[][] = c.fit_transform(x3);
    print(c.n_output_features, newLine=true);
    var k: int = 0;
    while (k < rc.cols) {
        print(rc[1][k], newLine=true);
        k++;
    };
};