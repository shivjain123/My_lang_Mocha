"""
mocha-SymCha v0.3 — Symbolic Mathematics Library
Pure Mocha 🐶 (almost)
"""

from "mocha-math" import *;

function c_sin(x: float) -> float native mocha_wrap_sin;
function c_cos(x: float) -> float native mocha_wrap_cos;
function c_log(x: float) -> float native mocha_wrap_log;
function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;
// =============================================
// NODE KIND CONSTANTS
// =============================================

const NUM: int = 0;
const VAR: int = 1;
const ADD: int = 2;
const SUB: int = 3;
const MUL: int = 4;
const DIV: int = 5;
const POW: int = 6;
const NEG: int = 7;
const SIN: int = 8;
const COS: int = 9;
const LN:  int = 10;
const EXP: int = 11;


// =============================================
// EXPRESSION NODE
// =============================================

class Expr {
    var kind:  int;
    var value: float;
    var name:  str;
    var left:  Expr;
    var right: Expr;

    function constructor(kind: int, value: float, name: str, left: Expr, right: Expr) -> null {
        this.kind  = kind;
        this.value = value;
        this.name  = name;
        this.left  = left;
        this.right = right;
    };
};


// =============================================
// SMART CONSTRUCTORS
// =============================================

function num(v: float) -> Expr {
    return Expr(NUM, v, "", null, null);
};

function var_e(name: str) -> Expr {
    return Expr(VAR, 0.0, name, null, null);
};

function add(a: Expr, b: Expr) -> Expr {
    return Expr(ADD, 0.0, "", a, b);
};

function sub(a: Expr, b: Expr) -> Expr {
    return Expr(SUB, 0.0, "", a, b);
};

function mul(a: Expr, b: Expr) -> Expr {
    return Expr(MUL, 0.0, "", a, b);
};

function div_e(a: Expr, b: Expr) -> Expr {
    return Expr(DIV, 0.0, "", a, b);
};

function pow_e(base: Expr, exp: Expr) -> Expr {
    return Expr(POW, 0.0, "", base, exp);
};

function neg(a: Expr) -> Expr {
    return Expr(NEG, 0.0, "", a, null);
};

function sin_e(a: Expr) -> Expr {
    return Expr(SIN, 0.0, "", a, null);
};

function cos_e(a: Expr) -> Expr {
    return Expr(COS, 0.0, "", a, null);
};

function ln_e(a: Expr) -> Expr {
    return Expr(LN, 0.0, "", a, null);
};

function exp_e(a: Expr) -> Expr {
    return Expr(EXP, 0.0, "", a, null);
};


// =============================================
// SYMBOLIC DIFFERENTIATION
// sym_diff_pass(expr, "x") → d/dx of expr
// Rules: constant, variable, sum, product,
//        quotient, power, log diff, trig, ln, exp
// =============================================

function sym_diff_pass(e: Expr, var_name: str) -> Expr {
    match(e.kind) {

        // d/dx(c) = 0
        case NUM: return num(0.0);

        // d/dx(x) = 1, d/dx(y) = 0
        case VAR:
            if (e.name == var_name) {
                return num(1.0);
            };
            return num(0.0);

        // d/dx(f + g) = f' + g'
        case ADD:
            return add(sym_diff(e.left, var_name), sym_diff(e.right, var_name));

        // d/dx(f - g) = f' - g'
        case SUB:
            return sub(sym_diff(e.left, var_name), sym_diff(e.right, var_name));

        // d/dx(f * g) = f'g + fg'  (product rule)
        case MUL:
            return add(
                mul(sym_diff(e.left, var_name), e.right),
                mul(e.left, sym_diff(e.right, var_name))
            );

        // d/dx(f / g) = (f'g - fg') / g²  (quotient rule)
        case DIV:
            return div_e(
                sub(
                    mul(sym_diff(e.left, var_name), e.right),
                    mul(e.left, sym_diff(e.right, var_name))
                ),
                mul(e.right, e.right)
            );

        // d/dx(f^n) = n*f^(n-1)*f'               (power rule, constant exponent)
        // d/dx(f^g) = f^g*(g'*ln(f) + g*f'/f)    (logarithmic diff, variable exponent)
        case POW:
            if (e.right.kind == NUM) {
                return mul(mul(e.right, pow_e(e.left, sub(e.right, num(1.0)))), sym_diff(e.left, var_name));
            };
            var ld_f: Expr = e.left;
            var ld_g: Expr = e.right;
            var ld_base: Expr = pow_e(ld_f, ld_g);
            var ld_fp: Expr = sym_diff(ld_f, var_name);
            var ld_gp: Expr = sym_diff(ld_g, var_name);
            var ld_term1: Expr = mul(ld_gp, ln_e(ld_f));
            var ld_term2: Expr = div_e(mul(ld_g, ld_fp), ld_f);
            var ld_result: Expr = mul(ld_base, add(ld_term1, ld_term2));
            return ld_result;

        // d/dx(-f) = -f'
        case NEG:
            return neg(sym_diff(e.left, var_name));

        // d/dx(sin(f)) = cos(f) * f'
        case SIN:
            return mul(cos_e(e.left), sym_diff(e.left, var_name));

        // d/dx(cos(f)) = -sin(f) * f'
        case COS:
            return neg(mul(sin_e(e.left), sym_diff(e.left, var_name)));

        // d/dx(ln(f)) = f' / f
        case LN:
            return div_e(sym_diff(e.left, var_name), e.left);

        // d/dx(e^f) = e^f * f'
        case EXP:
            return mul(exp_e(e.left), sym_diff(e.left, var_name));

        default: return num(0.0);
    };
};

