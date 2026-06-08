from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic pie with percentages (default)
    var labels: str[] = ["Python", "JavaScript", "Mocha", "Rust", "Go"];
    var values: float[] = [35.0, 28.0, 20.0, 10.0, 7.0];
    var p: PieChart = pie(labels, values);
    p.title("Language Popularity");
    p.save("pie_basic.svg");
    print("pie_basic.svg saved", newLine=true);

    // Test 2: show values only
    var p2: PieChart = pie(labels, values);
    p2.title("Language Popularity (Values)");
    p2.show_values();
    p2.save("pie_values.svg");
    print("pie_values.svg saved", newLine=true);

    // Test 3: show both percent and values
    var p3: PieChart = pie(labels, values);
    p3.title("Language Popularity (Both)");
    p3.show_percent();
    p3.show_values();
    p3.save("pie_both.svg");
    print("pie_both.svg saved", newLine=true);

    // Test 4: small slice goes to legend
    var labels2: str[] = ["A", "B", "C", "D", "tiny"];
    var values2: float[] = [40.0, 30.0, 20.0, 8.0, 1.0];
    var p4: PieChart = pie(labels2, values2);
    p4.title("Small Slice Test");
    p4.save("pie_small_slice.svg");
    print("pie_small_slice.svg saved", newLine=true);

    // Test 5: custom colors
    var p5: PieChart = pie(labels, values);
    p5.title("Custom Colors");
    p5.color(0, "red");
    p5.color(1, "teal");
    p5.color(2, "gold");
    p5.save("pie_colors.svg");
    print("pie_colors.svg saved", newLine=true);

};