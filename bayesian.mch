from "mocha-forge" import *;
function test_bayes(didLoad) -> null {
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

    print("--- KNN Bayesian Search ---", newLine=true);
    var bs: BayesianSearch = BayesianSearch(5, 10);
    bs.add_int_param("k", 1, 5);
    var result: SearchResult = bs.search_knn(x, y, folds);
    result.print_result();

    print("\n");

    print("--- DT Bayesian Search ---", newLine=true);
    var bs2: BayesianSearch = BayesianSearch(5, 10);
    bs2.add_int_param("max_depth", 1, 5);
    var result2: SearchResult = bs2.search_dt(x, y, folds);
    result2.print_result();

    print("\n");

    print("--- SVM Bayesian Search ---", newLine=true);
    var bs3: BayesianSearch = BayesianSearch(5, 10);
    bs3.add_float_param("lr", 0.001, 0.1);
    bs3.add_int_param("iterations", 100, 1000);
    var result3: SearchResult = bs3.search_svm(x, y, folds);
    result3.print_result();
};