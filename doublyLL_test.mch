from "mocha-ds" import *;

function main(didLoad) -> null {
    // Setup
    var dll: DoublyLL = DoublyLL();

    // is_empty on fresh list
    if (dll.is_empty()) {
        print("PASS: is_empty on empty list");
    } else {
        print("FAIL: is_empty on empty list");
    };

    // push_back and size
    dll.push_back(ds_int(10));
    dll.push_back(ds_int(20));
    dll.push_back(ds_int(30));
    if (dll.size == 3) {
        print("PASS: size after 3 push_back");
    } else {
        print("FAIL: size after 3 push_back");
    };

    // print_all (visual check: 10 <-> 20 <-> 30)
    print("Expect [10 <-> 20 <-> 30]:", newLine=false);
    print(" ", newLine=false);
    dll.print_all();

    // front and back
    var f1: DSValue = dll.front();
    if (f1.int_val == 10) {
        print("PASS: front() == 10");
    } else {
        print("FAIL: front() == 10");
    };
    var b1: DSValue = dll.back();
    if (b1.int_val == 30) {
        print("PASS: back() == 30");
    } else {
        print("FAIL: back() == 30");
    };

    // push_front
    dll.push_front(ds_int(5));
    var f2: DSValue = dll.front();
    if (f2.int_val == 5) {
        print("PASS: push_front -> front() == 5");
    } else {
        print("FAIL: push_front -> front() == 5");
    };
    if (dll.size == 4) {
        print("PASS: size after push_front");
    } else {
        print("FAIL: size after push_front");
    };

    // print_all (visual check: 5 <-> 10 <-> 20 <-> 30)
    print("Expect [5 <-> 10 <-> 20 <-> 30]:", newLine=false);
    print(" ", newLine=false);
    dll.print_all();

    // get
    var g0: DSValue = dll.get(0);
    if (g0.int_val == 5) {
        print("PASS: get(0) == 5");
    } else {
        print("FAIL: get(0) == 5");
    };
    var g2: DSValue = dll.get(2);
    if (g2.int_val == 20) {
        print("PASS: get(2) == 20");
    } else {
        print("FAIL: get(2) == 20");
    };
    var g3: DSValue = dll.get(3);
    if (g3.int_val == 30) {
        print("PASS: get(3) == 30");
    } else {
        print("FAIL: get(3) == 30");
    };

    // contains
    if (dll.contains(ds_int(20))) {
        print("PASS: contains(20) == true");
    } else {
        print("FAIL: contains(20) == true");
    };
    var c2: bool = dll.contains(ds_int(99));
    if (c2 == false) {
        print("PASS: contains(99) == false");
    } else {
        print("FAIL: contains(99) == false");
    };

    // pop_front
    var pf: DSValue = dll.pop_front();
    if (pf.int_val == 5) {
        print("PASS: pop_front() == 5");
    } else {
        print("FAIL: pop_front() == 5");
    };
    var f3: DSValue = dll.front();
    if (f3.int_val == 10) {
        print("PASS: front() == 10 after pop_front");
    } else {
        print("FAIL: front() == 10 after pop_front");
    };
    if (dll.size == 3) {
        print("PASS: size == 3 after pop_front");
    } else {
        print("FAIL: size == 3 after pop_front");
    };

    // pop_back
    var pb: DSValue = dll.pop_back();
    if (pb.int_val == 30) {
        print("PASS: pop_back() == 30");
    } else {
        print("FAIL: pop_back() == 30");
    };
    var b2: DSValue = dll.back();
    if (b2.int_val == 20) {
        print("PASS: back() == 20 after pop_back");
    } else {
        print("FAIL: back() == 20 after pop_back");
    };
    if (dll.size == 2) {
        print("PASS: size == 2 after pop_back");
    } else {
        print("FAIL: size == 2 after pop_back");
    };

    // remove middle node — list: 10 <-> 20 <-> 40 <-> 50
    dll.push_back(ds_int(40));
    dll.push_back(ds_int(50));
    var r1: bool = dll.remove(ds_int(40));
    if (r1) {
        print("PASS: remove(40) returned true");
    } else {
        print("FAIL: remove(40) returned true");
    };
    if (dll.size == 3) {
        print("PASS: size == 3 after remove middle");
    } else {
        print("FAIL: size == 3 after remove middle");
    };
    var g2b: DSValue = dll.get(2);
    if (g2b.int_val == 50) {
        print("PASS: get(2) == 50 after remove middle");
    } else {
        print("FAIL: get(2) == 50 after remove middle");
    };

    // remove head
    var r2: bool = dll.remove(ds_int(10));
    if (r2) {
        print("PASS: remove(10) head returned true");
    } else {
        print("FAIL: remove(10) head returned true");
    };
    var f4: DSValue = dll.front();
    if (f4.int_val == 20) {
        print("PASS: front() == 20 after remove head");
    } else {
        print("FAIL: front() == 20 after remove head");
    };

    // remove tail
    var r3: bool = dll.remove(ds_int(50));
    if (r3) {
        print("PASS: remove(50) tail returned true");
    } else {
        print("FAIL: remove(50) tail returned true");
    };
    var b3: DSValue = dll.back();
    if (b3.int_val == 20) {
        print("PASS: back() == 20 after remove tail");
    } else {
        print("FAIL: back() == 20 after remove tail");
    };
    if (dll.size == 1) {
        print("PASS: size == 1 after remove tail");
    } else {
        print("FAIL: size == 1 after remove tail");
    };

    // remove nonexistent
    var r4: bool = dll.remove(ds_int(999));
    if (r4 == false) {
        print("PASS: remove(999) returned false");
    } else {
        print("FAIL: remove(999) returned false");
    };

    // singleton: pop down to empty
    dll.pop_front();
    if (dll.is_empty()) {
        print("PASS: is_empty after popping last element");
    } else {
        print("FAIL: is_empty after popping last element");
    };
    if (dll.head == null) {
        print("PASS: head == null on empty list");
    } else {
        print("FAIL: head == null on empty list");
    };
    if (dll.tail == null) {
        print("PASS: tail == null on empty list");
    } else {
        print("FAIL: tail == null on empty list");
    };

    // DSKind variety: float, str, bool
    var dll2: DoublyLL = DoublyLL();
    dll2.push_back(ds_float(3.14));
    dll2.push_back(ds_str("hello"));
    dll2.push_back(ds_bool(true));
    var flt: DSValue = dll2.front();
    if (flt.flt_val == 3.14) {
        print("PASS: float front");
    } else {
        print("FAIL: float front");
    };
    var bl: DSValue = dll2.back();
    if (bl.bool_val) {
        print("PASS: bool back");
    } else {
        print("FAIL: bool back");
    };
    var sv: DSValue = dll2.get(1);
    if (sv.str_val == "hello") {
        print("PASS: str get(1)");
    } else {
        print("FAIL: str get(1)");
    };

    print("DoublyLL tests done.");
};