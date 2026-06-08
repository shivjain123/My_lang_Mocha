// test_errorplot.mch
// Tests for ErrorPlot in mocha-ink

from "mocha-ink" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — basic error plot, save to file
    // ============================================================

    var x1: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var y1: float[] = [2.1, 3.9, 6.0, 8.2, 9.8];
    var err1: float[] = [0.3, 0.4, 0.5, 0.3, 0.6];

    var ep1: ErrorPlot = errorplot(x1, y1, err1);
    ep1.title("Basic Error Plot");
    ep1.xlabel("X Axis");
    ep1.ylabel("Y Axis");
    ep1.save("error_plot_basic.svg");

    // ============================================================
    // TEST 2 — with color, label, and grid
    // ============================================================

    var x2: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var y2: float[] = [1.5, 3.0, 5.5, 7.0, 9.5];
    var err2: float[] = [0.2, 0.3, 0.4, 0.2, 0.5];

    var ep2: ErrorPlot = errorplot(x2, y2, err2);
    ep2.title("Styled Error Plot");
    ep2.xlabel("Time");
    ep2.ylabel("Value");
    ep2.color("crimson");
    ep2.label("experiment A");
    ep2.grid(true);
    ep2.save("error_plot_styled.svg");

    // ============================================================
    // TEST 3 — connected error plot (line through points)
    // ============================================================

    var x3: float[] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];
    var y3: float[] = [0.0, 1.1, 3.9, 9.2, 16.1, 25.3];
    var err3: float[] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6];

    var ep3: ErrorPlot = errorplot(x3, y3, err3);
    ep3.title("Connected Error Plot");
    ep3.xlabel("X");
    ep3.ylabel("Y");
    ep3.color("steelblue");
    ep3.connect();
    ep3.save("error_plot_connected.svg");

    // ============================================================
    // TEST 4 — asymmetric errors
    // ============================================================

    var x4: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var y4: float[] = [3.0, 5.5, 4.0, 6.5, 8.0];
    var err4: float[] = [0.1, 0.1, 0.1, 0.1, 0.1];
    var err_lo: float[] = [0.2, 0.5, 0.3, 0.6, 0.4];
    var err_hi: float[] = [0.4, 0.3, 0.6, 0.2, 0.5];

    var ep4: ErrorPlot = errorplot(x4, y4, err4);
    ep4.title("Asymmetric Error Plot");
    ep4.xlabel("X");
    ep4.ylabel("Y");
    ep4.asymmetric(err_lo, err_hi);
    ep4.save("error_plot_asymmetric.svg");

    // ============================================================
    // TEST 5 — multiple series via add()
    // ============================================================

    var xa: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var ya: float[] = [2.0, 4.1, 5.9, 8.0, 10.2];
    var erra: float[] = [0.3, 0.3, 0.3, 0.3, 0.3];

    var xb: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var yb: float[] = [1.0, 2.2, 3.1, 4.5, 5.8];
    var errb: float[] = [0.2, 0.4, 0.2, 0.3, 0.5];

    var ep5: ErrorPlot = errorplot(xa, ya, erra);
    ep5.title("Multi-Series Error Plot");
    ep5.xlabel("X");
    ep5.ylabel("Y");
    ep5.color("darkorange");
    ep5.label("series A");
    ep5.add(xb, yb, errb);
    ep5.grid(true);
    ep5.connect();
    ep5.save("error_plot_multiseries.svg");

};