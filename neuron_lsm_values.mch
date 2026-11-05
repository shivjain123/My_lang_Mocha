from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    var lsm: Lsm = Lsm(1, 50, 1, 0.9);

    // same sine run as neuron_lsm.mch: 200 inputs, target is the next value
    var inputs: float[] = [];
    var targets: float[] = [];
    var t: int = 0;
    while (t < 200) {
        var angle: float = t * 0.1;
        inputs.push(angle.sin());
        var next_angle: float = (t + 1) * 0.1;
        targets.push(next_angle.sin());
        t = t + 1;
    };

    lsm.train_values(inputs, targets, 0.002);
    print("Training done!", newLine=true);

    print("Predictions vs actual:", newLine=true);
    print("\n");
    var t2: int = 200;
    while (t2 < 240) {
        var a2: float = t2 * 0.1;
        var res: float[] = lsm.step_values([a2.sin()]);
        var na2: float = (t2 + 1) * 0.1;
        print(" t=", t2, " pred=", res[0], "; actual= ", na2.sin(), "\n");
        t2 = t2 + 1;
    };

    lsm.dispose();
};