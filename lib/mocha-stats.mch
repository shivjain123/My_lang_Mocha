// mocha-lib-deps: mocha-math

""" MOCHA STATS LIB """

function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;
function c_sqrt(x: float) -> float native mocha_wrap_sqrt_f;
function c_erf(x: float) -> float native mocha_wrap_erf;
function c_tgamma(x: float) -> float native mocha_wrap_tgamma;
function c_lgamma(x: float) -> float native mocha_wrap_lgamma;
function c_exp(x: float) -> float native mocha_wrap_exp;

const EARTH_RADIUS_KM: float = 6371.0;

extend float[] {
    function mean() -> float {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): mean() called on empty array.");
            c_exit(2);
            return 0.0; // dummy
        };
        var sum: float = 0.0;
        var i: int = 0;
        while (i < this.length) {
            sum = sum + this[i];
            i++;
        };
        return sum / this.length;
    };
    function median() -> float {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): median() called on empty array.");
            c_exit(2);
            return 0.0;
        };
        var copy: float[] = this.copy();
        sort(copy);
        var mid: int = copy.length / 2;
        if (copy.length % 2 == 0) {
            return (copy[mid - 1] + copy[mid]) / 2.0;
        };
        return copy[mid];
    };
    // instead of modes = []
    // build a fresh result at the end using max_count
    function mode() -> float[] {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): mode() called on empty array.");
            c_exit(2);
            return [];
        };
        var copy: float[] = this.copy();
        sort(copy);

        // First pass — find max frequency
        var max_count: int = 1;
        var cur_count: int = 1;
        var i: int = 1;
        while (i < copy.length) {
            if (copy[i] == copy[i - 1]) {
                cur_count++;
                if (cur_count > max_count) { max_count = cur_count; };
            } else {
                cur_count = 1;
            };
            i++;
        };

        // Second pass — collect all values with max frequency
        var modes: float[] = [];
        cur_count = 1;
        i = 1;
        while (i < copy.length) {
            if (copy[i] == copy[i - 1]) {
                cur_count++;
            } else {
                if (cur_count == max_count) { modes.push(copy[i - 1]); };
                cur_count = 1;
            };
            i++;
        };
        if (cur_count == max_count) { modes.push(copy[copy.length - 1]); };

        return modes;
    };
    function var_popu() -> float {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): var_popu() called on empty array.");
            c_exit(2);
            return 0.0;
        };
        var m: float = this.mean();
        var sum: float = 0.0;
        var i: int = 0;
        while (i < this.length) {
            var diff: float = this[i] - m;
            sum = sum + diff * diff;
            i++;
        };
        return sum / this.length;
    };

    function var_sample() -> float {
        if (this.length < 2) {
            c_print_err("MochaLibError (mocha-stats): var_sample() requires at least 2 elements.");
            c_exit(2);
            return 0.0;
        };
        var m: float = this.mean();
        var sum: float = 0.0;
        var i: int = 0;
        while (i < this.length) {
            var diff: float = this[i] - m;
            sum = sum + diff * diff;
            i++;
        };
        return sum / (this.length - 1);
    };
    function std_popu() -> float {
        return c_sqrt(this.var_popu());
    };

    function std_sample() -> float {
        return c_sqrt(this.var_sample());
    };
    function first_quart() -> float {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): first_quart() called on empty array.");
            c_exit(2);
            return 0.0;
        };
        var copy: float[] = this.copy();
        sort(copy);
        var mid: int = copy.length / 2;
        var lower: float[] = [];
        var i: int = 0;
        while (i < mid) {
            lower.push(copy[i]);
            i++;
        };
        return lower.median();
    };

    function third_quart() -> float {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): third_quart() called on empty array.");
            c_exit(2);
            return 0.0;
        };
        var copy: float[] = this.copy();
        sort(copy);
        var mid: int = copy.length / 2;
        // skip middle element if odd length
        var upper_start: int = 0;
        if (copy.length % 2 == 0) {
            upper_start = mid;
        } else {
            upper_start = mid + 1;
        };
        var upper: float[] = [];
        var i: int = upper_start;
        while (i < copy.length) {
            upper.push(copy[i]);
            i++;
        };
        return upper.median();
    };

    function range_of_quart() -> float {
        return this.third_quart() - this.first_quart();
    };
    function outlier_bounds() -> float[] {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): outlier_bounds() called on empty array.");
            c_exit(2);
            return [];
        };
        var q1: float = this.first_quart();
        var q3: float = this.third_quart();
        var iqr: float = q3 - q1;
        var lower: float = q1 - 1.5 * iqr;
        var upper: float = q3 + 1.5 * iqr;
        var bounds: float[] = [];
        bounds.push(lower);
        bounds.push(upper);
        return bounds;
    };
    function z_score(val: float) -> float {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): z_score() called on empty array.");
            c_exit(2);
            return 0.0;
        };
        if (this.length < 30) {
            print("###Warning (mocha-stats): z_score() used on small sample (n < 30). Consider t_score() for small samples.", newLine=true);
        };
        var m: float = this.mean();
        var s: float = this.std_popu();
        if (s == 0.0) {
            c_print_err("MochaLibError (mocha-stats): z_score() called on array with zero standard deviation.");
            c_exit(2);
            return 0.0;
        };
        return (val - m) / s;
    };

    function t_score(val: float) -> float {
        if (this.length < 2) {
            c_print_err("MochaLibError (mocha-stats): t_score() requires at least 2 elements.");
            c_exit(2);
            return 0.0;
        };
        if (this.length >= 30) {
            print("###Warning (mocha-stats): t_score() used on large sample (n >= 30). Consider z_score() for large populations.", newLine=true);
        };
        var m: float = this.mean();
        var s: float = this.std_sample();
        var n: float = float(this.length);
        if (s == 0.0) {
            c_print_err("MochaLibError (mocha-stats): t_score() called on array with zero standard deviation.");
            c_exit(2);
            return 0.0;
        };
        return (val - m) / (s / c_sqrt(n));
    };
    function normalize() -> float[] {
        if (this.length == 0) {
            c_print_err("MochaLibError (mocha-stats): normalize() called on empty array.");
            c_exit(2);
            return [];
        };
        var min_val: float = this[0];
        var max_val: float = this[0];
        var i: int = 1;
        while (i < this.length) {
            if (this[i] < min_val) { min_val = this[i]; };
            if (this[i] > max_val) { max_val = this[i]; };
            i++;
        };
        if (max_val - min_val == 0.0) {
            c_print_err("MochaLibError (mocha-stats): normalize() called on array with all identical values.");
            c_exit(2);
            return [];
        };
        var result: float[] = [];
        i = 0;
        while (i < this.length) {
            result.push((this[i] - min_val) / (max_val - min_val));
            i++;
        };
        return result;
    };

    // ===========================================================
    // SKEWNESS — population and sample (Fisher-Pearson)
    // ===========================================================

    // Population skewness — third standardized moment
    function skewness() -> float {
        var n: int = this.length;
        var mu: float = this.mean();
        var sigma: float = this.std_popu();

        var sum_cubed: float = 0.0;
        var i: int = 0;
        while (i < n) {
            var diff: float = this[i] - mu;
            sum_cubed = sum_cubed + (diff * diff * diff);
            i = i + 1;
        };

        var m3: float = sum_cubed / float(n);
        return m3 / (sigma * sigma * sigma);
    };

    // Sample skewness — bias-corrected (Fisher-Pearson adjusted)
    // G1 = [sqrt(n*(n-1)) / (n-2)] * g1
    function skewness_sample() -> float {
        var n: int = this.length;
        if (n < 3) {
            c_print_err("MochaStatsError (mocha-stats): skewness_sample requires at least 3 values.");
            c_exit(2);
            return 0.0;
        };

        var g1: float = this.skewness();
        var nf: float = float(n);
        var correction: float = c_sqrt(nf * (nf - 1.0)) / (nf - 2.0);
        return correction * g1;
    };
};

