from "mocha-forge" import *;

function main(didLoad) -> null {
    rand_seed(123);

    // 100 samples with noise
    var x: float[][] = alloc float[100][2];
    var y: int[] = alloc int[100];

    var i: int = 0;
    while (i < 100) {
        x[i][0] = rand_float(0.0, 10.0);
        x[i][1] = rand_float(0.0, 10.0);
        // harder nonlinear boundary + noise
        var signal: float = x[i][0] * x[i][0] + x[i][1] * x[i][1];
        var noise: float = rand_float(0.0 - 5.0, 5.0);
        if (signal + noise > 50.0) {
            y[i] = 1;
        };
        if (signal + noise <= 50.0) {
            y[i] = 0;
        };
        i++;
    };

    var split: TrainTestSplit = train_test_split(x, y, 0.25, 42);

    var gb: GradientBoosting = GradientBoosting(50, 3, 0.1, 0.8);
    gb.fit(split.x_train, split.y_train);

    print("=== Train ===", newLine=true);
    print("accuracy=" + str(gb.accuracy(split.x_train, split.y_train)), newLine=true);
    print("f1=" + str(gb.f1(split.x_train, split.y_train)), newLine=true);

    print("=== Test ===", newLine=true);
    print("accuracy=" + str(gb.accuracy(split.x_test, split.y_test)), newLine=true);
    print("f1=" + str(gb.f1(split.x_test, split.y_test)), newLine=true);
};