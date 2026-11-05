from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    var rbm: Rbm = Rbm(6, 4);

    // 4 patterns, 6 values each, one after another
    var samples: float[] = [
        1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 1.0, 1.0,
        1.0, 0.0, 1.0, 0.0, 1.0, 0.0,
        0.0, 1.0, 0.0, 1.0, 0.0, 1.0
    ];

    // error before training
    var before: float = 0.0;
    var i: int = 0;
    while (i < 4) {
        var v: Tensor = Tensor(1, 6);
        var k: int = 0;
        while (k < 6) {
            v.put(0, k, samples[i * 6 + k]);
            k = k + 1;
        };
        before = before + rbm.reconstruction_error(v);
        v.dispose();
        i = i + 1;
    };
    print("error before: ", before / 4.0, newLine=true);

    rbm.train_values(samples, 500, 0.1);

    // save, load into a fresh Rbm, compare reconstructions
    rbm.save("rbm_test.db");
    var b: Rbm = Rbm(6, 4);
    b.load("rbm_test.db");

    var after: float = 0.0;
    var maxd: float = 0.0;
    var j: int = 0;
    while (j < 4) {
        var row: float[] = [];
        var m: int = 0;
        while (m < 6) {
            row.push(samples[j * 6 + m]);
            m = m + 1;
        };
        var ra: float[] = rbm.reconstruct_values(row);
        var rb: float[] = b.reconstruct_values(row);
        var q: int = 0;
        while (q < 6) {
            var d: float = ra[q] - rb[q];
            if (d < 0.0) {
                d = 0.0 - d;
            };
            if (d > maxd) {
                maxd = d;
            };
            var e: float = ra[q] - row[q];
            after = after + e * e;
            q = q + 1;
        };
        j = j + 1;
    };
    print("error after: ", after / 24.0, newLine=true);
    print("save/load max difference: ", maxd, newLine=true);

    rbm.dispose();
    b.dispose();
};