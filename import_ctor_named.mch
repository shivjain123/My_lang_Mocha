from "mocha-neuron" import *;

function main(didLoad) -> null {
    var r: Rbm = Rbm(6, hidden_size=4);
    var s: Rbm = Rbm(hidden_size=3, visible_size=5);
    print(r.visible_size, " ", r.hidden_size, newLine=true);
    print(s.visible_size, " ", s.hidden_size, newLine=true);
    r.dispose();
    s.dispose();
};