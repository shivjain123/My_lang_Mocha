from "mocha-neuron" import *;

function main(didLoad) -> null {
    var lsm: Lsm = Lsm(1, 10, 2, 0.9);
    var s: Tensor = Tensor(5, 10);
    s.zeros();
    var t: Tensor = Tensor(5, 2);
    t.zeros();
    lsm.train(s, t, 0.1);
    print("should never print", newLine=true);
};