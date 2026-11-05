from "mocha-neuron" import *;

function make_seq(a: float, b: float, c: float) -> Tensor[] {
    var xs: Tensor[] = [];
    var t0: Tensor = Tensor(1, 1); t0.put(0, 0, a);
    var t1: Tensor = Tensor(1, 1); t1.put(0, 0, b);
    var t2: Tensor = Tensor(1, 1); t2.put(0, 0, c);
    xs.push(t0);
    xs.push(t1);
    xs.push(t2);
    return xs;
};

function free_one(t: Tensor) -> null {
    t.dispose();
};

function free_seq(xs: Tensor[]) -> null {
    var i: int = 0;
    while (i < xs.length) {
        free_one(xs[i]);
        i++;
    };
};

function xor_bit(x: float, y: float) -> float {
    if (x != y) {
        return 1.0;
    };
    return 0.0;
};

function hit(p: float, t: float) -> int {
    if (t == 1.0) {
        if (p > 0.5) { return 1; };
        return 0;
    };
    if (p < 0.5) { return 1; };
    return 0;
};

function main(didLoad) -> null {
    rand_seed(42);
    var gru: Gru = Gru(1, 8);
    var head: Dense = Dense(8, 1, Activation.SIGMOID);
    var lr: float = 0.01;

    var a: float[] = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
    var b: float[] = [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0];
    var c: float[] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0];

    var epoch: int = 0;
    while (epoch < 2000) {
        var total: float = 0.0;
        var i: int = 0;
        while (i < 8) {
            var xs: Tensor[] = make_seq(a[i], b[i], c[i]);
            var hs: Tensor = gru.forward_all(xs);
            var pred: Tensor = head.forward(hs);

            if (epoch == 0) {
                if (i == 0) {
                    print("shapes: hs ", hs.nrows, "x", hs.ncols, ", pred ", pred.nrows, "x", pred.ncols, "\n");
                };
            };

            var y1: float = a[i];
            var y2: float = xor_bit(y1, b[i]);
            var y3: float = xor_bit(y2, c[i]);
            var label: Tensor = Tensor(3, 1);
            label.put(0, 0, y1);
            label.put(1, 0, y2);
            label.put(2, 0, y3);

            var loss: float = mocha_tensor_mse_loss(pred.ptr, label.ptr);
            total = total + loss;

            var dout: Tensor = Tensor(3, 1);
            mocha_tensor_free(dout.ptr);
            dout.ptr = mocha_tensor_mse_grad(pred.ptr, label.ptr);
            var dh: Tensor = head.backward(dout, lr);
            dout.dispose();

            var dX: Tensor = Tensor(3, 1);
            dX.zeros();
            gru.backward_steps(dh, dX, lr);

            dX.dispose();
            dh.dispose();
            pred.dispose();
            label.dispose();
            hs.dispose();
            free_seq(xs);
            i++;
        };
        if (epoch % 400 == 0) {
            print("Epoch ", epoch, " loss: ", total / 8.0, "\n");
        };
        epoch++;
    };

    var correct: int = 0;
    var k: int = 0;
    while (k < 8) {
        var txs: Tensor[] = make_seq(a[k], b[k], c[k]);
        var ths: Tensor = gru.forward_all(txs);
        var tp: Tensor = head.forward(ths);
        var t1: float = a[k];
        var t2: float = xor_bit(t1, b[k]);
        var t3: float = xor_bit(t2, c[k]);
        var p1: float = tp.at(0, 0);
        var p2: float = tp.at(1, 0);
        var p3: float = tp.at(2, 0);
        correct = correct + hit(p1, t1) + hit(p2, t2) + hit(p3, t3);
        print(a[k], " ", b[k], " ", c[k], " -> ", p1, " ", p2, " ", p3, "  (targets ", t1, " ", t2, " ", t3, ")\n");
        tp.dispose();
        ths.dispose();
        free_seq(txs);
        k++;
    };
    print("Correct: ", correct, " / 24\n");

    gru.clear_seq();
    gru.dispose();
    head.dispose();
};