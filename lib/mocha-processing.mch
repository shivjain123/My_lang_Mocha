// mocha-lib-deps: mocha-stats, mocha-matvec

"""
mocha-processing — filter, map, reduce for int, float, str
"""

function filter(arr: int[], pred: lambda) -> int[] {
    var result: int[] = [];
    for each x in arr {
        if (pred(x)) {
            result.push(x);
        };
    };
    return result;
};

function filterFloat(arr: float[], pred: lambda) -> float[] {
    var result: float[] = [];
    for each x in arr {
        if (pred(x)) {
            result.push(x);
        };
    };
    return result;
};

function filterStr(arr: str[], pred: lambda) -> str[] {
    var result: str[] = [];
    for each x in arr {
        if (pred(x)) {
            result.push(x);
        };
    };
    return result;
};

function map(arr: int[], transform: lambda) -> int[] {
    var result: int[] = [];
    for each x in arr {
        var val: int = int(transform(x));
        result.push(val);
    };
    return result;
};

function mapFloat(arr: float[], transform: lambda) -> float[] {
    var result: float[] = [];
    for each x in arr {
        result.push(transform(x));
    };
    return result;
};

function mapStr(arr: str[], transform: lambda) -> str[] {
    var result: str[] = [];
    for each x in arr {
        result.push(transform(x));
    };
    return result;
};

function reduce(arr: int[], combiner: lambda, init: int) -> int {
    var acc: int = init;
    for each x in arr {
        acc = int(combiner(acc, x));
    };
    return acc;
};

function reduceFloat(arr: float[], combiner: lambda, init: float) -> float {
    var acc: float = init;
    for each x in arr {
        acc = float(combiner(acc, x));
    };
    return acc;
};

function reduceStr(arr: str[], combiner: lambda, init: str) -> str {
    var acc: str = init;
    for each x in arr {
        acc = str(combiner(acc, x));
    };
    return acc;
};

class StandardScaler {
    var mean_val: float;
    var std_val: float;
    var fitted: bool;

    function constructor() -> null {
        this.mean_val = 0.0;
        this.std_val = 0.0;
        this.fitted = false;
    };

    function fit(data: float[]) -> null {
        this.mean_val = data.mean();
        this.std_val = data.std_popu();
        this.fitted = true;
    };

    function transform(data: float[]) -> float[] {
        if (this.fitted == false) {
            c_print_err("MochaLibError (mocha-process): StandardScaler must be fit() before transform().");
            c_exit(2);
            return [];
        };
        if (this.std_val == 0.0) {
            c_print_err("MochaLibError (mocha-process): StandardScaler std is zero — cannot scale.");
            c_exit(2);
            return [];
        };
        var result: float[] = [];
        var i: int = 0;
        while (i < data.length) {
            result.push((data[i] - this.mean_val) / this.std_val);
            i++;
        };
        return result;
    };

    function fit_transform(data: float[]) -> float[] {
        this.fit(data);
        return this.transform(data);
    };
};

class MinMaxScaler {
    var min_val: float;
    var max_val: float;
    var fitted: bool;

    function constructor() -> null {
        this.min_val = 0.0;
        this.max_val = 0.0;
        this.fitted = false;
    };

    function fit(data: float[]) -> null {
        if (data.length == 0) {
            c_print_err("MochaLibError (mocha-process): MinMaxScaler.fit() called on empty array.");
            c_exit(2);
            return;
        };
        this.min_val = data[0];
        this.max_val = data[0];
        var i: int = 1;
        while (i < data.length) {
            if (data[i] < this.min_val) { this.min_val = data[i]; };
            if (data[i] > this.max_val) { this.max_val = data[i]; };
            i++;
        };
        this.fitted = true;
    };

