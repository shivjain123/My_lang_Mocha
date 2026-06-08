from "mocha-forge" import *;

function main(didLoad) -> null {
    var x: float[][] = alloc float[5][2];
    x[0][0] = 1.0; x[0][1] = 2.0;
    x[1][0] = 2.0; x[1][1] = 3.0;
    x[2][0] = 3.0; x[2][1] = 4.0;
    x[3][0] = 4.0; x[3][1] = 5.0;
    x[4][0] = 5.0; x[4][1] = 6.0;

    var y: float[] = alloc float[5];
    y[0] = 5.0; y[1] = 8.0; y[2] = 11.0; y[3] = 14.0; y[4] = 17.0;

    // train and save
    var model: LinearRegression = LinearRegression(0.01, 1000);
    model.fit(x, y);
    print("before save r2=" + str(model.r2(x, y)), newLine=true);
    model.save("lr_model.db");

    // load into fresh model and predict
    var model2: LinearRegression = LinearRegression(0.01, 1000);
    model2.load("lr_model.db");
    print("after load r2=" + str(model2.r2(x, y)), newLine=true);

    // predictions should match
    var p1: float[] = model.predict(x);
    var p2: float[] = model2.predict(x);
    var i: int = 0;
    while (i < 5) {
        print("orig=" + str(p1[i]) + " loaded=" + str(p2[i]), newLine=true);
        i++;
    };
};