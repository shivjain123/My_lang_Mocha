from "mocha-string" import *;
from "mocha-neuron" import *;

function mean_err(rbm: Rbm, data: float[], n: int) -> float {
    var total: float = 0.0;
    var s: int = 0;
    while (s < n) {
        var v: Tensor = Tensor(1, 64);
        var k: int = 0;
        while (k < 64) {
            v.put(0, k, data[s * 64 + k]);
            k++;
        };
        total = total + rbm.reconstruction_error(v);
        v.dispose();
        s++;
    };
    return total / float(n);
};

function main(didLoad) -> null {
    var r: File = open("digits.csv", "read");
    var train: float[] = [];
    var held: float[] = [];
    var n_tr: int = 0;
    var n_te: int = 0;
    var i: int = 0;
    while (!r.eof()) {
        var rec: str[] = r.readCsvRecord();
        if (rec.length == 65) {
            var is_test: bool = (i % 5 == 0);
            var want: bool = false;
            if (is_test && n_te < 300) { want = true; };
            if (!is_test && n_tr < 300) { want = true; };
            if (want) {
                var c: int = 0;
                while (c < 64) {
                    var px: float = 0.0;
                    if (rec[c].toInt() >= 8) {
                        px = 1.0;
                    };
                    if (is_test) {
                        held.push(px);
                    } else {
                        train.push(px);
                    };
                    c++;
                };
                if (is_test) {
                    n_te++;
                } else {
                    n_tr++;
                };
            };
            i++;
        };
    };
    r.close();
    print("rows seen ", i, " train samples ", n_tr, " held-out samples ", n_te, newLine=true);

    var cd: Rbm = Rbm(64, 32);
    var pcd: Rbm = Rbm(64, 32);

    var e0_cd: float = mean_err(cd, train, n_tr);
    var e0_pcd: float = mean_err(pcd, train, n_tr);
    print("untrained error: cd ", e0_cd, " pcd ", e0_pcd, newLine=true);

    cd.train_values(train, 20, 0.05);
    pcd.train_values(train, 20, 0.05, pers=true);

    var cd_tr: float = mean_err(cd, train, n_tr);
    var cd_te: float = mean_err(cd, held, n_te);
    var pcd_tr: float = mean_err(pcd, train, n_tr);
    var pcd_te: float = mean_err(pcd, held, n_te);
    print("cd-1  train error ", cd_tr, " held-out error ", cd_te, newLine=true);
    print("pcd   train error ", pcd_tr, " held-out error ", pcd_te, newLine=true);

    if (e0_cd > 0.15 && e0_cd < 0.35 && e0_pcd > 0.15 && e0_pcd < 0.35) { print("PASS untrained error plausible", newLine=true); } else { print("FAIL untrained error", newLine=true); };
    if (cd_tr < 0.1 && cd_te < 0.12) { print("PASS cd-1 learned (train < 0.1, held-out < 0.12)", newLine=true); } else { print("FAIL cd-1", newLine=true); };
    if (pcd_tr < 0.12 && pcd_te < 0.13) { print("PASS pcd learned (train < 0.12, held-out < 0.13)", newLine=true); } else { print("FAIL pcd", newLine=true); };

    cd.dispose();
    pcd.dispose();
};