from "mocha-ds" import *;

function main(didLoad) -> null {
    var q: Queue = Queue();

    // is_empty on fresh queue
    if (q.is_empty()) {
        print("PASS: is_empty on empty queue", newLine=true);
    } else {
        print("FAIL: is_empty on empty queue", newLine=true);
    };

    // enqueue and size
    q.enqueue(ds_int(10));
    q.enqueue(ds_int(20));
    q.enqueue(ds_int(30));
    if (q.size == 3) {
        print("PASS: size == 3 after 3 enqueues", newLine=true);
    } else {
        print("FAIL: size == 3 after 3 enqueues", newLine=true);
    };

    // front after enqueues
    var f1: DSValue = q.front;
    if (f1.int_val == 10) {
        print("PASS: front == 10 after enqueues", newLine=true);
    } else {
        print("FAIL: front == 10 after enqueues", newLine=true);
    };

    // print_all (visual: 10 <-> 20 <-> 30)
    print("Expect [10 <-> 20 <-> 30]:", newLine=true);
    q.print_all();

    // dequeue
    var d1: DSValue = q.dequeue();
    if (d1.int_val == 10) {
        print("PASS: dequeue() == 10", newLine=true);
    } else {
        print("FAIL: dequeue() == 10", newLine=true);
    };
    var f2: DSValue = q.front;
    if (f2.int_val == 20) {
        print("PASS: front == 20 after dequeue", newLine=true);
    } else {
        print("FAIL: front == 20 after dequeue", newLine=true);
    };
    if (q.size == 2) {
        print("PASS: size == 2 after dequeue", newLine=true);
    } else {
        print("FAIL: size == 2 after dequeue", newLine=true);
    };

    // dequeue again
    var d2: DSValue = q.dequeue();
    if (d2.int_val == 20) {
        print("PASS: dequeue() == 20", newLine=true);
    } else {
        print("FAIL: dequeue() == 20", newLine=true);
    };
    var f3: DSValue = q.front;
    if (f3.int_val == 30) {
        print("PASS: front == 30 after second dequeue", newLine=true);
    } else {
        print("FAIL: front == 30 after second dequeue", newLine=true);
    };

    // dequeue down to empty
    var d3: DSValue = q.dequeue();
    if (d3.int_val == 30) {
        print("PASS: dequeue() == 30", newLine=true);
    } else {
        print("FAIL: dequeue() == 30", newLine=true);
    };
    if (q.is_empty()) {
        print("PASS: is_empty after dequeuing all", newLine=true);
    } else {
        print("FAIL: is_empty after dequeuing all", newLine=true);
    };
    if (q.front == null) {
        print("PASS: front == null on empty queue", newLine=true);
    } else {
        print("FAIL: front == null on empty queue", newLine=true);
    };
    if (q.size == 0) {
        print("PASS: size == 0 on empty queue", newLine=true);
    } else {
        print("FAIL: size == 0 on empty queue", newLine=true);
    };

    // enqueue after empty — front must reset correctly
    q.enqueue(ds_int(99));
    var f4: DSValue = q.front;
    if (f4.int_val == 99) {
        print("PASS: front == 99 after enqueue on empty", newLine=true);
    } else {
        print("FAIL: front == 99 after enqueue on empty", newLine=true);
    };
    if (q.size == 1) {
        print("PASS: size == 1 after enqueue on empty", newLine=true);
    } else {
        print("FAIL: size == 1 after enqueue on empty", newLine=true);
    };

    // DSKind variety
    var q2: Queue = Queue();
    q2.enqueue(ds_float(2.71));
    q2.enqueue(ds_str("world"));
    q2.enqueue(ds_bool(false));
    var f5: DSValue = q2.front;
    if (f5.flt_val == 2.71) {
        print("PASS: front float == 2.71", newLine=true);
    } else {
        print("FAIL: front float == 2.71", newLine=true);
    };
    var d4: DSValue = q2.dequeue();
    var f6: DSValue = q2.front;
    if (f6.str_val == "world") {
        print("PASS: front str == world after dequeue", newLine=true);
    } else {
        print("FAIL: front str == world after dequeue", newLine=true);
    };
    var d5: DSValue = q2.dequeue();
    var f7: DSValue = q2.front;
    var fb: bool = f7.bool_val;
    if (fb == false) {
        print("PASS: front bool == false after dequeue", newLine=true);
    } else {
        print("FAIL: front bool == false after dequeue", newLine=true);
    };

    print("Queue tests done.", newLine=true);
};