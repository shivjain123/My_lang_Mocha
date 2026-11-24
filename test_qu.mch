from "mocha-string" import *;
from "mocha-neuron" import *;

function binarize_row(rec: str[]) -> float[] {
    var p: float[] = [];
    var c: int = 0;
    while (c < 64) {
        if (rec[c].toInt() >= 8) {
            p.push(1.0);
        } else {
            p.push(0.0 - 1.0);
        };
        c++;
    };
    return p;
};

function get_pat(flat: float[], idx: int) -> float[] {
    var p: float[] = [];
    var c: int = 0;
    while (c < 64) {
        p.push(flat[idx * 64 + c]);
        c++;
    };
    return p;
};

function same(a: float[], b: float[]) -> bool {
    var j: int = 0;
    while (j < 64) {
        if (a[j] != b[j]) {
            return false;
        };
        j++;
    };
    return true;
};

// fraction of exact recoveries over n_pat patterns x trials noisy copies
// mode 0 = synchronous recall_values, mode 1 = recall_async
function rate(h: Hopfield, flat: float[], n_pat: int, k: int, trials: int, mode: int) -> float {
    var ok: int = 0;
    var total: int = 0;
    var pi: int = 0;
    while (pi < n_pat) {
        var pat: float[] = get_pat(flat, pi);
        var t: int = 0;
        while (t < trials) {
            var noisy: float[] = flip_bits(pat, k);
            var recovered: bool = false;
            if (mode == 0) {
                var res: float[] = h.recall_values(noisy, 20);
                recovered = same(res, pat);
            } else {
                var inp: Tensor = Tensor(1, 64);
                var j: int = 0;
                while (j < 64) {
                    inp.put(0, j, noisy[j]);
                    j++;
                };
                var out: Tensor = h.recall_async(inp, 20);
                var good: bool = true;
                var m: int = 0;
                while (m < 64) {
                    if (out.at(0, m) != pat[m]) {
                        good = false;
                    };
                    m++;
                };
                recovered = good;
                inp.dispose();
                out.dispose();
            };
            if (recovered) {
                ok++;
            };
            total++;
            t++;
        };
        pi++;
    };
    return float(ok) / float(total);
};

function main(didLoad) -> null {
    var r: File = open("digits.csv", "read");
    var p0: float[] = [];
    var p1: float[] = [];
    var p7: float[] = [];
    while (!r.eof()) {
        var rec: str[] = r.readCsvRecord();
        if (rec.length == 65) {
            var lab: int = rec[64].toInt();
            if (lab == 0 && p0.length == 0) { p0 = binarize_row(rec); };
            if (lab == 1 && p1.length == 0) { p1 = binarize_row(rec); };
            if (lab == 7 && p7.length == 0) { p7 = binarize_row(rec); };
        };
    };
    r.close();
    print("pattern lengths ", p0.length, " ", p1.length, " ", p7.length, newLine=true);

    var flat2: float[] = [];
    var flat3: float[] = [];
    var c: int = 0;
    while (c < 64) {
        flat2.push(p0[c]);
        flat3.push(p0[c]);
        c++;
    };
    c = 0;
    while (c < 64) {
        flat2.push(p1[c]);
        flat3.push(p1[c]);
        c++;
    };
    c = 0;
    while (c < 64) {
        flat3.push(p7[c]);
        c++;
    };

    var ha: Hopfield = Hopfield(64);
    ha.store_values(p0);
    ha.store_values(p1);
    ha.normalize();

    var hb: Hopfield = Hopfield(64);
    hb.store_values(p0);
    hb.store_values(p1);
    hb.store_values(p7);
    hb.normalize();

    // stage A: 2 patterns, 25 trials per pattern
    var a0s: float = rate(ha, flat2, 2, 0, 1, 0);
    var a0a: float = rate(ha, flat2, 2, 0, 1, 1);
    var a4s: float = rate(ha, flat2, 2, 4, 25, 0);
    var a4a: float = rate(ha, flat2, 2, 4, 25, 1);
    var a8s: float = rate(ha, flat2, 2, 8, 25, 0);
    var a8a: float = rate(ha, flat2, 2, 8, 25, 1);
    var a12s: float = rate(ha, flat2, 2, 12, 25, 0);
    var a12a: float = rate(ha, flat2, 2, 12, 25, 1);
    print("stage A (0,1) clean sync ", a0s, " async ", a0a, newLine=true);
    print("stage A flips 4  sync ", a4s, " async ", a4a, newLine=true);
    print("stage A flips 8  sync ", a8s, " async ", a8a, newLine=true);
    print("stage A flips 12 sync ", a12s, " async ", a12a, newLine=true);

    // stage B: 3 patterns, 30 trials per pattern
    var b0s: float = rate(hb, flat3, 3, 0, 1, 0);
    var b0a: float = rate(hb, flat3, 3, 0, 1, 1);
    var b4s: float = rate(hb, flat3, 3, 4, 30, 0);
    var b4a: float = rate(hb, flat3, 3, 4, 30, 1);
    var b8s: float = rate(hb, flat3, 3, 8, 30, 0);
    var b8a: float = rate(hb, flat3, 3, 8, 30, 1);
    var b12s: float = rate(hb, flat3, 3, 12, 30, 0);
    var b12a: float = rate(hb, flat3, 3, 12, 30, 1);
    print("stage B (0,1,7) clean sync ", b0s, " async ", b0a, newLine=true);
    print("stage B flips 4  sync ", b4s, " async ", b4a, newLine=true);
    print("stage B flips 8  sync ", b8s, " async ", b8a, newLine=true);
    print("stage B flips 12 sync ", b12s, " async ", b12a, newLine=true);

    if (a0s == 1.0 && a0a == 1.0 && b0s == 1.0 && b0a == 1.0) { print("PASS stored patterns are fixed points", newLine=true); } else { print("FAIL stored patterns not stable", newLine=true); };
    if (a4s >= 0.95 && a4a >= 0.95 && a8s >= 0.95 && a8a >= 0.95 && a12s >= 0.95 && a12a >= 0.95) { print("PASS stage A exact recovery up to 12 flips", newLine=true); } else { print("FAIL stage A", newLine=true); };
    if (b4s >= 0.8 && b4a >= 0.8) { print("PASS stage B at 4 flips (>= 0.8)", newLine=true); } else { print("FAIL stage B 4 flips", newLine=true); };
    if (b8s >= 0.7 && b8a >= 0.7) { print("PASS stage B at 8 flips (>= 0.7)", newLine=true); } else { print("FAIL stage B 8 flips", newLine=true); };
    if (b12s >= 0.6 && b12a >= 0.6) { print("PASS stage B at 12 flips (>= 0.6)", newLine=true); } else { print("FAIL stage B 12 flips", newLine=true); };

    ha.dispose();
    hb.dispose();
};