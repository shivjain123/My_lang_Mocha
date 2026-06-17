from "mocha-stats" import *;

function main(didLoad) -> null {

    // ----- Skewness -----
    // Symmetric data — skewness should be ~0
    var symmetric: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var sk_sym: float = symmetric.skewness();
    if (sk_sym > -0.01 && sk_sym < 0.01) {
        print("PASS: skewness() ~0 for symmetric data", newLine=true);
    } else {
        print("FAIL: skewness() ~0 for symmetric data", newLine=true);
    };
    print("skewness (symmetric) = ", newLine=false);
    print(sk_sym, newLine=true);

    // Right-skewed data — skewness should be positive
    var right_skewed: float[] = [1.0, 2.0, 2.0, 3.0, 3.0, 3.0, 4.0, 10.0];
    var sk_right: float = right_skewed.skewness();
    if (sk_right > 0.0) {
        print("PASS: skewness() > 0 for right-skewed data", newLine=true);
    } else {
        print("FAIL: skewness() > 0 for right-skewed data", newLine=true);
    };
    print("skewness (right-skewed) = ", newLine=false);
    print(sk_right, newLine=true);

    // Left-skewed data — skewness should be negative
    var left_skewed: float[] = [10.0, 4.0, 3.0, 3.0, 3.0, 2.0, 2.0, 1.0];
    var sk_left: float = left_skewed.skewness();
    if (sk_left < 0.0) {
        print("PASS: skewness() < 0 for left-skewed data", newLine=true);
    } else {
        print("FAIL: skewness() < 0 for left-skewed data", newLine=true);
    };
    print("skewness (left-skewed) = ", newLine=false);
    print(sk_left, newLine=true);

    // Sample skewness — should differ slightly from population skewness
    var sk_sample: float = right_skewed.skewness_sample();
    print("skewness_sample (right-skewed) = ", newLine=false);
    print(sk_sample, newLine=true);
    if (sk_sample != sk_right) {
        print("PASS: skewness_sample() differs from skewness() (bias correction applied)", newLine=true);
    } else {
        print("FAIL: skewness_sample() differs from skewness() (bias correction applied)", newLine=true);
    };


    // ----- Spearman -----
    // Perfectly monotonic increasing — spearman should be 1.0
    var a1: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var b1: float[] = [10.0, 20.0, 30.0, 40.0, 50.0];
    var sp1: float = spearman(a1, b1);
    if (sp1 > 0.99 && sp1 < 1.01) {
        print("PASS: spearman() == 1.0 for perfectly monotonic data", newLine=true);
    } else {
        print("FAIL: spearman() == 1.0 for perfectly monotonic data", newLine=true);
    };
    print("spearman (monotonic) = ", newLine=false);
    print(sp1, newLine=true);

    // Perfectly monotonic decreasing — spearman should be -1.0
    var a2: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var b2: float[] = [50.0, 40.0, 30.0, 20.0, 10.0];
    var sp2: float = spearman(a2, b2);
    if (sp2 < -0.99 && sp2 > -1.01) {
        print("PASS: spearman() == -1.0 for perfectly inverse data", newLine=true);
    } else {
        print("FAIL: spearman() == -1.0 for perfectly inverse data", newLine=true);
    };
    print("spearman (inverse) = ", newLine=false);
    print(sp2, newLine=true);

    // Data with ties — should still compute without error
    var a3: float[] = [1.0, 2.0, 2.0, 3.0, 4.0];
    var b3: float[] = [1.0, 3.0, 2.0, 4.0, 5.0];
    var sp3: float = spearman(a3, b3);
    print("spearman (with ties) = ", newLine=false);
    print(sp3, newLine=true);
    if (sp3 > 0.5) {
        print("PASS: spearman() with ties is positive and reasonable", newLine=true);
    } else {
        print("FAIL: spearman() with ties is positive and reasonable", newLine=true);
    };

    // Compare with Pearson (corr) — for monotonic non-linear relationship,
    // spearman should be 1.0 even though pearson may not be
    var a4: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var b4: float[] = [1.0, 8.0, 27.0, 64.0, 125.0]; // cubic relationship
    var sp4: float = spearman(a4, b4);
    var pe4: float = corr(a4, b4);
    print("spearman (cubic) = ", newLine=false);
    print(sp4, newLine=true);
    print("pearson (cubic) = ", newLine=false);
    print(pe4, newLine=true);
    if (sp4 > 0.99 && sp4 < 1.01) {
        print("PASS: spearman() == 1.0 for monotonic non-linear relationship", newLine=true);
    } else {
        print("FAIL: spearman() == 1.0 for monotonic non-linear relationship", newLine=true);
    };

    print("Stats lib tests done.", newLine=true);
};