function covar(x: float[], y: float[]) -> float {
    if (x.length != y.length) {
        c_print_err("MochaLibError (mocha-stats): covar() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (x.length < 2) {
        c_print_err("MochaLibError (mocha-stats): covar() requires at least 2 elements.");
        c_exit(2);
        return 0.0;
    };
    var mx: float = x.mean();
    var my: float = y.mean();
    var sum: float = 0.0;
    var i: int = 0;
    while (i < x.length) {
        sum = sum + (x[i] - mx) * (y[i] - my);
        i++;
    };
    return sum / float(x.length - 1);
};

function corr(x: float[], y: float[]) -> float {
    if (x.length != y.length) {
        c_print_err("MochaLibError (mocha-stats): corr() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    var sx: float = x.std_sample();
    var sy: float = y.std_sample();
    if (sx == 0.0 || sy == 0.0) {
        c_print_err("MochaLibError (mocha-stats): corr() called with zero standard deviation in one or both arrays.");
        c_exit(2);
        return 0.0;
    };
    return covar(x, y) / (sx * sy);
};

function chi(observed: float[], expected: float[]) -> float {
    if (observed.length != expected.length) {
        c_print_err("MochaLibError (mocha-stats): chi() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (observed.length == 0) {
        c_print_err("MochaLibError (mocha-stats): chi() called on empty arrays.");
        c_exit(2);
        return 0.0;
    };
    var result: float = 0.0;
    var i: int = 0;
    while (i < observed.length) {
        if (expected[i] == 0.0) {
            c_print_err("MochaLibError (mocha-stats): chi() has zero expected value — division by zero.");
            c_exit(2);
            return 0.0;
        };
        var diff: float = observed[i] - expected[i];
        result = result + (diff * diff) / expected[i];
        i++;
    };
    return result;
};

// ===========================================================
    // SPEARMAN RANK CORRELATION
    // ===========================================================

    // Compute ranks for an array, averaging ranks for tied values
    function ranks_of(a: float[]) -> float[] {
        var n: int = a.length;
        var result: float[] = [];
        var i: int = 0;
        while (i < n) {
            result.push(0.0);
            i = i + 1;
        };

        // sorted indices, ascending by value (insertion sort on index array)
        var order: int[] = [];
        i = 0;
        while (i < n) {
            order.push(i);
            i = i + 1;
        };
        var p: int = 1;
        while (p < n) {
            var key: int = order[p];
            var key_val: float = a[key];
            var q: int = p - 1;
            while (q >= 0 && a[order[q]] > key_val) {
                order[q + 1] = order[q];
                q = q - 1;
            };
            order[q + 1] = key;
            p = p + 1;
        };

        // assign average ranks for tie groups
        var idx: int = 0;
        while (idx < n) {
            var begin: int = idx;
            var end: int = idx;
            while (end + 1 < n && a[order[end + 1]] == a[order[begin]]) {
                end = end + 1;
            };
            // ranks are 1-indexed; average rank for [begin, end]
            var rank_sum: float = 0.0;
            var r: int = begin;
            while (r <= end) {
                rank_sum = rank_sum + float(r + 1);
                r = r + 1;
            };
            var avg_rank: float = rank_sum / float(end - begin + 1);

            var j: int = begin;
            while (j <= end) {
                result[order[j]] = avg_rank;
                j = j + 1;
            };
            idx = end + 1;
        };

        return result;
    };

    // Spearman's rank correlation coefficient
    function spearman(x: float[], y: float[]) -> float {
        if (x.length != y.length) {
            c_print_err("MochaStatsError (mocha-stats): spearman requires arrays of equal length.");
            c_exit(2);
            return 0.0;
        };
        var rx: float[] = ranks_of(x);
        var ry: float[] = ranks_of(y);
        return corr(rx, ry);
    };

"""     DISTANCES    """

function euclidean(a: float[], b: float[]) -> float {
    if (a.length != b.length) {
        c_print_err("MochaLibError (mocha-stats): euclidean() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (a.length == 0) {
        c_print_err("MochaLibError (mocha-stats): euclidean() called on empty arrays.");
        c_exit(2);
        return 0.0;
    };
    var sum: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        var diff: float = a[i] - b[i];
        sum = sum + diff * diff;
        i++;
    };
    return c_sqrt(sum);
};

function manhattan(a: float[], b: float[]) -> float {
    if (a.length != b.length) {
        c_print_err("MochaLibError (mocha-stats): manhattan() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (a.length == 0) {
        c_print_err("MochaLibError (mocha-stats): manhattan() called on empty arrays.");
        c_exit(2);
        return 0.0;
    };
    var sum: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        sum = sum + abs(a[i] - b[i]);
        i++;
    };
    return sum;
};

function chebyshev(a: float[], b: float[]) -> float {
    if (a.length != b.length) {
        c_print_err("MochaLibError (mocha-stats): chebyshev() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (a.length == 0) {
        c_print_err("MochaLibError (mocha-stats): chebyshev() called on empty arrays.");
        c_exit(2);
        return 0.0;
    };
    var max_val: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        var diff: float = abs(a[i] - b[i]);
        if (diff > max_val) { max_val = diff; };
        i++;
    };
    return max_val;
};

function minkowski(a: float[], b: float[], p: float) -> float {
    if (a.length != b.length) {
        c_print_err("MochaLibError (mocha-stats): minkowski() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (a.length == 0) {
        c_print_err("MochaLibError (mocha-stats): minkowski() called on empty arrays.");
        c_exit(2);
        return 0.0;
    };
    if (p <= 0.0) {
        c_print_err("MochaLibError (mocha-stats): minkowski() requires p > 0.");
        c_exit(2);
        return 0.0;
    };
    var sum: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        sum = sum + c_pow(abs(a[i] - b[i]), p);
        i++;
    };
    return c_pow(sum, 1.0 / p);
};

function cosine(a: float[], b: float[]) -> float {
    if (a.length != b.length) {
        c_print_err("MochaLibError (mocha-stats): cosine() requires arrays of equal length.");
        c_exit(2);
        return 0.0;
    };
    if (a.length == 0) {
        c_print_err("MochaLibError (mocha-stats): cosine() called on empty arrays.");
        c_exit(2);
        return 0.0;
    };
    var dot: float = 0.0;
    var mag_a: float = 0.0;
    var mag_b: float = 0.0;
    var i: int = 0;
    while (i < a.length) {
        dot = dot + a[i] * b[i];
        mag_a = mag_a + a[i] * a[i];
        mag_b = mag_b + b[i] * b[i];
        i++;
    };
    mag_a = c_sqrt(mag_a);
    mag_b = c_sqrt(mag_b);
    if (mag_a == 0.0 || mag_b == 0.0) {
        c_print_err("MochaLibError (mocha-stats): cosine() called with zero magnitude vector.");
        c_exit(2);
        return 0.0;
    };
    return dot / (mag_a * mag_b);
};

function haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float {
    var dlat: float = (lat2 - lat1) / 2.0;
    var dlon: float = (lon2 - lon1) / 2.0;

    var sin_dlat: float = dlat.sin(DEG);
    var sin_dlon: float = dlon.sin(DEG);
    var cos_lat1: float = lat1.cos(DEG);
    var cos_lat2: float = lat2.cos(DEG);

    var a: float = sin_dlat * sin_dlat +
                   sin_dlon * sin_dlon * cos_lat1 * cos_lat2;

    var sqrt_a: float = c_sqrt(a);
    var c: float = 2.0 * sqrt_a.inv_sin().real;
    return EARTH_RADIUS_KM * c;
};

function hamming(a: str, b: str) -> int {
    if (a.length != b.length) {
        c_print_err("MochaLibError (mocha-stats): hamming() requires strings of equal length.");
        c_exit(2);
        return 0;
    };
    if (a.length == 0) {
        c_print_err("MochaLibError (mocha-stats): hamming() called on empty strings.");
        c_exit(2);
        return 0;
    };
    var count: int = 0;
    var i: int = 0;
    while (i < a.length) {
        if (a.charAt(i) != b.charAt(i)) {
            count++;
        };
        i++;
    };
    return count;
};

class NormalDist {
    var mean_val: float;
    var std_val: float;

    function constructor(mean: float, std: float) -> null {
        if (std <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): NormalDist std must be > 0.");
            c_exit(2);
            return;
        };
        this.mean_val = mean;
        this.std_val = std;
    };

    function pdf(x: float) -> float {
        var pi: float = 3.14159265358979;
        var z: float = (x - this.mean_val) / this.std_val;
        return c_exp(-0.5 * z * z) / (this.std_val * c_sqrt(2.0 * pi));
    };

    function cdf(x: float) -> float {
        var z: float = (x - this.mean_val) / (this.std_val * c_sqrt(2.0));
        return 0.5 * (1.0 + c_erf(z));
    };

    function survival(x: float) -> float {
        return 1.0 - this.cdf(x);
    };

    function contains(x: float, prob: float) -> bool {
        if (prob <= 0.0 || prob >= 1.0) {
            c_print_err("MochaLibError (mocha-stats): contains() prob must be between 0 and 1.");
            c_exit(2);
            return false;
        };
        var tail: float = (1.0 - prob) / 2.0;
        var lower: float = this.cdf(x);
        return lower >= tail && lower <= (1.0 - tail);
    };
};

class PoissonDist {
    var rate: float;

    function constructor(rate: float) -> null {
        if (rate <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): PoissonDist rate must be > 0.");
            c_exit(2);
            return;
        };
        this.rate = rate;
    };

    function pmf(k: int) -> float {
        if (k < 0) {
            c_print_err("MochaLibError (mocha-stats): PoissonDist pmf() k must be >= 0.");
            c_exit(2);
            return 0.0;
        };
        var k_fact: float = c_tgamma(float(k) + 1.0);
        return c_exp(-this.rate) * c_pow(this.rate, float(k)) / k_fact;
    };

    function cdf(k: int) -> float {
        if (k < 0) {
            c_print_err("MochaLibError (mocha-stats): PoissonDist cdf() k must be >= 0.");
            c_exit(2);
            return 0.0;
        };
        var sum: float = 0.0;
        var i: int = 0;
        while (i <= k) {
            sum = sum + this.pmf(i);
            i++;
        };
        return sum;
    };

    function survival(k: int) -> float {
        return 1.0 - this.cdf(k);
    };

    function mean() -> float {
        return this.rate;
    };

    function variance() -> float {
        return this.rate;
    };
};

class BinomialDist {
    var n: int;
    var p: float;

    function constructor(n: int, p: float) -> null {
        if (n <= 0) {
            c_print_err("MochaLibError (mocha-stats): BinomialDist n must be > 0.");
            c_exit(2);
            return;
        };
        if (p < 0.0 || p > 1.0) {
            c_print_err("MochaLibError (mocha-stats): BinomialDist p must be between 0 and 1.");
            c_exit(2);
            return;
        };
        this.n = n;
        this.p = p;
    };

    function choose(k: int) -> float {
        if (k < 0 || k > this.n) {
            return 0.0;
        };
        var num: float = c_tgamma(float(this.n) + 1.0);
        var den: float = c_tgamma(float(k) + 1.0) * c_tgamma(float(this.n - k) + 1.0);
        return num / den;
    };

    function pmf(k: int) -> float {
        if (k < 0 || k > this.n) {
            c_print_err("MochaLibError (mocha-stats): BinomialDist pmf() k must be between 0 and n.");
            c_exit(2);
            return 0.0;
        };
        return this.choose(k) * c_pow(this.p, float(k)) * c_pow(1.0 - this.p, float(this.n - k));
    };

    function cdf(k: int) -> float {
        if (k < 0) {
            c_print_err("MochaLibError (mocha-stats): BinomialDist cdf() k must be >= 0.");
            c_exit(2);
            return 0.0;
        };
        if (k >= this.n) {
            return 1.0;
        };
        var sum: float = 0.0;
        var i: int = 0;
        while (i <= k) {
            sum = sum + this.pmf(i);
            i++;
        };
        return sum;
    };

    function survival(k: int) -> float {
        return 1.0 - this.cdf(k);
    };

    function mean() -> float {
        return float(this.n) * this.p;
    };

    function variance() -> float {
        return float(this.n) * this.p * (1.0 - this.p);
    };
};

class ExponentialDist {
    var rate: float;

    function constructor(rate: float) -> null {
        if (rate <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): ExponentialDist rate must be > 0.");
            c_exit(2);
            return;
        };
        this.rate = rate;
    };

    function pdf(x: float) -> float {
        if (x < 0.0) {
            return 0.0;
        };
        return this.rate * c_exp(-this.rate * x);
    };

    function cdf(x: float) -> float {
        if (x < 0.0) {
            return 0.0;
        };
        return 1.0 - c_exp(-this.rate * x);
    };

    function survival(x: float) -> float {
        if (x < 0.0) {
            return 1.0;
        };
        return c_exp(-this.rate * x);
    };

    function mean() -> float {
        return 1.0 / this.rate;
    };

    function variance() -> float {
        return 1.0 / (this.rate * this.rate);
    };

    function median() -> float {
        var ln2: float = 0.69314718055994;
        return ln2 / this.rate;
    };

    function memoryless(t: float, s: float) -> float {
        if (t < 0.0 || s < 0.0) {
            c_print_err("MochaLibError (mocha-stats): ExponentialDist memoryless() requires t >= 0 and s >= 0.");
            c_exit(2);
            return 0.0;
        };
        return this.survival(t + s) / this.survival(s);
    };
};

class GammaDist {
    var alpha: float;
    var beta: float;

    function constructor(alpha: float, beta: float) -> null {
        if (alpha <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): GammaDist alpha must be > 0.");
            c_exit(2);
            return;
        };
        if (beta <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): GammaDist beta must be > 0.");
            c_exit(2);
            return;
        };
        this.alpha = alpha;
        this.beta = beta;
    };

    function pdf(x: float) -> float {
        if (x <= 0.0) {
            return 0.0;
        };
        var gamma_alpha: float = c_tgamma(this.alpha);
        var num: float = c_pow(this.beta, this.alpha) * c_pow(x, this.alpha - 1.0) * c_exp(-this.beta * x);
        return num / gamma_alpha;
    };

    function mean() -> float {
        return this.alpha / this.beta;
    };

    function variance() -> float {
        return this.alpha / (this.beta * this.beta);
    };

    function mode() -> float {
        if (this.alpha < 1.0) {
            c_print_err("MochaLibError (mocha-stats): GammaDist mode() undefined for alpha < 1.");
            c_exit(2);
            return 0.0;
        };
        return (this.alpha - 1.0) / this.beta;
    };

    function is_exponential() -> bool {
        return this.alpha == 1.0;
    };

    function is_chi_squared(df: int) -> bool {
        var half_df: float = float(df) / 2.0;
        return this.alpha == half_df && this.beta == 0.5;
    };
};

