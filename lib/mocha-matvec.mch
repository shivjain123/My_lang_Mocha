// mocha-lib-deps: mocha-math
"""
mocha-matvec — Vector and Matrix operations for Mocha
!!THIS IS VERSION 0.3. FROM PREVIOUS VERSION, BREAKING CHANGES HAVE OCCURED!!
Extends int[], float[], int[][], float[][] with mathematical operations.

Operations:
  .scalar(n)        — multiply every element by n
  .vector(arr)      — dot product (1D) / matrix multiply (2D)
  .hadamard(arr)    — element-wise multiplication
  .add(arr)         — element-wise addition
  .sub(arr)         — element-wise subtraction
  .magn()           — magnitude / norm (always float)
  .normalize()      — unit vector (1D only, float[])
  .transpose()      — rows <-> cols (2D only)
  .trace()          — sum of diagonal (2D only)
  .det()            — determinant (2D only, float)
  .rank()           — rank of matrix (2D only, int)
  .svd()
  .singular_values()
"""

// ============================================================
// NATIVE WRAPPERS
// ============================================================

//function c_sqrt(x: float) -> float native mocha_wrap_sqrt_f;
function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;

// ============================================================
// extend int[]
// ============================================================

extend int[] {

    function scalar(n: int) -> int[] {
        var result: int[] = alloc int[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] * n;
            i++;
        };
        return result;
    };

    function vector(other: int[]) -> int {
        var result: int = 0;
        var i: int = 0;
        while (i < this.length) {
            result = result + (this[i] * other[i]);
            i++;
        };
        return result;
    };

    function hadamard(other: int[]) -> int[] {
        var result: int[] = alloc int[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] * other[i];
            i++;
        };
        return result;
    };

    function add(other: int[]) -> int[] {
        var result: int[] = alloc int[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] + other[i];
            i++;
        };
        return result;
    };

    function sub(other: int[]) -> int[] {
        var result: int[] = alloc int[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] - other[i];
            i++;
        };
        return result;
    };

    function magn() -> float {
        var sum: float = 0.0;
        var i: int = 0;
        while (i < this.length) {
            var elem: float = float(this[i]);
            sum = sum + (elem * elem);
            i++;
        };
        //return c_sqrt(sum);
        return sum.sqrt().real;
    };

    function unit_vector() -> float[] {
        var m: float = this.magn();
        var result: float[] = alloc float[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = float(this[i]) / m;
            i++;
        };
        return result;
    };
};


// ============================================================
// extend float[]
// ============================================================

extend float[] {

    function scalar(n: float) -> float[] {
        var result: float[] = alloc float[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] * n;
            i++;
        };
        return result;
    };

    function vector(other: float[]) -> float {
        var result: float = 0.0;
        var i: int = 0;
        while (i < this.length) {
            result = result + (this[i] * other[i]);
            i++;
        };
        return result;
    };

    function hadamard(other: float[]) -> float[] {
        var result: float[] = alloc float[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] * other[i];
            i++;
        };
        return result;
    };

    function add(other: float[]) -> float[] {
        var result: float[] = alloc float[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] + other[i];
            i++;
        };
        return result;
    };

    function sub(other: float[]) -> float[] {
        var result: float[] = alloc float[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] - other[i];
            i++;
        };
        return result;
    };

    function magn() -> float {
        var sum: float = 0.0;
        var i: int = 0;
        while (i < this.length) {
            sum = sum + (this[i] * this[i]);
            i++;
        };
        //return c_sqrt(sum);
        return sum.sqrt().real;
    };

    function unit_vector() -> float[] {
        var m: float = this.magn();
        var result: float[] = alloc float[this.length];
        var i: int = 0;
        while (i < this.length) {
            result[i] = this[i] / m;
            i++;
        };
        return result;
    };
};

"""
mocha-matvec v3 — Complex Matrix Operations
Changes from v2:
  - eigenvalues()   now returns Complex[] (handles complex roots correctly)
  - eigenvectors()  now returns Complex[][] (each column is one eigenvector)
  - diagonalise()   now returns Complex[][] (diagonal entries are Complex)
  - SVD stays float[][] (AᵀA is symmetric, eigenvalues guaranteed real)
  - Defective matrix detection: errors loudly instead of silently corrupting
  - Fixed free-column detection in null space extraction
  - Fixed V column indexing in SVD

Dependencies: mocha-math (already a dep of mocha-matvec)
"""

// ============================================================
// HELPER: Newton's method sqrt
// ============================================================

function newton_sqrt(x: float) -> float {
    if (x <= 0.0) { return 0.0; };
    var guess: float = x / 2.0;
    if (guess == 0.0) { guess = 0.0001; };
    var i: int = 0;
    while (i < 20) {
        guess = (guess + (x / guess)) / 2.0;
        i++;
    };
    return guess;
};

// ============================================================
// HELPER: Complex dot product of two Complex[] vectors
// Returns the dot product z1·z2 = sum(z1[i] * z2[i])
// (no conjugation — not inner product, just dot)
// ============================================================

