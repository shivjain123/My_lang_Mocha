class Model {
    var weights: float[];
    var lr: float;

    function constructor(v: int) -> null {
        this.lr = 0.01;
    };

    function fit(x: float[][]) -> null {
        var n_features: int = x.cols;
        this.weights = alloc float[n_features];
        this.weights[0] = 0.0;
        var iter: int = 0;
        while (iter < 3) {
            var dw: float[] = alloc float[n_features];
            dw[0] = 0.0;
            var x_r: float[][] = x;
            var w_r: float[] = this.weights;
            var z: float = w_r[0] * x_r[0][0];
            var w_r2: float[] = this.weights;
            w_r2[0] = w_r2[0] - this.lr * dw[0];
            iter++;
        };
    };
};

function main(didLoad) -> null {
    var x: float[][] = alloc float[2][1];
    x[0][0] = 1.0;
    x[1][0] = 2.0;
    var m: Model = Model(1);
    m.fit(x);
    print("ok", newLine=true);
};