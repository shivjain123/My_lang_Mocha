"""
    kuramoto.mch v0.3
    Kuramoto model: sweep the coupling K and watch sync switch on
"""
"""from "mocha-math" import *;

// order parameter r: 0 = everyone out of step, 1 = perfect unison
function order_r(theta: float[], n: int) -> float {
    var sc: float = 0.0;
    var ss: float = 0.0;
    var i: int = 0;
    while (i < n) {
        sc = sc + theta[i].cos(RAD);
        ss = ss + theta[i].sin(RAD);
        i = i + 1;
    };
    var mc: float = sc / float(n);
    var ms: float = ss / float(n);
    return (mc * mc + ms * ms).sqrt().real;
};

// run one crowd for `steps` steps at coupling k, return the final r
function simulate(k: float, n: int, steps: int, dt: float) -> float {
    rand_seed(42);   // same crowd every time, so only K changes between runs

    var theta: float[] = alloc float[n];
    var omega: float[] = alloc float[n];

    var i: int = 0;
    while (i < n) {
        theta[i] = rand_float(0.0, TAU);
        omega[i] = rand_float(-1.0, 1.0);
        i = i + 1;
    };

    var s: int = 0;
    while (s < steps) {
        var c: float = 0.0;
        var sn: float = 0.0;
        var j: int = 0;
        while (j < n) {
            c = c + theta[j].cos(RAD);
            sn = sn + theta[j].sin(RAD);
            j = j + 1;
        };
        c = c / float(n);
        sn = sn / float(n);

        j = 0;
        while (j < n) {
            var pull: float = sn * theta[j].cos(RAD) - c * theta[j].sin(RAD);
            theta[j] = theta[j] + dt * (omega[j] + k * pull);
            j = j + 1;
        };
        s = s + 1;
    };
    return order_r(theta, n);
};

function run(didLoad) -> null {
    var n: int = 500;
    print("Kuramoto sweep (zoom): N = ", n, newLine=true);
    var ki: int = 0;
    while (ki <= 12) {
        var k: float = 1.0 + float(ki) * 0.05;
        print("K = ", k, "   r = ", simulate(k, n, 3000, 0.05), newLine=true);
        ki = ki + 1;
    };
};"""

"""
    kuramoto.mch v0.4
    Kuramoto model with mocha-ink graphs
"""
from "mocha-math" import *;
from "mocha-ink" import *;

// order parameter r: 0 = everyone out of step, 1 = perfect unison
function order_r(theta: float[], n: int) -> float {
    var sc: float = 0.0;
    var ss: float = 0.0;
    var i: int = 0;
    while (i < n) {
        sc = sc + theta[i].cos(RAD);
        ss = ss + theta[i].sin(RAD);
        i = i + 1;
    };
    var mc: float = sc / float(n);
    var ms: float = ss / float(n);
    return (mc * mc + ms * ms).sqrt().real;
};

// run one crowd for samples * every steps; record r at t = 0 and then every `every` steps
// returns samples + 1 values
function trace(k: float, n: int, samples: int, every: int, dt: float) -> float[] {
    rand_seed(42);   // same crowd every time, so only K changes between runs

    var out: float[] = alloc float[samples + 1];
    var theta: float[] = alloc float[n];
    var omega: float[] = alloc float[n];

    var i: int = 0;
    while (i < n) {
        theta[i] = rand_float(0.0, TAU);
        omega[i] = rand_float(-1.0, 1.0);
        i = i + 1;
    };
    out[0] = order_r(theta, n);

    var steps: int = samples * every;
    var s: int = 0;
    var m: int = 1;
    while (s < steps) {
        var c: float = 0.0;
        var sn: float = 0.0;
        var j: int = 0;
        while (j < n) {
            c = c + theta[j].cos(RAD);
            sn = sn + theta[j].sin(RAD);
            j = j + 1;
        };
        c = c / float(n);
        sn = sn / float(n);

        j = 0;
        while (j < n) {
            var pull: float = sn * theta[j].cos(RAD) - c * theta[j].sin(RAD);
            theta[j] = theta[j] + dt * (omega[j] + k * pull);
            j = j + 1;
        };

        s = s + 1;
        if (s % every == 0) {
            out[m] = order_r(theta, n);
            m = m + 1;
        };
    };
    return out;
};

// final r after `steps` steps
function final_r(k: float, n: int, steps: int, dt: float) -> float {
    var tr: float[] = trace(k, n, 1, steps, dt);
    return tr[1];
};

function run(didLoad) -> null {
    var n: int = 300;
    var dt: float = 0.05;

    // ---------- graph 1: r vs K ----------
    var points: int = 29;
    var ks: float[] = alloc float[points];
    var rs: float[] = alloc float[points];
    var i: int = 0;
    while (i < points) {
        ks[i] = 0.6 + float(i) * 0.05;
        rs[i] = final_r(ks[i], n, 2500, dt);
        i = i + 1;
    };

    var p: LinePlot = line(ks, rs);
    p.label("r(K), N = 300");
    p.title("Kuramoto: synchronisation vs coupling strength");
    p.xlabel("coupling K");
    p.ylabel("order parameter r");
    p.grid(true);
    p.add_scatter(ks, rs);
    p.label("one simulation per K");
    p.save("kuramoto_sweep.svg");
    p.dispose();

    // ---------- graph 2: r vs time for three K values ----------
    var samples: int = 100;
    var every: int = 25;
    var t: float[] = alloc float[samples + 1];
    var j: int = 0;
    while (j <= samples) {
        t[j] = float(j * every) * dt;
        j = j + 1;
    };

    var r_low: float[] = trace(0.8, n, samples, every, dt);
    var r_mid: float[] = trace(1.4, n, samples, every, dt);
    var r_high: float[] = trace(2.5, n, samples, every, dt);

    var q: LinePlot = line(t, r_low);
    q.label("K = 0.8");
    q.title("Kuramoto: r over time for K = 0.8, 1.4, 2.5");
    q.xlabel("time");
    q.ylabel("order parameter r");
    q.grid(true);
    q.add_line(t, r_mid);
    q.label("K = 1.4");
    q.add_line(t, r_high);
    q.label("K = 2.5");
    q.save("kuramoto_time.svg");

    print("Saved kuramoto_sweep.svg and kuramoto_time.svg", newLine=true);
};