from "mocha-ds" import *;

function main(didLoad) -> null {

    // ----- BloomFilter basic -----
    var bf: BloomFilter = BloomFilter(100, 0.01);

    if (bf.is_empty()) {
        print("PASS: BloomFilter is_empty on fresh filter", newLine=true);
    } else {
        print("FAIL: BloomFilter is_empty on fresh filter", newLine=true);
    };

    var c0: bool = bf.contains("apple");
    if (c0 == false) {
        print("PASS: contains(apple) == false before add", newLine=true);
    } else {
        print("FAIL: contains(apple) == false before add", newLine=true);
    };

    bf.add("apple");
    bf.add("banana");
    bf.add("cherry");

    var ie: bool = bf.is_empty();
    if (ie == false) {
        print("PASS: is_empty == false after adds", newLine=true);
    } else {
        print("FAIL: is_empty == false after adds", newLine=true);
    };

    var c1: bool = bf.contains("apple");
    if (c1) {
        print("PASS: contains(apple) == true after add", newLine=true);
    } else {
        print("FAIL: contains(apple) == true after add", newLine=true);
    };
    var c2: bool = bf.contains("banana");
    if (c2) {
        print("PASS: contains(banana) == true after add", newLine=true);
    } else {
        print("FAIL: contains(banana) == true after add", newLine=true);
    };
    var c3: bool = bf.contains("cherry");
    if (c3) {
        print("PASS: contains(cherry) == true after add", newLine=true);
    } else {
        print("FAIL: contains(cherry) == true after add", newLine=true);
    };

    // Likely-absent item (not a guaranteed false, but should be false for small filter)
    var c4: bool = bf.contains("zzz_not_added");
    if (c4 == false) {
        print("PASS: contains(zzz_not_added) == false (no false positive here)", newLine=true);
    } else {
        print("FAIL: contains(zzz_not_added) == false (no false positive here)", newLine=true);
    };

    // m and k should be positive and sensible
    if (bf.m > 0 && bf.k > 0) {
        print("PASS: BloomFilter m and k are positive", newLine=true);
    } else {
        print("FAIL: BloomFilter m and k are positive", newLine=true);
    };
    print("m = ", newLine=false);
    print(bf.m, newLine=true);
    print("k = ", newLine=false);
    print(bf.k, newLine=true);


    // ----- CountingBloomFilter basic -----
    var cbf: CountingBloomFilter = CountingBloomFilter(100, 0.01);

    if (cbf.is_empty()) {
        print("PASS: CountingBloomFilter is_empty on fresh filter", newLine=true);
    } else {
        print("FAIL: CountingBloomFilter is_empty on fresh filter", newLine=true);
    };

    cbf.add("apple");
    cbf.add("banana");

    var cc1: bool = cbf.contains("apple");
    if (cc1) {
        print("PASS: counting contains(apple) == true after add", newLine=true);
    } else {
        print("FAIL: counting contains(apple) == true after add", newLine=true);
    };
    var cc2: bool = cbf.contains("banana");
    if (cc2) {
        print("PASS: counting contains(banana) == true after add", newLine=true);
    } else {
        print("FAIL: counting contains(banana) == true after add", newLine=true);
    };
    var cc3: bool = cbf.contains("cherry");
    if (cc3 == false) {
        print("PASS: counting contains(cherry) == false (not added)", newLine=true);
    } else {
        print("FAIL: counting contains(cherry) == false (not added)", newLine=true);
    };

    // Remove apple, should no longer be contained
    cbf.remove("apple");
    var cc4: bool = cbf.contains("apple");
    if (cc4 == false) {
        print("PASS: contains(apple) == false after remove", newLine=true);
    } else {
        print("FAIL: contains(apple) == false after remove", newLine=true);
    };

    // banana should still be present
    var cc5: bool = cbf.contains("banana");
    if (cc5) {
        print("PASS: contains(banana) == true still after removing apple", newLine=true);
    } else {
        print("FAIL: contains(banana) == true still after removing apple", newLine=true);
    };

    var cie: bool = cbf.is_empty();
    if (cie == false) {
        print("PASS: counting is_empty == false (banana still in)", newLine=true);
    } else {
        print("FAIL: counting is_empty == false (banana still in)", newLine=true);
    };

    print("BloomFilter tests done.", newLine=true);
};

"""from "mocha-ds" import *;

function main(didLoad) -> null {

    var cbf: CountingBloomFilter = CountingBloomFilter(100, 0.01);
    print("cbf.m = ", newLine=false);
    print(cbf.m, newLine=true);
    print("cbf.k = ", newLine=false);
    print(cbf.k, newLine=true);

    cbf.add("apple");
    cbf.add("banana");

    // Print all indices touched by each
    print("apple indices: ", newLine=false);
    var i: int = 0;
    while (i < cbf.k) {
        var idx: int = cbf.index_for("apple", i);
        print(idx, newLine=false);
        print(" ", newLine=false);
        i = i + 1;
    };
    print("", newLine=true);

    print("banana indices: ", newLine=false);
    i = 0;
    while (i < cbf.k) {
        var idx: int = cbf.index_for("banana", i);
        print(idx, newLine=false);
        print(" ", newLine=false);
        i = i + 1;
    };
    print("", newLine=true);

    // Print counter values at apple's indices before remove
    print("counters at apple indices before remove: ", newLine=false);
    i = 0;
    while (i < cbf.k) {
        var idx: int = cbf.index_for("apple", i);
        print(cbf.counters[idx], newLine=false);
        print(" ", newLine=false);
        i = i + 1;
    };
    print("", newLine=true);

    cbf.remove("apple");

    print("counters at apple indices after remove: ", newLine=false);
    i = 0;
    while (i < cbf.k) {
        var idx: int = cbf.index_for("apple", i);
        print(cbf.counters[idx], newLine=false);
        print(" ", newLine=false);
        i = i + 1;
    };
    print("", newLine=true);

    var cc4: bool = cbf.contains("apple");
    print("contains(apple) after remove: ", newLine=false);
    print(cc4, newLine=true);
};"""