function complex_dot(a: Complex[], b: Complex[], n: int) -> Complex {
    var result: Complex = 0.0 + 0im;
    var i: int = 0;
    while (i < n) {
        result = result.add(a[i].mul(b[i]));
        i++;
    };
    return result;
};

// ============================================================
// HELPER: Complex vector norm (magnitude)
// sqrt(sum |z[i]|^2) = sqrt(sum (re^2 + im^2))
// ============================================================

function complex_norm(v: Complex[], n: int) -> float {
    var sum: float = 0.0;
    var i: int = 0;
    while (i < n) {
        var re: float = v[i].real;
        var im: float = v[i].imag;
        sum = sum + (re * re) + (im * im);
        i++;
    };
    return newton_sqrt(sum);
};

// ============================================================
// extend int[][]
// ============================================================

extend int[][] {

    function scalar(n: int) -> int[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: int[][] = alloc int[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] * n;
                j++;
            };
            i++;
        };
        return result;
    };

    function vector(other: int[][]) -> int[][] {
        var m: int = this.rows;
        var n: int = this.cols;
        var p: int = other.cols;
        var result: int[][] = alloc int[m][p];
        var i: int = 0;
        while (i < m) {
            var j: int = 0;
            while (j < p) {
                var sum: int = 0;
                var k: int = 0;
                while (k < n) {
                    sum = sum + (this[i][k] * other[k][j]);
                    k++;
                };
                result[i][j] = sum;
                j++;
            };
            i++;
        };
        return result;
    };

    function hadamard(other: int[][]) -> int[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: int[][] = alloc int[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] * other[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function add(other: int[][]) -> int[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: int[][] = alloc int[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] + other[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function sub(other: int[][]) -> int[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: int[][] = alloc int[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] - other[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function transpose() -> int[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: int[][] = alloc int[cols][rows];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[j][i] = this[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function trace() -> int {
        var result: int = 0;
        var i: int = 0;
        while (i < this.rows) {
            result = result + this[i][i];
            i++;
        };
        return result;
    };

    function det() -> float {
        var n: int = this.rows;
        if (n == 1) {
            return float(this[0][0]);
        };
        if (n == 2) {
            return float((this[0][0] * this[1][1]) - (this[0][1] * this[1][0]));
        };
        var result: float = 0.0;
        var j: int = 0;
        while (j < n) {
            var sub: int[][] = alloc int[n-1][n-1];
            var si: int = 0;
            var ri: int = 1;
            while (ri < n) {
                var sj: int = 0;
                var rj: int = 0;
                while (rj < n) {
                    if (rj != j) {
                        sub[si][sj] = this[ri][rj];
                        sj++;
                    };
                    rj++;
                };
                si++;
                ri++;
            };
            var sign: float = 1.0;
            if (j % 2 != 0) {
                sign = -1.0;
            };
            result = result + (sign * float(this[0][j]) * sub.det());
            j++;
        };
        return result;
    };

    function rank() -> int {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var mat: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                mat[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return mat.rank();
    };

    function minor(ri: int, ci: int) -> int[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: int[][] = alloc int[rows-1][cols-1];
        var si: int = 0;
        var r: int = 0;
        while (r < rows) {
            if (r != ri) {
                var sj: int = 0;
                var c: int = 0;
                while (c < cols) {
                    if (c != ci) {
                        result[si][sj] = this[r][c];
                        sj++;
                    };
                    c++;
                };
                si++;
            };
            r++;
        };
        return result;
    };

    function cofactor() -> float[][] {
        var n: int = this.rows;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.cofactor();
    };

    function inverse() -> float[][] {
        var n: int = this.rows;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.inverse();
    };

    function eigenvalues() -> Complex[] {
        var n: int = this.rows;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.eigenvalues();
    };

    function eigenvectors() -> Complex[][] {
        var n: int = this.rows;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.eigenvectors();
    };

    function diagonalise() -> Complex[][] {
        var n: int = this.rows;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.diagonalise();
    };

    function svd() -> (float[][], 3) {
        var n: int = this.rows;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.svd();
    };

    function singular_values() -> float[] {
        var n: int = this.length;
        var fm: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                fm[i][j] = float(this[i][j]);
                j++;
            };
            i++;
        };
        return fm.singular_values();
};
};


// ============================================================
// extend float[][]
// ============================================================

extend float[][] {

    function scalar(n: float) -> float[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] * n;
                j++;
            };
            i++;
        };
        return result;
    };

    function vector(other: float[][]) -> float[][] {
        var m: int = this.rows;
        var n: int = this.cols;
        var p: int = other.cols;
        var result: float[][] = alloc float[m][p];
        var i: int = 0;
        while (i < m) {
            var j: int = 0;
            while (j < p) {
                var sum: float = 0.0;
                var k: int = 0;
                while (k < n) {
                    sum = sum + (this[i][k] * other[k][j]);
                    k++;
                };
                result[i][j] = sum;
                j++;
            };
            i++;
        };
        return result;
    };

    function hadamard(other: float[][]) -> float[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] * other[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function add(other: float[][]) -> float[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] + other[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function sub(other: float[][]) -> float[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[i][j] = this[i][j] - other[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function transpose() -> float[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: float[][] = alloc float[cols][rows];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                result[j][i] = this[i][j];
                j++;
            };
            i++;
        };
        return result;
    };

    function trace() -> float {
        var result: float = 0.0;
        var i: int = 0;
        while (i < this.rows) {
            result = result + this[i][i];
            i++;
        };
        return result;
    };

    function det() -> float {
        var n: int = this.rows;
        if (n == 1) {
            return this[0][0];
        };
        if (n == 2) {
            return (this[0][0] * this[1][1]) - (this[0][1] * this[1][0]);
        };
        var result: float = 0.0;
        var j: int = 0;
        while (j < n) {
            var sub: float[][] = alloc float[n-1][n-1];
            var si: int = 0;
            var ri: int = 1;
            while (ri < n) {
                var sj: int = 0;
                var rj: int = 0;
                while (rj < n) {
                    if (rj != j) {
                        sub[si][sj] = this[ri][rj];
                        sj++;
                    };
                    rj++;
                };
                si++;
                ri++;
            };
            var sign: float = 1.0;
            if (j % 2 != 0) {
                sign = -1.0;
            };
            result = result + (sign * this[0][j] * sub.det());
            j++;
        };
        return result;
    };

    function rank() -> int {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var mat: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                mat[i][j] = this[i][j];
                j++;
            };
            i++;
        };
        var rank: int = 0;
        var row: int = 0;
        var col: int = 0;
        while (col < cols && row < rows) {
            var pivot: int = -1;
            var pi: int = row;
            while (pi < rows) {
                if (mat[pi][col] != 0.0) {
                    pivot = pi;
                    break;
                };
                pi++;
            };
            if (pivot == -1) {
                col++;
            } else {
                var c2: int = 0;
                while (c2 < cols) {
                    var tmp: float = mat[row][c2];
                    mat[row][c2] = mat[pivot][c2];
                    mat[pivot][c2] = tmp;
                    c2++;
                };
                var ei: int = row + 1;
                while (ei < rows) {
                    var factor: float = mat[ei][col] / mat[row][col];
                    var ej: int = col;
                    while (ej < cols) {
                        mat[ei][ej] = mat[ei][ej] - (factor * mat[row][ej]);
                        ej++;
                    };
                    ei++;
                };
                rank++;
                row++;
                col++;
            };
        };
        return rank;
    };

    function minor(ri: int, ci: int) -> float[][] {
        var rows: int = this.rows;
        var cols: int = this.cols;
        var result: float[][] = alloc float[rows-1][cols-1];
        var si: int = 0;
        var r: int = 0;
        while (r < rows) {
            if (r != ri) {
                var sj: int = 0;
                var c: int = 0;
                while (c < cols) {
                    if (c != ci) {
                        result[si][sj] = this[r][c];
                        sj++;
                    };
                    c++;
                };
                si++;
            };
            r++;
        };
        return result;
    };

    function cofactor() -> float[][] {
        var n: int = this.rows;
        var result: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                var m: float[][] = this.minor(i, j);
                var sign: float = 1.0;
                if ((i + j) % 2 != 0) {
                    sign = -1.0;
                };
                result[i][j] = sign * m.det();
                j++;
            };
            i++;
        };
        return result;
    };

    function inverse() -> float[][] {
        var d: float = this.det();
        var n: int = this.rows;
        var result: float[][] = alloc float[n][n];
        if (d == 0.0) {
            c_print_err("MochaLibError (mocha-matvec): inverse() called on singular matrix (det=0). Matrix is not invertible.");
            c_exit(2);
        };
        var adj: float[][] = this.cofactor().transpose();
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                result[i][j] = adj[i][j] / d;
                j++;
            };
            i++;
        };
        return result;
    };

    // ----------------------------------------------------------
    // EIGENVALUES — 2x2 quadratic formula
    // Returns Complex[] — real eigenvalues have imag=0
    // ----------------------------------------------------------

    function eigenvalues_2x2() -> Complex[] {
        var a: float = this[0][0];
        var b: float = this[0][1];
        var c: float = this[1][0];
        var d: float = this[1][1];
        var tr: float = a + d;
        var det: float = (a * d) - (b * c);
        var disc: float = (tr * tr) - (4.0 * det);
        var result: Complex[] = alloc Complex[2];
        if (disc >= 0.0) {
            var sq_r: float = newton_sqrt(disc);
            result[0] = ((tr + sq_r) / 2.0) + 0im;
            result[1] = ((tr - sq_r) / 2.0) + 0im;
        } else {
            var sq_cmp: float = newton_sqrt(-disc);
            var re: float = tr / 2.0;
            var im: float = sq_cmp / 2.0;
            result[0] = (re + 0im).add(im * 1im);
            result[1] = (re + 0im).add((-im) * 1im);
        };
        return result;
    };

    // ----------------------------------------------------------
    // EIGENVALUES — 3x3 Cardano's method
    // Returns Complex[] — complex roots have nonzero imag
    // disc > 0 case: one real root + complex conjugate pair
    // disc <= 0 case: three real roots (trigonometric method)
    // ----------------------------------------------------------

    function eigenvalues_3x3() -> Complex[] {
        var a00: float = this[0][0];
        var a01: float = this[0][1];
        var a02: float = this[0][2];
        var a10: float = this[1][0];
        var a11: float = this[1][1];
        var a12: float = this[1][2];
        var a20: float = this[2][0];
        var a21: float = this[2][1];
        var a22: float = this[2][2];

        var p: float = -(a00 + a11 + a22);
        var q: float = (a00*a11 - a01*a10) + (a00*a22 - a02*a20) + (a11*a22 - a12*a21);
        var r: float = -this.det();

        var p3: float = p / 3.0;
        var qq: float = q - (p * p / 3.0);
        var rr: float = r + ((2.0 * p * p * p / 27.0) - (p * q / 3.0));

        var disc: float = (qq * qq * qq / 27.0) + (rr * rr / 4.0);

        var PI_f: float = 3.14159265358979;
        var two_pi_3: float = 2.0 * PI_f / 3.0;

        var result: Complex[] = alloc Complex[3];

        if (disc > 0.0) {
            // One real root + complex conjugate pair
            var sqd: float = newton_sqrt(disc);
            var u: float = ((-rr / 2.0) + sqd).cubrot();
            var v: float = ((-rr / 2.0) - sqd).cubrot();
            var t1: float = u + v;

            // Real root
            result[0] = (t1 - p3) + 0im;

            // Complex conjugate pair: -(t1/2) - p3 ± sqrt(3)/2*(u-v)*i
            var re_part: float = -(t1 / 2.0) - p3;
            var im_part: float = (newton_sqrt(3.0) / 2.0) * (u - v);
            result[1] = (re_part + 0im).add(im_part * 1im);
            result[2] = (re_part + 0im).add((-im_part) * 1im);
        } else {
            // Three real roots — trigonometric method
            var neg_q3: float = -qq / 3.0;
            var sq_neg_q3: float = newton_sqrt(neg_q3);
            if (sq_neg_q3 < 0.0001) {
                // Triple root
                var lam: Complex = (-p3) + 0im;
                result[0] = lam;
                result[1] = lam;
                result[2] = lam;
            } else {
                var m2: float = 2.0 * sq_neg_q3;
                var cos_arg: float = (3.0 * rr) / (2.0 * qq * sq_neg_q3);
                if (cos_arg > 1.0)  { cos_arg = 1.0; };
                if (cos_arg < -1.0) { cos_arg = -1.0; };
                var theta: float = cos_arg.inv_cos().real / 3.0;
                result[0] = (m2 * theta.cos(mes=RAD) - p3) + 0im;
                result[1] = (m2 * (theta - two_pi_3).cos(mes=RAD) - p3) + 0im;
                result[2] = (m2 * (theta - 2.0 * two_pi_3).cos(mes=RAD) - p3) + 0im;
            };
        };
        return result;
    };

    // ----------------------------------------------------------
    // EIGENVALUES — QR iteration with Wilkinson shift for n > 3
    // Uses Gram-Schmidt QR decomposition with shift-restore cycle
    // Detects 2x2 subdiagonal blocks for complex conjugate pairs
    // Returns Complex[] — both real and complex eigenvalues correct
    // ----------------------------------------------------------

    function eigenvalues_qr() -> Complex[] {
        var n: int = this.rows;
        var a: float[][] = alloc float[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                a[i][j] = this[i][j];
                j++;
            };
            i++;
        };

        // ── QR iteration with Wilkinson shift ──
        var iter: int = 0;
        while (iter < 200) {

            // Wilkinson shift from bottom-right 2x2
            var shift: float = 0.0;
            if (n > 1) {
                var a00: float = a[n-2][n-2];
                var a01: float = a[n-2][n-1];
                var a10: float = a[n-1][n-2];
                var a11: float = a[n-1][n-1];
                var trace2: float = (a00 + a11) / 2.0;
                var det2: float = (a00 * a11) - (a01 * a10);
                var disc2: float = (trace2 * trace2) - det2;
                var sq: float = 0.0;
                if (disc2 >= 0.0) {
                    sq = newton_sqrt(disc2);
                };
                var e1: float = trace2 + sq;
                var e2: float = trace2 - sq;
                // pick eigenvalue closer to a[n-1][n-1]
                var d1: float = e1 - a11;
                var d2: float = e2 - a11;
                if (d1 < 0.0) { d1 = 0.0 - d1; };
                if (d2 < 0.0) { d2 = 0.0 - d2; };
                if (d1 < d2) {
                    shift = e1;
                } else {
                    shift = e2;
                };
            };

            // Subtract shift from diagonal
            var si: int = 0;
            while (si < n) {
                a[si][si] = a[si][si] - shift;
                si++;
            };

            // QR decomposition via Gram-Schmidt
            var q: float[][] = alloc float[n][n];
            var rmat: float[][] = alloc float[n][n];

            var col: int = 0;
            while (col < n) {
                var v: float[] = alloc float[n];
                var vi: int = 0;
                while (vi < n) {
                    v[vi] = a[vi][col];
                    vi++;
                };

                var prev: int = 0;
                while (prev < col) {
                    var dot: float = 0.0;
                    var di: int = 0;
                    while (di < n) {
                        dot = dot + (v[di] * q[di][prev]);
                        di++;
                    };
                    rmat[prev][col] = dot;
                    var si2: int = 0;
                    while (si2 < n) {
                        v[si2] = v[si2] - (dot * q[si2][prev]);
                        si2++;
                    };
                    prev++;
                };

                var norm_sq: float = 0.0;
                var ni: int = 0;
                while (ni < n) {
                    norm_sq = norm_sq + (v[ni] * v[ni]);
                    ni++;
                };
                var norm: float = newton_sqrt(norm_sq);
                rmat[col][col] = norm;
                var qi: int = 0;
                while (qi < n) {
                    if (norm > 0.0001) {
                        q[qi][col] = v[qi] / norm;
                    } else {
                        q[qi][col] = 0.0;
                    };
                    qi++;
                };
                col++;
            };

            // A = R*Q
            a = rmat.vector(q);

            // Add shift back to diagonal
            var ai: int = 0;
            while (ai < n) {
                a[ai][ai] = a[ai][ai] + shift;
                ai++;
            };

            iter++;
        };

        // ── Extract eigenvalues — handle 2x2 complex blocks ──
        var result: Complex[] = [];  // ← dynamic, push works
        var ri: int = 0;
        var epsilon: float = 0.0001;

        while (ri < n) {
            // Check if this is a 2x2 complex block
            if (ri < n - 1) {
                var subdiag: float = a[ri+1][ri];
                if (subdiag < 0.0) { subdiag = 0.0 - subdiag; };

                if (subdiag > epsilon) {
                    // 2x2 block — extract complex pair
                    var b00: float = a[ri][ri];
                    var b01: float = a[ri][ri+1];
                    var b10: float = a[ri+1][ri];
                    var b11: float = a[ri+1][ri+1];
                    var trace: float = b00 + b11;
                    var det: float = (b00 * b11) - (b01 * b10);
                    var disc: float = (trace * trace) - (4.0 * det);
                    var real_part: float = trace / 2.0;
                    var imag_part: float = newton_sqrt(0.0 - disc) / 2.0;
                    // disc is negative here so 0.0 - disc is positive
                    result.push(real_part + imag_part * 1im);
                    result.push(real_part - imag_part * 1im);
                    ri = ri + 2;
                    continue;
                };
            };

            // Real eigenvalue — just diagonal
            result.push(a[ri][ri] + 0im);
            ri++;
        };

        return result;
    };

    // eigenvalues(): dispatch by size, always returns Complex[]
    function eigenvalues() -> Complex[] {
        var n: int = this.rows;
        if (n == 1) {
            var r: Complex[] = [];
            r.push(this[0][0] + 0im);
            return r;
        };
        if (n == 2) {
            return this.eigenvalues_2x2();
        };
        if (n == 3) {
            return this.eigenvalues_3x3();
        };
        return this.eigenvalues_qr();
    };

    // ----------------------------------------------------------
    // EIGENVECTORS
    // Solves (A - λI)x = 0 over Complex via Gauss-Jordan
    // Works for complex λ: builds Complex[][] augmented matrix
    // Each COLUMN of result is one normalised eigenvector
    //
    // Defective detection: after computing all eigenvectors,
    // checks each pair for linear dependence (|dot| > 0.9999).
    // If found: errors loudly — matrix is not diagonalisable.
    // ----------------------------------------------------------

    function eigenvectors() -> Complex[][] {
        var n: int = this.rows;
        var evals: Complex[] = this.eigenvalues();
        var result: Complex[][] = alloc Complex[n][n];

        var ei: int = 0;
        while (ei < n) {
            var lam: Complex = evals[ei];

            // Build (A - λI) as Complex[][]
            var m: Complex[][] = alloc Complex[n][n];
            var i: int = 0;
            while (i < n) {
                var j: int = 0;
                while (j < n) {
                    var entry: Complex = this[i][j] + 0im;
                    if (i == j) {
                        entry = entry.sub(lam);
                    };
                    m[i][j] = entry;
                    j++;
                };
                i++;
            };

            // Gauss-Jordan on Complex[][] augmented system
            // pivot threshold: |z| > 0.0001
            var row: int = 0;
            var col: int = 0;
            // Track which columns had pivots
            var pivot_cols: int[] = alloc int[n];
            var pc: int = 0;
            while (pc < n) {
                pivot_cols[pc] = -1;
                pc++;
            };
            var pivot_count: int = 0;

            while (col < n && row < n - 1) {
                // Find pivot row: largest |m[pi][col]| for numerical stability
                var best_row: int = -1;
                var best_abs: float = 0.0001;
                var pi: int = row;
                while (pi < n) {
                    var re: float = m[pi][col].real;
                    var im: float = m[pi][col].imag;
                    var ab: float = newton_sqrt(re*re + im*im);
                    if (ab > best_abs) {
                        best_abs = ab;
                        best_row = pi;
                    };
                    pi++;
                };

                if (best_row == -1) {
                    // No pivot in this column — free variable
                    col++;
                } else {
                    // Swap rows
                    var c2: int = 0;
                    while (c2 < n) {
                        var tmp: Complex = m[row][c2];
                        m[row][c2] = m[best_row][c2];
                        m[best_row][c2] = tmp;
                        c2++;
                    };

                    // Scale pivot row so pivot = 1+0im
                    var pivot_val: Complex = m[row][col];
                    var sc: int = col;
                    while (sc < n) {
                        m[row][sc] = m[row][sc].div(pivot_val);
                        sc++;
                    };

                    // Eliminate all other rows
                    var eli: int = 0;
                    while (eli < n) {
                        if (eli != row) {
                            var factor: Complex = m[eli][col];
                            var re2: float = factor.real;
                            var im2: float = factor.imag;
                            var fab: float = newton_sqrt(re2*re2 + im2*im2);
                            if (fab > 0.00001) {
                                var ej: int = col;
                                while (ej < n) {
                                    m[eli][ej] = m[eli][ej].sub(factor.mul(m[row][ej]));
                                    ej++;
                                };
                            };
                        };
                        eli++;
                    };

                    pivot_cols[pivot_count] = col;
                    pivot_count++;
                    row++;
                    col++;
                };
            };

            // Find the free column (first column without a pivot)
            // Build a set of pivot columns for O(n) lookup
            var is_pivot_col: int[] = alloc int[n];
            var ipc: int = 0;
            while (ipc < n) {
                is_pivot_col[ipc] = 0;
                ipc++;
            };
            var pp: int = 0;
            while (pp < pivot_count) {
                if (pivot_cols[pp] >= 0) {
                    is_pivot_col[pivot_cols[pp]] = 1;
                };
                pp++;
            };

            var free_col: int = n - 1;
            var fc: int = 0;
            while (fc < n) {
                if (is_pivot_col[fc] == 0) {
                    free_col = fc;
                    break;
                };
                fc++;
            };

            // Build null space vector: set free variable = 1, back-substitute
            var vec: Complex[] = alloc Complex[n];
            var vi: int = 0;
            while (vi < n) {
                vec[vi] = 0.0 + 0im;
                vi++;
            };
            vec[free_col] = 1.0 + 0im;

            // For each pivot row (in reverse), solve for pivot variable
            var pr2: int = pivot_count - 1;
            while (pr2 >= 0) {
                var pcol: int = pivot_cols[pr2];
                if (pcol >= 0 && pcol != free_col) {
                    // m[pr2][pcol] = 1 (after scaling), so:
                    // vec[pcol] = -sum(m[pr2][j] * vec[j]) for j != pcol
                    var sum: Complex = 0.0 + 0im;
                    var bj: int = 0;
                    while (bj < n) {
                        if (bj != pcol) {
                            sum = sum.add(m[pr2][bj].mul(vec[bj]));
                        };
                        bj++;
                    };
                    vec[pcol] = (0.0 + 0im).sub(sum);
                };
                pr2--;
            };

            // Normalise
            var norm: float = complex_norm(vec, n);
            if (norm < 0.0001) { norm = 1.0; };

            var si: int = 0;
            while (si < n) {
                var re3: float = vec[si].real / norm;
                var im3: float = vec[si].imag / norm;
                result[si][ei] = (re3 + 0im).add(im3 * 1im);
                si++;
            };

            ei++;
        };

        // ----------------------------------------------------------
        // Defective matrix check:
        // For each pair of eigenvectors (columns i, j), compute
        // |dot(vi, vj)|. If two eigenvectors are parallel (|dot| > 0.9999)
        // the matrix is defective — not diagonalisable.
        // ----------------------------------------------------------
        var ci: int = 0;
        while (ci < n) {
            var cj: int = ci + 1;
            while (cj < n) {
                // Extract columns ci and cj
                var vi2: Complex[] = alloc Complex[n];
                var vj: Complex[] = alloc Complex[n];
                var ri2: int = 0;
                while (ri2 < n) {
                    vi2[ri2] = result[ri2][ci];
                    vj[ri2] = result[ri2][cj];
                    ri2++;
                };
                var dot: Complex = complex_dot(vi2, vj, n);
                var dot_re: float = dot.real;
                var dot_im: float = dot.imag;
                var dot_abs: float = newton_sqrt(dot_re*dot_re + dot_im*dot_im);
                if (dot_abs > 0.9999) {
                    c_print_err("MochaMatVec: matrix is defective (eigenvectors are NOT linearly independent). Not diagonalisable even over C. Use Jordan normal form.");
                    c_exit(2);
                };
                cj++;
            };
            ci++;
        };

        return result;
    };

    function eigenvectors_relaxed() -> Complex[][] {
        var n: int = this.rows;
        var evals: Complex[] = this.eigenvalues();
        var result: Complex[][] = alloc Complex[n][n];

        var ei: int = 0;
        while (ei < n) {
            var lam: Complex = evals[ei];

            // Build (A - λI) as Complex[][]
            var m: Complex[][] = alloc Complex[n][n];
            var i: int = 0;
            while (i < n) {
                var j: int = 0;
                while (j < n) {
                    var entry: Complex = this[i][j] + 0im;
                    if (i == j) {
                        entry = entry.sub(lam);
                    };
                    m[i][j] = entry;
                    j++;
                };
                i++;
            };

            // Gauss-Jordan on Complex[][] augmented system
            // pivot threshold: |z| > 0.0001
            var row: int = 0;
            var col: int = 0;
            // Track which columns had pivots
            var pivot_cols: int[] = alloc int[n];
            var pc: int = 0;
            while (pc < n) {
                pivot_cols[pc] = -1;
                pc++;
            };
            var pivot_count: int = 0;

            while (col < n && row < n - 1) {
                // Find pivot row: largest |m[pi][col]| for numerical stability
                var best_row: int = -1;
                var best_abs: float = 0.0001;
                var pi: int = row;
                while (pi < n) {
                    var re: float = m[pi][col].real;
                    var im: float = m[pi][col].imag;
                    var ab: float = newton_sqrt(re*re + im*im);
                    if (ab > best_abs) {
                        best_abs = ab;
                        best_row = pi;
                    };
                    pi++;
                };

                if (best_row == -1) {
                    // No pivot in this column — free variable
                    col++;
                } else {
                    // Swap rows
                    var c2: int = 0;
                    while (c2 < n) {
                        var tmp: Complex = m[row][c2];
                        m[row][c2] = m[best_row][c2];
                        m[best_row][c2] = tmp;
                        c2++;
                    };

                    // Scale pivot row so pivot = 1+0im
                    var pivot_val: Complex = m[row][col];
                    var sc: int = col;
                    while (sc < n) {
                        m[row][sc] = m[row][sc].div(pivot_val);
                        sc++;
                    };

                    // Eliminate all other rows
                    var eli: int = 0;
                    while (eli < n) {
                        if (eli != row) {
                            var factor: Complex = m[eli][col];
                            var re2: float = factor.real;
                            var im2: float = factor.imag;
                            var fab: float = newton_sqrt(re2*re2 + im2*im2);
                            if (fab > 0.00001) {
                                var ej: int = col;
                                while (ej < n) {
                                    m[eli][ej] = m[eli][ej].sub(factor.mul(m[row][ej]));
                                    ej++;
                                };
                            };
                        };
                        eli++;
                    };

                    pivot_cols[pivot_count] = col;
                    pivot_count++;
                    row++;
                    col++;
                };
            };

            // Find the free column (first column without a pivot)
            // Build a set of pivot columns for O(n) lookup
            var is_pivot_col: int[] = alloc int[n];
            var ipc: int = 0;
            while (ipc < n) {
                is_pivot_col[ipc] = 0;
                ipc++;
            };
            var pp: int = 0;
            while (pp < pivot_count) {
                if (pivot_cols[pp] >= 0) {
                    is_pivot_col[pivot_cols[pp]] = 1;
                };
                pp++;
            };

            var free_col: int = n - 1;
            var fc: int = 0;
            while (fc < n) {
                if (is_pivot_col[fc] == 0) {
                    free_col = fc;
                    break;
                };
                fc++;
            };

            // Build null space vector: set free variable = 1, back-substitute
            var vec: Complex[] = alloc Complex[n];
            var vi: int = 0;
            while (vi < n) {
                vec[vi] = 0.0 + 0im;
                vi++;
            };
            vec[free_col] = 1.0 + 0im;

            // For each pivot row (in reverse), solve for pivot variable
            var pr2: int = pivot_count - 1;
            while (pr2 >= 0) {
                var pcol: int = pivot_cols[pr2];
                if (pcol >= 0 && pcol != free_col) {
                    // m[pr2][pcol] = 1 (after scaling), so:
                    // vec[pcol] = -sum(m[pr2][j] * vec[j]) for j != pcol
                    var sum: Complex = 0.0 + 0im;
                    var bj: int = 0;
                    while (bj < n) {
                        if (bj != pcol) {
                            sum = sum.add(m[pr2][bj].mul(vec[bj]));
                        };
                        bj++;
                    };
                    vec[pcol] = (0.0 + 0im).sub(sum);
                };
                pr2--;
            };

            // Normalise
            var norm: float = complex_norm(vec, n);
            if (norm < 0.0001) { norm = 1.0; };

            var si: int = 0;
            while (si < n) {
                var re3: float = vec[si].real / norm;
                var im3: float = vec[si].imag / norm;
                result[si][ei] = (re3 + 0im).add(im3 * 1im);
                si++;
            };

            ei++;
        };
        return result;
    };

    // ----------------------------------------------------------
    // DIAGONALISE
    // Returns Complex[][] diagonal matrix D where D[i][i] = λᵢ
    // ----------------------------------------------------------

    function diagonalise() -> Complex[][] {
        var n: int = this.rows;
        var evals: Complex[] = this.eigenvalues();
        var result: Complex[][] = alloc Complex[n][n];
        var i: int = 0;
        while (i < n) {
            var j: int = 0;
            while (j < n) {
                if (i == j) {
                    result[i][j] = evals[i];
                } else {
                    result[i][j] = 0.0 + 0im;
                };
                j++;
            };
            i++;
        };
        return result;
    };

    // ----------------------------------------------------------
    // SVD — Singular Value Decomposition
    // A = U * Σ * Vᵀ
    // AᵀA is real symmetric → eigenvalues guaranteed real
    // We take .real off Complex eigenvalues of AᵀA safely
    // V  = eigenvectors of AᵀA  (real, cols of result)
    // Σ  = sqrt(eigenvalues of AᵀA) on diagonal
    // U  = A*vᵢ/σᵢ
    // Returns (U, Σ, V) all float[][]
    // ----------------------------------------------------------

    function svd() -> (float[][], 3) {
        var rows: int = this.rows;
        var cols: int = this.cols;

        var at: float[][] = this.transpose();
        var ata: float[][] = at.vector(this);

        // AᵀA eigenvalues are always real — extract .real from Complex[]
        var ata_evals_c: Complex[] = ata.eigenvalues();
        var ata_evals: float[] = alloc float[cols];
        var ei: int = 0;
        while (ei < cols) {
            ata_evals[ei] = ata_evals_c[ei].real;
            ei++;
        };

        // V: eigenvectors of AᵀA — also real since AᵀA is symmetric
        // Extract real parts from Complex[][] result
        var v_c: Complex[][] = ata.eigenvectors_relaxed();
        var v: float[][] = alloc float[cols][cols];
        var vi: int = 0;
        while (vi < cols) {
            var vj: int = 0;
            while (vj < cols) {
                v[vi][vj] = v_c[vi][vj].real;
                vj++;
            };
            vi++;
        };

        var svd_k: int = rows;
        if (cols < rows) { svd_k = cols; };

        var sigma: float[][] = alloc float[rows][cols];
        var i: int = 0;
        while (i < rows) {
            var j: int = 0;
            while (j < cols) {
                sigma[i][j] = 0.0;
                j++;
            };
            i++;
        };

        i = 0;
        while (i < svd_k) {
            var ev: float = ata_evals[i];
            if (ev > 0.0) {
                sigma[i][i] = newton_sqrt(ev);
            } else {
                sigma[i][i] = 0.0;
            };
            i++;
        };

        // U: columns are A*vᵢ/σᵢ
        // v[row][col] — col i of V is v[0][i], v[1][i], ... v[cols-1][i]
        var u: float[][] = alloc float[rows][rows];
        i = 0;
        while (i < rows) {
            var ji: int = 0;
            while (ji < rows) {
                u[i][ji] = 0.0;
                ji++;
            };
            i++;
        };

        var ui: int = 0;
        while (ui < svd_k) {
            var sig: float = sigma[ui][ui];
            if (sig > 0.0001) {
                var r: int = 0;
                while (r < rows) {
                    var sum: float = 0.0;
                    var c: int = 0;
                    while (c < cols) {
                        // v[c][ui] = column ui of V, row c
                        sum = sum + (this[r][c] * v[c][ui]);
                        c++;
                    };
                    u[r][ui] = sum / sig;
                    r++;
                };
            } else {
                u[ui][ui] = 1.0;
            };
            ui++;
        };

        return (u, sigma, v);
    };

    function singular_values() -> float[] {
        var result: (float[][]) = this.svd();
        var sigma: float[][] = result#1;
        var rows: int = sigma.length;
        var cols: int = sigma[0].length;
        var size: int = rows;
        if (cols < rows) { size = cols; };
        var vals: float[] = [];
        var i: int = 0;
        while (i < size) {
            if (sigma[i][i] > 0.0) {
                vals.push(sigma[i][i]);
            };
            i++;
        };
        return vals;
    };
};