function sym_grad(e: Expr, var1: str, var2: str) -> Expr[] {
    var result: Expr[2] = alloc Expr[2];
    result[0] = sym_diff(e, var1);
    result[1] = sym_diff(e, var2);
    return result;
};

function sym_partial2(e: Expr, var1: str, var2: str) -> Expr {
    return sym_diff(sym_diff(e, var1), var2);
};

// =============================================
// UNICODE SUPERSCRIPT HELPER
// Converts digit string to superscript Unicode
// e.g. "23" → "²³", "-1" → "⁻¹"
// =============================================

function to_superscript(s: str) -> str {
    var result: str = "";
    var i: int = 0;
    while (i < s.length) {
        var ch: str = s.charAt(i);
        if (ch == "0") { result = result + "⁰"; };
        if (ch == "1") { result = result + "¹"; };
        if (ch == "2") { result = result + "²"; };
        if (ch == "3") { result = result + "³"; };
        if (ch == "4") { result = result + "⁴"; };
        if (ch == "5") { result = result + "⁵"; };
        if (ch == "6") { result = result + "⁶"; };
        if (ch == "7") { result = result + "⁷"; };
        if (ch == "8") { result = result + "⁸"; };
        if (ch == "9") { result = result + "⁹"; };
        if (ch == "-") { result = result + "⁻"; };
        if (ch == "+") { result = result + "⁺"; };
        if (ch == "(") { result = result + "⁽"; };
        if (ch == ")") { result = result + "⁾"; };
        i = i + 1;
    };
    return result;
};


// =============================================
// SYMBOLIC PRINT
// sym_print(expr) → human readable Unicode string
// e.g. x^2 + 3x + 1, cos(x), 2^x·ln(2)
// =============================================

// =============================================
// PRECEDENCE HELPER
// Higher number = tighter binding
// =============================================
function sym_precedence(e: Expr) -> int {
    if (e.kind == NUM) { return 5; };
    if (e.kind == VAR) { return 5; };
    if (e.kind == SIN) { return 5; };
    if (e.kind == COS) { return 5; };
    if (e.kind == LN)  { return 5; };
    if (e.kind == EXP) { return 5; };
    if (e.kind == POW) { return 4; };
    if (e.kind == MUL) { return 3; };
    if (e.kind == DIV) { return 3; };
    if (e.kind == NEG) { return 2; };
    if (e.kind == ADD) { return 1; };
    if (e.kind == SUB) { return 1; };
    return 0;
};

// Wrap in parens if child has lower precedence than parent
function sym_print_parens(e: Expr, parent_prec: int) -> str {
    if (sym_precedence(e) < parent_prec) {
        return "(" + sym_print(e) + ")";
    };
    return sym_print(e);
};

// =============================================
// SYMBOLIC PRINT — precedence aware
// =============================================
function sym_print(e: Expr) -> str {
    match(e.kind) {

        case NUM:
            if (e.value == float(int(e.value))) {
                return str(int(e.value));
            };
            return str(e.value);

        case VAR:
            return e.name;

        case ADD:
            // a + (negative_num * ...) → print as "a - b"
            if (e.right.kind == MUL && e.right.left.kind == NUM) {
                if (e.right.left.value < 0.0) {
                    var pos_node: Expr = mul(num(0.0 - e.right.left.value), e.right.right);
                    return sym_print(e.left) + " - " + sym_print(pos_node);
                };
            };
            // a + (-b) → print as "a - b"  
            if (e.right.kind == NEG) {
                return sym_print(e.left) + " - " + sym_print(e.right.left);
            };
            return sym_print(e.left) + " + " + sym_print(e.right);

        case SUB:
            // right side needs parens if ADD/SUB to avoid ambiguity
            var sub_l: str = sym_print(e.left);
            var sub_r: str = sym_print_parens(e.right, 2);
            return sub_l + " - " + sub_r;

        case MUL:
            var ml: str = sym_print_parens(e.left, 3);
            var mr: str = sym_print_parens(e.right, 3);
            // Eat · when left is NUM and right is VAR or POW (3x, 3x²)
            if (e.left.kind == NUM && (e.right.kind == VAR || e.right.kind == POW)) {
                return sym_print(e.left) + sym_print(e.right);
            };
            // Eat · when both VAR/POW (xy, x²y)
            if ((e.left.kind == VAR || e.left.kind == POW) && (e.right.kind == VAR || e.right.kind == POW)) {
                return ml + mr;
            };
            return ml + "·" + mr;

        case DIV:
            // both sides need parens if ADD/SUB
            var dl: str = sym_print_parens(e.left, 3);
            var dr: str = sym_print_parens(e.right, 3);
            return dl + "/" + dr;

        case POW:
            // base needs parens if ADD/SUB/MUL/DIV
            var pb: str = sym_print_parens(e.left, 4);
            var pe: str = sym_print(e.right);
            if (e.right.kind == NUM) {
                return pb + to_superscript(pe);
            };
            return pb + "^" + pe;

        case NEG:
            // inner needs parens if ADD/SUB
            var ni: str = sym_print_parens(e.left, 2);
            return "-" + ni;

        case SIN:
            return "sin(" + sym_print(e.left) + ")";

        case COS:
            return "cos(" + sym_print(e.left) + ")";

        case LN:
            return "ln(" + sym_print(e.left) + ")";

        case EXP:
            return "exp(" + sym_print(e.left) + ")";

        default: return "?";
    };
};


