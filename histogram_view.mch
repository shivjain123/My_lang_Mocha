from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic histogram — auto bins
    var data: float[] = [
        2.1, 3.4, 2.8, 4.1, 3.7, 2.5, 3.9, 4.5, 2.2, 3.1,
        4.2, 3.6, 2.9, 3.3, 4.0, 2.7, 3.8, 4.3, 2.4, 3.5,
        3.2, 4.4, 2.6, 3.0, 4.1, 2.3, 3.7, 4.2, 2.8, 3.4
    ];
    var h: Histogram = histogram(data);
    h.title("Basic Histogram");
    h.xlabel("Value");
    h.ylabel("Frequency");
    h.save("hist_basic.svg");
    print("hist_basic.svg saved", newLine=true);

    // Test 2: custom bin count
    var h2: Histogram = histogram(data);
    h2.title("Custom Bins (5)");
    h2.xlabel("Value");
    h2.ylabel("Frequency");
    h2.bins(5);
    h2.save("hist_bins.svg");
    print("hist_bins.svg saved", newLine=true);

    // Test 3: density mode with normal curve
    var h3: Histogram = histogram(data);
    h3.title("Density with Normal Curve");
    h3.xlabel("Value");
    h3.ylabel("Density");
    h3.density();
    h3.normal_curve();
    h3.save("hist_density.svg");
    print("hist_density.svg saved", newLine=true);

    // Test 4: two overlaid datasets
    var data2: float[] = [
        3.5, 4.2, 3.8, 5.1, 4.7, 3.9, 4.5, 5.3, 3.6, 4.4,
        5.0, 4.3, 3.7, 4.1, 4.8, 3.8, 4.6, 5.1, 3.9, 4.2
    ];
    var h4: Histogram = histogram(data);
    h4.label("Group A");
    h4.add(data2);
    h4.label("Group B");
    h4.title("Two Distributions");
    h4.xlabel("Value");
    h4.ylabel("Frequency");
    h4.save("hist_multi.svg");
    print("hist_multi.svg saved", newLine=true);

    // Test 5: colored + no grid
    var h5: Histogram = histogram(data);
    h5.title("Custom Color");
    h5.color("purple");
    h5.grid(false);
    h5.save("hist_color.svg");
    print("hist_color.svg saved", newLine=true);

};