from "mocha-forge" import *;

"""function test(didLoad) -> null {
    var x: float[][] = alloc float[10][2];
    x[0][0] = 1.0; x[0][1] = 1.0;
    x[1][0] = 2.0; x[1][1] = 2.0;
    x[2][0] = 3.0; x[2][1] = 3.0;
    x[3][0] = 4.0; x[3][1] = 4.0;
    x[4][0] = 5.0; x[4][1] = 5.0;
    x[5][0] = 6.0; x[5][1] = 6.0;
    x[6][0] = 7.0; x[6][1] = 7.0;
    x[7][0] = 8.0; x[7][1] = 8.0;
    x[8][0] = 9.0; x[8][1] = 9.0;
    x[9][0] = 10.0; x[9][1] = 10.0;

    var y: int[] = alloc int[10];
    y[0]=0; y[1]=0; y[2]=0; y[3]=0; y[4]=0;
    y[5]=1; y[6]=1; y[7]=1; y[8]=1; y[9]=1;

    var split: TrainTestSplit = train_test_split(x, y, 0.2, 42);

    print("n_train: " + str(split.n_train), newLine=true);
    print("n_test: " + str(split.n_test), newLine=true);

    print("y_train:", newLine=true);
    var i: int = 0;
    while (i < split.n_train) {
        print(str(split.y_train[i]), newLine=true);
        i++;
    };

    print("y_test:", newLine=true);
    var j: int = 0;
    while (j < split.n_test) {
        print(str(split.y_test[j]), newLine=true);
        j++;
    };
};"""

"""function abd(didLoad){
    var y_true: int[] = alloc int[6];
    y_true[0]=0; y_true[1]=0; y_true[2]=0;
    y_true[3]=1; y_true[4]=1; y_true[5]=1;

    var y_pred: int[] = alloc int[6];
    y_pred[0]=0; y_pred[1]=0; y_pred[2]=1;  // one wrong
    y_pred[3]=1; y_pred[4]=1; y_pred[5]=1;  // all right

    var cm: ConfusionMatrix = confusion_matrix(y_true, y_pred);
    cm.print_matrix();  
};"""

"""function encoding(didLoad){
    // OrdinalEncoder
    var ord_enc: OrdinalEncoder = OrdinalEncoder();
    var data: str[] = ["high", "low", "medium", "high", "low"];
    var order: str[] = ["low", "medium", "high"];
    ord_enc.fit(data, order);
    var encoded_ord: int[] = ord_enc.transform(data);
    var i: int = 0;
    while (i < encoded_ord.length) {
        print(str(encoded_ord[i]), newLine=true);
        i++;
    };
    var decoded_ord: str[] = ord_enc.inverse_transform(encoded_ord);
    var j: int = 0;
    while (j < decoded_ord.length) {
        print(decoded_ord[j], newLine=true);
        j++;
    };

    // TargetEncoder
    var tgt_enc: TargetEncoder = TargetEncoder();
    var labels: str[] = ["cat", "dog", "cat", "bird", "dog"];
    tgt_enc.fit(labels);
    var encoded_tgt: int[] = tgt_enc.transform(labels);
    var k: int = 0;
    while (k < encoded_tgt.length) {
        print(str(encoded_tgt[k]), newLine=true);
        k++;
    };
    var decoded_tgt: str[] = tgt_enc.inverse_transform(encoded_tgt);
    var l: int = 0;
    while (l < decoded_tgt.length) {
        print(decoded_tgt[l], newLine=true);
        l++;
    };
};"""

"""function test_cv(didLoad) -> null {
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

    var folds: TrainTestSplit[] = cross_val_split(x, y, 3, 42);

    var scores: float[] = alloc float[3];
    var i: int = 0;
    while (i < 3) {
        var fold: TrainTestSplit = folds[i];
        var model: KNNClassifier = KNNClassifier(1);
        model.fit(fold.x_train, fold.y_train);
        scores[i] = model.accuracy(fold.x_test, fold.y_test);
        print("Fold " + str(i) + " accuracy: " + str(scores[i]), newLine=true);
        i++;
    };

    var avg: float = 0.0;
    var j: int = 0;
    while (j < 3) {
        avg = avg + scores[j];
        j++;
    };
    avg = avg / 3.0;
    print("Mean CV accuracy: " + str(avg), newLine=true);
};"""

function test_poly(didLoad) -> null {
    // simple 2-feature data
    var x: float[][] = alloc float[4][2];
    x[0][0] = 1.0; x[0][1] = 2.0;
    x[1][0] = 2.0; x[1][1] = 3.0;
    x[2][0] = 3.0; x[2][1] = 4.0;
    x[3][0] = 4.0; x[3][1] = 5.0;

    // degree 2 normal
    var pf: PolynomialFeatures = PolynomialFeatures(2);
    var x_poly: float[][] = pf.fit_transform(x);

    print("n_output_features: " + str(pf.n_output_features), newLine=true);
    print("Expected: 5 (x0, x1, x0^2, x0*x1, x1^2)", newLine=true);

    // print first row to verify
    print("Row 0: ", newLine=false);
    var fi: int = 0;
    while (fi < pf.n_output_features) {
        print(str(x_poly[0][fi]) + " ", newLine=false);
        fi++;
    };
    print("", newLine=true);
    print("Expected: 1 2 1 2 4", newLine=true);

    // degree 2 interaction only
    var pf2: PolynomialFeatures = PolynomialFeatures(2);
    pf2.inter_only();
    var x_poly2: float[][] = pf2.fit_transform(x);

    print("inter_only n_output_features: " + str(pf2.n_output_features), newLine=true);
    print("Expected: 3 (x0, x1, x0*x1)", newLine=true);

    print("Row 0: ", newLine=false);
    var fi2: int = 0;
    while (fi2 < pf2.n_output_features) {
        print(str(x_poly2[0][fi2]) + " ", newLine=false);
        fi2++;
    };
    print("", newLine=true);
    print("Expected: 1 2 2", newLine=true);
};