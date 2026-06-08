from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic heatmap — correlation matrix style
    var matrix: float[][] = [
        [1.0, 0.8, 0.3, 0.1],
        [0.8, 1.0, 0.5, 0.2],
        [0.3, 0.5, 1.0, 0.7],
        [0.1, 0.2, 0.7, 1.0]
    ];
    var h: Heatmap = heatmap(matrix);
    h.title("Correlation Matrix");
    h.xlabel("Features");
    h.ylabel("Features");
    h.save("heatmap_basic.svg");
    print("heatmap_basic.svg saved", newLine=true);

    // Test 2: white->blue scheme
    var h2: Heatmap = heatmap(matrix);
    h2.title("Correlation (White-Blue)");
    h2.white_blue();
    h2.save("heatmap_white_blue.svg");
    print("heatmap_white_blue.svg saved", newLine=true);

    // Test 3: black->yellow scheme
    var h3: Heatmap = heatmap(matrix);
    h3.title("Correlation (Black-Yellow)");
    h3.black_yellow();
    h3.save("heatmap_black_yellow.svg");
    print("heatmap_black_yellow.svg saved", newLine=true);

    // Test 4: larger matrix
    var big: float[][] = [
        [10.0, 20.0, 30.0, 40.0, 50.0],
        [15.0, 25.0, 35.0, 45.0, 55.0],
        [5.0,  15.0, 25.0, 35.0, 45.0],
        [20.0, 30.0, 40.0, 50.0, 60.0],
        [8.0,  18.0, 28.0, 38.0, 48.0]
    ];
    var h4: Heatmap = heatmap(big);
    h4.title("5x5 Heatmap");
    h4.xlabel("Columns");
    h4.ylabel("Rows");
    h4.save("heatmap_5x5.svg");
    print("heatmap_5x5.svg saved", newLine=true);

};