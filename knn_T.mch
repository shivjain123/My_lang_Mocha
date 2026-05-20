from "mocha-forge" import *;
function test(didLoad){
    print("starting test", newLine=true);
    var x: float[][] = alloc float[6][2];
    x[0][0] = 1.0; x[0][1] = 2.0;
    x[1][0] = 1.5; x[1][1] = 1.8;
    x[2][0] = 2.0; x[2][1] = 2.5;
    x[3][0] = 7.0; x[3][1] = 8.0;
    x[4][0] = 8.0; x[4][1] = 7.5;
    x[5][0] = 7.5; x[5][1] = 8.5;

    var y: int[] = alloc int[6];
    y[0] = 0; y[1] = 0; y[2] = 0;
    y[3] = 1; y[4] = 1; y[5] = 1;

    var model: KNNClassifier = KNNClassifier(3);
    model.fit(x, y);
    var preds: int[] = model.predict(x);
    var i: int = 0;
    while (i < preds.length) {
        print(str(preds[i]), newLine=true);
        i++;
    };
    print("Accuracy: " + str(model.accuracy(x, y)), newLine=true);
    print("F1: " + str(model.f1(x, y)), newLine=true);

    var x_reg: float[][] = alloc float[5][1];
    x_reg[0][0] = 1.0; x_reg[1][0] = 2.0; x_reg[2][0] = 3.0;
    x_reg[3][0] = 4.0; x_reg[4][0] = 5.0;

    var y_reg: float[] = alloc float[5];
    y_reg[0] = 1.5; y_reg[1] = 3.0; y_reg[2] = 4.5;
    y_reg[3] = 6.0; y_reg[4] = 7.5;

    var reg_model: KNNClassifier = KNNClassifier(2);
    reg_model.fit_reg(x_reg, y_reg);
    var reg_preds: float[] = reg_model.predict_reg(x_reg);
    var ri: int = 0;
    while (ri < reg_preds.length) {
        print(str(reg_preds[ri]), newLine=true);
        ri++;
    };
};