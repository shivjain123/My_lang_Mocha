from "mocha-ink" import *;

function test(didLoad) -> null {
    var data1: float[] = [2.1, 3.4, 2.8, 4.1, 3.7, 2.5, 3.9, 4.5, 2.2, 3.1,
                          4.2, 3.6, 2.9, 3.3, 4.0, 2.7, 3.8, 4.3, 2.4, 3.5];
    var data2: float[] = [3.5, 4.2, 3.8, 5.1, 4.7, 3.9, 4.5, 5.3, 3.6, 4.4,
                          5.0, 4.3, 3.7, 4.1, 4.8, 3.8, 4.6, 5.1, 3.9, 4.2];

    // Test 1: basic violin
    var v: ViolinPlot = violin(data1);
    v.title("Basic Violin");
    v.xlabel("Group");
    v.ylabel("Value");
    v.save("violin_basic.svg");
    v.show();

    // Test 2: multi-group
    var v2: ViolinPlot = violin(data1);
    v2.label("Group A");
    v2.add(data2);
    v2.label("Group B");
    v2.title("Multi-Group Violin");
    v2.save("violin_multi.svg");
    v2.show();

    // Test 3: no box, custom bandwidth
    var v3: ViolinPlot = violin(data1);
    v3.no_box();
    v3.bandwidth(0.3);
    v3.title("KDE Only");
    v3.save("violin_kde.svg");
    v3.show();

    // Test 4: horizontal
    var v4: ViolinPlot = violin(data1);
    v4.label("Group A");
    v4.add(data2);
    v4.label("Group B");
    v4.horizontal();
    v4.title("Horizontal Violin");
    v4.save("violin_horizontal.svg");
    v4.show();
};