class BetaDist {
    var alpha: float;
    var beta: float;

    function constructor(alpha_val: float, beta_val: float) -> null {
        if (alpha_val <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): BetaDist alpha must be > 0.");
            c_exit(2);
            return;
        };
        if (beta_val <= 0.0) {
            c_print_err("MochaLibError (mocha-stats): BetaDist beta must be > 0.");
            c_exit(2);
            return;
        };
        this.alpha = alpha_val;
        this.beta = beta_val;
    };

    function beta_func() -> float {
        return (c_tgamma(this.alpha) * c_tgamma(this.beta)) / c_tgamma(this.alpha + this.beta);
    };

    function pdf(x: float) -> float {
        if (x <= 0.0 || x >= 1.0) {
            return 0.0;
        };
        return c_pow(x, this.alpha - 1.0) * c_pow(1.0 - x, this.beta - 1.0) / this.beta_func();
    };

    function mean() -> float {
        return this.alpha / (this.alpha + this.beta);
    };

    function variance() -> float {
        var ab: float = this.alpha + this.beta;
        return (this.alpha * this.beta) / (ab * ab * (ab + 1.0));
    };

    function mode() -> float {
        if (this.alpha <= 1.0 || this.beta <= 1.0) {
            c_print_err("MochaLibError (mocha-stats): BetaDist mode() undefined for alpha <= 1 or beta <= 1.");
            c_exit(2);
            return 0.0;
        };
        return (this.alpha - 1.0) / (this.alpha + this.beta - 2.0);
    };

    function is_uniform() -> bool {
        return this.alpha == 1.0 && this.beta == 1.0;
    };

    function is_symmetric() -> bool {
        return this.alpha == this.beta;
    };

    function skewness() -> float {
        var ab: float = this.alpha + this.beta;
        var num: float = 2.0 * (this.beta - this.alpha) * c_sqrt(ab + 1.0);
        var den: float = (ab + 2.0) * c_sqrt(this.alpha * this.beta);
        if (den == 0.0) {
            c_print_err("MochaLibError (mocha-stats): BetaDist skewness() undefined for these parameters.");
            c_exit(2);
            return 0.0;
        };
        return num / den;
    };
    function update(successes: int, failures: int) -> BetaDist {
        if (successes < 0 || failures < 0) {
            c_print_err("MochaLibError (mocha-stats): BetaDist update() requires non-negative successes and failures.");
            c_exit(2);
            return BetaDist(this.alpha, this.beta);
        };
        return BetaDist(this.alpha + float(successes), this.beta + float(failures));
    };
};

