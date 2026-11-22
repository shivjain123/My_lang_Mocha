from "mocha-forge" import *;

function total(a: float[][]) -> float {
    var s: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        s = s + a[i][0];
        i++;
    };
    return s;
};

function total_sq(a: float[][]) -> float {
    var s: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        s = s + a[i][0] * a[i][0];
        i++;
    };
    return s;
};

function paired(a: float[][], b: int[]) -> int {
    var ok: int = 1;
    var i: int = 0;
    while (i < a.length) {
        if (int(a[i][0]) != b[i]) { ok = 0; };
        i++;
    };
    return ok;
};

function same_rows(a: float[][], b: float[][]) -> int {
    var ok: int = 1;
    var i: int = 0;
    while (i < a.length) {
        if (a[i][0] != b[i][0]) { ok = 0; };
        i++;
    };
    return ok;
};

function main(didLoad) -> null {
    var x: float[][] = alloc float[20][1];
    var y: int[] = alloc int[20];
    var i: int = 0;
    while (i < 20) {
        x[i][0] = float(i);
        y[i] = i;
        i++;
    };

    var s1: TrainTestSplit = train_test_split(x, y, 0.25, 7);
    print(s1.n_train, newLine=true);
    print(s1.n_test, newLine=true);
    print(total(s1.x_train) + total(s1.x_test), newLine=true);
    print(total_sq(s1.x_train) + total_sq(s1.x_test), newLine=true);
    print(paired(s1.x_train, s1.y_train), newLine=true);
    print(paired(s1.x_test, s1.y_test), newLine=true);

    // same seed again: identical split
    var s2: TrainTestSplit = train_test_split(x, y, 0.25, 7);
    print(same_rows(s1.x_train, s2.x_train), newLine=true);

    // different seed: different split
    var s3: TrainTestSplit = train_test_split(x, y, 0.25, 8);
    var differs: int = 1 - same_rows(s1.x_train, s3.x_train);
    print(differs, newLine=true);

    // 4-fold cross validation
    var folds: TrainTestSplit[] = cross_val_split(x, y, 4, 7);
    print(folds.length, newLine=true);
    var all_ok: int = 1;
    var test_sum: float = 0.0;
    var test_count: int = 0;
    var f: int = 0;
    while (f < folds.length) {
        var fold: TrainTestSplit = folds[f];
        print(fold.n_test, newLine=true);
        if (total(fold.x_train) + total(fold.x_test) != 190.0) { all_ok = 0; };
        if (paired(fold.x_train, fold.y_train) == 0) { all_ok = 0; };
        if (paired(fold.x_test, fold.y_test) == 0) { all_ok = 0; };
        test_sum = test_sum + total(fold.x_test);
        test_count = test_count + fold.n_test;
        f++;
    };
    print(all_ok, newLine=true);
    print(test_sum, newLine=true);
    print(test_count, newLine=true);
};