from "mocha-neuron" import *;

function norm_of(t: Tensor) -> float {
    var s: float = 0.0;
    var j: int = 0;
    while (j < t.ncols) {
        var x: float = t.at(0, j);
        s = s + x * x;
        j = j + 1;
    };
    return s.sqrt().real;
};

function main(didLoad) -> null {
    var seed: int = 1;
    while (seed <= 5) {
        rand_seed(seed);
        var lsm: Lsm = Lsm(1, 50, 1, 0.9);

        var v: Tensor = Tensor(1, 50);
        var j: int = 0;
        while (j < 50) {
            v.put(0, j, rand_float(0.0 - 1.0, 1.0));
            j = j + 1;
        };
        v.scale(1.0 / norm_of(v));

        var chunk_prod: float = 1.0;
        var rates_prod: float = 1.0;
        var last_rate: float = 0.0;
        var chunks: int = 0;
        var k: int = 1;
        while (k <= 300) {
            var nv: Tensor = v.matmul(lsm.w);
            var g: float = norm_of(nv);
            nv.scale(1.0 / g);
            v.dispose();
            v = nv.clone_tensor();
            nv.dispose();
            chunk_prod = chunk_prod * g;
            if (k % 25 == 0) {
                last_rate = float(c_pow(chunk_prod, 1.0 / 25.0));
                rates_prod = rates_prod * last_rate;
                chunk_prod = 1.0;
                chunks = chunks + 1;
            };
            if (k % 100 == 0) {
                var avg_rate: float = float(c_pow(rates_prod, 1.0 / chunks));
                print("seed ", seed, " k=", k, " average ", avg_rate, " latest ", last_rate, "\n");
            };
            k = k + 1;
        };
        v.dispose();
        lsm.dispose();
        seed = seed + 1;
    };
};