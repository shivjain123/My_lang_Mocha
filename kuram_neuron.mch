"""
    kuramoto_mem.mch v0.1
    Oscillator memory: Kuramoto dynamics with Hopfield weights as the wiring
"""
from "mocha-math" import *;
from "mocha-neuron" import *;

// random pattern of +1 / -1
function make_pattern(n: int) -> float[] {
    var p: float[] = alloc float[n];
    var i: int = 0;
    while (i < n) {
        if (rand_int(0, 1) == 1) {
            p[i] = 1.0;
        } else {
            p[i] = 0.0 - 1.0;
        };
        i = i + 1;
    };
    return p;
};

// overlap of the phases with a stored pattern: 0 = unrelated, 1 = exact match
function overlap(p: float[], theta: float[], n: int) -> float {
    var sc: float = 0.0;
    var ss: float = 0.0;
    var i: int = 0;
    while (i < n) {
        sc = sc + p[i] * theta[i].cos(RAD);
        ss = ss + p[i] * theta[i].sin(RAD);
        i = i + 1;
    };
    return (sc * sc + ss * ss).sqrt().real / float(n);
};

// one Euler step; the Hopfield weights are the wiring, all natural speeds are 0
function step(theta: float[], h: Hopfield, n: int, k: float, dt: float) -> null {
    var s: Tensor = Tensor(1, n);
    var c: Tensor = Tensor(1, n);
    var i: int = 0;
    while (i < n) {
        s.put(0, i, theta[i].sin(RAD));
        c.put(0, i, theta[i].cos(RAD));
        i = i + 1;
    };

    var sw: Tensor = s.matmul(h.weights);
    var cw: Tensor = c.matmul(h.weights);

    i = 0;
    while (i < n) {
        var pull: float = c.at(0, i) * sw.at(0, i) - s.at(0, i) * cw.at(0, i);
        theta[i] = theta[i] + dt * (k * pull - 0.3 * (2.0 * theta[i]).sin(RAD));
        i = i + 1;
    };

    s.dispose();
    c.dispose();
    sw.dispose();
    cw.dispose();
};

function run(didLoad) -> null {
    var n: int = 64;
    var k: float = 4.0 / float(n);
    var dt: float = 0.1;
    var steps: int = 400;

    rand_seed(42);

    // store 3 random patterns
    var p0: float[] = make_pattern(n);
    var p1: float[] = make_pattern(n);
    var p2: float[] = make_pattern(n);
    var h: Hopfield = Hopfield(n);
    h.store_values(p0);
    h.store_values(p1);
    h.store_values(p2);
    h.normalize();

    // corrupt pattern 0: flip 12 of the 64 values
    var noisy: float[] = flip_bits(p0, 12);

    // value +1 -> phase 0, value -1 -> phase pi, plus a small random kick
    var theta: float[] = alloc float[n];
    var i: int = 0;
    while (i < n) {
        var base: float = 0.0;
        if (noisy[i] < 0.0) {
            base = PI;
        };
        theta[i] = base + rand_float(-0.3, 0.3);
        i = i + 1;
    };

    print("Oscillator memory: N = ", n, ", 3 patterns, 12 of 64 values corrupted", newLine=true);
    print("t = 0.0   pattern 0: ", overlap(p0, theta, n), "   pattern 1: ", overlap(p1, theta, n), "   pattern 2: ", overlap(p2, theta, n), newLine=true);

    var s: int = 0;
    while (s < steps) {
        step(theta, h, n, k, dt);
        s = s + 1;
        if (s % 40 == 0) {
            print("t = ", float(s) * dt, "   pattern 0: ", overlap(p0, theta, n), "   pattern 1: ", overlap(p1, theta, n), "   pattern 2: ", overlap(p2, theta, n), newLine=true);
        };
    };

    h.dispose();
};