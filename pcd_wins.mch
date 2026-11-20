// rbm_pcd_gen_test: does PCD give a model whose own samples match the data?
from "mocha-neuron" import *;
// 0 = A (111000), 1 = B (000111), 2 = C (101010), 3 = anything else
function classify(v: Tensor) -> int {
    var code: int = 0;
    var i: int = 0;
    while (i < 6) {
        code = code * 2;
        if (v.at(0, i) > 0.5) {
            code = code + 1;
        };
        i = i + 1;
    };
    if (code == 56) { return 0; };
    if (code == 7)  { return 1; };
    if (code == 42) { return 2; };
    return 3;
};

// many short chains from noise; counts the final state of each chain
// returns [tv distance, spurious fraction]
function gibbs_stats(r: Rbm, chains: int) -> float[] {
    var ca: float = 0.0;
    var cb: float = 0.0;
    var cc: float = 0.0;
    var cs: float = 0.0;
    var c: int = 0;
    while (c < chains) {
        var v: Tensor = Tensor(1, 6);
        var i: int = 0;
        while (i < 6) {
            v.put(0, i, 0.5);
            i = i + 1;
        };
        r.binarize(v);

        var s: int = 0;
        while (s < 30) {
            var h: Tensor = r.sample_hidden(v);
            r.binarize(h);
            v.dispose();
            v = r.sample_visible(h);
            h.dispose();
            r.binarize(v);
            s = s + 1;
        };

        var k: int = classify(v);
        if (k == 0) { ca = ca + 1.0; };
        if (k == 1) { cb = cb + 1.0; };
        if (k == 2) { cc = cc + 1.0; };
        if (k == 3) { cs = cs + 1.0; };
        v.dispose();
        c = c + 1;
    };

    var n: float = ca + cb + cc + cs;
    var fa: float = ca / n;
    var fb: float = cb / n;
    var fc: float = cc / n;
    var fs: float = cs / n;
    var tv: float = 0.5 * (abs(fa - 0.6) + abs(fb - 0.3) + abs(fc - 0.1) + fs);
    return [tv, fs];
};

function main(didLoad) -> null {
    // 10 samples, 6 visible units: A x6, B x3, C x1, interleaved
    var samples: float[] = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 1.0, 1.0, 1.0,
                            1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
                            1.0, 0.0, 1.0, 0.0, 1.0, 0.0,
                            1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 1.0, 1.0, 1.0,
                            1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 1.0, 1.0, 1.0,
                            1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
                            1.0, 1.0, 1.0, 0.0, 0.0, 0.0];

    var runs: int = 5;
    var pcd_tv: float = 0.0;
    var pcd_sp: float = 0.0;
    var cd_tv: float = 0.0;
    var cd_sp: float = 0.0;

    var t: int = 0;
    while (t < runs) {
        var rp: Rbm = Rbm(6, 4);
        rp.train_values(samples, 3000, 0.01, pers=true);
        var sp: float[] = gibbs_stats(rp, 300);
        pcd_tv = pcd_tv + sp[0];
        pcd_sp = pcd_sp + sp[1];
        rp.dispose();

        var rc: Rbm = Rbm(6, 4);
        rc.train_values(samples, 2000, 0.05);
        var sc: float[] = gibbs_stats(rc, 300);
        cd_tv = cd_tv + sc[0];
        cd_sp = cd_sp + sc[1];
        rc.dispose();

        print("run ", t, "  PCD tv ", sp[0], " spurious ", sp[1], "   CD-1 tv ", sc[0], " spurious ", sc[1], newLine=true);
        t = t + 1;
    };

    print("MEAN  PCD  tv ", pcd_tv / runs, " spurious ", pcd_sp / runs, newLine=true);
    print("MEAN  CD-1 tv ", cd_tv / runs, " spurious ", cd_sp / runs, newLine=true);

    if (pcd_tv < cd_tv) {
        print("PCD samples are closer to the data distribution", newLine=true);
    };
    if (pcd_tv >= cd_tv) {
        print("CD-1 samples are as close or closer in this run", newLine=true);
    };
};