from "mocha-ink" import *;

function test(didLoad) -> null {

    // Test 1: basic single box plot
    var data: float[] = [
        2.1, 3.4, 2.8, 4.1, 3.7, 2.5, 3.9, 4.5, 2.2, 3.1,
        4.2, 3.6, 2.9, 3.3, 4.0, 2.7, 3.8, 4.3, 2.4, 3.5,
        1.0, 5.5  // outliers
    ];
    var b: BoxPlot = boxplot(data);
    b.title("Basic Box Plot");
    b.ylabel("Value");
    b.label("Group A");
    b.save("box_basic.svg");
    print("box_basic.svg saved", newLine=true);

    // Test 2: multi-series comparison
    var data2: float[] = [
        3.5, 4.2, 3.8, 5.1, 4.7, 3.9, 4.5, 5.3, 3.6, 4.4,
        5.0, 4.3, 3.7, 4.1, 4.8, 3.8, 4.6, 5.1, 3.9, 4.2,
        6.5  // outlier
    ];
    var data3: float[] = [
        1.5, 2.2, 1.8, 3.1, 2.7, 1.9, 2.5, 3.3, 1.6, 2.4,
        3.0, 2.3, 1.7, 2.1, 2.8, 1.8, 2.6, 3.1, 1.9, 2.2
    ];
    var b2: BoxPlot = boxplot(data);
    b2.label("Group A");
    b2.add(data2);
    b2.label("Group B");
    b2.add(data3);
    b2.label("Group C");
    b2.title("Multi-Group Comparison");
    b2.ylabel("Value");
    b2.save("box_multi.svg");
    print("box_multi.svg saved", newLine=true);

    // Test 3: horizontal
    var b3: BoxPlot = boxplot(data);
    b3.label("Group A");
    b3.add(data2);
    b3.label("Group B");
    b3.title("Horizontal Box Plot");
    b3.xlabel("Value");
    b3.horizontal();
    b3.save("box_horizontal.svg");
    print("box_horizontal.svg saved", newLine=true);

    // Test 4: with confidence interval
    var b4: BoxPlot = boxplot(data);
    b4.label("Group A");
    b4.add(data2);
    b4.label("Group B");
    b4.title("With Confidence Intervals");
    b4.ylabel("Value");
    b4.confidence();
    b4.save("box_confidence.svg");
    print("box_confidence.svg saved", newLine=true);

    // Test 5: custom color no grid
    var b5: BoxPlot = boxplot(data);
    b5.title("Custom Color");
    b5.label("Data");
    b5.color("teal");
    b5.grid(false);
    b5.ylabel("Value");
    b5.save("box_color.svg");
    print("box_color.svg saved", newLine=true);

};