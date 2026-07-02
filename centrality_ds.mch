from "mocha-ds" import *;

function main(didLoad) -> null {

    // Build test graph: undirected, edges 0-1, 1-2, 2-3, 3-4, 1-3
    var g: Graph = Graph(false);
    g.add_edge("0", "1", 1.0);
    g.add_edge("1", "2", 1.0);
    g.add_edge("2", "3", 1.0);
    g.add_edge("3", "4", 1.0);
    g.add_edge("1", "3", 1.0);

    // degree_centrality("1") = 0.75
    var t1: float = g.degree_centrality("1");
    if (t1 == 0.75) {
        print("PASS: degree_centrality(1) == 0.75", newLine=true);
    } else {
        print("FAIL: degree_centrality(1)", newLine=true);
    };
    print(t1, newLine=true);

    // degree_centrality("0") = 0.25
    var t2: float = g.degree_centrality("0");
    if (t2 == 0.25) {
        print("PASS: degree_centrality(0) == 0.25", newLine=true);
    } else {
        print("FAIL: degree_centrality(0)", newLine=true);
    };
    print(t2, newLine=true);

    // network_density() = 0.5
    var t3: float = g.network_density();
    if (t3 == 0.5) {
        print("PASS: network_density == 0.5", newLine=true);
    } else {
        print("FAIL: network_density", newLine=true);
    };
    print(t3, newLine=true);

    // average_degree() = 2.0
    var t4: float = g.average_degree();
    if (t4 == 2.0) {
        print("PASS: average_degree == 2.0", newLine=true);
    } else {
        print("FAIL: average_degree", newLine=true);
    };
    print(t4, newLine=true);

    // clustering_coefficient("1") ~ 0.333333
    var t5: float = g.clustering_coefficient("1");
    var diff_t5: float = t5 - 0.333333;
    var abs_t5: float = 0.0;
    if (diff_t5 < 0.0) { abs_t5 = -diff_t5; } else { abs_t5 = diff_t5; };
    if (abs_t5 < 0.001) {
        print("PASS: clustering_coefficient(1) ~ 0.333333", newLine=true);
    } else {
        print("FAIL: clustering_coefficient(1)", newLine=true);
    };
    print(t5, newLine=true);

    // clustering_coefficient("3") ~ 0.333333
    var t6: float = g.clustering_coefficient("3");
    var diff_t6: float = t6 - 0.333333;
    var abs_t6: float = 0.0;
    if (diff_t6 < 0.0) { abs_t6 = -diff_t6; } else { abs_t6 = diff_t6; };
    if (abs_t6 < 0.001) {
        print("PASS: clustering_coefficient(3) ~ 0.333333", newLine=true);
    } else {
        print("FAIL: clustering_coefficient(3)", newLine=true);
    };
    print(t6, newLine=true);

    // clustering_coefficient("0") = 0.0 (only 1 neighbor)
    var t7: float = g.clustering_coefficient("0");
    if (t7 == 0.0) {
        print("PASS: clustering_coefficient(0) == 0.0", newLine=true);
    } else {
        print("FAIL: clustering_coefficient(0)", newLine=true);
    };
    print(t7, newLine=true);

    // closeness_centrality("1") = 0.8
    var t8: float = g.closeness_centrality("1");
    if (t8 == 0.8) {
        print("PASS: closeness_centrality(1) == 0.8", newLine=true);
    } else {
        print("FAIL: closeness_centrality(1)", newLine=true);
    };
    print(t8, newLine=true);

    // closeness_centrality("0") = 0.5
    var t9: float = g.closeness_centrality("0");
    if (t9 == 0.5) {
        print("PASS: closeness_centrality(0) == 0.5", newLine=true);
    } else {
        print("FAIL: closeness_centrality(0)", newLine=true);
    };
    print(t9, newLine=true);

    // betweenness_centrality("1") = 3.0
    var t10: float = g.betweenness_centrality("1");
    if (t10 == 3.0) {
        print("PASS: betweenness_centrality(1) == 3.0", newLine=true);
    } else {
        print("FAIL: betweenness_centrality(1)", newLine=true);
    };
    print(t10, newLine=true);

    // betweenness_centrality("3") = 3.0
    var t11: float = g.betweenness_centrality("3");
    if (t11 == 3.0) {
        print("PASS: betweenness_centrality(3) == 3.0", newLine=true);
    } else {
        print("FAIL: betweenness_centrality(3)", newLine=true);
    };
    print(t11, newLine=true);

    // betweenness_centrality("2") = 0.0
    var t12: float = g.betweenness_centrality("2");
    if (t12 == 0.0) {
        print("PASS: betweenness_centrality(2) == 0.0", newLine=true);
    } else {
        print("FAIL: betweenness_centrality(2)", newLine=true);
    };
    print(t12, newLine=true);

    print("mocha-ds Graph centrality methods tests done.", newLine=true);
};