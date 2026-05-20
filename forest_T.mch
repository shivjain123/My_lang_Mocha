from "mocha-forge" import *;

function main(didLoad){
    var x: float[][] = alloc float[6][2];
    x[0][0] = 1.0; x[0][1] = 1.0;
    x[1][0] = 1.5; x[1][1] = 2.0;
    x[2][0] = 2.0; x[2][1] = 1.5;
    x[3][0] = 8.0; x[3][1] = 8.0;
    x[4][0] = 8.5; x[4][1] = 9.0;
    x[5][0] = 9.0; x[5][1] = 8.5;

    var y: int[] = alloc int[6];
    y[0] = 0; y[1] = 0; y[2] = 0;
    y[3] = 1; y[4] = 1; y[5] = 1;

    var model: RandomForest = RandomForest(10, 3);
    model.fit(x, y);

    var preds: int[] = model.predict(x);
    var i: int = 0;
    while (i < preds.length) {
        print(str(preds[i]), newLine=true);
        i++;
    };
    print("Accuracy: " + str(model.accuracy(x, y)), newLine=true);
    print("F1: " + str(model.f1(x, y)), newLine=true);  
};