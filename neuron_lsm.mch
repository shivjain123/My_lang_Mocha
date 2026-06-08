from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // LSM: input=1, reservoir=50, output=1, spectral_radius=0.9
    var lsm: Lsm = Lsm(1, 50, 1, 0.9);

    // generate sine wave: 200 timesteps
    var Ts: int = 200;
    var states: Tensor = Tensor(Ts, 50);
    var targets: Tensor = Tensor(Ts, 1);

    // run reservoir on sine wave, collect states
    var t: int = 0;
    while (t < Ts) {
        var angle: float = t * 0.1;
        var val: float = angle.sin();
        var next_angle: float = (t + 1) * 0.1;
        var next_val: float = next_angle.sin();

        var u: Tensor = Tensor(1, 1);
        u.put(0, 0, val);

        var out: Tensor = lsm.step(u);
        out.dispose();

        // collect state
        var cur_state: Tensor = lsm.state;
        var s: int = 0;
        while (s < 50) {
            var sv: float = cur_state.at(0, s);
            states.put(t, s, sv);
            s = s + 1;
        };

        // target is next value
        targets.put(t, 0, next_val);
        u.dispose();
        t = t + 1;
    };

    // train readout
    lsm.train(states, targets, 0.002);// last value is lambda
    print("Training done!", newLine=true);

    // test: run 20 more steps and compare prediction vs actual
    lsm.reset();
    print("Predictions vs actual:", newLine=true);
    print("\n");
    var t2: int = 0;
    while (t2 < 20) {
        var angle: float = t2 * 0.1;
        var val: float = angle.sin();
        var next_angle: float = (t2 + 1) * 0.1;
        var actual: float = next_angle.sin();

        var u: Tensor = Tensor(1, 1);
        u.put(0, 0, val);
        var pred: Tensor = lsm.step(u);
        var pred_val: float = pred.at(0, 0);

        print(" t=", t2, " pred=", pred_val, "; actual= ", actual, "\n");

        u.dispose();
        pred.dispose();
        t2 = t2 + 1;
    };

    states.dispose();
    targets.dispose();
    lsm.dispose();
};