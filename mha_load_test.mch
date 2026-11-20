from "mocha-neuron" import *;

function sq_err(a: Tensor, b: Tensor) -> float {
    var total: float = 0.0;
    var i: int = 0;
    while (i < a.nrows) {
        var j: int = 0;
        while (j < a.ncols) {
            var d: float = a.at(i, j) - b.at(i, j);
            total = total + d * d;
            j = j + 1;
        };
        i = i + 1;
    };
    return total;
};

function main(didLoad) -> null {
    var x: Tensor = Tensor(3, 8);
    var target: Tensor = Tensor(3, 8);
    var i: int = 0;
    while (i < 3) {
        var j: int = 0;
        while (j < 8) {
            x.put(i, j, rand_float(-1.0, 1.0));
            target.put(i, j, rand_float(-1.0, 1.0));
            j = j + 1;
        };
        i = i + 1;
    };

    // 2 heads of size 4 (d_model 8)
    var layer: BertLayer = BertLayer(8, 4, 16);
    layer.use_heads(2);

    var first_err: float = 0.0;
    var last_err: float = 0.0;
    var step: int = 0;
    while (step < 300) {
        var out: Tensor = layer.forward(x);
        var err: float = sq_err(out, target);
        if (step == 0) { first_err = err; };
        last_err = err;

        var dout: Tensor = Tensor(3, 8);
        var r: int = 0;
        while (r < 3) {
            var c: int = 0;
            while (c < 8) {
                dout.put(r, c, out.at(r, c) - target.at(r, c));
                c = c + 1;
            };
            r = r + 1;
        };
        var dx: Tensor = layer.backward(dout, 0.01);
        dx.dispose();
        dout.dispose();
        out.dispose();
        step = step + 1;
    };
    print("2 heads: error first ", first_err, " last ", last_err, newLine=true);
    if (last_err < first_err) { print("PASS: multi-head layer learns", newLine=true); };
    if (last_err >= first_err) { print("FAIL: error did not drop", newLine=true); };

    // save, then load into a layer built with the default single head
    layer.save("mha_layer_test.db");
    var loaded: BertLayer = BertLayer(8, 4, 16);
    loaded.load("mha_layer_test.db");

    var oa: Tensor = layer.forward(x);
    var ob: Tensor = loaded.forward(x);
    var maxdiff: float = 0.0;
    var p: int = 0;
    while (p < 3) {
        var q: int = 0;
        while (q < 8) {
            var dd: float = abs(oa.at(p, q) - ob.at(p, q));
            if (dd > maxdiff) { maxdiff = dd; };
            q = q + 1;
        };
        p = p + 1;
    };
    print("save/load max difference: ", maxdiff, newLine=true);
    if (maxdiff < 0.001) { print("PASS: loaded layer matches", newLine=true); };
    if (maxdiff >= 0.001) { print("FAIL: loaded layer differs", newLine=true); };

    oa.dispose();
    ob.dispose();
    loaded.dispose();
    layer.dispose();
    x.dispose();
    target.dispose();
    print("dispose done", newLine=true);
};