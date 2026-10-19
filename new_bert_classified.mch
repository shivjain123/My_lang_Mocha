from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    mocha_cuda_init();

    var positive: str[] = [
        "i love this movie",
        "this film is great",
        "amazing wonderful brilliant",
        "i really enjoyed it",
        "best movie ever",
        "fantastic performance",
        "i loved every moment",
        "absolutely brilliant film"
    ];

    var negative: str[] = [
        "this was terrible",
        "i hated this movie",
        "awful boring film",
        "worst movie ever",
        "complete waste of time",
        "i did not enjoy this",
        "terrible acting bad story",
        "so boring and awful"
    ];

    var model: BertClassifier = BertClassifier(positive, negative, 32, 16, 64);
    model.train(positive, negative, 2000, 0.0001);

    print("i love this film -> ", model.predict("i love this film"), "\n");
    print("terrible awful movie -> ", model.predict("terrible awful movie"), "\n");
    print("brilliant amazing story -> ", model.predict("brilliant amazing story"), "\n");
    print("i hated every moment -> ", model.predict("i hated every moment"), "\n");

    model.dispose();
};