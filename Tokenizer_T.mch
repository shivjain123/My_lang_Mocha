from "mocha-string" import *;

function main(didLoad) -> null {
    var tok: Tokenizer = Tokenizer();

    // fit on some sentences
    var texts: str[] = [
        "the cat sat on the mat",
        "the dog ran in the park",
        "I love machine learning"
    ];
    tok.fit(texts);

    print("Vocab size: ", tok.size(), "\n");

    // encode a sentence
    var ids: int[] = tok.encode("the cat love learning");
    print("Encoded: ");
    var i: int = 0;
    while (i < ids.length) {
        print(ids[i], " ");
        i = i + 1;
    };
    print("\n");

    // decode back

    var decoded: str = tok.decode(ids);
    print("Decoded: ", decoded, "\n");

    // encode with unknown word
    var ids2: int[] = tok.encode("the cat chased a dragon");
    print("With unknowns: ");
    var j: int = 0;
    while (j < ids2.length) {
        print(ids2[j], " ");
        j = j + 1;
    };
    print("\n");
    var decoded2: str = tok.decode(ids2);
    print("Decoded: ", decoded2, "\n");
};