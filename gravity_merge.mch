from "mocha-ds" import *;

function main(didLoad) -> null {

    // ----- Connected weighted graph -----
    var g: Graph = Graph(false);
    g.add_edge("A", "B", 1.0);
    g.add_edge("B", "C", 2.0);
    g.add_edge("A", "C", 4.0);
    g.add_edge("C", "D", 1.0);
    g.add_edge("D", "E", 3.0);
    g.add_edge("B", "E", 7.0);
    g.add_edge("A", "D", 5.0);

    var order: DSValue[] = g.gravity_merge();

    if (order.length == 5) {
        print("PASS: gravity_merge() visits all 5 nodes", newLine=true);
    } else {
        print("FAIL: gravity_merge() visits all 5 nodes", newLine=true);
    };

    // Check all labels are unique and valid
    var labels: str[] = ["A", "B", "C", "D", "E"];
    var all_present: bool = true;
    var li: int = 0;
    while (li < labels.length) {
        var found: bool = false;
        var oi: int = 0;
        while (oi < order.length) {
            if (order[oi].str_val == labels[li]) {
                found = true;
            };
            oi = oi + 1;
        };
        if (found == false) {
            all_present = false;
        };
        li = li + 1;
    };
    if (all_present) {
        print("PASS: gravity_merge() visits all distinct nodes", newLine=true);
    } else {
        print("FAIL: gravity_merge() visits all distinct nodes", newLine=true);
    };

    // Check no duplicates
    var no_dupes: bool = true;
    var oi2: int = 0;
    while (oi2 < order.length) {
        var oj: int = oi2 + 1;
        while (oj < order.length) {
            if (order[oi2].str_val == order[oj].str_val) {
                no_dupes = false;
            };
            oj = oj + 1;
        };
        oi2 = oi2 + 1;
    };
    if (no_dupes) {
        print("PASS: gravity_merge() has no duplicate nodes", newLine=true);
    } else {
        print("FAIL: gravity_merge() has no duplicate nodes", newLine=true);
    };

    // Print the order for visual inspection
    print("Order: ", newLine=false);
    var oi3: int = 0;
    while (oi3 < order.length) {
        print(order[oi3].str_val, newLine=false);
        if (oi3 < order.length - 1) {
            print(", ", newLine=false);
        };
        oi3 = oi3 + 1;
    };
    print("", newLine=true);

    // ----- Single node graph -----
    var g_single: Graph = Graph(false);
    g_single.add_node("X");
    var order_single: DSValue[] = g_single.gravity_merge();
    if (order_single.length == 1 && order_single[0].str_val == "X") {
        print("PASS: gravity_merge() single node graph", newLine=true);
    } else {
        print("FAIL: gravity_merge() single node graph", newLine=true);
    };

    // ----- Empty graph -----
    var g_empty: Graph = Graph(false);
    var order_empty: DSValue[] = g_empty.gravity_merge();
    if (order_empty.length == 0) {
        print("PASS: gravity_merge() empty graph", newLine=true);
    } else {
        print("FAIL: gravity_merge() empty graph", newLine=true);
    };

    // ----- Larger graph (square with diagonal) -----
    var g2: Graph = Graph(false);
    g2.add_edge("A", "B", 1.0);
    g2.add_edge("B", "C", 1.0);
    g2.add_edge("C", "D", 1.0);
    g2.add_edge("D", "A", 1.0);
    g2.add_edge("A", "C", 10.0);
    g2.add_edge("B", "D", 10.0);

    var order2: DSValue[] = g2.gravity_merge();
    if (order2.length == 4) {
        print("PASS: gravity_merge() square graph visits all 4 nodes", newLine=true);
    } else {
        print("FAIL: gravity_merge() square graph visits all 4 nodes", newLine=true);
    };

    // ----- Disconnected graph -----
    var g3: Graph = Graph(false);
    g3.add_edge("A", "B", 1.0);
    g3.add_edge("C", "D", 1.0);
    // E isolated
    g3.add_node("E");

    var order3: DSValue[] = g3.gravity_merge();
    if (order3.length < 5) {
        print("PASS: gravity_merge() on disconnected graph terminates without visiting all", newLine=true);
    } else {
        print("FAIL: gravity_merge() on disconnected graph terminates without visiting all", newLine=true);
    };
    print("Disconnected order length: ", newLine=false);
    print(order3.length, newLine=true);

    print("GravityMerge tests done.", newLine=true);
};