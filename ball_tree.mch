from "mocha-ds" import *;

function main(didLoad) -> null {

    // is_empty on fresh tree
    var bt: BallTree = BallTree(2);
    if (bt.is_empty()) {
        print("PASS: is_empty on empty tree", newLine=true);
    } else {
        print("FAIL: is_empty on empty tree", newLine=true);
    };

    // insert and size
    var p1: float[] = [1.0, 2.0];
    var p2: float[] = [3.0, 4.0];
    var p3: float[] = [5.0, 6.0];
    var p4: float[] = [1.5, 2.5];
    var p5: float[] = [4.0, 5.0];
    bt.insert(p1, ds_str("A"));
    bt.insert(p2, ds_str("B"));
    bt.insert(p3, ds_str("C"));
    bt.insert(p4, ds_str("D"));
    bt.insert(p5, ds_str("E"));
    if (bt.size == 5) {
        print("PASS: size == 5 after 5 inserts", newLine=true);
    } else {
        print("FAIL: size == 5 after 5 inserts", newLine=true);
    };

    // nearest neighbor — query close to A and D
    var q1: float[]  = [1.1, 2.1];
    var nn1: DSValue = bt.nearest_neighbor(q1);
    if (nn1.str_val == "A" || nn1.str_val == "D") {
        print("PASS: nearest_neighbor([1.1, 2.1]) near A/D", newLine=true);
    } else {
        print("FAIL: nearest_neighbor([1.1, 2.1]) near A/D", newLine=true);
    };

    // nearest neighbor — query close to C
    var q2: float[]  = [4.9, 5.9];
    var nn2: DSValue = bt.nearest_neighbor(q2);
    if (nn2.str_val == "C") {
        print("PASS: nearest_neighbor([4.9, 5.9]) == C", newLine=true);
    } else {
        print("FAIL: nearest_neighbor([4.9, 5.9]) == C", newLine=true);
    };

    // nearest neighbor — query close to B
    var q3: float[]  = [3.1, 4.1];
    var nn3: DSValue = bt.nearest_neighbor(q3);
    if (nn3.str_val == "B" || nn3.str_val == "E") {
        print("PASS: nearest_neighbor([3.1, 4.1]) near B/E", newLine=true);
    } else {
        print("FAIL: nearest_neighbor([3.1, 4.1]) near B/E", newLine=true);
    };

    // contains
    var c1: bool = bt.contains(p1);
    if (c1) {
        print("PASS: contains([1.0, 2.0]) == true", newLine=true);
    } else {
        print("FAIL: contains([1.0, 2.0]) == true", newLine=true);
    };
    var c2: bool = bt.contains([9.0, 9.0]);
    if (c2 == false) {
        print("PASS: contains([9.0, 9.0]) == false", newLine=true);
    } else {
        print("FAIL: contains([9.0, 9.0]) == false", newLine=true);
    };

    // range search — small radius around A
    var r1: DSValue[] = bt.range_search([1.0, 2.0], 1.0);
    if (r1.length == 2) {
        print("PASS: range_search radius 1.0 around A finds 2 points", newLine=true);
    } else {
        print("FAIL: range_search radius 1.0 around A finds 2 points", newLine=true);
    };

    // range search — large radius catches all
    var r2: DSValue[] = bt.range_search([3.0, 4.0], 10.0);
    if (r2.length == 5) {
        print("PASS: range_search radius 10.0 finds all 5 points", newLine=true);
    } else {
        print("FAIL: range_search radius 10.0 finds all 5 points", newLine=true);
    };

    // range search — zero radius finds nothing
    var r3: DSValue[] = bt.range_search([0.0, 0.0], 0.1);
    if (r3.length == 0) {
        print("PASS: range_search far from all points finds 0", newLine=true);
    } else {
        print("FAIL: range_search far from all points finds 0", newLine=true);
    };

    // adaptive threshold — insert 10 more points to trigger recalibration
    var bt2: BallTree = BallTree(2);
    var i: int = 0;
    while (i < 10) {
        var coords: float[] = [i * 1.0, i * 1.0];
        bt2.insert(coords, ds_int(i));
        i = i + 1;
    };
    if (bt2.size == 10) {
        print("PASS: size == 10 after 10 inserts", newLine=true);
    } else {
        print("FAIL: size == 10 after 10 inserts", newLine=true);
    };
    // threshold should have adapted
    if (bt2.threshold > 0.0) {
        print("PASS: threshold adapted after 10 inserts", newLine=true);
    } else {
        print("FAIL: threshold adapted after 10 inserts", newLine=true);
    };

    // 3D ball tree
    var bt3: BallTree = BallTree(3);
    var p3d1: float[] = [1.0, 2.0, 3.0];
    var p3d2: float[] = [4.0, 5.0, 6.0];
    var p3d3: float[] = [7.0, 8.0, 9.0];
    bt3.insert(p3d1, ds_str("X"));
    bt3.insert(p3d2, ds_str("Y"));
    bt3.insert(p3d3, ds_str("Z"));
    var nn3d: DSValue = bt3.nearest_neighbor([1.1, 2.1, 3.1]);
    if (nn3d.str_val == "X") {
        print("PASS: 3D nearest_neighbor near X == X", newLine=true);
    } else {
        print("FAIL: 3D nearest_neighbor near X == X", newLine=true);
    };
    var mn3d: DSValue = bt3.nearest_neighbor([6.9, 7.9, 8.9]);
    if (mn3d.str_val == "Z") {
        print("PASS: 3D nearest_neighbor near Z == Z", newLine=true);
    } else {
        print("FAIL: 3D nearest_neighbor near Z == Z", newLine=true);
    };

    print("BallTree tests done.", newLine=true);
};