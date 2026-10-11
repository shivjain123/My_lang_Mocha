class Model {
    var weights: float[];
    var bias: float;
    var lr: float;
    var max_iter: int;
    var reg_lamb_da: float;
    var mode: str;
    var fitted: int;

    function constructor(max_iter: int) -> null {
        this.max_iter = max_iter;
        this.lr = 0.01;
        this.reg_lamb_da = 0.0;
        this.bias = 0.0;
        this.mode = "lin";
        this.fitted = 0;
    };

    function linear(lr: float) -> null {
        this.lr = lr;
        this.mode = "lin";
    };

    function fit(x: float[][], y: int[]) -> null {
        if (this.mode == "lin") {
            this.fit_linear(x, y);
        };
        this.fitted = 1;
    };

    function fit_linear(x: float[][], y: int[]) -> null {
        var n: int = x.length;
        var n_features: int = x.cols;

        this.weights = alloc float[n_features];
        var wi: int = 0;
        while (wi < n_features) {
            this.weights[wi] = 0.0;
            wi++;
        };
        this.bias = 0.0;

        var iter: int = 0;
        while (iter < this.max_iter) {
            var dw: float[] = alloc float[n_features];
            var db: float = 0.0;
            var ki: int = 0;
            while (ki < n_features) { dw[ki] = 0.0; ki++; };

            var i: int = 0;
            var x_r: float[][] = x;
            var w_r: float[] = this.weights;
            while (i < n) {
                var yi: float = -1.0;
                if (y[i] == 1) { yi = 1.0; };

                var z: float = this.bias;
                var j: int = 0;
                while (j < n_features) {
                    z = z + w_r[j] * x_r[i][j];
                    j++;
                };

                if (yi * z < 1.0) {
                    var k: int = 0;
                    while (k < n_features) {
                        dw[k] = dw[k] - yi * x_r[i][k];
                        k++;
                    };
                    db = db - yi;
                };
                i++;
            };

            var ai: int = 0;
            while (ai < n_features) {
                dw[ai] = dw[ai] / float(n);
                if (this.reg_lamb_da > 0.0) {
                    dw[ai] = dw[ai] + 2.0 * this.reg_lamb_da * this.weights[ai];
                };
                ai++;
            };
            db = db / float(n);

            var ui: int = 0;
            var w_r2: float[] = this.weights;
            while (ui < n_features) {
                w_r2[ui] = w_r2[ui] - this.lr * dw[ui];
                ui++;
            };
            this.bias = this.bias - this.lr * db;
            iter++;
        };
    };
};

function main(didLoad) -> null {
    var x: float[][] = alloc float[6][1];
    x[0][0] = 1.0; x[1][0] = 2.0; x[2][0] = 3.0;
    x[3][0] = 5.0; x[4][0] = 6.0; x[5][0] = 7.0;

    var y: int[] = alloc int[6];
    y[0] = 0; y[1] = 0; y[2] = 0;
    y[3] = 1; y[4] = 1; y[5] = 1;

    var model: Model = Model(1000);
    model.linear(0.01);
    model.fit(x, y);
    print("ok", newLine=true);
};