from "mocha-forge" import *;

function linear(didLoad){
    var x: float[][] = alloc float[6][1];
    x[0][0] = 1.0; x[1][0] = 2.0; x[2][0] = 3.0;
    x[3][0] = 5.0; x[4][0] = 6.0; x[5][0] = 7.0;

    var y: int[] = alloc int[6];
    y[0] = 0; y[1] = 0; y[2] = 0;
    y[3] = 1; y[4] = 1; y[5] = 1;

    var model: LinearSVM = LinearSVM(0.01, 1000);
    model.fit(x, y);

    var preds: int[] = model.predict(x);
    var i: int = 0;
    while (i < preds.length) {
        print(str(preds[i]), newLine=true);
        i++;
    };
    print("Accuracy: " + str(model.accuracy(x, y)), newLine=true);
    print("F1: " + str(model.f1(x, y)), newLine=true);
    print("Precision: " + str(model.precision(x, y)), newLine=true);
    print("Recall: " + str(model.recall(x, y)), newLine=true);
};