class GaussianMixture {
    var means: float[];
    var stds: float[];
    var weights: float[];
    var n_components: int;

    function constructor(means: float[], stds: float[], weights: float[]) -> null {
        if (means.length == 0) {
            c_print_err("MochaLibError (mocha-stats): GaussianMixture requires at least 1 component.");
            c_exit(2);
            return;
        };
        if (means.length != stds.length || means.length != weights.length) {
            c_print_err("MochaLibError (mocha-stats): GaussianMixture means, stds and weights must be same length.");
            c_exit(2);
            return;
        };
        var i: int = 0;
        while (i < stds.length) {
            if (stds[i] <= 0.0) {
                c_print_err("MochaLibError (mocha-stats): GaussianMixture all stds must be > 0.");
                c_exit(2);
                return;
            };
            i++;
        };
        var weight_sum: float = 0.0;
        i = 0;
        while (i < weights.length) {
            if (weights[i] < 0.0) {
                c_print_err("MochaLibError (mocha-stats): GaussianMixture all weights must be >= 0.");
                c_exit(2);
                return;
            };
            weight_sum = weight_sum + weights[i];
            i++;
        };
        if (weight_sum < 0.9999 || weight_sum > 1.0001) {
            c_print_err("MochaLibError (mocha-stats): GaussianMixture weights must sum to 1.0.");
            c_exit(2);
            return;
        };
        this.means = means;
        this.stds = stds;
        this.weights = weights;
        this.n_components = means.length;
    };

