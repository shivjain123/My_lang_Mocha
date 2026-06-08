from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic curve
    var data: float[] = [
        2.1, 3.4, 2.8, 4.1, 3.7, 2.5, 3.9, 4.5, 2.2, 3.1,
        4.2, 3.6, 2.9, 3.3, 4.0, 2.7, 3.8, 4.3, 2.4, 3.5,
        3.2, 4.4, 2.6, 3.0, 4.1, 2.3, 3.7, 4.2, 2.8, 3.4
    ];
    var c: CurvePlot = curve(data);
    c.title("Basic Curve Plot");
    c.xlabel("Value");
    c.ylabel("Density");
    c.save("curve_basic.svg");
    print("curve_basic.svg saved", newLine=true);

    // Test 2: filled curve
    var c2: CurvePlot = curve(data);
    c2.title("Filled Curve");
    c2.color("teal");
    c2.fill();
    c2.xlabel("Value");
    c2.ylabel("Density");
    c2.save("curve_filled.svg");
    print("curve_filled.svg saved", newLine=true);

    // Test 3: multi-series comparison
    var data2: float[] = [
        3.5, 4.2, 3.8, 5.1, 4.7, 3.9, 4.5, 5.3, 3.6, 4.4,
        5.0, 4.3, 3.7, 4.1, 4.8, 3.8, 4.6, 5.1, 3.9, 4.2
    ];
    var c3: CurvePlot = curve(data);
    c3.label("Group A");
    c3.fill();
    c3.add(data2);
    c3.label("Group B");
    c3.fill();
    c3.title("Two Distributions");
    c3.xlabel("Value");
    c3.ylabel("Density");
    c3.save("curve_multi.svg");
    print("curve_multi.svg saved", newLine=true);

    // Test 4: custom bandwidth
    var c4: CurvePlot = curve(data);
    c4.title("Wide Bandwidth");
    c4.bandwidth(0.8);
    c4.color("purple");
    c4.fill();
    c4.save("curve_bandwidth.svg");
    print("curve_bandwidth.svg saved", newLine=true);

    // Test 5: no grid
    var c5: CurvePlot = curve(data);
    c5.title("No Grid Curve");
    c5.color("coral");
    c5.grid(false);
    c5.save("curve_nogrid.svg");
    print("curve_nogrid.svg saved", newLine=true);

};