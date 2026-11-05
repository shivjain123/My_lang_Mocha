from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    var a: Lsm = Lsm(1, 50, 1, 0.9);

    var inputs: float[] = [];
    var targets: float[] = [];
    var t: int = 0;
    while (t < 200) {
        var ang: float = t * 0.1;
        inputs.push(ang.sin());
        var nang: float = (t + 1) * 0.1;
        targets.push(nang.sin());
        t = t + 1;
    };
    a.train_values(inputs, targets, 0.002);
    a.save("lsm_saveload_test.db");

    // different seed, so b's random weights differ until load overwrites them
    rand_seed(7);
    var b: Lsm = Lsm(1, 50, 1, 0.9);
    b.load("lsm_saveload_test.db");

    var maxd: float = 0.0;
    var t2: int = 200;
    while (t2 < 240) {
        var a2: float = t2 * 0.1;
        var pa: float[] = a.step_values([a2.sin()]);
        var pb: float[] = b.step_values([a2.sin()]);
        var d: float = pa[0] - pb[0];
        if (d < 0.0) {
            d = 0.0 - d;
        };
        if (d > maxd) {
            maxd = d;
        };
        t2 = t2 + 1;
    };
    print("max difference: ", maxd, newLine=true);

    a.dispose();
    b.dispose();
};