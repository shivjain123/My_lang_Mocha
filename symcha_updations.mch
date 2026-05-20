from "mocha-SymCha" import *;

function main(didLoad) -> null {
    var x: Expr = var_e("x");
    
    // ln(x*y) → ln(x) + ln(y)
    var e1: Expr = ln_e(mul(x, num(2.0)));
    print(sym_print(sym_simplify(e1)), newLine=true);
    // expected: ln(x) + ln(2)

    // ln(x^3) → 3*ln(x)
    var e2: Expr = ln_e(pow_e(x, num(3.0)));
    print(sym_print(sym_simplify(e2)), newLine=true);
    // expected: 3·ln(x)

    // ln(e^x) → x
    var e3: Expr = ln_e(exp_e(x));
    print(sym_print(sym_simplify(e3)), newLine=true);
    // expected: x

    // e^ln(x) → x
    var e4: Expr = exp_e(ln_e(x));
    print(sym_print(sym_simplify(e4)), newLine=true);
    // expected: x

    // sin(-x) → -sin(x)
    var e5: Expr = sin_e(neg(x));
    print(sym_print(sym_simplify(e5)), newLine=true);
    // expected: -sin(x)

    // cos(-x) → cos(x)
    var e6: Expr = cos_e(neg(x));
    print(sym_print(sym_simplify(e6)), newLine=true);
    // expected: cos(x)

    // sin²(x) + cos²(x) → 1
    var e7: Expr = add(pow_e(sin_e(x), num(2.0)), pow_e(cos_e(x), num(2.0)));
    print(sym_print(sym_simplify(e7)), newLine=true);
    // expected: 1

    // ∫sin(2x) = -cos(2x)/2
    var e8: Expr = sin_e(mul(num(2.0), x));
    print(sym_print_antidv(e8, "x"), newLine=true);

    // ∫cos(3x+1) = sin(3x+1)/3
    var e9: Expr = cos_e(add(mul(num(3.0), x), num(1.0)));
    print(sym_print_antidv(e9, "x"), newLine=true);

    // ∫e^(2x) = e^(2x)/2
    var e10: Expr = exp_e(mul(num(2.0), x));
    print(sym_print_antidv(e10, "x"), newLine=true);

    // ∫(2x+1)^3 = (2x+1)^4/8
    var e11: Expr = pow_e(add(mul(num(2.0), x), num(1.0)), num(3.0));
    print(sym_print_antidv(e11, "x"), newLine=true);

    // ∫ln(2x+1)
    var e12: Expr = ln_e(add(mul(num(2.0), x), num(1.0)));
    print(sym_print_antidv(e12, "x"), newLine=true);

    // ── Direct substitution ──

    // lim x→2 of x² + 1 = 5
    var e13: Expr = add(pow_e(x, num(2.0)), num(1.0));
    print("lim x→2 (x²+1): ", newLine=true);
    print(sym_limit(e13, "x", 2.0), newLine=true);  // 5.0

    // lim x→0 of sin(x) = 0
    var e14: Expr = sin_e(x);
    print("lim x→0 sin(x): ", newLine=true);
    print(sym_limit(e14, "x", 0.0), newLine=true);  // 0.0

    // lim x→0 of cos(x) = 1
    var e15: Expr = cos_e(x);
    print("lim x→0 cos(x): ", newLine=true);
    print(sym_limit(e15, "x", 0.0), newLine=true);  // 1.0

    // ── L'Hôpital 0/0 ──

    // lim x→0 of sin(x)/x = 1
    var e16: Expr = div_e(sin_e(x), x);
    print("lim x→0 sin(x)/x: ", newLine=true);
    print(sym_limit(e16, "x", 0.0), newLine=true);  // 1.0

    // lim x→0 of (1 - cos(x))/x = 0
    var e17: Expr = div_e(sub(num(1.0), cos_e(x)), x);
    print("lim x→0 (1-cos(x))/x: ", newLine=true);
    print(sym_limit(e17, "x", 0.0), newLine=true);  // 0.0

    // lim x→0 of (1 - cos(x))/x² = 0.5
    var e18: Expr = div_e(sub(num(1.0), cos_e(x)), pow_e(x, num(2.0)));
    print("lim x→0 (1-cos(x))/x²: ", newLine=true);
    print(sym_limit(e18, "x", 0.0), newLine=true);  // 0.5

    // lim x→1 of (x²-1)/(x-1) = 2
    var e19: Expr = div_e(sub(pow_e(x, num(2.0)), num(1.0)), sub(x, num(1.0)));
    print("lim x→1 (x²-1)/(x-1): ", newLine=true);
    print(sym_limit(e19, "x", 1.0), newLine=true);  // 2.0

    // lim x→0 of (e^x - 1)/x = 1
    var e20: Expr = div_e(sub(exp_e(x), num(1.0)), x);
    print("lim x→0 (eˣ-1)/x: ", newLine=true);
    print(sym_limit(e20, "x", 0.0), newLine=true);  // 1.0

    // lim x→0 of (e^x - 1 - x)/x² = 0.5
    var e21: Expr = div_e(sub(sub(exp_e(x), num(1.0)), x), pow_e(x, num(2.0)));
    print("lim x→0 (eˣ-1-x)/x²: ", newLine=true);
    print(sym_limit(e21, "x", 0.0), newLine=true);  // 0.5

    // lim x→0 of ln(1+x)/x = 1
    var e22: Expr = div_e(ln_e(add(num(1.0), x)), x);
    print("lim x→0 ln(1+x)/x: ", newLine=true);
    print(sym_limit(e22, "x", 0.0), newLine=true);  // 1.0

    // ── L'Hôpital applied twice ──

    // lim x→0 of (x - sin(x))/x³ = 1/6 ≈ 0.1667
    var e23: Expr = div_e(sub(x, sin_e(x)), pow_e(x, num(3.0)));
    print("lim x→0 (x-sin(x))/x³: ", newLine=true);
    print(sym_limit(e23, "x", 0.0), newLine=true);  // ~0.166667

    // ── MUL 0*∞ case ──

    // lim x→0 of x·ln(x) = 0
    var e24: Expr = mul(x, ln_e(x));
    print("lim x→0 x·ln(x): ", newLine=true);
    print(sym_limit(e24, "x", 0.0), newLine=true);  // 0.0

    // ── Numerical fallback ──

    // lim x→0 of sin(x²)/x² = 1 (numerical)
    var e25: Expr = div_e(sin_e(pow_e(x, num(2.0))), pow_e(x, num(2.0)));
    print("lim x→0 sin(x²)/x²: ", newLine=true);
    print(sym_limit(e25, "x", 0.0), newLine=true);  // ~1.0

    // lim x→1 of ln(x)/(x-1) = 1
    var e26: Expr = div_e(ln_e(x), sub(x, num(1.0)));
    print("lim x→1 ln(x)/(x-1): ", newLine=true);
    print(sym_limit(e26, "x", 1.0), newLine=true);  // 1.0

    print("TAYLOR SERIES", newLine=true);
    // sin(x) around 0, 6 terms
    print(sym_print(sym_taylor(sin_e(x), "x", 0.0, 6)), newLine=true);
    // expected: x - x³/6 + x⁵/120

    // cos(x) around 0, 6 terms  
    print(sym_print(sym_taylor(cos_e(x), "x", 0.0, 6)), newLine=true);
    // expected: 1 - x²/2 + x⁴/24

    // exp(x) around 0, 5 terms
    print(sym_print(sym_taylor(exp_e(x), "x", 0.0, 5)), newLine=true);
    // expected: 1 + x + x²/2 + x³/6 + x⁴/24

    // ln(x) around x=1, 4 terms
    print(sym_print(sym_taylor(ln_e(x), "x", 1.0, 4)), newLine=true);
    // expected: (x-1) - (x-1)²/2 + (x-1)³/3
};