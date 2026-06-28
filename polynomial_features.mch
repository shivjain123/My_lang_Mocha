from "mocha-forge" import *;

function main(didLoad) -> null {
    var x: float[][] = [[]];
    var r1: float[] = [1.0];
    var r2: float[] = [2.0];
    var r3: float[] = [3.0];
    x.push(r1);
    x.push(r2);
    x.push(r3);

    var y: float[] = [2.0, 4.0, 9.0];

    var poly: PolynomialFeatures = PolynomialFeatures(2);
    var x_poly: float[][] = poly.fit_transform(x);

    var model: LinearRegression = LinearRegression(0.01, 5000);
    model.fit(x_poly, y);
    model.summary(x_poly, y);

    var test: float[][] = [[]];
    var t: float[] = [4.0];
    test.push(t);
    var test_poly: float[][] = poly.transform(test);
    var pred: float[] = model.predict(test_poly);
    print("Predicted for x=4: $0|2f".format(pred[0]), newLine=true);
};