from "mocha-neuron" import *;
from "mocha-stopwatch" import *;

function main(didLoad) -> null {
    var net: Hopfield = Hopfield(25);

    var sw: Stopwatch = Stopwatch();
    print("Starting now!");
    sw.begin();

    // pattern 1: checkerboard A
    var p1: Tensor = Tensor(1, 25);
    var i: int = 0;
    while (i < 25) {
        if (i % 2 == 0) {
            p1.put(0, i, 1.0);
        } else {
            p1.put(0, i, -1.0);
        };
        i = i + 1;
    };

    // pattern 2: inverse checkerboard
    var p2: Tensor = Tensor(1, 25);
    i = 0;
    while (i < 25) {
        if (i % 2 == 0) {
            p2.put(0, i, -1.0);
        } else {
            p2.put(0, i, 1.0);
        };
        i = i + 1;
    };

    // pattern 3: first half on, second half off
    var p3: Tensor = Tensor(1, 25);
    i = 0;
    while (i < 25) {
        if (i < 13) {
            p3.put(0, i, 1.0);
        } else {
            p3.put(0, i, -1.0);
        };
        i = i + 1;
    };

    net.store(p1);
    net.store(p2);
    net.store(p3);
    net.normalize();

    // noisy p1 — flip 3 bits
    var noisy1: Tensor = Tensor(1, 25);
    i = 0;
    while (i < 25) {
        if (i % 2 == 0) {
            noisy1.put(0, i, 1.0);
        } else {
            noisy1.put(0, i, -1.0);
        };
        i = i + 1;
    };
    noisy1.put(0, 2, -1.0);
    noisy1.put(0, 8, -1.0);
    noisy1.put(0, 14, -1.0);

    // noisy p3 — flip 3 bits
    var noisy3: Tensor = Tensor(1, 25);
    i = 0;
    while (i < 25) {
        if (i < 13) {
            noisy3.put(0, i, 1.0);
        } else {
            noisy3.put(0, i, -1.0);
        };
        i = i + 1;
    };
    noisy3.put(0, 1, -1.0);
    noisy3.put(0, 5, 1.0);
    noisy3.put(0, 20, 1.0);

    print("Stored p1:", newLine=true); p1.show();
    print("Noisy p1:", newLine=true); noisy1.show();
    print("Recalled p1:", newLine=true);
    var r1: Tensor = net.recall(noisy1, 20);
    r1.show();

    print("Stored p3:", newLine=true); p3.show();
    print("Noisy p3:", newLine=true); noisy3.show();
    print("Recalled p3:", newLine=true);
    var r3: Tensor = net.recall(noisy3, 20);
    r3.show();

    sw.end();
    print("Done!");
    print("Time elapsed: " + str(sw.elapsed_ms()) + "ms", newLine=true);

    p1.dispose(); p2.dispose(); p3.dispose();
    noisy1.dispose(); noisy3.dispose();
    r1.dispose(); r3.dispose();
    net.dispose();
};