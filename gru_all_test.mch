from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    var gru: Gru = Gru(1, 4);

    var xs: Tensor[] = [];
    var x0: Tensor = Tensor(1, 1); x0.put(0, 0, 1.0);
    var x1: Tensor = Tensor(1, 1); x1.put(0, 0, 0.0);
    var x2: Tensor = Tensor(1, 1); x2.put(0, 0, 1.0);
    xs.push(x0);
    xs.push(x1);
    xs.push(x2);

    var all: Tensor = gru.forward_all(xs);
    print("all steps:", newLine=true);
    all.show();

    x0.dispose(); x1.dispose(); x2.dispose();
    all.dispose();
    gru.dispose();
};