// =============================================
// SIMPLIFICATION HELPERS
// =============================================

function is_num(e: Expr, v: float) -> bool {
    return e.kind == NUM && e.value == v;
};

function is_zero(e: Expr) -> bool {
    return is_num(e, 0.0);
};

function is_one(e: Expr) -> bool {
    return is_num(e, 1.0);
};


// =============================================
// SYMBOLIC SIMPLIFICATION
// sym_simplify(expr) → simplified expression
// Rules:
//   x + 0 = x,  0 + x = x
//   x - 0 = x,  0 - x = -x
//   x * 0 = 0,  x * 1 = x
//   x / 1 = x,  x / x = 1
//   x ^ 0 = 1,  x ^ 1 = x
//   -(-x) = x
//   constant folding for NUM op NUM
// =============================================

function sym_equal(a: Expr, b: Expr) -> bool {

    // POW x^1 == x
    if (a.kind == POW && is_one(a.right)) { return sym_equal(a.left, b); };
    if (b.kind == POW && is_one(b.right)) { return sym_equal(a, b.left); };

    // MUL 1*x == x
    if (a.kind == MUL && is_one(a.left))  { return sym_equal(a.right, b); };
    if (a.kind == MUL && is_one(a.right)) { return sym_equal(a.left, b); };
    if (b.kind == MUL && is_one(b.left))  { return sym_equal(a, b.right); };
    if (b.kind == MUL && is_one(b.right)) { return sym_equal(a, b.left); };

    // NEG(-(-x)) == x
    if (a.kind == NEG && a.left.kind == NEG) { return sym_equal(a.left.left, b); };
    if (b.kind == NEG && b.left.kind == NEG) { return sym_equal(a, b.left.left); };

    // SUB as ADD of NEG: a - b == a + (-b)
    if (a.kind == SUB && b.kind == ADD) {
        if (sym_equal(a.left, b.left) && b.right.kind == NEG) {
            return sym_equal(a.right, b.right.left);
        };
    };
    if (a.kind == ADD && b.kind == SUB) {
        if (sym_equal(a.left, b.left) && a.right.kind == NEG) {
            return sym_equal(a.right.left, b.right);
        };
    };

    if (a.kind != b.kind) { return false; };

    // NUM: compare values
    if (a.kind == NUM) { return a.value == b.value; };

    // VAR: compare names
    if (a.kind == VAR) { return a.name == b.name; };

    // Unary nodes
    if (a.kind == NEG || a.kind == SIN || a.kind == COS || a.kind == LN || a.kind == EXP) {
        return sym_equal(a.left, b.left);
    };

    // Binary nodes — structural
    var structural: bool = sym_equal(a.left, b.left) && sym_equal(a.right, b.right);
    if (structural) { return true; };

    // Commutative check for ADD and MUL
    if (a.kind == ADD || a.kind == MUL) {
        if (sym_equal(a.left, b.right) && sym_equal(a.right, b.left)) {
            return true;
        };
    };

    // Associativity for ADD and MUL: (a+b)+c == a+(b+c)
    if (a.kind == ADD || a.kind == MUL) {
        if (a.left.kind == a.kind && b.right.kind == b.kind) {
            if (sym_equal(a.left.left, b.left) &&
                sym_equal(a.left.right, b.right.left) &&
                sym_equal(a.right, b.right.right)) {
                return true;
            };
        };
    };

    return false;
};

