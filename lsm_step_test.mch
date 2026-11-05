from "mocha-neuron" import *;

function main(didLoad) -> null {
    var lsm: Lsm = Lsm(2, 10, 1, 0.9);
    var u: Tensor = Tensor(1, 3);
    u.zeros();
    var out: Tensor = lsm.step(u);
    print("should never print", newLine=true);
};