from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    var pos: str[] = ["i love this movie", "great film"];
    var neg: str[] = ["i hated this movie", "awful film"];
    var m: BertClassifier = BertClassifier(pos, neg, 8, 4, 8);
    m.train(pos, neg, 50, 0.01);
    print("before: ", m.predict("i love this film"), "\n");
    m.save("bc_test.db");
    m.dispose();
};