function sym_simplify(e: Expr) -> Expr {
    match(e.kind) {

        case NUM: return e;
        case VAR: return e;

        case ADD:
            var al: Expr = sym_simplify(e.left);
            var ar: Expr = sym_simplify(e.right);
            if (al.kind == NUM && ar.kind == NUM) { return num(al.value + ar.value); };
            if (is_zero(ar)) { return al; };
            if (is_zero(al)) { return ar; };
            // sin²(x) + cos²(x) → 1
            if (al.kind == POW && ar.kind == POW) {
                if (is_num(al.right, 2.0) && is_num(ar.right, 2.0)) {
                    if (al.left.kind == SIN && ar.left.kind == COS) {
                        if (sym_equal(al.left.left, ar.left.left)) {
                            return num(1.0);
                        };
                    };
                    if (al.left.kind == COS && ar.left.kind == SIN) {
                        if (sym_equal(al.left.left, ar.left.left)) {
                            return num(1.0);
                        };
                    };
                };
            };
            return add(al, ar);

        case SUB:
            var sl: Expr = sym_simplify(e.left);
            var sr: Expr = sym_simplify(e.right);
            if (sl.kind == NUM && sr.kind == NUM) { return num(sl.value - sr.value); };
            if (is_zero(sr)) { return sl; };
            if (is_zero(sl)) { return neg(sr); };
            if (sym_equal(sl, sr)) { return num(0.0); };
            // 1 - sin²(x) → cos²(x)
            if (is_one(sl) && sr.kind == POW && is_num(sr.right, 2.0) && sr.left.kind == SIN) {
                return pow_e(cos_e(sr.left.left), num(2.0));
            };
            // 1 - cos²(x) → sin²(x)
            if (is_one(sl) && sr.kind == POW && is_num(sr.right, 2.0) && sr.left.kind == COS) {
                return pow_e(sin_e(sr.left.left), num(2.0));
            };
            // sin²(x) - 1 → -cos²(x)
            if (sl.kind == POW && is_num(sl.right, 2.0) && sl.left.kind == SIN && is_one(sr)) {
                return neg(pow_e(cos_e(sl.left.left), num(2.0)));
            };
            // cos²(x) - 1 → -sin²(x)
            if (sl.kind == POW && is_num(sl.right, 2.0) && sl.left.kind == COS && is_one(sr)) {
                return neg(pow_e(sin_e(sl.left.left), num(2.0)));
            };
            return sub(sl, sr);

        case MUL:
            var ml: Expr = sym_simplify(e.left);
            var mr: Expr = sym_simplify(e.right);
            if (ml.kind == NUM && mr.kind == NUM) { return num(ml.value * mr.value); };
            if (is_zero(ml) || is_zero(mr)) { return num(0.0); };
            if (is_one(mr)) { return ml; };
            if (is_one(ml)) { return mr; };
            return mul(ml, mr);

        case DIV:
            var dl: Expr = sym_simplify(e.left);
            var dr: Expr = sym_simplify(e.right);
            if (dl.kind == NUM && dr.kind == NUM) { return num(dl.value / dr.value); };
            if (is_zero(dl)) { return num(0.0); };
            if (is_one(dr)) { return dl; };
            // f/f = 1
            if (sym_equal(dl, dr)) { return num(1.0); };
            return div_e(dl, dr);

        case POW:
            var pl: Expr = sym_simplify(e.left);
            var pr: Expr = sym_simplify(e.right);
            if (pl.kind == NUM && pr.kind == NUM) {
                return num(c_pow(pl.value, pr.value));
            };
            if (is_one(pr)) { return pl; };
            if (is_zero(pr)) { return num(1.0); };
            return pow_e(pl, pr);

        case NEG:
            var nl: Expr = sym_simplify(e.left);
            if (nl.kind == NEG) { return nl.left; };
            if (is_zero(nl)) { return num(0.0); };
            return neg(nl);

        case SIN:
            var sin_inner: Expr = sym_simplify(e.left);
            if (sin_inner.kind == NUM) {
                var pi: float = 3.14159265358979;
                if (sin_inner.value == pi / 2.0) { return num(1.0); };
                if (sin_inner.value == pi) { return num(0.0); };
            };
            // sin(-x) → -sin(x)
            if (sin_inner.kind == NEG) {
                return neg(sin_e(sin_inner.left));
            };
            // sin(0) → 0
            if (is_zero(sin_inner)) { return num(0.0); };
            return sin_e(sin_inner);

        case COS:
            var cos_inner: Expr = sym_simplify(e.left);
            if (cos_inner.kind == NUM) {
                var pi2: float = 3.14159265358979;
                if (cos_inner.value == pi2 / 2.0) { return num(0.0); };
                if (cos_inner.value == pi2) { return num(-1.0); };
            };
            // cos(-x) → cos(x)
            if (cos_inner.kind == NEG) {
                return cos_e(cos_inner.left);
            };
            // cos(0) → 1
            if (is_zero(cos_inner)) { return num(1.0); };
            return cos_e(cos_inner);

        case LN:
            var ln_inner: Expr = sym_simplify(e.left);
            // ln(1) → 0
            if (is_one(ln_inner)) { return num(0.0); };
            // ln(e^x) → x
            if (ln_inner.kind == EXP) { return ln_inner.left; };
            // ln(x*y) → ln(x) + ln(y)
            if (ln_inner.kind == MUL) {
                return add(ln_e(ln_inner.left), ln_e(ln_inner.right));
            };
            // ln(x/y) → ln(x) - ln(y)
            if (ln_inner.kind == DIV) {
                return sub(ln_e(ln_inner.left), ln_e(ln_inner.right));
            };
            // ln(x^n) → n*ln(x)  (general case, already handles most)
            if (ln_inner.kind == POW) {
                // ln(e^x) → x  (when base is e as a literal number)
                var e_val: float = 2.71828182845904;
                if (ln_inner.left.kind == NUM) {
                    if (ln_inner.left.value == e_val) {
                        return ln_inner.right;
                    };
                };
                // ln(a^b) → b*ln(a)  (general)
                return mul(ln_inner.right, ln_e(ln_inner.left));
            };
            return ln_e(ln_inner);

        case EXP:
            var exp_inner: Expr = sym_simplify(e.left);
            // e^0 → 1
            if (is_zero(exp_inner)) { return num(1.0); };
            // e^1 → e (as num)
            if (is_one(exp_inner)) { return num(2.71828182845904); };
            // e^ln(x) → x
            if (exp_inner.kind == LN) { return exp_inner.left; };
            // e^(ln(x) + ln(y)) → x*y  (exp distributes over add of logs)
            if (exp_inner.kind == ADD) {
                if (exp_inner.left.kind == LN && exp_inner.right.kind == LN) {
                    return mul(exp_inner.left.left, exp_inner.right.left);
                };
            };
            // e^(ln(x) - ln(y)) → x/y
            if (exp_inner.kind == SUB) {
                if (exp_inner.left.kind == LN && exp_inner.right.kind == LN) {
                    return div_e(exp_inner.left.left, exp_inner.right.left);
                };
            };
            // e^(a*ln(x)) → x^a  (reverse of ln(x^a) = a*ln(x))
            if (exp_inner.kind == MUL) {
                if (exp_inner.left.kind == LN) {
                    return pow_e(exp_inner.left.left, exp_inner.right);
                };
                if (exp_inner.right.kind == LN) {
                    return pow_e(exp_inner.right.left, exp_inner.left);
                };
            };
            // e^(-x) → stays as is, but simplify inner neg
            if (exp_inner.kind == NEG) {
                return exp_e(exp_inner);
            };
            return exp_e(exp_inner);

        default: return e;
    };
};

