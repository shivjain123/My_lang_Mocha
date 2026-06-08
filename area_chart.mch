from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic area chart
    var x: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
    var y: float[] = [2.0, 5.0, 3.0, 8.0, 6.0, 9.0, 4.0, 7.0];
    var a: AreaChart = area(x, y);
    a.title("Basic Area Chart");
    a.xlabel("X");
    a.ylabel("Y");
    a.save("area_basic.svg");
    print("area_basic.svg saved", newLine=true);

    // Test 2: colored area
    var a2: AreaChart = area(x, y);
    a2.title("Green Area Chart");
    a2.color("teal");
    a2.save("area_color.svg");
    print("area_color.svg saved", newLine=true);

    // Test 3: multi-series overlapping areas
    var y2: float[] = [1.0, 3.0, 5.0, 4.0, 7.0, 6.0, 8.0, 5.0];
    var a3: AreaChart = area(x, y);
    a3.label("Series A");
    a3.add_area(x, y2);
    a3.label("Series B");
    a3.title("Multi-Series Area Chart");
    a3.xlabel("X");
    a3.ylabel("Y");
    a3.save("area_multi.svg");
    print("area_multi.svg saved", newLine=true);

    // Test 4: no grid
    var a4: AreaChart = area(x, y);
    a4.title("No Grid Area");
    a4.color("coral");
    a4.grid(false);
    a4.save("area_nogrid.svg");
    print("area_nogrid.svg saved", newLine=true);

};