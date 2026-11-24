from "mocha-string" import *;
from "mocha-neuron" import *;

function build_input(pix: float[], base: int) -> Tensor {
    var x: Tensor = Tensor(8, 8);
    var t: int = 0;
    while (t < 8) {
        var c: int = 0;
        while (c < 8) {
            x.put(t, c, pix[base + t * 8 + c]);
            c++;
        };
        t++;
    };
    return x;
};

// mean over the 8 rows, one [1 x 8] tensor
function pool_rows(t: Tensor) -> Tensor {
    var p: Tensor = Tensor(1, 8);
    var c: int = 0;
    while (c < 8) {
        var sum: float = 0.0;
        var r: int = 0;
        while (r < 8) {
            sum = sum + t.at(r, c);
            r++;
        };
        p.put(0, c, sum / 8.0);
        c++;
    };
    return p;
};

function predict_class(bert: BertLayer, pe: PositionalEncoding, head: Dense, pix: float[], base: int) -> int {
    var raw: Tensor = build_input(pix, base);
    var enc: Tensor = pe.encode(raw);
    raw.dispose();
    var out: Tensor = bert.forward(enc);
    var pooled: Tensor = pool_rows(out);
    out.dispose();
    var pred: Tensor = head.forward(pooled);
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
    pooled.dispose();
    enc.dispose();
    return best;
};

function accuracy(bert: BertLayer, pe: PositionalEncoding, head: Dense, pix: float[], labs: int[]) -> float {
    var correct: int = 0;
    var i: int = 0;
    while (i < labs.length) {
        if (predict_class(bert, pe, head, pix, i * 64) == labs[i]) {
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

    var pe: PositionalEncoding = PositionalEncoding(8, 8);
    var bert: BertLayer = BertLayer(8, 4, 16);
    bert.use_heads(2);
    var head: Dense = Dense(8, 10, Activation.SOFTMAX);
    var lr: float = 0.003;

    var epoch: int = 0;
    while (epoch < 20) {
        var online_correct: int = 0;
        var s: int = 0;
        while (s < n_tr) {
            var k: int = (s * 7 + epoch * 13) % n_tr;
            var label: int = tr_labs[k];

            var raw: Tensor = build_input(train, k * 64);
            var enc: Tensor = pe.encode(raw);
            raw.dispose();
            var out: Tensor = bert.forward(enc);
            var pooled: Tensor = pool_rows(out);
            out.dispose();
            var pred: Tensor = head.forward(pooled);

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
            var dpool: Tensor = head.backward(dout, lr);
            dout.dispose();

            // every row of the sequence gets dpool / 8
            var dseq: Tensor = Tensor(8, 8);
            var rr: int = 0;
            while (rr < 8) {
                var cc: int = 0;
                while (cc < 8) {
                    dseq.put(rr, cc, dpool.at(0, cc) / 8.0);
                    cc++;
                };
                rr++;
            };
            var dx: Tensor = bert.backward(dseq, lr);

            dx.dispose();
            dseq.dispose();
            dpool.dispose();
            pred.dispose();
            pooled.dispose();
            enc.dispose();
            s++;
        };
        print("epoch ", epoch, " online accuracy ", float(online_correct) / float(n_tr), newLine=true);
        epoch++;
    };

    var train_acc: float = accuracy(bert, pe, head, train, tr_labs);
    var test_acc: float = accuracy(bert, pe, head, held, te_labs);
    print("train accuracy ", train_acc, " held-out accuracy ", test_acc, newLine=true);

    if (train_acc >= 0.8) { print("PASS train accuracy at least 0.8", newLine=true); } else { print("FAIL train accuracy", newLine=true); };
    if (test_acc >= 0.6) { print("PASS held-out accuracy at least 0.6", newLine=true); } else { print("FAIL held-out accuracy", newLine=true); };

    bert.dispose();
    head.dispose();
    pe.dispose();
};