function sym_simplify_full(e: Expr) -> Expr {
    var prev: Expr = e;
    var next: Expr = sym_simplify(e);
    while (!sym_equal(prev, next)) {
        prev = next;
        next = sym_simplify(next);
    };
    return next;
};

function sym_diff(e: Expr, var_name: str) -> Expr {
    return sym_simplify_full(sym_diff_pass(e, var_name));
};

// =============================================
// SYMBOLIC EVALUATION
// sym_eval(expr, "x", 2.0) → float
// Evaluates expression at a specific point
// =============================================

function sym_eval(e: Expr, var_name: str, val: float) -> float {
    match(e.kind) {

        case NUM: return e.value;

        case VAR:
            if (e.name == var_name) { return val; };
            c_print_err("MochaSymCha: unbound variable in sym_eval: ");
            c_print_err(e.name);
            c_exit(2);
            return 0.0;  // unreachable, just to satisfy return type

        case ADD:
            return sym_eval(e.left, var_name, val) + sym_eval(e.right, var_name, val);

        case SUB:
            return sym_eval(e.left, var_name, val) - sym_eval(e.right, var_name, val);

        case MUL:
            return sym_eval(e.left, var_name, val) * sym_eval(e.right, var_name, val);

        case DIV:
            return sym_eval(e.left, var_name, val) / sym_eval(e.right, var_name, val);

        // f^g
        case POW:
            var pbase: float = sym_eval(e.left, var_name, val);
            var pexp: float = sym_eval(e.right, var_name, val);
            return c_pow(pbase, pexp);

        case NEG:
            return 0.0 - sym_eval(e.left, var_name, val);

        case SIN:
            var sv: float = sym_eval(e.left, var_name, val);
            return c_sin(sv);

        case COS:
            var cv: float = sym_eval(e.left, var_name, val);
            return c_cos(cv);

        case LN:
            var lv: float = sym_eval(e.left, var_name, val);
            return c_log(lv);

        case EXP:
            var exponent: float = sym_eval(e.left, var_name, val);
            return c_pow(2.71828182845904523536, exponent);

        default: return 0.0;
    };
};


// =============================================
// INDEFINITE INTEGRATION (SYMBOLIC)
// sym_antidv(expr, "x") → Expr (antiderivative)
// Print result + " + C" for full notation
// Falls back to expr*x for unsupported forms
// =============================================

// ============= HELPER ============== //
// Returns the coefficient of var_name if expr is linear (ax or ax+b or a)
// Returns 0.0 if not linear
function linear_coeff(e: Expr, var_name: str) -> float {
    // just x → coefficient is 1
    if (e.kind == VAR && e.name == var_name) { return 1.0; };
    // c*x → coefficient is c
    if (e.kind == MUL) {
        if (e.left.kind == NUM && e.right.kind == VAR && e.right.name == var_name) {
            return e.left.value;
        };
        if (e.right.kind == NUM && e.left.kind == VAR && e.left.name == var_name) {
            return e.right.value;
        };
    };
    // ax + b → coefficient is a
    if (e.kind == ADD || e.kind == SUB) {
        var lc: float = linear_coeff(e.left, var_name);
        if (lc != 0.0) { return lc; };
        var rc: float = linear_coeff(e.right, var_name);
        if (rc != 0.0) { return rc; };
    };
    return 0.0;
};