    function transform(data: float[]) -> float[] {
        if (this.fitted == false) {
            c_print_err("MochaLibError (mocha-process): MinMaxScaler must be fit() before transform().");
            c_exit(2);
            return [];
        };
        if (this.max_val - this.min_val == 0.0) {
            c_print_err("MochaLibError (mocha-process): MinMaxScaler range is zero — cannot scale.");
            c_exit(2);
            return [];
        };
        var result: float[] = [];
        var i: int = 0;
        while (i < data.length) {
            result.push((data[i] - this.min_val) / (this.max_val - this.min_val));
            i++;
        };
        return result;
    };

    function fit_transform(data: float[]) -> float[] {
        this.fit(data);
        return this.transform(data);
    };
};

class RobustScaler {
    var median_val: float;
    var iqr_val: float;
    var fitted: bool;

    function constructor() -> null {
        this.median_val = 0.0;
        this.iqr_val = 0.0;
        this.fitted = false;
    };

    function fit(data: float[]) -> null {
        if (data.length == 0) {
            c_print_err("MochaLibError (mocha-process): RobustScaler.fit() called on empty array.");
            c_exit(2);
            return;
        };
        this.median_val = data.median();
        this.iqr_val = data.range_of_quart();
        this.fitted = true;
    };

    function transform(data: float[]) -> float[] {
        if (this.fitted == false) {
            c_print_err("MochaLibError (mocha-process): RobustScaler must be fit() before transform().");
            c_exit(2);
            return [];
        };
        if (this.iqr_val == 0.0) {
            c_print_err("MochaLibError (mocha-process): RobustScaler IQR is zero — cannot scale.");
            c_exit(2);
            return [];
        };
        var result: float[] = [];
        var i: int = 0;
        while (i < data.length) {
            result.push((data[i] - this.median_val) / this.iqr_val);
            i++;
        };
        return result;
    };

    function fit_transform(data: float[]) -> float[] {
        this.fit(data);
        return this.transform(data);
    };
};

class PCAReducer {
    var n_components: int;
    var components: float[][];
    var explained_variance: float[];
    var mean_vec: float[];
    var fitted: int;
    var n_samples: int;
    var n_features: int;

    function constructor(n_components: int) -> null {
        this.n_components = n_components;
        this.components = alloc float[0][0];
        this.explained_variance = [];
        this.mean_vec = [];
        this.fitted = 0;
        this.n_samples = 0;
        this.n_features = 0;
    };

