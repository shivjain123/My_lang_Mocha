from "mocha-ds" import *;

function main(didLoad) -> null {

    // ----- Connected weighted graph for MST -----
    // Edges: A-B(1), B-C(2), A-C(4), C-D(1), D-E(3), B-E(7), A-D(5)
    // MST weight should be: A-B(1) + C-D(1) + B-C(2) + D-E(3) = 7
    var g: Graph = Graph(false);
    g.add_edge("A", "B", 1.0);
    g.add_edge("B", "C", 2.0);
    g.add_edge("A", "C", 4.0);
    g.add_edge("C", "D", 1.0);
    g.add_edge("D", "E", 3.0);
    g.add_edge("B", "E", 7.0);
    g.add_edge("A", "D", 5.0);

    var prim_total: float = g.prim();
    if (prim_total == 7.0) {
        print("PASS: prim() == 7.0", newLine=true);
    } else {
        print("FAIL: prim() == 7.0", newLine=true);
    };

    var kruskal_total: float = g.kruskal();
    if (kruskal_total == 7.0) {
        print("PASS: kruskal() == 7.0", newLine=true);
    } else {
        print("FAIL: kruskal() == 7.0", newLine=true);
    };

    var boruvka_total: float = g.boruvka();
    if (boruvka_total == 7.0) {
        print("PASS: boruvka() == 7.0", newLine=true);
    } else {
        print("FAIL: boruvka() == 7.0", newLine=true);
    };

    // ----- Single node graph -----
    var g_single: Graph = Graph(false);
    g_single.add_node("X");

    var prim_single: float = g_single.prim();
    if (prim_single == 0.0) {
        print("PASS: prim() on single node == 0.0", newLine=true);
    } else {
        print("FAIL: prim() on single node == 0.0", newLine=true);
    };

    var kruskal_single: float = g_single.kruskal();
    if (kruskal_single == 0.0) {
        print("PASS: kruskal() on single node == 0.0", newLine=true);
    } else {
        print("FAIL: kruskal() on single node == 0.0", newLine=true);
    };

    var boruvka_single: float = g_single.boruvka();
    if (boruvka_single == 0.0) {
        print("PASS: boruvka() on single node == 0.0", newLine=true);
    } else {
        print("FAIL: boruvka() on single node == 0.0", newLine=true);
    };

    // ----- Empty graph -----
    var g_empty: Graph = Graph(false);
    var prim_empty: float = g_empty.prim();
    if (prim_empty == -1.0) {
        print("PASS: prim() on empty graph == -1.0", newLine=true);
    } else {
        print("FAIL: prim() on empty graph == -1.0", newLine=true);
    };

    var kruskal_empty: float = g_empty.kruskal();
    if (kruskal_empty == -1.0) {
        print("PASS: kruskal() on empty graph == -1.0", newLine=true);
    } else {
        print("FAIL: kruskal() on empty graph == -1.0", newLine=true);
    };

    var boruvka_empty: float = g_empty.boruvka();
    if (boruvka_empty == -1.0) {
        print("PASS: boruvka() on empty graph == -1.0", newLine=true);
    } else {
        print("FAIL: boruvka() on empty graph == -1.0", newLine=true);
    };

    // ----- Larger graph with a clear minimum spanning tree -----
    // Square with diagonal: A-B(1), B-C(1), C-D(1), D-A(1), A-C(10), B-D(10)
    // MST weight: 1+1+1 = 3
    var g2: Graph = Graph(false);
    g2.add_edge("A", "B", 1.0);
    g2.add_edge("B", "C", 1.0);
    g2.add_edge("C", "D", 1.0);
    g2.add_edge("D", "A", 1.0);
    g2.add_edge("A", "C", 10.0);
    g2.add_edge("B", "D", 10.0);

    var prim2: float = g2.prim();
    if (prim2 == 3.0) {
        print("PASS: prim() on square graph == 3.0", newLine=true);
    } else {
        print("FAIL: prim() on square graph == 3.0", newLine=true);
    };

    var kruskal2: float = g2.kruskal();
    if (kruskal2 == 3.0) {
        print("PASS: kruskal() on square graph == 3.0", newLine=true);
    } else {
        print("FAIL: kruskal() on square graph == 3.0", newLine=true);
    };

    var boruvka2: float = g2.boruvka();
    if (boruvka2 == 3.0) {
        print("PASS: boruvka() on square graph == 3.0", newLine=true);
    } else {
        print("FAIL: boruvka() on square graph == 3.0", newLine=true);
    };

    print("MST tests done.", newLine=true);
};