function sym_antidv(e: Expr, var_name: str) -> Expr {
    match(e.kind) {

        // ∫c dx = c*x
        case NUM:
            return mul(e, var_e(var_name));

        // ∫x dx = x²/2,  ∫y dx = y*x
        case VAR:
            if (e.name == var_name) {
                return div_e(pow_e(var_e(var_name), num(2.0)), num(2.0));
            };
            return mul(e, var_e(var_name));

        // ∫(f + g) dx = ∫f dx + ∫g dx
        case ADD:
            return add(sym_antidv(e.left, var_name), sym_antidv(e.right, var_name));

        // ∫(f - g) dx = ∫f dx - ∫g dx
        case SUB:
            return sub(sym_antidv(e.left, var_name), sym_antidv(e.right, var_name));

        // ∫c*f dx = c*∫f dx  (constant multiple rule)
        case MUL:
            if (e.left.kind == NUM) {
                return mul(e.left, sym_antidv(e.right, var_name));
            };
            if (e.right.kind == NUM) {
                return mul(e.right, sym_antidv(e.left, var_name));
            };

            // ── Integration by Parts (LIATE) ──
            // Identify polynomial side and function side
            var ibp_poly: Expr = null;
            var ibp_poly_found: int = 0;  // use int flag instead of null check
            var ibp_func: Expr = null;


            // x^n · sin(x), x^n · cos(x), x^n · e^x, x^n · ln(x)
            if (e.left.kind == POW && e.left.left.kind == VAR && e.left.left.name == var_name && e.left.right.kind == NUM) {
                if (e.right.kind == SIN || e.right.kind == COS || e.right.kind == EXP || e.right.kind == LN) {
                    ibp_poly = e.left;
                    ibp_func = e.right;
                };
            };
            if (e.right.kind == POW && e.right.left.kind == VAR && e.right.left.name == var_name && e.right.right.kind == NUM) {
                if (e.left.kind == SIN || e.left.kind == COS || e.left.kind == EXP || e.left.kind == LN) {
                    ibp_poly = e.right;
                    ibp_func = e.left;
                };
            };
            // x · sin(x), x · cos(x), x · e^x, x · ln(x)
            if (ibp_poly_found == 0) {
                if (e.left.kind == VAR && e.left.name == var_name) {
                    if (e.right.kind == SIN) {
                        ibp_poly = pow_e(e.left, num(1.0));
                        ibp_func = e.right;
                    };
                    if (e.right.kind == COS) { ibp_poly = pow_e(e.left, num(1.0)); ibp_func = e.right; };
                    if (e.right.kind == EXP) { ibp_poly = pow_e(e.left, num(1.0)); ibp_func = e.right; };
                    if (e.right.kind == LN)  { ibp_poly = pow_e(e.left, num(1.0)); ibp_func = e.right; };
                };
            };

            if (ibp_poly != null && ibp_func != null) {
                var ibp_degree: int = int(ibp_poly.right.value);

                // ln case
                if (ibp_func.kind == LN && ibp_func.left.kind == VAR && ibp_func.left.name == var_name) {
                    var ln_n: float = float(ibp_degree);
                    var ln_np1: Expr = num(ln_n + 1.0);
                    var ln_v: Expr = div_e(pow_e(var_e(var_name), ln_np1), ln_np1);
                    return sub(mul(ln_v, ibp_func), div_e(pow_e(var_e(var_name), ln_np1), mul(ln_np1, ln_np1)));
                };

                var xv: Expr = var_e(var_name);
                var ibp_n: Expr = num(float(ibp_degree));

                // ── BASE CASES — no recursion ──
                if (ibp_degree == 1) {
                    if (ibp_func.kind == SIN) { return add(neg(mul(xv, cos_e(xv))), sin_e(xv)); };
                    if (ibp_func.kind == COS) { return add(mul(xv, sin_e(xv)), cos_e(xv)); };
                    if (ibp_func.kind == EXP) { return sub(mul(xv, exp_e(xv)), exp_e(xv)); };
                };

                if (ibp_degree == 2) {
                    if (ibp_func.kind == SIN) {
                        // ∫x²·sin(x) = -x²cos(x) + 2xsin(x) + 2cos(x)
                        return add(add(neg(mul(ibp_poly, cos_e(xv))), mul(num(2.0), mul(xv, sin_e(xv)))), mul(num(2.0), cos_e(xv)));
                    };
                    if (ibp_func.kind == COS) {
                        // ∫x²·cos(x) = x²sin(x) + 2xcos(x) - 2sin(x)
                        return sub(add(mul(ibp_poly, sin_e(xv)), mul(num(2.0), mul(xv, cos_e(xv)))), mul(num(2.0), sin_e(xv)));
                    };
                    if (ibp_func.kind == EXP) {
                        // ∫x²·e^x = x²e^x - 2xe^x + 2e^x
                        return add(sub(mul(ibp_poly, exp_e(xv)), mul(num(2.0), mul(xv, exp_e(xv)))), mul(num(2.0), exp_e(xv)));
                    };
                };

                // degree > 2 — fallback for now
                return mul(e, var_e(var_name));
            };

            // fallback for non-IBP products
            return mul(e, var_e(var_name));

        // ∫(-f) dx = -(∫f dx)
        case NEG:
            return neg(sym_antidv(e.left, var_name));

        // ∫sin(f) dx — chain rule if f is linear
        case SIN:
            if (e.left.kind == VAR && e.left.name == var_name) {
                return neg(cos_e(e.left));  // existing
            };
            var sin_a: float = linear_coeff(e.left, var_name);
            if (sin_a != 0.0) {
                // ∫sin(ax+b) = -cos(ax+b)/a
                return div_e(neg(cos_e(e.left)), num(sin_a));
            };
            return mul(e, var_e(var_name));  // fallback

        // ∫cos(f) dx — chain rule if f is linear
        case COS:
            if (e.left.kind == VAR && e.left.name == var_name) {
                return sin_e(e.left);  // existing
            };
            var cos_a: float = linear_coeff(e.left, var_name);
            if (cos_a != 0.0) {
                // ∫cos(ax+b) = sin(ax+b)/a
                return div_e(sin_e(e.left), num(cos_a));
            };
            return mul(e, var_e(var_name));  // fallback

        // ∫e^f dx — chain rule if f is linear
        case EXP:
            if (e.left.kind == VAR && e.left.name == var_name) {
                return exp_e(e.left);  // existing
            };
            var exp_a: float = linear_coeff(e.left, var_name);
            if (exp_a != 0.0) {
                // ∫e^(ax+b) = e^(ax+b)/a
                return div_e(exp_e(e.left), num(exp_a));
            };
            return mul(e, var_e(var_name));  // fallback

        // ∫x^n dx and ∫(ax+b)^n dx
        case POW:
            if (e.left.kind == VAR && e.left.name == var_name && e.right.kind == NUM) {
                var new_exp: Expr = num(e.right.value + 1.0);
                return div_e(pow_e(e.left, new_exp), new_exp);  // existing
            };
            // chain rule: ∫(ax+b)^n = (ax+b)^(n+1) / (a*(n+1))
            if (e.right.kind == NUM) {
                var pow_a: float = linear_coeff(e.left, var_name);
                if (pow_a != 0.0) {
                    var new_n: Expr = num(e.right.value + 1.0);
                    return div_e(
                        pow_e(e.left, new_n),
                        num(pow_a * (e.right.value + 1.0))
                    );
                };
            };
            return mul(e, var_e(var_name));  // fallback
        
        // ∫ln(f) dx — chain rule if f is linear
        case LN:
            if (e.left.kind == VAR && e.left.name == var_name) {
                return sub(mul(e.left, ln_e(e.left)), e.left);  // existing: x·ln(x) - x
            };
            var ln_a: float = linear_coeff(e.left, var_name);
            if (ln_a != 0.0) {
                // ∫ln(ax+b) = ((ax+b)/a) * ln(ax+b) - (ax+b)/a
                // which simplifies to (ax+b)·ln(ax+b)/a - (ax+b)/a
                var inner: Expr = e.left;
                var inner_over_a: Expr = div_e(inner, num(ln_a));
                return sub(
                    mul(inner_over_a, ln_e(inner)),
                    inner_over_a
                );
            };
            return mul(e, var_e(var_name));  // fallback

        default: return mul(e, var_e(var_name));
    };
};

