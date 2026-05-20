"""
   MochaMath v0.4 — Mocha Standard Math Library
   Save as: lib/mocha-math.mch
   Compile with: mocha --lib lib/mocha-math.mch
"""

// =============================================
// CONSTANTS
// =============================================

const PI: float = 3.14159265358979323846;
const E: float = 2.71828182845904523536;
const TAU: float = 6.28318530717958647692;
const PHI: float = 1.61803398874989484820;
const INF: float = 999999999999999.0;

// Measurement units for trig functions
const RAD: int = 0;
const DEG: int = 1;

// =============================================
// ROUNDING — pure Mocha 🐶
// =============================================

function abs(x: float) -> float {
    if (x < 0.0) {
        return x * -1.0;
    };
    return x;
};

function rdown(x: float) -> float {
    var truncated: float = float(int(x));
    if (x < 0.0 && truncated != x) {
        return truncated - 1.0;
    };
    return truncated;
};

function rup(x: float) -> float {
    var truncated: float = float(int(x));
    if (x > 0.0 && truncated != x) {
        return truncated + 1.0;
    };
    return truncated;
};

function round(x: float) -> float {
    if (x >= 0.0) {
        return rdown(x + 0.5);
    };
    return rup(x - 0.5);
};

// =============================================
// POWERS
// =============================================

function fast_pow(base: float, exp: int) -> float native mocha_math_fast_pow;
function c_pow(base: float, exp: float) -> float native mocha_math_c_pow;
function complex_pow(base: Complex, exp: float) -> Complex native mocha_math_complex_pow;

// =========================================================
// TRIG, ROOTS, LOGS, CALC, and LIMS — float extension methods
// mes=RAD for radians, mes=DEG for degrees
// =========================================================

extend float {
    function sin(mes: int) -> float native mocha_ext_float_sin;
    function cos(mes: int) -> float native mocha_ext_float_cos;
    function tan(mes: int) -> float native mocha_ext_float_tan;
    function inv_sin() -> Complex native mocha_ext_float_inv_sin;
    function inv_cos() -> Complex native mocha_ext_float_inv_cos;
    function inv_tan() -> float native mocha_ext_float_inv_tan;
    function sqrt() -> Complex native mocha_ext_float_sqrt;
    function cubrot() -> float native mocha_ext_float_cubrot;
    function log() -> Complex native mocha_ext_float_log;
    function log2() -> Complex native mocha_ext_float_log2;
    function log10() -> Complex native mocha_ext_float_log10;
    function derivative(f: lambda) -> float native mocha_math_derivative;
    function limit(f: lambda) -> float native mocha_math_limit;
    function erf() -> float native mocha_wrap_erf;
};

// integral needs a and b — standalone function
function integral(f: lambda, a: float, b: float) -> float native mocha_math_integral;

// limit at infinity — no point needed
function limit_inf(f: lambda) -> float native mocha_math_limit_inf;

function rand_int(min: int, max: int) -> int native mocha_rand_int;
function rand_float(min: float, max: float) -> float native mocha_rand_float;
function rand_seed(seed: int) -> null native mocha_rand_seed;

// ── BCrypt RNG — cryptographically secure ──
function bcrypt_rand_int(min: int, max: int) -> int native mocha_bcrypt_rand_int;
function bcrypt_rand_float(min: float, max: float) -> float native mocha_bcrypt_rand_float;
function bcrypt_rand_unit() -> float native mocha_bcrypt_rand_unit;
function bcrypt_rand_ints(min: int, max: int, count: int) -> str native mocha_bcrypt_rand_ints;
function bcrypt_rand_bool() -> bool native mocha_bcrypt_rand_bool;
function bcrypt_rand_seed() -> int native mocha_bcrypt_rand_seed;