from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic vertical bar chart
    var labels: str[] = ["Jan", "Feb", "Mar", "Apr", "May"];
    var values: float[] = [120.0, 85.0, 200.0, 150.0, 175.0];
    var b: BarChart = bar(labels, values);
    b.title("Monthly Sales");
    b.xlabel("Month");
    b.ylabel("Sales");
    b.save("bar_basic.svg");
    print("bar_basic.svg saved", newLine=true);

    // Test 2: colored bar chart
    var b2: BarChart = bar(labels, values);
    b2.title("Monthly Sales (Green)");
    b2.color("green");
    b2.save("bar_colored.svg");
    print("bar_colored.svg saved", newLine=true);

    // Test 3: horizontal bar chart
    var b3: BarChart = bar(labels, values);
    b3.title("Monthly Sales (Horizontal)");
    b3.xlabel("Sales");
    b3.ylabel("Month");
    b3.horizontal();
    b3.save("bar_horizontal.svg");
    print("bar_horizontal.svg saved", newLine=true);

    // Test 4: multi-series grouped bar chart
    var values2: float[] = [90.0, 110.0, 160.0, 130.0, 145.0];
    var b4: BarChart = bar(labels, values);
    b4.label("2023");
    b4.add_series(values2);
    b4.label("2024");
    b4.title("Sales Comparison");
    b4.xlabel("Month");
    b4.ylabel("Sales");
    b4.save("bar_multi.svg");
    print("bar_multi.svg saved", newLine=true);

    // Test 5: no grid
    var b5: BarChart = bar(labels, values);
    b5.title("No Grid");
    b5.grid(false);
    b5.color("purple");
    b5.save("bar_nogrid.svg");
    print("bar_nogrid.svg saved", newLine=true);

};