function sym_print_antidv(e: Expr, var_name: str) -> str {
    return sym_print(sym_simplify_full(sym_antidv(e, var_name))) + " + C";
};

// =============================================
// DEFINITE INTEGRATION (SYMBOLIC + NUMERICAL)
// sym_integral(expr, "x", a, b) → float
// Tries symbolic first via sym_antidv,
// falls back to Simpson's rule if symbolic fails
// =============================================

function sym_integral(e: Expr, var_name: str, a: float, b: float) -> float {
    var antidv: Expr = sym_antidv(e, var_name);
    // Detect fallback pattern — sym_antidv returns e*x when it can't handle input
    // Fallback result has kind MUL with right child VAR(var_name)
    if (antidv.kind == MUL) {
        if (antidv.right.kind == VAR && antidv.right.name == var_name) {
            // Symbolic failed — fall back to Simpson's rule
            var n: int = 1000;
            var h: float = (b - a) / float(n);
            var sum: float = sym_eval(e, var_name, a) + sym_eval(e, var_name, b);
            var i: int = 1;
            while (i < n) {
                var xi: float = a + float(i) * h;
                if (i % 2 == 0) { sum = sum + 2.0 * sym_eval(e, var_name, xi); }
                else { sum = sum + 4.0 * sym_eval(e, var_name, xi); };
                i = i + 1;
            };
            return sum * h / 3.0;
        };
    };
    // Symbolic succeeded — F(b) - F(a)
    return sym_eval(antidv, var_name, b) - sym_eval(antidv, var_name, a);
};

