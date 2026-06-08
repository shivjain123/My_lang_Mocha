// test_lmplot.mch

from "mocha-ink" import*;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — basic linear relationship
    // ============================================================

    var x1: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
    var y1: float[] = [2.1, 3.9, 6.2, 7.8, 10.1, 12.3, 13.9, 16.2, 18.1, 19.8];

    var lm1: LMPlot = lmplot(x1, y1);
    lm1.title("Basic LM Plot");
    lm1.xlabel("X");
    lm1.ylabel("Y");
    lm1.save("test_lm_basic.svg");

    // ============================================================
    // TEST 2 — styled, custom colors
    // ============================================================

    var x2: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
    var y2: float[] = [5.2, 4.8, 6.1, 7.3, 8.9, 9.2, 11.1, 12.4];

    var lm2: LMPlot = lmplot(x2, y2);
    lm2.title("Styled LM Plot");
    lm2.xlabel("Time");
    lm2.ylabel("Value");
    lm2.color("crimson");
    lm2.linecolor("darkred");
    lm2.label("experiment A");
    lm2.grid(true);
    lm2.save("test_lm_styled.svg");

    // ============================================================
    // TEST 3 — no confidence band
    // ============================================================

    var x3: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
    var y3: float[] = [1.0, 2.2, 2.8, 4.1, 5.3, 5.9, 7.2, 8.0, 9.1, 10.3];

    var lm3: LMPlot = lmplot(x3, y3);
    lm3.title("LM Plot No Band");
    lm3.xlabel("X");
    lm3.ylabel("Y");
    lm3.noband();
    lm3.save("test_lm_noband.svg");

    // ============================================================
    // TEST 4 — custom CI level (99%)
    // ============================================================

    var x4: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
    var y4: float[] = [3.1, 4.5, 5.2, 7.8, 6.9, 9.3, 10.1, 12.4, 11.8, 14.2];

    var lm4: LMPlot = lmplot(x4, y4);
    lm4.title("LM Plot 99% CI");
    lm4.xlabel("X");
    lm4.ylabel("Y");
    lm4.ci(0.99);
    lm4.color("steelblue");
    lm4.linecolor("navy");
    lm4.save("test_lm_ci99.svg");

    // ============================================================
    // TEST 5 — noisy data (wide band expected)
    // ============================================================

    var x5: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
    var y5: float[] = [8.0, 1.0, 12.0, 3.0, 15.0, 2.0, 18.0, 5.0, 20.0, 7.0];

    var lm5: LMPlot = lmplot(x5, y5);
    lm5.title("Noisy Data Wide Band");
    lm5.xlabel("X");
    lm5.ylabel("Y");
    lm5.save("test_lm_noisy.svg");

    // ============================================================
    // TEST 6 — multi series
    // ============================================================

    var xa: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
    var ya: float[] = [2.0, 4.1, 5.9, 8.2, 9.8, 12.1, 14.0, 16.2];

    var xb: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
    var yb: float[] = [1.0, 1.8, 3.2, 3.9, 5.1, 6.0, 6.8, 8.1];

    var lm6: LMPlot = lmplot(xa, ya);
    lm6.title("Multi-Series LM Plot");
    lm6.xlabel("X");
    lm6.ylabel("Y");
    lm6.color("darkorange");
    lm6.linecolor("darkorange");
    lm6.label("group A");
    lm6.add(xb, yb);
    lm6.save("test_lm_multi.svg");

};