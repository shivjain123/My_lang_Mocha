from "mocha-ds" import *;

function main(didLoad) -> null {

    var g: Graph = Graph(false);

    // is_empty on fresh graph
    if (g.is_empty()) {
        print("PASS: is_empty on empty Graph", newLine=true);
    } else {
        print("FAIL: is_empty on empty Graph", newLine=true);
    };

    // add_node and contains
    g.add_node("A");
    if (g.contains("A")) {
        print("PASS: contains(A) after add_node", newLine=true);
    } else {
        print("FAIL: contains(A) after add_node", newLine=true);
    };
    if (g.contains("Z") == false) {
        print("PASS: contains(Z) == false", newLine=true);
    } else {
        print("FAIL: contains(Z) == false", newLine=true);
    };

    // add_edge auto-creates nodes
    g.add_edge("A", "B", 1.0);
    g.add_edge("B", "C", 2.0);
    g.add_edge("A", "C", 4.0);
    g.add_edge("C", "D", 1.0);
    g.add_edge("D", "E", 3.0);
    g.add_edge("B", "E", 7.0);

    if (g.size == 5) {
        print("PASS: size == 5 after edges", newLine=true);
    } else {
        print("FAIL: size == 5 after edges", newLine=true);
    };
    if (g.contains("E")) {
        print("PASS: contains(E) auto-created via add_edge", newLine=true);
    } else {
        print("FAIL: contains(E) auto-created via add_edge", newLine=true);
    };
    if (g.is_empty() == false) {
        print("PASS: is_empty == false after edges", newLine=true);
    } else {
        print("FAIL: is_empty == false after edges", newLine=true);
    };

    // undirected — edge both ways
    var idx_b: int = g.index_of("B");
    var b_has_a: bool = false;
    var i: int = 0;
    while (i < g.nodes[idx_b].edges.length) {
        if (g.nodes[idx_b].edges[i].to == "A") {
            b_has_a = true;
        };
        i = i + 1;
    };
    if (b_has_a) {
        print("PASS: undirected edge added both ways (B->A exists)", newLine=true);
    } else {
        print("FAIL: undirected edge added both ways (B->A exists)", newLine=true);
    };

    // BFS from A
    var bfs_order: DSValue[] = g.bfs("A");
    if (bfs_order.length == 5) {
        print("PASS: bfs(A) visits all 5 nodes", newLine=true);
    } else {
        print("FAIL: bfs(A) visits all 5 nodes", newLine=true);
    };
    if (bfs_order[0].str_val == "A") {
        print("PASS: bfs(A) starts at A", newLine=true);
    } else {
        print("FAIL: bfs(A) starts at A", newLine=true);
    };

    // BFS from non-existent node
    var bfs_none: DSValue[] = g.bfs("Z");
    if (bfs_none.length == 0) {
        print("PASS: bfs(Z) on missing node returns empty", newLine=true);
    } else {
        print("FAIL: bfs(Z) on missing node returns empty", newLine=true);
    };

    // DFS from A
    var dfs_order: DSValue[] = g.dfs("A");
    if (dfs_order.length == 5) {
        print("PASS: dfs(A) visits all 5 nodes", newLine=true);
    } else {
        print("FAIL: dfs(A) visits all 5 nodes", newLine=true);
    };
    if (dfs_order[0].str_val == "A") {
        print("PASS: dfs(A) starts at A", newLine=true);
    } else {
        print("FAIL: dfs(A) starts at A", newLine=true);
    };

    // DFS from non-existent node
    var dfs_none: DSValue[] = g.dfs("Z");
    if (dfs_none.length == 0) {
        print("PASS: dfs(Z) on missing node returns empty", newLine=true);
    } else {
        print("FAIL: dfs(Z) on missing node returns empty", newLine=true);
    };

    // Dijkstra — shortest path A to E
    // A-B-C-D-E = 1+2+1+3 = 7, A-C-D-E = 4+1+3 = 8, A-B-E = 1+7 = 8
    // shortest should be 7
    var dist_ae: float = g.dijkstra("A", "E");
    if (dist_ae == 7.0) {
        print("PASS: dijkstra(A, E) == 7.0", newLine=true);
    } else {
        print("FAIL: dijkstra(A, E) == 7.0", newLine=true);
    };

    // Dijkstra — same node
    var dist_aa: float = g.dijkstra("A", "A");
    if (dist_aa == 0.0) {
        print("PASS: dijkstra(A, A) == 0.0", newLine=true);
    } else {
        print("FAIL: dijkstra(A, A) == 0.0", newLine=true);
    };

    // Dijkstra — non-existent node
    var dist_az: float = g.dijkstra("A", "Z");
    if (dist_az == -1.0) {
        print("PASS: dijkstra(A, Z) == -1.0 (missing node)", newLine=true);
    } else {
        print("FAIL: dijkstra(A, Z) == -1.0 (missing node)", newLine=true);
    };

    // Unreachable node in directed graph
    var g2: Graph = Graph(true);
    g2.add_edge("X", "Y", 1.0);
    g2.add_node("W");
    var dist_xw: float = g2.dijkstra("X", "W");
    if (dist_xw == -1.0) {
        print("PASS: dijkstra unreachable returns -1.0", newLine=true);
    } else {
        print("FAIL: dijkstra unreachable returns -1.0", newLine=true);
    };

    // Bellman-Ford — same graph, should match Dijkstra
    var bf_ae: float = g.bellman_ford("A", "E");
    if (bf_ae == 7.0) {
        print("PASS: bellman_ford(A, E) == 7.0", newLine=true);
    } else {
        print("FAIL: bellman_ford(A, E) == 7.0", newLine=true);
    };

    // Bellman-Ford with negative weights (directed, no negative cycle)
    var g3: Graph = Graph(true);
    g3.add_edge("S", "A", 4.0);
    g3.add_edge("S", "B", 5.0);
    g3.add_edge("A", "B", -2.0);
    g3.add_edge("B", "C", 3.0);
    g3.add_edge("A", "C", 6.0);
    // S->A->B->C = 4-2+3 = 5, S->A->C = 4+6 = 10, S->B->C = 5+3 = 8
    var bf_sc: float = g3.bellman_ford("S", "C");
    if (bf_sc == 5.0) {
        print("PASS: bellman_ford with negatives == 5.0", newLine=true);
    } else {
        print("FAIL: bellman_ford with negatives == 5.0", newLine=true);
    };

    // Bellman-Ford negative cycle detection
    var g4: Graph = Graph(true);
    g4.add_edge("P", "Q", 1.0);
    g4.add_edge("Q", "R", -1.0);
    g4.add_edge("R", "P", -1.0);
    var bf_cycle: float = g4.bellman_ford("P", "R");
    if (bf_cycle == -2.0) {
        print("PASS: bellman_ford detects negative cycle", newLine=true);
    } else {
        print("FAIL: bellman_ford detects negative cycle", newLine=true);
    };

    print("Graph tests done.", newLine=true);
};