// =============================================
// DEFINITE LIMITS NTEGRATION (SYMBOLIC + NUMERICAL)
// falls back to numerical if symbolic fails
// =============================================
function sym_limit(e: Expr, var_name: str, point: float) -> float {

    // ── Case 1: Not DIV or MUL — safe direct eval ──
    if (e.kind != DIV && e.kind != MUL) {
        return sym_eval(e, var_name, point);
    };

    // ── Case 2: DIV ──
    if (e.kind == DIV) {
        // evaluate num and den separately — safe since neither is a raw division
        var nv: float = sym_eval(e.left, var_name, point);
        var dv: float = sym_eval(e.right, var_name, point);

        // ✅ clean substitution
        if (dv != 0.0) {
            return nv / dv;
        };

        // 0/0 — L'Hôpital
        if (nv == 0.0) {
            var lh_num: Expr = e.left;
            var lh_den: Expr = e.right;
            var iter: int = 0;
            while (iter < 5) {
                lh_num = sym_diff(lh_num, var_name);
                lh_den = sym_diff(lh_den, var_name);
                var lnv: float = sym_eval(lh_num, var_name, point);
                var ldv: float = sym_eval(lh_den, var_name, point);
                if (ldv != 0.0) {
                    return lnv / ldv;
                };
                iter = iter + 1;
            };
            // L'Hôpital exhausted
            c_print_err("###WARNING (mocha-SymCha): L'Hopital exhausted after 5 iterations, falling back to numerical.");
            return sym_limit_numerical(e, var_name, point);
        };

        // nv != 0, dv == 0 — true pole
        return sym_limit_numerical(e, var_name, point);
    };

    // ── Case 3: MUL — check for 0*∞ ──
    if (e.kind == MUL) {
        var ml: float = sym_eval(e.left, var_name, point);
        var mr: float = sym_eval(e.right, var_name, point);

        // both nonzero — safe
        if (ml != 0.0 && mr != 0.0) {
            return ml * mr;
        };

        // left → 0, check if right → ∞ by seeing if its reciprocal → 0
        if (ml == 0.0) {
            var recip_r: float = sym_eval(e.right, var_name, point);
            if (recip_r == 0.0) {
                // genuine 0*∞ — rewrite f*g = f / (1/g)
                var rw: Expr = div_e(e.left, div_e(num(1.0), e.right));
                return sym_limit(rw, var_name, point);
            };
            return 0.0;  // 0 * finite = 0
        };

        // right → 0
        if (mr == 0.0) {
            var recip_l: float = sym_eval(e.left, var_name, point);
            if (recip_l == 0.0) {
                var rw2: Expr = div_e(e.right, div_e(num(1.0), e.left));
                return sym_limit(rw2, var_name, point);
            };
            return 0.0;
        };

        return ml * mr;
    };

    return sym_limit_numerical(e, var_name, point);
};

function sym_limit_numerical(e: Expr, var_name: str, point: float) -> float {
    var h: float = 0.000000001;  // 1e-9 matching mocha_math_limit

    // if e is DIV, check denominators at offset points before evaluating
    if (e.kind == DIV) {
        var den_left: float  = sym_eval(e.right, var_name, point - h);
        var den_right: float = sym_eval(e.right, var_name, point + h);

        // denominator still zero at offset — pole is wide, limit likely DNE
        if (den_left == 0.0 || den_right == 0.0) {
            c_print_err("MochaLibWarn (mocha-sym): pole detected, limit may not exist. Returning numerical best-effort.");
        };

        var lv: float = sym_eval(e.left, var_name, point - h) / den_left;
        var rv: float = sym_eval(e.left, var_name, point + h) / den_right;
        var diff: float = lv - rv;
        if (diff < 0.0) { diff = 0.0 - diff; };
        if (diff < 0.0001) {
            return (lv + rv) / 2.0;
        };
        return (lv + rv) / 2.0;  // return average with implicit DNE warning
    };

    // non-DIV — safe to eval directly at offset points
    var lv2: float = sym_eval(e, var_name, point - h);
    var rv2: float = sym_eval(e, var_name, point + h);
    var diff2: float = lv2 - rv2;
    if (diff2 < 0.0) { diff2 = 0.0 - diff2; };
    if (diff2 < 0.0001) {
        return (lv2 + rv2) / 2.0;
    };
    return (lv2 + rv2) / 2.0;
};

// =============================================
// SERIES EXPANSION
// =============================================
function sym_taylor(e: Expr, var_name: str, point: float, terms: int) -> Expr {
    var result: Expr = num(0.0);
    var current: Expr = e;
    var factorial: float = 1.0;
    var i: int = 0;
    while (i < terms) {
        if (i > 0) { factorial = factorial * float(i); };
        var coeff: float = sym_eval(current, var_name, point) / factorial;
        // coeff * (x - point)^i
        var term: Expr = mul(
            num(coeff),
            pow_e(sub(var_e(var_name), num(point)), num(float(i)))
        );
        result = add(result, term);
        current = sym_diff(current, var_name);
        i = i + 1;
    };
    return sym_simplify_full(result);
};