    function pdf(x: float) -> float {
        var pi: float = 3.14159265358979;
        var result: float = 0.0;
        var i: int = 0;
        while (i < this.n_components) {
            var z: float = (x - this.means[i]) / this.stds[i];
            var component: float = c_exp(-0.5 * z * z) / (this.stds[i] * c_sqrt(2.0 * pi));
            result = result + this.weights[i] * component;
            i++;
        };
        return result;
    };

    function cdf(x: float) -> float {
        var result: float = 0.0;
        var i: int = 0;
        while (i < this.n_components) {
            var z: float = (x - this.means[i]) / (this.stds[i] * c_sqrt(2.0));
            result = result + this.weights[i] * 0.5 * (1.0 + c_erf(z));
            i++;
        };
        return result;
    };

    function mean() -> float {
        var result: float = 0.0;
        var i: int = 0;
        while (i < this.n_components) {
            result = result + this.weights[i] * this.means[i];
            i++;
        };
        return result;
    };

    function variance() -> float {
        var overall_mean: float = this.mean();
        var result: float = 0.0;
        var i: int = 0;
        while (i < this.n_components) {
            var variance_i: float = this.stds[i] * this.stds[i];
            var mean_sq_diff: float = (this.means[i] - overall_mean) * (this.means[i] - overall_mean);
            result = result + this.weights[i] * (variance_i + mean_sq_diff);
            i++;
        };
        return result;
    };

