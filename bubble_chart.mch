from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic bubble chart
    var x: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0];
    var y: float[] = [3.0, 5.0, 2.0, 8.0, 4.0, 7.0, 6.0];
    var z: float[] = [10.0, 30.0, 15.0, 50.0, 25.0, 45.0, 35.0];
    var b: BubbleChart = bubble(x, y, z);
    b.title("Basic Bubble Chart");
    b.xlabel("X");
    b.ylabel("Y");
    b.save("bubble_basic.svg");
    print("bubble_basic.svg saved", newLine=true);

    // Test 2: custom color
    var b2: BubbleChart = bubble(x, y, z);
    b2.title("Teal Bubbles");
    b2.color("teal");
    b2.xlabel("X");
    b2.ylabel("Y");
    b2.save("bubble_color.svg");
    print("bubble_color.svg saved", newLine=true);

    // Test 3: custom size range
    var b3: BubbleChart = bubble(x, y, z);
    b3.title("Large Bubbles");
    b3.min_size(8.0);
    b3.max_size(60.0);
    b3.xlabel("X");
    b3.ylabel("Y");
    b3.save("bubble_large.svg");
    print("bubble_large.svg saved", newLine=true);

    // Test 4: multi-series
    var x2: float[] = [1.5, 2.5, 3.5, 4.5, 5.5];
    var y2: float[] = [6.0, 4.0, 7.0, 3.0, 8.0];
    var z2: float[] = [20.0, 40.0, 10.0, 35.0, 55.0];
    var b4: BubbleChart = bubble(x, y, z);
    b4.label("Group A");
    b4.add(x2, y2, z2);
    b4.label("Group B");
    b4.title("Multi-Series Bubbles");
    b4.xlabel("X");
    b4.ylabel("Y");
    b4.save("bubble_multi.svg");
    print("bubble_multi.svg saved", newLine=true);

    // Test 5: no grid
    var b5: BubbleChart = bubble(x, y, z);
    b5.title("No Grid Bubbles");
    b5.color("purple");
    b5.grid(false);
    b5.save("bubble_nogrid.svg");
    print("bubble_nogrid.svg saved", newLine=true);
};