from "mocha-forge" import *;

function test(didLoad) -> null {
    var x: float[][] = alloc float[5][1];
    x[0][0] = 1.0; x[1][0] = 2.0; x[2][0] = 3.0;
    x[3][0] = 4.0; x[4][0] = 5.0;

    var y: float[] = alloc float[5];
    y[0] = 3.0; y[1] = 5.0; y[2] = 7.0;
    y[3] = 9.0; y[4] = 11.0;

    var model: LinearRegression = LinearRegression(0.01, 1000);
    model.fit(x, y);

    var preds: float[] = model.predict(x);
    var i: int = 0;
    while (i < preds.length) {
        print(str(preds[i]), newLine=true);
        i++;
    };

    print("R2: " + str(model.r2(x, y)), newLine=true);
    print("MSE: " + str(model.mse(x, y)), newLine=true);
    print("RMSE: " + str(model.rmse(x, y)), newLine=true);

    // Ridge test
    var ridge_model: LinearRegression = LinearRegression(0.01, 1000);
    ridge_model.ridge(0.1);
    ridge_model.fit(x, y);
    print("Ridge R2: " + str(ridge_model.r2(x, y)), newLine=true);

    // Lasso test
    var lasso_model: LinearRegression = LinearRegression(0.01, 1000);
    lasso_model.lasso(0.1);
    lasso_model.fit(x, y);
    print("Lasso R2: " + str(lasso_model.r2(x, y)), newLine=true);
};