from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(7);
    var p: str[] = ["a"];
    var q: str[] = ["b"];
    var m: BertClassifier = BertClassifier(p, q, 2, 1, 1);
    m.load("bc_test.db");
    print("after: ", m.predict("i love this film"), "\n");
    print("other: ", m.predict("i hated this movie"), "\n");
    m.dispose();
};