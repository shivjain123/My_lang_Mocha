from "mocha-string" import *;
from "mocha-neuron" import *;

function make_seq(pix: float[], base: int) -> Tensor[] {
    var xs: Tensor[] = [];
    var t: int = 0;
    while (t < 8) {
        var x: Tensor = Tensor(1, 8);
        var c: int = 0;
        while (c < 8) {
            x.put(0, c, pix[base + t * 8 + c]);
            c++;
        };
        xs.push(x);
        t++;
    };
    return xs;
};

function free_seq(xs: Tensor[]) -> null {
    var i: int = 0;
    while (i < xs.length) {
        xs[i].dispose();
        i++;
    };
};

function predict_class(gru: Gru, head: Dense, pix: float[], base: int) -> int {
    var xs: Tensor[] = make_seq(pix, base);
    var h: Tensor = gru.forward_seq(xs);
    var pred: Tensor = head.forward(h);
    var best: int = 0;
    var best_v: float = pred.at(0, 0);
    var k: int = 1;
    while (k < 10) {
        var v: float = pred.at(0, k);
        if (v > best_v) {
            best_v = v;
            best = k;
        };
        k++;
    };
    pred.dispose();
    h.dispose();
    free_seq(xs);
    gru.clear_seq();
    return best;
};

function accuracy(gru: Gru, head: Dense, pix: float[], labs: int[]) -> float {
    var correct: int = 0;
    var i: int = 0;
    while (i < labs.length) {
        if (predict_class(gru, head, pix, i * 64) == labs[i]) {
            correct++;
        };
        i++;
    };
    return float(correct) / float(labs.length);
};

function main(didLoad) -> null {
    var r: File = open("digits.csv", "read");
    var train: float[] = [];
    var held: float[] = [];
    var tr_labs: int[] = [];
    var te_labs: int[] = [];
    var i: int = 0;
    while (!r.eof()) {
        var rec: str[] = r.readCsvRecord();
        if (rec.length == 65) {
            var is_test: bool = (i % 5 == 0);
            var want: bool = false;
            if (is_test && te_labs.length < 150) { want = true; };
            if (!is_test && tr_labs.length < 300) { want = true; };
            if (want) {
                var c: int = 0;
                while (c < 64) {
                    var px: float = float(rec[c].toInt()) / 16.0;
                    if (is_test) {
                        held.push(px);
                    } else {
                        train.push(px);
                    };
                    c++;
                };
                if (is_test) {
                    te_labs.push(rec[64].toInt());
                } else {
                    tr_labs.push(rec[64].toInt());
                };
            };
            i++;
        };
    };
    r.close();
    var n_tr: int = tr_labs.length;
    print("rows seen ", i, " train samples ", n_tr, " held-out samples ", te_labs.length, newLine=true);

    var gru: Gru = Gru(8, 16);
    var head: Dense = Dense(16, 10, Activation.SOFTMAX);
    var lr: float = 0.01;

    var epoch: int = 0;
    while (epoch < 10) {
        var online_correct: int = 0;
        var s: int = 0;
        while (s < n_tr) {
            var k: int = (s * 7 + epoch * 13) % n_tr;
            var label: int = tr_labs[k];
            var xs: Tensor[] = make_seq(train, k * 64);
            var h_last: Tensor = gru.forward_seq(xs);
            var pred: Tensor = head.forward(h_last);

            var best: int = 0;
            var best_v: float = pred.at(0, 0);
            var q: int = 1;
            while (q < 10) {
                var pv: float = pred.at(0, q);
                if (pv > best_v) {
                    best_v = pv;
                    best = q;
                };
                q++;
            };
            if (best == label) {
                online_correct++;
            };

            // softmax + cross-entropy gradient: pred - onehot(label)
            var dout: Tensor = Tensor(1, 10);
            var m: int = 0;
            while (m < 10) {
                var tv: float = 0.0;
                if (m == label) {
                    tv = 1.0;
                };
                dout.put(0, m, pred.at(0, m) - tv);
                m++;
            };
            var dh: Tensor = head.backward(dout, lr);
            dout.dispose();
            var dX: Tensor = Tensor(8, 8);
            dX.zeros();
            gru.backward_seq(dh, dX, lr);
            dh.dispose();
            dX.dispose();
            pred.dispose();
            h_last.dispose();
            free_seq(xs);
            s++;
        };
        print("epoch ", epoch, " online accuracy ", float(online_correct) / float(n_tr), newLine=true);
        epoch++;
    };

    var train_acc: float = accuracy(gru, head, train, tr_labs);
    var test_acc: float = accuracy(gru, head, held, te_labs);
    print("train accuracy ", train_acc, " held-out accuracy ", test_acc, newLine=true);

    if (train_acc >= 0.85) { print("PASS train accuracy at least 0.85", newLine=true); } else { print("FAIL train accuracy", newLine=true); };
    if (test_acc >= 0.7) { print("PASS held-out accuracy at least 0.7", newLine=true); } else { print("FAIL held-out accuracy", newLine=true); };

    gru.dispose();
    head.dispose();
};