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

function cell(t: Tensor, r: int, c: int) -> float {
    return t.at(r, c);
};

function row_of(t: Tensor, r: int) -> Tensor {
    return t.get_row(r);
};

function hit(p: float, t: float) -> int {
    if (t == 1.0) {
        if (p > 0.5) { return 1; };
        return 0;
    };
    if (p < 0.5) { return 1; };
    return 0;
};

function stack_outs(outs: Tensor[]) -> Tensor {
    var s: Tensor = Tensor(outs.length, 8);
    var r: int = 0;
    while (r < outs.length) {
        var c: int = 0;
        while (c < 8) {
            s.put(r, c, cell(outs[r], 0, c));
            c++;
        };
        r++;
    };
    return s;
};

function main(didLoad) -> null {
    rand_seed(42);
    var bi: BiGru = BiGru(1, 4);
    var head: Dense = Dense(8, 1, Activation.SIGMOID);
    var lr: float = 0.01;

    var a: float[] = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
    var b: float[] = [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0];
    var c: float[] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0];

    var epoch: int = 0;
    while (epoch < 600) {
        var total: float = 0.0;
        var i: int = 0;
        while (i < 8) {
            var xs: Tensor[] = make_seq(a[i], b[i], c[i]);
            var outs: Tensor[] = bi.forward(xs);
            var stack: Tensor = stack_outs(outs);
            var pred: Tensor = head.forward(stack);

            // targets: step 1 = second input, step 2 = third input, step 3 = first input
            var label: Tensor = Tensor(3, 1);
            label.put(0, 0, b[i]);
            label.put(1, 0, c[i]);
            label.put(2, 0, a[i]);

            var loss: float = mocha_tensor_mse_loss(pred.ptr, label.ptr);
            total = total + loss;

            var dout: Tensor = Tensor(3, 1);
            mocha_tensor_free(dout.ptr);
            dout.ptr = mocha_tensor_mse_grad(pred.ptr, label.ptr);
            var dh: Tensor = head.backward(dout, lr);
            dout.dispose();

            var douts: Tensor[] = [];
            var r: int = 0;
            while (r < 3) {
                douts.push(row_of(dh, r));
                r++;
            };
            var dxs: Tensor[] = bi.backward(douts, lr);

            free_seq(dxs);
            free_seq(douts);
            free_seq(outs);
            free_seq(xs);
            dh.dispose();
            pred.dispose();
            label.dispose();
            stack.dispose();
            i++;
        };
        if (epoch % 100 == 0) {
            print("Epoch ", epoch, " loss: ", total / 8.0, "\n");
        };
        epoch++;
    };

    var correct: int = 0;
    var k: int = 0;
    while (k < 8) {
        var txs: Tensor[] = make_seq(a[k], b[k], c[k]);
        var touts: Tensor[] = bi.forward(txs);
        var tstack: Tensor = stack_outs(touts);
        var tp: Tensor = head.forward(tstack);
        var p1: float = cell(tp, 0, 0);
        var p2: float = cell(tp, 1, 0);
        var p3: float = cell(tp, 2, 0);
        correct = correct + hit(p1, b[k]) + hit(p2, c[k]) + hit(p3, a[k]);
        print(a[k], " ", b[k], " ", c[k], " -> ", p1, " ", p2, " ", p3, "  (targets ", b[k], " ", c[k], " ", a[k], ")\n");
        tp.dispose();
        tstack.dispose();
        free_seq(touts);
        free_seq(txs);
        k++;
    };
    print("Correct: ", correct, " / 24\n");

    bi.dispose();
    head.dispose();
};