    // ─────────────────────────────────────────
    // fit: compute principal components via SVD
    // ─────────────────────────────────────────
    function fit(data: float[][]) -> null {
        var n: int = data.length;
        var p: int = data.cols;
        this.n_samples = n;
        this.n_features = p;

        // ── Step 1: compute mean of each feature ──
        this.mean_vec = alloc float[p];
        var fi: int = 0;
        while (fi < p) {
            this.mean_vec[fi] = 0.0;
            fi++;
        };
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < p) {
                this.mean_vec[j] = this.mean_vec[j] + data[i][j];
                j++;
            };
            i++;
        };
        var mi: int = 0;
        while (mi < p) {
            this.mean_vec[mi] = this.mean_vec[mi] / float(n);
            mi++;
        };

        // ── Step 2: center the data (X - mean) ──
        var centered: float[][] = alloc float[n][p];
        var ci: int = 0;
        while (ci < n) {
            var cj: int = 0;
            while (cj < p) {
                centered[ci][cj] = data[ci][cj] - this.mean_vec[cj];
                cj++;
            };
            ci++;
        };

        // ── Step 3: SVD of centered data ──
        // centered = u * s * Vt
        // principal components = rows of Vt = columns of V
        var svd_result: (float[][], 3) = centered.svd();
        var u: float[][] = svd_result#0;
        var s: float[][] = svd_result#1;
        var Vt: float[][] = svd_result#2;

        // ── Step 4: explained variance from singular values ──
        // variance_i = s_i² / (n - 1)
        var n_sv: int = s.length;
        if (s.cols < n_sv) { n_sv = s.cols; };  // ← ADD THIS
        var total_var: float = 0.0;
        var vi: int = 0;
        while (vi < n_sv) {
            var sv: float = s[vi][vi];
            total_var = total_var + sv * sv;
            vi++;
        };

        // ── Step 5: store top n_components rows of Vt ──
        var k: int = this.n_components;
        if (k > n_sv) { k = n_sv; };
        if (k > p)    { k = p; };

        this.components = alloc float[k][p];
        this.explained_variance = alloc float[k];

        var ki: int = 0;
        while (ki < k) {
            var sv_i: float = s[ki][ki];
            this.explained_variance[ki] = (sv_i * sv_i) / float(n - 1);
            var pj: int = 0;
            while (pj < p) {
                this.components[ki][pj] = Vt[ki][pj];
                pj++;
            };
            ki++;
        };

        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // transform: project data onto components
    // X_reduced = (X - mean) · Vt^T
    // ─────────────────────────────────────────
    function transform(data: float[][]) -> float[][] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (PCAReducer): transform called before fit.");
            c_exit(2);
            return alloc float[0][0];
        };
        var n: int = data.length;
        var k: int = this.n_components;
        var p: int = this.n_features;
        var result: float[][] = alloc float[n][k];

        var i: int = 0;
        while (i < n) {
            // center sample
            var sample: float[] = alloc float[p];
            var si: int = 0;
            while (si < p) {
                sample[si] = data[i][si] - this.mean_vec[si];
                si++;
            };
            // project onto each component
            var ki: int = 0;
            while (ki < k) {
                var dot: float = 0.0;
                var di: int = 0;
                while (di < p) {
                    dot = dot + sample[di] * this.components[ki][di];
                    di++;
                };
                result[i][ki] = dot;
                ki++;
            };
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // fit_transform: fit then transform
    // ─────────────────────────────────────────
    function fit_transform(data: float[][]) -> float[][] {
        this.fit(data);
        return this.transform(data);
    };

    // ─────────────────────────────────────────
    // inverse_transform: reconstruct from reduced
    // X_approx = X_reduced · Vt + mean
    // ─────────────────────────────────────────
    function inverse_transform(data: float[][]) -> float[][] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (PCAReducer): inverse_transform called before fit.");
            c_exit(2);
            return alloc float[0][0];
        };
        var n: int = data.length;
        var k: int = this.n_components;
        var p: int = this.n_features;
        var result: float[][] = alloc float[n][p];

        var i: int = 0;
        while (i < n) {
            var pi: int = 0;
            while (pi < p) {
                var val: float = this.mean_vec[pi];
                var ki: int = 0;
                while (ki < k) {
                    val = val + data[i][ki] * this.components[ki][pi];
                    ki++;
                };
                result[i][pi] = val;
                pi++;
            };
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // explained_variance_ratio: fraction of
    // total variance captured by each component
    // ─────────────────────────────────────────
    function explained_variance_ratio() -> float[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (PCAReducer): explained_variance_ratio called before fit.");
            c_exit(2);
            return [];
        };
        var total: float = 0.0;
        var i: int = 0;
        while (i < this.n_components) {
            total = total + this.explained_variance[i];
            i++;
        };
        if (total == 0.0) { return this.explained_variance; };
        var ratio: float[] = alloc float[this.n_components];
        var ri: int = 0;
        while (ri < this.n_components) {
            ratio[ri] = this.explained_variance[ri] / total;
            ri++;
        };
        return ratio;
    };

    // ─────────────────────────────────────────
    // n_components_for_variance: how many
    // components needed to explain threshold%
    // e.g. threshold = 0.95 for 95%
    // ─────────────────────────────────────────
    function n_components_for_variance(threshold: float) -> int {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (PCAReducer): n_components_for_variance called before fit.");
            c_exit(2);
            return 0;
        };
        var ratio: float[] = this.explained_variance_ratio();
        var cumulative: float = 0.0;
        var i: int = 0;
        while (i < this.n_components) {
            cumulative = cumulative + ratio[i];
            if (cumulative >= threshold) {
                return i + 1;
            };
            i++;
        };
        return this.n_components;
    };
};