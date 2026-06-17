from "mocha-ds" import *;

function main(didLoad) -> null {
    var d: Deck = Deck();

    // is_empty on fresh deck
    if (d.is_empty()) {
        print("PASS: is_empty on empty deck", newLine=true);
    } else {
        print("FAIL: is_empty on empty deck", newLine=true);
    };

    // push_back and size
    d.push_back(ds_int(10));
    d.push_back(ds_int(20));
    d.push_back(ds_int(30));
    if (d.size == 3) {
        print("PASS: size == 3 after 3 push_back", newLine=true);
    } else {
        print("FAIL: size == 3 after 3 push_back", newLine=true);
    };

    // front and back after push_back
    var f1: DSValue = d.front;
    if (f1.int_val == 10) {
        print("PASS: front == 10 after push_back", newLine=true);
    } else {
        print("FAIL: front == 10 after push_back", newLine=true);
    };
    var b1: DSValue = d.back;
    if (b1.int_val == 30) {
        print("PASS: back == 30 after push_back", newLine=true);
    } else {
        print("FAIL: back == 30 after push_back", newLine=true);
    };

    // print_all (visual: 10 <-> 20 <-> 30)
    print("Expect [10 <-> 20 <-> 30]:", newLine=true);
    d.print_all();

    // push_front
    d.push_front(ds_int(5));
    var f2: DSValue = d.front;
    if (f2.int_val == 5) {
        print("PASS: front == 5 after push_front", newLine=true);
    } else {
        print("FAIL: front == 5 after push_front", newLine=true);
    };
    var b2: DSValue = d.back;
    if (b2.int_val == 30) {
        print("PASS: back == 30 unchanged after push_front", newLine=true);
    } else {
        print("FAIL: back == 30 unchanged after push_front", newLine=true);
    };
    if (d.size == 4) {
        print("PASS: size == 4 after push_front", newLine=true);
    } else {
        print("FAIL: size == 4 after push_front", newLine=true);
    };

    // print_all (visual: 5 <-> 10 <-> 20 <-> 30)
    print("Expect [5 <-> 10 <-> 20 <-> 30]:", newLine=true);
    d.print_all();

    // pop_front
    var pf1: DSValue = d.pop_front();
    if (pf1.int_val == 5) {
        print("PASS: pop_front() == 5", newLine=true);
    } else {
        print("FAIL: pop_front() == 5", newLine=true);
    };
    var f3: DSValue = d.front;
    if (f3.int_val == 10) {
        print("PASS: front == 10 after pop_front", newLine=true);
    } else {
        print("FAIL: front == 10 after pop_front", newLine=true);
    };
    if (d.size == 3) {
        print("PASS: size == 3 after pop_front", newLine=true);
    } else {
        print("FAIL: size == 3 after pop_front", newLine=true);
    };

    // pop_back
    var pb1: DSValue = d.pop_back();
    if (pb1.int_val == 30) {
        print("PASS: pop_back() == 30", newLine=true);
    } else {
        print("FAIL: pop_back() == 30", newLine=true);
    };
    var b3: DSValue = d.back;
    if (b3.int_val == 20) {
        print("PASS: back == 20 after pop_back", newLine=true);
    } else {
        print("FAIL: back == 20 after pop_back", newLine=true);
    };
    if (d.size == 2) {
        print("PASS: size == 2 after pop_back", newLine=true);
    } else {
        print("FAIL: size == 2 after pop_back", newLine=true);
    };

    // drain to empty via pop_front
    d.pop_front();
    d.pop_front();
    if (d.is_empty()) {
        print("PASS: is_empty after draining", newLine=true);
    } else {
        print("FAIL: is_empty after draining", newLine=true);
    };
    if (d.front == null) {
        print("PASS: front == null on empty deck", newLine=true);
    } else {
        print("FAIL: front == null on empty deck", newLine=true);
    };
    if (d.back == null) {
        print("PASS: back == null on empty deck", newLine=true);
    } else {
        print("FAIL: back == null on empty deck", newLine=true);
    };
    if (d.size == 0) {
        print("PASS: size == 0 on empty deck", newLine=true);
    } else {
        print("FAIL: size == 0 on empty deck", newLine=true);
    };

    // push after empty — both front and back must reset
    d.push_back(ds_int(99));
    var f4: DSValue = d.front;
    if (f4.int_val == 99) {
        print("PASS: front == 99 after push_back on empty", newLine=true);
    } else {
        print("FAIL: front == 99 after push_back on empty", newLine=true);
    };
    var b4: DSValue = d.back;
    if (b4.int_val == 99) {
        print("PASS: back == 99 after push_back on empty", newLine=true);
    } else {
        print("FAIL: back == 99 after push_back on empty", newLine=true);
    };

    // DSKind variety
    var d2: Deck = Deck();
    d2.push_back(ds_float(1.11));
    d2.push_front(ds_str("hello"));
    d2.push_back(ds_bool(true));
    // list: hello <-> 1.11 <-> true
    var f5: DSValue = d2.front;
    if (f5.str_val == "hello") {
        print("PASS: front str == hello", newLine=true);
    } else {
        print("FAIL: front str == hello", newLine=true);
    };
    var b5: DSValue = d2.back;
    var bv: bool = b5.bool_val;
    if (bv) {
        print("PASS: back bool == true", newLine=true);
    } else {
        print("FAIL: back bool == true", newLine=true);
    };
    var pb2: DSValue = d2.pop_back();
    var b6: DSValue = d2.back;
    if (b6.flt_val == 1.11) {
        print("PASS: back float == 1.11 after pop_back", newLine=true);
    } else {
        print("FAIL: back float == 1.11 after pop_back", newLine=true);
    };

    print("Deck tests done.", newLine=true);
};