    function dominant_component() -> int {
        var max_weight: float = this.weights[0];
        var max_idx: int = 0;
        var i: int = 1;
        while (i < this.n_components) {
            if (this.weights[i] > max_weight) {
                max_weight = this.weights[i];
                max_idx = i;
            };
            i++;
        };
        return max_idx;
    };

    function responsibility(x: float, k: int) -> float {
        if (k < 0 || k >= this.n_components) {
            c_print_err("MochaLibError (mocha-stats): GaussianMixture responsibility() k out of range.");
            c_exit(2);
            return 0.0;
        };
        var total: float = this.pdf(x);
        if (total == 0.0) {
            return 0.0;
        };
        var pi: float = 3.14159265358979;
        var z: float = (x - this.means[k]) / this.stds[k];
        var component_k: float = c_exp(-0.5 * z * z) / (this.stds[k] * c_sqrt(2.0 * pi));
        return (this.weights[k] * component_k) / total;
    };
};

class FDist {
    var d1: float;  // numerator degrees of freedom
    var d2: float;  // denominator degrees of freedom

    function constructor(d1: float, d2: float) -> null {
        this.d1 = d1;
        this.d2 = d2;
    };

    // ─────────────────────────────────────────
    // log_beta: log B(a,b) = lgamma(a) + lgamma(b) - lgamma(a+b)
    // ─────────────────────────────────────────
    function log_beta(a: float, b: float) -> float {
        return c_lgamma(a) + c_lgamma(b) - c_lgamma(a + b);
    };

