from "mocha-ink" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — simple undirected graph
    // ============================================================

    var g1: NetworkChart = network();
    g1.title("Simple Undirected Graph");
    g1.node("a", "A");
    g1.node("b", "B");
    g1.node("c", "C");
    g1.node("d", "D");
    g1.edge("a", "b");
    g1.edge("b", "c");
    g1.edge("c", "d");
    g1.edge("d", "a");
    g1.save("test_net_basic.svg");

    // ============================================================
    // TEST 2 — directed graph
    // ============================================================

    var g2: NetworkChart = network();
    g2.title("Directed Graph");
    g2.node("a", "A");
    g2.node("b", "B");
    g2.node("c", "C");
    g2.node("d", "D");
    g2.node("e", "E");
    g2.edge("a", "b");
    g2.edge("a", "c");
    g2.edge("b", "d");
    g2.edge("c", "d");
    g2.edge("d", "e");
    g2.directed(true);
    g2.save("test_net_directed.svg");

    // ============================================================
    // TEST 3 — weighted graph
    // ============================================================

    var g3: NetworkChart = network();
    g3.title("Weighted Graph");
    g3.node("a", "A");
    g3.node("b", "B");
    g3.node("c", "C");
    g3.node("d", "D");
    g3.edgeweight("a", "b", 1.0);
    g3.edgeweight("b", "c", 4.0);
    g3.edgeweight("c", "d", 2.0);
    g3.edgeweight("d", "a", 5.0);
    g3.edgeweight("a", "c", 3.0);
    g3.save("test_net_weighted.svg");

    // ============================================================
    // TEST 4 — custom node colors and sizes
    // ============================================================

    var g4: NetworkChart = network();
    g4.title("Custom Nodes");
    g4.node("hub", "Hub");
    g4.node("x", "X");
    g4.node("y", "Y");
    g4.node("z", "Z");
    g4.node("w", "W");
    g4.edge("hub", "x");
    g4.edge("hub", "y");
    g4.edge("hub", "z");
    g4.edge("hub", "w");
    g4.nodecolor("hub", "crimson");
    g4.nodesize("hub", 1.6);
    g4.nodecolor("x", "steelblue");
    g4.nodecolor("y", "steelblue");
    g4.nodecolor("z", "steelblue");
    g4.nodecolor("w", "steelblue");
    g4.save("test_net_custom.svg");

    // ============================================================
    // TEST 5 — directed weighted with edge colors
    // ============================================================

    var g5: NetworkChart = network();
    g5.title("Directed Weighted");
    g5.node("s", "S");
    g5.node("a", "A");
    g5.node("b", "B");
    g5.node("t", "T");
    g5.edgeweight("s", "a", 3.0);
    g5.edgeweight("s", "b", 5.0);
    g5.edgeweight("a", "t", 2.0);
    g5.edgeweight("b", "t", 4.0);
    g5.edgecolor("s", "a", "steelblue");
    g5.edgecolor("s", "b", "darkorange");
    g5.edgecolor("a", "t", "steelblue");
    g5.edgecolor("b", "t", "darkorange");
    g5.directed(true);
    g5.save("test_net_directed_weighted.svg");

    // ============================================================
    // TEST 6 — no labels
    // ============================================================

    var g6: NetworkChart = network();
    g6.title("No Edge Labels");
    g6.node("a", "A");
    g6.node("b", "B");
    g6.node("c", "C");
    g6.edgeweight("a", "b", 2.0);
    g6.edgeweight("b", "c", 3.0);
    g6.edgeweight("c", "a", 1.0);
    g6.labels(false);
    g6.save("test_net_nolabels.svg");

};