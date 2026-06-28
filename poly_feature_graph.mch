from "mocha-forge" import *;
from "mocha-ink" import *;

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

    // generate predictions for smooth curve
    var x_plot: float[] = [];
    var y_plot: float[] = [];
    var i: int = 0;
    while (i < 50) {
        var xval: float = float(i) * 0.1;
        var test: float[][] = [[]];
        var sample: float[] = [xval];
        test.push(sample);
        var test_poly: float[][] = poly.transform(test);
        var pred: float[] = model.predict(test_poly);
        x_plot.push(xval);
        y_plot.push(pred[0]);
        i++;
    };

    // data points
    var x_data: float[] = [1.0, 2.0, 3.0];

    var plt: ScatterPlot = scatter(x_data, y);
    plt.title("Polynomial Regression (degree=2)");
    plt.xlabel("x");
    plt.ylabel("y");
    plt.color("red");
    plt.add_line(x_plot, y_plot);
    plt.save("poly_plot.svg");
    plt.show();
};