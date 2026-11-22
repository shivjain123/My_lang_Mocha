from "mocha-forge" import *;

function main(didLoad) -> null {
    var labels: str[] = ["cat", "dog", "cat", "bird"];

    var enc: TargetEncoder = TargetEncoder();
    enc.fit(labels);
    print(enc.n_categories, newLine=true);

    var cats: str[] = enc.get_categories();
    var i: int = 0;
    while (i < cats.length) {
        print(cats[i], newLine=true);
        i++;
    };

    // encode, then decode
    var codes: int[] = enc.transform(labels);
    var c: int = 0;
    while (c < codes.length) {
        print(codes[c], newLine=true);
        c++;
    };
    var back: str[] = enc.inverse_transform(codes);
    var b: int = 0;
    while (b < back.length) {
        print(back[b], newLine=true);
        b++;
    };

    // save and load
    enc.save("tgt_test.db");
    var enc2: TargetEncoder = TargetEncoder();
    enc2.load("tgt_test.db");
    var one: str[] = ["bird"];
    var c2: int[] = enc2.transform(one);
    print(c2[0], newLine=true);
    var cats2: str[] = enc2.get_categories();
    var k: int = 0;
    while (k < cats2.length) {
        print(cats2[k], newLine=true);
        k++;
    };
};