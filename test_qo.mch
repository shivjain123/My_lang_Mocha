from "mocha-neuron" import *;

function accuracy(net: Network, x: Tensor, ls: int[]) -> float {
    var out: Tensor = net.predict(x);
    var correct: int = 0;
    var p: int = 0;
    while (p < ls.length) {
        var best: int = 0;
        var best_v: float = out.at(p, 0);
        var k: int = 1;
        while (k < 10) {
            var v: float = out.at(p, k);
            if (v > best_v) {
                best_v = v;
                best = k;
            };
            k++;
        };
        if (best == ls[p]) {
            correct++;
        };
        p++;
    };
    out.dispose();
    return float(correct) / float(ls.length);
};

function main(didLoad) -> null {
    var r: File = open("digits.csv", "read");
    var feats: float[] = [];
    var labs: int[] = [];
    while (!r.eof()) {
        var rec: str[] = r.readCsvRecord();
        if (rec.length == 65) {
            var c: int = 0;
            while (c < 64) {
                feats.push(float(rec[c].toInt()) / 16.0);
                c++;
            };
            labs.push(rec[64].toInt());
        };
    };
    r.close();

    var n: int = labs.length;
    print("rows read ", n, newLine=true);

    // every 5th row is test, the rest is train
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

    var xtr: Tensor = Tensor(n_train, 64);
    var ytr: Tensor = Tensor(n_train, 10);
    ytr.zeros();
    var xte: Tensor = Tensor(n_test, 64);
    var tr_labs: int[] = [];
    var te_labs: int[] = [];
    var itr: int = 0;
    var ite: int = 0;
    var i: int = 0;
    while (i < n) {
        var j: int = 0;
        if (i % 5 == 0) {
            while (j < 64) {
                xte.put(ite, j, feats[i * 64 + j]);
                j++;
            };
            te_labs.push(labs[i]);
            ite++;
        } else {
            while (j < 64) {
                xtr.put(itr, j, feats[i * 64 + j]);
                j++;
            };
            ytr.put(itr, labs[i], 1.0);
            tr_labs.push(labs[i]);
            itr++;
        };
        i++;
    };

    var net: Network = Network();
    net.add(Dense(64, 32, Activation.RELU));
    net.add(Dense(32, 10, Activation.SOFTMAX));

    var first_loss: float = 0.0;
    var last_loss: float = 0.0;
    var epoch: int = 0;
    while (epoch < 300) {
        var loss: float = net.fit_step(xtr, ytr, 0.01, "crossentropy");
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

    var train_acc: float = accuracy(net, xtr, tr_labs);
    var test_acc: float = accuracy(net, xte, te_labs);
    print("train accuracy ", train_acc, " test accuracy ", test_acc, newLine=true);

    if (first_loss > 1.5 && first_loss < 3.5) { print("PASS first loss plausible", newLine=true); } else { print("FAIL first loss", newLine=true); };
    if (last_loss < 0.05) { print("PASS last loss below 0.05", newLine=true); } else { print("FAIL last loss", newLine=true); };
    if (train_acc >= 0.99) { print("PASS train accuracy at least 0.99", newLine=true); } else { print("FAIL train accuracy", newLine=true); };
    if (test_acc >= 0.94) { print("PASS test accuracy at least 0.94", newLine=true); } else { print("FAIL test accuracy", newLine=true); };

    net.dispose();
    xtr.dispose();
    ytr.dispose();
    xte.dispose();
};