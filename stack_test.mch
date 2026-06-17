from "mocha-ds" import *;

function main(didLoad) -> null {
    var s: Stack = Stack();

    // is_empty on fresh stack
    if (s.is_empty()) {
        print("PASS: is_empty on empty stack", newLine=true);
    } else {
        print("FAIL: is_empty on empty stack", newLine=true);
    };

    // push and size
    s.push(ds_int(10));
    s.push(ds_int(20));
    s.push(ds_int(30));
    if (s.size == 3) {
        print("PASS: size == 3 after 3 pushes", newLine=true);
    } else {
        print("FAIL: size == 3 after 3 pushes", newLine=true);
    };

    // top after pushes
    if (s.top.int_val == 30) {
        print("PASS: top == 30 after push(30)", newLine=true);
    } else {
        print("FAIL: top == 30 after push(30)", newLine=true);
    };

    // print_all (visual: 30 -> 20 -> 10)
    print("Expect [30 -> 20 -> 10]:");
    s.print_all();

    // pop
    var p1: DSValue = s.pop();
    if (p1.int_val == 30) {
        print("PASS: pop() == 30", newLine=true);
    } else {
        print("FAIL: pop() == 30", newLine=true);
    };
    if (s.top.int_val == 20) {
        print("PASS: top == 20 after pop", newLine=true);
    } else {
        print("FAIL: top == 20 after pop", newLine=true);
    };
    if (s.size == 2) {
        print("PASS: size == 2 after pop", newLine=true);
    } else {
        print("FAIL: size == 2 after pop", newLine=true);
    };

    // pop again
    var p2: DSValue = s.pop();
    if (p2.int_val == 20) {
        print("PASS: pop() == 20", newLine=true);
    } else {
        print("FAIL: pop() == 20", newLine=true);
    };
    if (s.top.int_val == 10) {
        print("PASS: top == 10 after second pop", newLine=true);
    } else {
        print("FAIL: top == 10 after second pop", newLine=true);
    };

    // pop down to empty
    var p3: DSValue = s.pop();
    if (p3.int_val == 10) {
        print("PASS: pop() == 10", newLine=true);
    } else {
        print("FAIL: pop() == 10", newLine=true);
    };
    if (s.is_empty()) {
        print("PASS: is_empty after popping all", newLine=true);
    } else {
        print("FAIL: is_empty after popping all", newLine=true);
    };
    if (s.top == null) {
        print("PASS: top == null on empty stack", newLine=true);
    } else {
        print("FAIL: top == null on empty stack", newLine=true);
    };
    if (s.size == 0) {
        print("PASS: size == 0 on empty stack", newLine=true);
    } else {
        print("FAIL: size == 0 on empty stack", newLine=true);
    };

    // DSKind variety
    var s2: Stack = Stack();
    s2.push(ds_float(1.5));
    s2.push(ds_str("hello"));
    s2.push(ds_bool(true));
    var t1: DSValue = s2.top;
    if (t1.bool_val) {
        print("PASS: top bool == true", newLine=true);
    } else {
        print("FAIL: top bool == true", newLine=true);
    };
    var p4: DSValue = s2.pop();
    var t2: DSValue = s2.top;
    if (t2.str_val == "hello") {
        print("PASS: top str == hello after pop", newLine=true);
    } else {
        print("FAIL: top str == hello after pop", newLine=true);
    };
    var p5: DSValue = s2.pop();
    var t3: DSValue = s2.top;
    if (t3.flt_val == 1.5) {
        print("PASS: top float == 1.5 after pop", newLine=true);
    } else {
        print("FAIL: top float == 1.5 after pop", newLine=true);
    };

    print("Stack tests done.", newLine=true);
};