    // ─────────────────────────────────────────
    // reg_incomplete_beta: Iₓ(a,b)
    // Via Numerical recipes formula
    // ─────────────────────────────────────────
    function beta_cf(x: float, a: float, b: float) -> float {
        // Continued fraction for incomplete beta via Numerical Recipes method
        var tiny: float = 0.0000000001;
        var max_iter: int = 200;
        var eps: float = 0.0000001;

        var qab: float = a + b;
        var qap: float = a + 1.0;
        var qam: float = a - 1.0;

        var c: float = 1.0;
        var d: float = 1.0 - qab * x / qap;
        if (d < tiny && d > -tiny) { d = tiny; };
        d = 1.0 / d;
        var h: float = d;

        var m: int = 1;
        while (m <= max_iter) {
            var mf: float = float(m);
            var m2: float = 2.0 * mf;

            // Even step
            var aa_e: float = mf * (b - mf) * x / ((qam + m2) * (a + m2));
            d = 1.0 + aa_e * d;
            if (d < tiny && d > -tiny) { d = tiny; };
            c = 1.0 + aa_e / c;
            if (c < tiny && c > -tiny) { c = tiny; };
            d = 1.0 / d;
            h = h * d * c;

            // Odd step
            var aa_o: float = -(a + mf) * (qab + mf) * x / ((a + m2) * (qap + m2));
            d = 1.0 + aa_o * d;
            if (d < tiny && d > -tiny) { d = tiny; };
            c = 1.0 + aa_o / c;
            if (c < tiny && c > -tiny) { c = tiny; };
            d = 1.0 / d;
            var delta: float = d * c;
            h = h * delta;

            // Convergence check
            var diff: float = delta - 1.0;
            if (diff < 0.0) { diff = diff * -1.0; };
            if (diff < eps) { break; };

            m++;
        };
        return h;
    };

    function reg_incomplete_beta(x: float, a: float, b: float) -> float {
        if (x <= 0.0) { return 0.0; };
        if (x >= 1.0) { return 1.0; };

        // Front factor: x^a * (1-x)^b / (a * B(a,b))
        var lbeta: float = this.log_beta(a, b);
        var front: float = c_exp(a * x.log().real + b * (1.0 - x).log().real - lbeta) / a;

        // Use symmetry for better convergence:
        // Iₓ(a,b) = 1 - I₁₋ₓ(b,a) when x > (a+1)/(a+b+2)
        if (x < (a + 1.0) / (a + b + 2.0)) {
            return front * this.beta_cf(x, a, b);
        } else {
            var front2: float = c_exp(b * (1.0 - x).log().real + a * x.log().real - lbeta) / b;
            return 1.0 - front2 * this.beta_cf(1.0 - x, b, a);
        };
    };

    // ─────────────────────────────────────────
    // pdf: f(x) = sqrt((d1x)^d1 * d2^d2 / (d1x+d2)^(d1+d2))
    //             / (x * B(d1/2, d2/2))
    // ─────────────────────────────────────────
    function pdf(x: float) -> float {
        if (x <= 0.0) { return 0.0; };
        var a: float = this.d1 / 2.0;
        var b: float = this.d2 / 2.0;
        var lbeta: float = this.log_beta(a, b);
        var log_pdf: float = a * (this.d1 * x / (this.d1 * x + this.d2)).log().real
                           + b * (this.d2 / (this.d1 * x + this.d2)).log().real
                           - x.log().real - lbeta;
        return c_exp(log_pdf);
    };

    // ─────────────────────────────────────────
    // cdf: P(X ≤ x) = I_{d1x/(d1x+d2)}(d1/2, d2/2)
    // ─────────────────────────────────────────
    function cdf(x: float) -> float {
        if (x <= 0.0) { return 0.0; };
        var t: float = (this.d1 * x) / (this.d1 * x + this.d2);
        return this.reg_incomplete_beta(t, this.d1 / 2.0, this.d2 / 2.0);
    };

    // ─────────────────────────────────────────
    // survival: P(X > x) = 1 - cdf(x)
    // ─────────────────────────────────────────
    function survival(x: float) -> float {
        return 1.0 - this.cdf(x);
    };

    // ─────────────────────────────────────────
    // mean: d2 / (d2 - 2), defined for d2 > 2
    // ─────────────────────────────────────────
    function mean() -> float {
        if (this.d2 <= 2.0) {
            c_print_err("MochaLibError (FDist): mean undefined for d2 <= 2.");
            c_exit(2);
            return 0.0;
        };
        return this.d2 / (this.d2 - 2.0);
    };

    // ─────────────────────────────────────────
    // variance: 2d2²(d1+d2-2) / (d1(d2-2)²(d2-4))
    // defined for d2 > 4
    // ─────────────────────────────────────────
    function variance() -> float {
        if (this.d2 <= 4.0) {
            c_print_err("MochaLibError (FDist): variance undefined for d2 <= 4.");
            c_exit(2);
            return 0.0;
        };
        var num: float = 2.0 * this.d2 * this.d2 * (this.d1 + this.d2 - 2.0);
        var den: float = this.d1 * (this.d2 - 2.0) * (this.d2 - 2.0) * (this.d2 - 4.0);
        return num / den;
    };
};

