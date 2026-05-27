from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic line chart
    var x: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var y: float[] = [2.0, 4.0, 1.0, 8.0, 3.0];
    var p: LinePlot = line(x, y);
    p.title("Basic Line Chart");
    p.xlabel("X Axis");
    p.ylabel("Y Axis");
    p.save("line_test.svg");
    print("line_test.svg saved", newLine=true);

    // Test 2: scatter chart
    var x2: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var y2: float[] = [5.0, 3.0, 4.0, 2.0, 6.0];
    var s: ScatterPlot = scatter(x2, y2);
    s.title("Basic Scatter Chart");
    s.xlabel("X");
    s.ylabel("Y");
    s.save("scatter_test.svg");
    print("scatter_test.svg saved", newLine=true);

    // Test 3: multi-series line chart with labels
    var x3: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var y3: float[] = [1.0, 4.0, 9.0, 16.0, 25.0];
    var y4: float[] = [1.0, 8.0, 27.0, 64.0, 125.0];
    var m: LinePlot = line(x3, y3);
    m.label("x squared");
    m.add_line(x3, y4);
    m.label("x cubed");
    m.title("Multi-Series Line Chart");
    m.xlabel("X");
    m.ylabel("Y");
    m.save("multi_line_test.svg");
    print("multi_line_test.svg saved", newLine=true);

    // Test 4: mixed line and scatter
    var mx: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var my1: float[] = [2.0, 4.0, 6.0, 8.0, 10.0];
    var my2: float[] = [1.5, 3.5, 5.5, 7.5, 9.5];
    var mix: LinePlot = line(mx, my1);
    mix.label("trend");
    mix.add_scatter(mx, my2);
    mix.label("data points");
    mix.title("Mixed Chart");
    mix.color("red");
    mix.xlabel("X");
    mix.ylabel("Y");
    mix.save("mixed_test.svg");
    print("mixed_test.svg saved", newLine=true);

    // Test 5: no grid
    var ng: ScatterPlot = scatter(x, y);
    ng.title("No Grid");
    ng.grid(false);
    ng.color("purple");
    ng.save("no_grid_test.svg");
    print("no_grid_test.svg saved", newLine=true);
};