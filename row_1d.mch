from "mocha-neuron" import *;

function main(didLoad) -> null {
    var t: Tensor = Tensor(3, 4);
    t.put(0, 0, 1.0); t.put(0, 1, 2.0); t.put(0, 2, 3.0); t.put(0, 3, 4.0);
    t.put(1, 0, 5.0); t.put(1, 1, 6.0); t.put(1, 2, 7.0); t.put(1, 3, 8.0);
    t.put(2, 0, 9.0); t.put(2, 1, 10.0); t.put(2, 2, 11.0); t.put(2, 3, 12.0);

    var row: Tensor = t[0][];
    print("row: ", newLine=true);
    row.show();
    row.dispose();
    t.dispose();
};