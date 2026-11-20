from "mocha-neuron" import *;

function pattern_error(r: Rbm, p: float[]) -> float {
        var out: float[] = r.reconstruct_values(p);
        var total: float = 0.0;
        var i: int = 0;
        while (i < p.length) {
            var d: float = p[i] - out[i];
            total = total + d * d;
            i = i + 1;
        };
        return total / p.length;
    };

function doo(didLoad){
    // rbm_pcd_test: PCD (pers=true) vs CD-1 on two patterns

    // two patterns, 6 visible units each, flat array
    var samples: float[] = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 1.0, 1.0, 1.0];
    var pa: float[] = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0];
    var pb: float[] = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0];

    // PCD
    var rp: Rbm = Rbm(6, 4);
    var pcd_before: float = pattern_error(rp, pa) + pattern_error(rp, pb);
    rp.train_values(samples, 1000, 0.05, pers=true);
    var pcd_after: float = pattern_error(rp, pa) + pattern_error(rp, pb);
    print("PCD  before ", pcd_before, " after ", pcd_after, newLine=true);

    // CD-1 baseline, default call, no pers
    var rc: Rbm = Rbm(6, 4);
    var cd_before: float = pattern_error(rc, pa) + pattern_error(rc, pb);
    rc.train_values(samples, 1000, 0.05);
    var cd_after: float = pattern_error(rc, pa) + pattern_error(rc, pb);
    print("CD-1 before ", cd_before, " after ", cd_after, newLine=true);
    print("chain_ready: pers=true run ", rp.chain_ready, "  default run ", rc.chain_ready, newLine=true);

    if (pcd_after < pcd_before) {
        print("PASS: PCD error dropped", newLine=true);
    };
    if (pcd_after >= pcd_before) {
        print("FAIL: PCD error did not drop", newLine=true);
    };
    if (cd_after < cd_before) {
        print("PASS: CD-1 error dropped", newLine=true);
    };
    if (cd_after >= cd_before) {
        print("FAIL: CD-1 error did not drop", newLine=true);
    };

    rp.dispose();
    rc.dispose();
    print("dispose done", newLine=true);
};