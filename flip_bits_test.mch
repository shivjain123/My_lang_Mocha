from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(1);
    var a: float[] = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0];
    var b: float[] = flip_bits(a, 3);

    var diff: int = 0;
    var i: int = 0;
    while (i < a.length) {
        print(a[i], " ", b[i], "\n");
        if (a[i] != b[i]) { diff = diff + 1; };
        i = i + 1;
    };
    print("differing bits: ", diff, "\n");
};