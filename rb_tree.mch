from "mocha-ds" import *;

function main(didLoad) -> null {

    // is_empty on fresh tree
    var t: RBTree = RBTree();
    if (t.is_empty()) {
        print("PASS: is_empty on empty tree", newLine=true);
    } else {
        print("FAIL: is_empty on empty tree", newLine=true);
    };

    // insert and size
    t.insert(ds_int(30));
    t.insert(ds_int(20));
    t.insert(ds_int(40));
    t.insert(ds_int(10));
    t.insert(ds_int(25));
    t.insert(ds_int(35));
    t.insert(ds_int(50));
    if (t.size == 7) {
        print("PASS: size == 7 after 7 inserts", newLine=true);
    } else {
        print("FAIL: size == 7 after 7 inserts", newLine=true);
    };

    // contains
    var c1: bool = t.contains(ds_int(25));
    if (c1) {
        print("PASS: contains(25) == true", newLine=true);
    } else {
        print("FAIL: contains(25) == true", newLine=true);
    };
    var c2: bool = t.contains(ds_int(99));
    if (c2 == false) {
        print("PASS: contains(99) == false", newLine=true);
    } else {
        print("FAIL: contains(99) == false", newLine=true);
    };

    // min and max
    var mn: DSValue = t.min();
    if (mn.int_val == 10) {
        print("PASS: min() == 10", newLine=true);
    } else {
        print("FAIL: min() == 10", newLine=true);
    };
    var mx: DSValue = t.max();
    if (mx.int_val == 50) {
        print("PASS: max() == 50", newLine=true);
    } else {
        print("FAIL: max() == 50", newLine=true);
    };

    // height — RB tree is not as strictly balanced as AVL
    // 7 nodes must be between 3 and 5
    var h1: int = t.height();
    if (h1 >= 3 && h1 <= 5) {
        print("PASS: height in valid RB range [3,5]", newLine=true);
    } else {
        print("FAIL: height in valid RB range [3,5]", newLine=true);
    };

    // inorder (visual: should print 10 20 25 30 35 40 50)
    print("Expect inorder [10 20 25 30 35 40 50]:", newLine=true);
    t.inorder();

    // successor
    var s1: DSValue = t.successor(ds_int(25));
    if (s1.int_val == 30) {
        print("PASS: successor(25) == 30", newLine=true);
    } else {
        print("FAIL: successor(25) == 30", newLine=true);
    };
    var s2: DSValue = t.successor(ds_int(10));
    if (s2.int_val == 20) {
        print("PASS: successor(10) == 20", newLine=true);
    } else {
        print("FAIL: successor(10) == 20", newLine=true);
    };
    var s3: DSValue = t.successor(ds_int(40));
    if (s3.int_val == 50) {
        print("PASS: successor(40) == 50", newLine=true);
    } else {
        print("FAIL: successor(40) == 50", newLine=true);
    };

    // predecessor
    var p1: DSValue = t.predecessor(ds_int(30));
    if (p1.int_val == 25) {
        print("PASS: predecessor(30) == 25", newLine=true);
    } else {
        print("FAIL: predecessor(30) == 25", newLine=true);
    };
    var p2: DSValue = t.predecessor(ds_int(50));
    if (p2.int_val == 40) {
        print("PASS: predecessor(50) == 40", newLine=true);
    } else {
        print("FAIL: predecessor(50) == 40", newLine=true);
    };
    var p3: DSValue = t.predecessor(ds_int(20));
    if (p3.int_val == 10) {
        print("PASS: predecessor(20) == 10", newLine=true);
    } else {
        print("FAIL: predecessor(20) == 10", newLine=true);
    };

    // remove leaf
    t.remove(ds_int(10));
    var c3: bool = t.contains(ds_int(10));
    if (c3 == false) {
        print("PASS: contains(10) == false after remove", newLine=true);
    } else {
        print("FAIL: contains(10) == false after remove", newLine=true);
    };
    if (t.size == 6) {
        print("PASS: size == 6 after remove", newLine=true);
    } else {
        print("FAIL: size == 6 after remove", newLine=true);
    };
    var mn2: DSValue = t.min();
    if (mn2.int_val == 20) {
        print("PASS: min() == 20 after removing 10", newLine=true);
    } else {
        print("FAIL: min() == 20 after removing 10", newLine=true);
    };

    // remove node with two children
    t.remove(ds_int(30));
    var c4: bool = t.contains(ds_int(30));
    if (c4 == false) {
        print("PASS: contains(30) == false after remove", newLine=true);
    } else {
        print("FAIL: contains(30) == false after remove", newLine=true);
    };
    if (t.size == 5) {
        print("PASS: size == 5 after remove", newLine=true);
    } else {
        print("FAIL: size == 5 after remove", newLine=true);
    };

    // RB balance guarantee — sorted insert must stay balanced
    var t2: RBTree = RBTree();
    t2.insert(ds_int(1));
    t2.insert(ds_int(2));
    t2.insert(ds_int(3));
    t2.insert(ds_int(4));
    t2.insert(ds_int(5));
    t2.insert(ds_int(6));
    t2.insert(ds_int(7));
    // plain BST would degrade to height 7, RB must stay bounded
    var h2: int = t2.height();
    if (h2 <= 5) {
        print("PASS: RB height <= 5 for sorted insert of 7 nodes", newLine=true);
    } else {
        print("FAIL: RB height <= 5 for sorted insert of 7 nodes", newLine=true);
    };

    // inorder after removals (visual: 20 25 35 40 50)
    print("Expect inorder after removals [20 25 35 40 50]:", newLine=true);
    t.inorder();

    // float keys
    var tf: RBTree = RBTree();
    tf.insert(ds_float(3.14));
    tf.insert(ds_float(1.41));
    tf.insert(ds_float(2.71));
    var mnf: DSValue = tf.min();
    if (mnf.flt_val == 1.41) {
        print("PASS: min() float == 1.41", newLine=true);
    } else {
        print("FAIL: min() float == 1.41", newLine=true);
    };
    var mxf: DSValue = tf.max();
    if (mxf.flt_val == 3.14) {
        print("PASS: max() float == 3.14", newLine=true);
    } else {
        print("FAIL: max() float == 3.14", newLine=true);
    };

    // str keys
    var ts: RBTree = RBTree();
    ts.insert(ds_str("banana"));
    ts.insert(ds_str("apple"));
    ts.insert(ds_str("cherry"));
    var mns: DSValue = ts.min();
    if (mns.str_val == "apple") {
        print("PASS: min() str == apple", newLine=true);
    } else {
        print("FAIL: min() str == apple", newLine=true);
    };
    var scs: DSValue = ts.successor(ds_str("apple"));
    if (scs.str_val == "banana") {
        print("PASS: successor(apple) == banana", newLine=true);
    } else {
        print("FAIL: successor(apple) == banana", newLine=true);
    };

    // drain to empty
    t.remove(ds_int(20));
    t.remove(ds_int(25));
    t.remove(ds_int(35));
    t.remove(ds_int(40));
    t.remove(ds_int(50));
    if (t.is_empty()) {
        print("PASS: is_empty after draining", newLine=true);
    } else {
        print("FAIL: is_empty after draining", newLine=true);
    };

    print("RBTree tests done.", newLine=true);
};