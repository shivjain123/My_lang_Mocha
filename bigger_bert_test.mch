from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    mocha_cuda_init();

    var positive: str[] = [
        "i love this movie", "this film is great", "amazing wonderful brilliant",
        "i really enjoyed it", "best movie ever", "fantastic performance",
        "i loved every moment", "absolutely brilliant film", "what a beautiful story",
        "the acting was superb", "i would watch it again", "a truly great film",
        "so much fun to watch", "the music was wonderful", "i enjoyed every minute",
        "an excellent and moving story", "the cast was fantastic",
        "great movie with a lovely ending", "i was really impressed",
        "a brilliant and funny film", "what an amazing movie", "such a charming story",
        "i liked it a lot", "the best film this year"
    ];

    var negative: str[] = [
        "this was terrible", "i hated this movie", "awful boring film",
        "worst movie ever", "complete waste of time", "i did not enjoy this",
        "terrible acting bad story", "so boring and awful", "what an ugly mess",
        "the acting was dreadful", "i would never watch it again", "a truly bad film",
        "so much pain to watch", "the music was annoying", "i hated every minute",
        "a boring and confusing story", "the cast was awful",
        "bad movie with a dull ending", "i was really disappointed",
        "a messy and unfunny film", "what a horrible movie", "such a tedious story",
        "i disliked it a lot", "the worst film this year"
    ];

    var pos_test: str[] = [
        "what a great and wonderful film", "i really loved this story",
        "an amazing and fun movie", "the acting was fantastic",
        "a delightful surprise", "i adored every scene"
    ];

    var neg_test: str[] = [
        "what a terrible and boring film", "i really hated this story",
        "an awful and dull movie", "the acting was bad",
        "a dreadful surprise", "i despised every scene"
    ];

    var model: BertClassifier = BertClassifier(positive, negative, 32, 16, 64);
    model.train(positive, negative, 2000, 0.0001);

    var correct: int = 0;
    var i: int = 0;
    while (i < pos_test.length) {
        var sp: float = model.predict(pos_test[i]);
        print("[pos] ", pos_test[i], " -> ", sp, "\n");
        if (sp > 0.5) { correct++; };
        i++;
    };
    var j: int = 0;
    while (j < neg_test.length) {
        var sn: float = model.predict(neg_test[j]);
        print("[neg] ", neg_test[j], " -> ", sn, "\n");
        if (sn < 0.5) { correct++; };
        j++;
    };
    print("Correct: ", correct, " / 12\n");

    model.dispose();
};