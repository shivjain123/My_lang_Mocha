from "mocha-ds" import *;

function main(didLoad) -> null {

    var p: Patricia = Patricia();

    // is_empty on fresh trie
    if (p.is_empty()) {
        print("PASS: is_empty on empty Patricia", newLine=true);
    } else {
        print("FAIL: is_empty on empty Patricia", newLine=true);
    };

    // insert and size
    p.insert("apple", ds_int(1));
    p.insert("application", ds_int(2));
    p.insert("apt", ds_int(3));
    p.insert("bat", ds_int(4));
    p.insert("batch", ds_int(5));
    if (p.size == 5) {
        print("PASS: size == 5 after 5 inserts", newLine=true);
    } else {
        print("FAIL: size == 5 after 5 inserts", newLine=true);
    };

    // contains
    var c1: bool = p.contains("apple");
    if (c1) {
        print("PASS: contains(apple) == true", newLine=true);
    } else {
        print("FAIL: contains(apple) == true", newLine=true);
    };
    var c2: bool = p.contains("app");
    if (c2 == false) {
        print("PASS: contains(app) == false", newLine=true);
    } else {
        print("FAIL: contains(app) == false", newLine=true);
    };
    var c3: bool = p.contains("batch");
    if (c3) {
        print("PASS: contains(batch) == true", newLine=true);
    } else {
        print("FAIL: contains(batch) == true", newLine=true);
    };

    // get
    var g1: DSValue = p.get("apple");
    if (g1.int_val == 1) {
        print("PASS: get(apple) == 1", newLine=true);
    } else {
        print("FAIL: get(apple) == 1", newLine=true);
    };
    var g2: DSValue = p.get("application");
    if (g2.int_val == 2) {
        print("PASS: get(application) == 2", newLine=true);
    } else {
        print("FAIL: get(application) == 2", newLine=true);
    };
    var g3: DSValue = p.get("apt");
    if (g3.int_val == 3) {
        print("PASS: get(apt) == 3", newLine=true);
    } else {
        print("FAIL: get(apt) == 3", newLine=true);
    };

    // starts_with
    var s1: bool = p.starts_with("app");
    if (s1) {
        print("PASS: starts_with(app) == true", newLine=true);
    } else {
        print("FAIL: starts_with(app) == true", newLine=true);
    };
    var s2: bool = p.starts_with("ba");
    if (s2) {
        print("PASS: starts_with(ba) == true", newLine=true);
    } else {
        print("FAIL: starts_with(ba) == true", newLine=true);
    };
    var s3: bool = p.starts_with("xyz");
    if (s3 == false) {
        print("PASS: starts_with(xyz) == false", newLine=true);
    } else {
        print("FAIL: starts_with(xyz) == false", newLine=true);
    };

    // all_with_prefix
    var aw1: DSValue[] = p.all_with_prefix("app");
    if (aw1.length == 2) {
        print("PASS: all_with_prefix(app) finds 2 words", newLine=true);
    } else {
        print("FAIL: all_with_prefix(app) finds 2 words", newLine=true);
    };
    var aw2: DSValue[] = p.all_with_prefix("bat");
    if (aw2.length == 2) {
        print("PASS: all_with_prefix(bat) finds 2 words", newLine=true);
    } else {
        print("FAIL: all_with_prefix(bat) finds 2 words", newLine=true);
    };
    var aw3: DSValue[] = p.all_with_prefix("apt");
    if (aw3.length == 1) {
        print("PASS: all_with_prefix(apt) finds 1 word", newLine=true);
    } else {
        print("FAIL: all_with_prefix(apt) finds 1 word", newLine=true);
    };
    var aw4: DSValue[] = p.all_with_prefix("xyz");
    if (aw4.length == 0) {
        print("PASS: all_with_prefix(xyz) finds 0 words", newLine=true);
    } else {
        print("FAIL: all_with_prefix(xyz) finds 0 words", newLine=true);
    };

    // delete leaf node
    var d1: bool = p.delete("application");
    if (d1) {
        print("PASS: delete(application) == true", newLine=true);
    } else {
        print("FAIL: delete(application) == true", newLine=true);
    };
    var c4: bool = p.contains("application");
    if (c4 == false) {
        print("PASS: contains(application) == false after delete", newLine=true);
    } else {
        print("FAIL: contains(application) == false after delete", newLine=true);
    };
    var c5: bool = p.contains("apple");
    if (c5) {
        print("PASS: contains(apple) == true after deleting application", newLine=true);
    } else {
        print("FAIL: contains(apple) == true after deleting application", newLine=true);
    };
    if (p.size == 4) {
        print("PASS: size == 4 after delete", newLine=true);
    } else {
        print("FAIL: size == 4 after delete", newLine=true);
    };

    // delete non-existent key
    var d2: bool = p.delete("nonexistent");
    if (d2 == false) {
        print("PASS: delete(nonexistent) == false", newLine=true);
    } else {
        print("FAIL: delete(nonexistent) == false", newLine=true);
    };
    if (p.size == 4) {
        print("PASS: size unchanged after failed delete", newLine=true);
    } else {
        print("FAIL: size unchanged after failed delete", newLine=true);
    };

    // delete and verify merge — delete "batch", "bat" should remain
    var d3: bool = p.delete("batch");
    if (d3) {
        print("PASS: delete(batch) == true", newLine=true);
    } else {
        print("FAIL: delete(batch) == true", newLine=true);
    };
    var c6: bool = p.contains("bat");
    if (c6) {
        print("PASS: contains(bat) == true after deleting batch", newLine=true);
    } else {
        print("FAIL: contains(bat) == true after deleting batch", newLine=true);
    };
    var c7: bool = p.contains("batch");
    if (c7 == false) {
        print("PASS: contains(batch) == false after delete", newLine=true);
    } else {
        print("FAIL: contains(batch) == false after delete", newLine=true);
    };

    // delete and verify merge — delete "apt", "apple" should remain reachable
    var d4: bool = p.delete("apt");
    if (d4) {
        print("PASS: delete(apt) == true", newLine=true);
    } else {
        print("FAIL: delete(apt) == true", newLine=true);
    };
    var c8: bool = p.contains("apple");
    if (c8) {
        print("PASS: contains(apple) == true after deleting apt", newLine=true);
    } else {
        print("FAIL: contains(apple) == true after deleting apt", newLine=true);
    };
    var g4: DSValue = p.get("apple");
    if (g4.int_val == 1) {
        print("PASS: get(apple) == 1 after merge", newLine=true);
    } else {
        print("FAIL: get(apple) == 1 after merge", newLine=true);
    };

    // single character keys
    var p2: Patricia = Patricia();
    p2.insert("a", ds_str("alpha"));
    p2.insert("b", ds_str("beta"));
    var g5: DSValue = p2.get("a");
    if (g5.str_val == "alpha") {
        print("PASS: get(a) == alpha", newLine=true);
    } else {
        print("FAIL: get(a) == alpha", newLine=true);
    };

    // overwrite existing key — size shouldn't increase
    p2.insert("a", ds_str("ALPHA"));
    var g6: DSValue = p2.get("a");
    if (g6.str_val == "ALPHA") {
        print("PASS: insert(a) overwrites to ALPHA", newLine=true);
    } else {
        print("FAIL: insert(a) overwrites to ALPHA", newLine=true);
    };
    if (p2.size == 2) {
        print("PASS: size == 2 after overwrite (no increase)", newLine=true);
    } else {
        print("FAIL: size == 2 after overwrite (no increase)", newLine=true);
    };

    print("Patricia tests done.", newLine=true);
};