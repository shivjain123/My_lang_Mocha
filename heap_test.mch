from "mocha-ds" import *;

function main(didLoad) -> null {

    // MIN HEAP — int
    var minh: Heap = Heap(HeapKind.MIN);
    if (minh.is_empty()) {
        print("PASS: is_empty on empty min heap", newLine=true);
    } else {
        print("FAIL: is_empty on empty min heap", newLine=true);
    };

    minh.insert(ds_int(40));
    minh.insert(ds_int(10));
    minh.insert(ds_int(30));
    minh.insert(ds_int(20));
    minh.insert(ds_int(50));
    if (minh.size == 5) {
        print("PASS: size == 5 after 5 inserts", newLine=true);
    } else {
        print("FAIL: size == 5 after 5 inserts", newLine=true);
    };

    // top should be minimum
    var t1: DSValue = minh.top;
    if (t1.int_val == 10) {
        print("PASS: min heap top == 10", newLine=true);
    } else {
        print("FAIL: min heap top == 10", newLine=true);
    };

    // remove_top should give ascending order
    var r1: DSValue = minh.remove_top();
    if (r1.int_val == 10) {
        print("PASS: remove_top() == 10", newLine=true);
    } else {
        print("FAIL: remove_top() == 10", newLine=true);
    };
    var r2: DSValue = minh.remove_top();
    if (r2.int_val == 20) {
        print("PASS: remove_top() == 20", newLine=true);
    } else {
        print("FAIL: remove_top() == 20", newLine=true);
    };
    var r3: DSValue = minh.remove_top();
    if (r3.int_val == 30) {
        print("PASS: remove_top() == 30", newLine=true);
    } else {
        print("FAIL: remove_top() == 30", newLine=true);
    };
    var r4: DSValue = minh.remove_top();
    if (r4.int_val == 40) {
        print("PASS: remove_top() == 40", newLine=true);
    } else {
        print("FAIL: remove_top() == 40", newLine=true);
    };
    var r5: DSValue = minh.remove_top();
    if (r5.int_val == 50) {
        print("PASS: remove_top() == 50", newLine=true);
    } else {
        print("FAIL: remove_top() == 50", newLine=true);
    };
    if (minh.is_empty()) {
        print("PASS: is_empty after draining min heap", newLine=true);
    } else {
        print("FAIL: is_empty after draining min heap", newLine=true);
    };
    if (minh.top == null) {
        print("PASS: top == null on empty min heap", newLine=true);
    } else {
        print("FAIL: top == null on empty min heap", newLine=true);
    };

    // MAX HEAP — int
    var maxh: Heap = Heap(HeapKind.MAX);
    maxh.insert(ds_int(40));
    maxh.insert(ds_int(10));
    maxh.insert(ds_int(30));
    maxh.insert(ds_int(20));
    maxh.insert(ds_int(50));

    var t2: DSValue = maxh.top;
    if (t2.int_val == 50) {
        print("PASS: max heap top == 50", newLine=true);
    } else {
        print("FAIL: max heap top == 50", newLine=true);
    };

    // remove_top should give descending order
    var m1: DSValue = maxh.remove_top();
    if (m1.int_val == 50) {
        print("PASS: remove_top() == 50", newLine=true);
    } else {
        print("FAIL: remove_top() == 50", newLine=true);
    };
    var m2: DSValue = maxh.remove_top();
    if (m2.int_val == 40) {
        print("PASS: remove_top() == 40", newLine=true);
    } else {
        print("FAIL: remove_top() == 40", newLine=true);
    };
    var m3: DSValue = maxh.remove_top();
    if (m3.int_val == 30) {
        print("PASS: remove_top() == 30", newLine=true);
    } else {
        print("FAIL: remove_top() == 30", newLine=true);
    };
    var m4: DSValue = maxh.remove_top();
    if (m4.int_val == 20) {
        print("PASS: remove_top() == 20", newLine=true);
    } else {
        print("FAIL: remove_top() == 20", newLine=true);
    };
    var m5: DSValue = maxh.remove_top();
    if (m5.int_val == 10) {
        print("PASS: remove_top() == 10", newLine=true);
    } else {
        print("FAIL: remove_top() == 10", newLine=true);
    };
    if (maxh.is_empty()) {
        print("PASS: is_empty after draining max heap", newLine=true);
    } else {
        print("FAIL: is_empty after draining max heap", newLine=true);
    };

    // MIN HEAP — float
    var fh: Heap = Heap(HeapKind.MIN);
    fh.insert(ds_float(3.14));
    fh.insert(ds_float(1.41));
    fh.insert(ds_float(2.71));
    var ft1: DSValue = fh.top;
    if (ft1.flt_val == 1.41) {
        print("PASS: min heap float top == 1.41", newLine=true);
    } else {
        print("FAIL: min heap float top == 1.41", newLine=true);
    };
    var fr1: DSValue = fh.remove_top();
    if (fr1.flt_val == 1.41) {
        print("PASS: remove_top() float == 1.41", newLine=true);
    } else {
        print("FAIL: remove_top() float == 1.41", newLine=true);
    };

    // MIN HEAP — str (lexicographic)
    var sh: Heap = Heap(HeapKind.MIN);
    sh.insert(ds_str("banana"));
    sh.insert(ds_str("apple"));
    sh.insert(ds_str("cherry"));
    var st1: DSValue = sh.top;
    if (st1.str_val == "apple") {
        print("PASS: min heap str top == apple", newLine=true);
    } else {
        print("FAIL: min heap str top == apple", newLine=true);
    };
    var sr1: DSValue = sh.remove_top();
    if (sr1.str_val == "apple") {
        print("PASS: remove_top() str == apple", newLine=true);
    } else {
        print("FAIL: remove_top() str == apple", newLine=true);
    };

    // top field stays in sync after insert
    var sh2: Heap = Heap(HeapKind.MIN);
    sh2.insert(ds_int(100));
    var ts1: DSValue = sh2.top;
    if (ts1.int_val == 100) {
        print("PASS: top == 100 singleton", newLine=true);
    } else {
        print("FAIL: top == 100 singleton", newLine=true);
    };
    sh2.insert(ds_int(5));
    var ts2: DSValue = sh2.top;
    if (ts2.int_val == 5) {
        print("PASS: top updated to 5 after insert", newLine=true);
    } else {
        print("FAIL: top updated to 5 after insert", newLine=true);
    };
    sh2.insert(ds_int(50));
    var ts3: DSValue = sh2.top;
    if (ts3.int_val == 5) {
        print("PASS: top stays 5 after inserting larger", newLine=true);
    } else {
        print("FAIL: top stays 5 after inserting larger", newLine=true);
    };

    print("Heap tests done.", newLine=true);
};