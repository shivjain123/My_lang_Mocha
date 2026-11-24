from "mocha-string" import *;
from "mocha-neuron" import *;

function mse_of(net: Network, x: Tensor, ys: float[]) -> float {
    var out: Tensor = net.predict(x);
    var sum: float = 0.0;
    var p: int = 0;
    while (p < ys.length) {
        var diff: float = out.at(p, 0) - ys[p];
        sum = sum + diff * diff;
        p++;
    };
    out.dispose();
    return sum / float(ys.length);
};

function main(didLoad) -> null {
    var r: File = open("diabetes.csv", "read");
    var raw: float[] = [];
    var n: int = 0;
    while (!r.eof()) {
        var rec: str[] = r.readCsvRecord();
        if (rec.length == 11) {
            var c: int = 0;
            while (c < 11) {
                raw.push(rec[c].toFloat());
                c++;
            };
            n++;
        };
    };
    r.close();
    print("rows read ", n, newLine=true);

    // standardize all 11 columns (10 features + target), population std
    var means: float[] = [];
    var stds: float[] = [];
    var col: int = 0;
    while (col < 11) {
        var s: float = 0.0;
        var a: int = 0;
        while (a < n) {
            s = s + raw[a * 11 + col];
            a++;
        };
        var mu: float = s / float(n);
        var ss: float = 0.0;
        var b: int = 0;
        while (b < n) {
            var dv: float = raw[b * 11 + col] - mu;
            ss = ss + dv * dv;
            b++;
        };
        var vr: float = ss / float(n);
        var sd: float = (vr.sqrt()).real;
        means.push(mu);
        stds.push(sd);
        col++;
    };
    print("target mean ", means[10], " target std ", stds[10], newLine=true);

    var n_test: int = 0;
    var q: int = 0;
    while (q < n) {
        if (q % 5 == 0) {
            n_test++;
        };
        q++;
    };
    var n_train: int = n - n_test;
    print("train ", n_train, " test ", n_test, newLine=true);

    var xtr: Tensor = Tensor(n_train, 10);
    var ytr: Tensor = Tensor(n_train, 1);
    var xte: Tensor = Tensor(n_test, 10);
    var tr_y: float[] = [];
    var te_y: float[] = [];
    var itr: int = 0;
    var ite: int = 0;
    var i: int = 0;
    while (i < n) {
        var yv: float = (raw[i * 11 + 10] - means[10]) / stds[10];
        var j: int = 0;
        if (i % 5 == 0) {
            while (j < 10) {
                xte.put(ite, j, (raw[i * 11 + j] - means[j]) / stds[j]);
                j++;
            };
            te_y.push(yv);
            ite++;
        } else {
            while (j < 10) {
                xtr.put(itr, j, (raw[i * 11 + j] - means[j]) / stds[j]);
                j++;
            };
            ytr.put(itr, 0, yv);
            tr_y.push(yv);
            itr++;
        };
        i++;
    };

    // baseline: always predict the mean (0 after standardizing)
    var base_sum: float = 0.0;
    var z: int = 0;
    while (z < te_y.length) {
        base_sum = base_sum + te_y[z] * te_y[z];
        z++;
    };
    var baseline: float = base_sum / float(te_y.length);
    print("baseline test mse (predict the mean) ", baseline, newLine=true);

    var net: Network = Network();
    net.add(Dense(10, 16, Activation.RELU));
    net.add(Dense(16, 1, Activation.NONE));

    var first_loss: float = 0.0;
    var last_loss: float = 0.0;
    var epoch: int = 0;
    while (epoch < 200) {
        var loss: float = net.fit_step(xtr, ytr, 0.01, "mse");
        if (epoch == 0) {
            first_loss = loss;
        };
        last_loss = loss;
        if (epoch % 100 == 0) {
            print("epoch ", epoch, " loss ", loss, newLine=true);
        };
        epoch++;
    };
    print("first loss ", first_loss, " last loss ", last_loss, newLine=true);

    var train_mse: float = mse_of(net, xtr, tr_y);
    var test_mse: float = mse_of(net, xte, te_y);
    print("train mse ", train_mse, " test mse ", test_mse, newLine=true);

    if (first_loss > 0.7 && first_loss < 3.0) { print("PASS first loss plausible", newLine=true); } else { print("FAIL first loss", newLine=true); };
    if (last_loss < first_loss * 0.5) { print("PASS loss at least halved", newLine=true); } else { print("FAIL loss did not halve", newLine=true); };
    if (train_mse < 0.5) { print("PASS train mse below 0.5", newLine=true); } else { print("FAIL train mse", newLine=true); };
    if (test_mse < baseline) { print("PASS test mse beats the mean predictor", newLine=true); } else { print("FAIL test mse", newLine=true); };

    net.dispose();
    xtr.dispose();
    ytr.dispose();
    xte.dispose();
};