// ─────────────────────────────────────────
// one_way_anova: one-way ANOVA test
// groups: float[][] — each row is a group
// returns: (f-statistic, p-value, between-df, within-df)
// ─────────────────────────────────────────
function one_way_anova(groups: float[][]) -> (float, 4) {
    var k: int = groups.length;  // number of groups
    if (k < 2) {
        c_print_err("MochaLibError (one_way_anova): need at least 2 groups.");
        c_exit(2);
        return (0.0, 0.0, 0.0, 0.0);
    };

    // ── Step 1: compute group means and sizes ──
    var group_means: float[] = alloc float[k];
    var group_ns: int[] = alloc int[k];
    var total_n: int = 0;
    var grand_sum: float = 0.0;

    var gi: int = 0;
    while (gi < k) {
        var n_i: int = groups[gi].length;
        group_ns[gi] = n_i;
        total_n = total_n + n_i;
        var s: float = 0.0;
        var j: int = 0;
        while (j < n_i) {
            s = s + groups[gi][j];
            j++;
        };
        group_means[gi] = s / float(n_i);
        grand_sum = grand_sum + s;
        gi++;
    };

    var grand_mean: float = grand_sum / float(total_n);

    // ── Step 2: between-group sum of squares (SSB) ──
    var ssb: float = 0.0;
    var bi: int = 0;
    while (bi < k) {
        var diff: float = group_means[bi] - grand_mean;
        ssb = ssb + float(group_ns[bi]) * diff * diff;
        bi++;
    };

    // ── Step 3: within-group sum of squares (SSW) ──
    var ssw: float = 0.0;
    var wi: int = 0;
    while (wi < k) {
        var n_i: int = group_ns[wi];
        var j: int = 0;
        while (j < n_i) {
            var diff: float = groups[wi][j] - group_means[wi];
            ssw = ssw + diff * diff;
            j++;
        };
        wi++;
    };

    // ── Step 4: degrees of freedom ──
    var df_between: float = float(k - 1);
    var df_within: float = float(total_n - k);

    if (df_within <= 0.0) {
        c_print_err("MochaLibError (one_way_anova): not enough observations.");
        c_exit(2);
        return (0.0, 0.0, 0.0, 0.0);
    };

    // ── Step 5: mean squares and f-statistic ──
    var msb: float = ssb / df_between;
    var msw: float = ssw / df_within;

    if (msw == 0.0) {
        c_print_err("MochaLibError (one_way_anova): within-group variance is zero.");
        c_exit(2);
        return (0.0, 0.0, 0.0, 0.0);
    };

    var f: float = msb / msw;

    // ── Step 6: p-value via f-distribution ──
    var fdist: FDist = FDist(df_between, df_within);
    var p_value: float = fdist.survival(f);

    return (f, p_value, df_between, df_within);
};

// ─────────────────────────────────────────
// one_way_anova_unequal: one-way ANOVA with unequal group sizes
// groups: float[][] — each row is a group, padded to same width
// sizes: int[]     — actual number of valid observations per group
// returns: (f-statistic, p-value, between-df, within-df)
// ─────────────────────────────────────────
function one_way_anova_unequal(groups: float[][], sizes: int[]) -> (float, 4) {
    var k: int = groups.length;
    if (k < 2) {
        c_print_err("MochaLibError (one_way_anova_unequal): need at least 2 groups.");
        c_exit(2);
        return (0.0, 0.0, 0.0, 0.0);
    };

    // ── Step 1: compute group means and sizes ──
    var group_means: float[] = alloc float[k];
    var group_ns: int[] = alloc int[k];
    var total_n: int = 0;
    var grand_sum: float = 0.0;

    var gi: int = 0;
    while (gi < k) {
        var n_i: int = sizes[gi];
        if (n_i <= 0) {
            c_print_err("MochaLibError (one_way_anova_unequal): group size must be > 0.");
            c_exit(2);
            return (0.0, 0.0, 0.0, 0.0);
        };
        group_ns[gi] = n_i;
        total_n = total_n + n_i;
        var s: float = 0.0;
        var j: int = 0;
        while (j < n_i) {
            s = s + groups[gi][j];
            j++;
        };
        group_means[gi] = s / float(n_i);
        grand_sum = grand_sum + s;
        gi++;
    };

    var grand_mean: float = grand_sum / float(total_n);

    // ── Step 2: between-group sum of squares (SSB) ──
    var ssb: float = 0.0;
    var bi: int = 0;
    while (bi < k) {
        var diff: float = group_means[bi] - grand_mean;
        ssb = ssb + float(group_ns[bi]) * diff * diff;
        bi++;
    };

    // ── Step 3: within-group sum of squares (SSW) ──
    var ssw: float = 0.0;
    var wi: int = 0;
    while (wi < k) {
        var n_i: int = group_ns[wi];
        var j: int = 0;
        while (j < n_i) {
            var diff: float = groups[wi][j] - group_means[wi];
            ssw = ssw + diff * diff;
            j++;
        };
        wi++;
    };

    // ── Step 4: degrees of freedom ──
    var df_between: float = float(k - 1);
    var df_within: float = float(total_n - k);

    if (df_within <= 0.0) {
        c_print_err("MochaLibError (one_way_anova_unequal): not enough observations.");
        c_exit(2);
        return (0.0, 0.0, 0.0, 0.0);
    };

    // ── Step 5: mean squares and f-statistic ──
    var msb: float = ssb / df_between;
    var msw: float = ssw / df_within;

    if (msw == 0.0) {
        c_print_err("MochaLibError (one_way_anova_unequal): within-group variance is zero.");
        c_exit(2);
        return (0.0, 0.0, 0.0, 0.0);
    };

    var f: float = msb / msw;

    // ── Step 6: p-value via f-distribution ──
    var fdist: FDist = FDist(df_between, df_within);
    var p_value: float = fdist.survival(f);

    return (f, p_value, df_between, df_within);
};