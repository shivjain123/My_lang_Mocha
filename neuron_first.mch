from "mocha-neuron" import *;

function main(didLoad) -> null {
    var a: Tensor = Tensor(2, 2);
    a.put(0, 0, 1.0);
    a.put(0, 1, 2.0);
    a.put(1, 0, 3.0);
    a.put(1, 1, 4.0);

    var b: Tensor = Tensor(2, 2);
    b.put(0, 0, 5.0);
    b.put(0, 1, 6.0);
    b.put(1, 0, 7.0);
    b.put(1, 1, 8.0);

    var c: Tensor = a.matmul(b);
    c.show();

    a.dispose();
    b.dispose();
    c.dispose();
};