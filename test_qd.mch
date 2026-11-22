from "mocha-forge" import *;

function main(didLoad) -> null {
    var order: str[] = ["low", "medium", "high"];
    var data: str[] = ["medium", "low", "high", "low"];

    var enc: OrdinalEncoder = OrdinalEncoder();
    enc.fit(data, order);
    print(enc.n_categories, newLine=true);

    var o: str[] = enc.get_order();
    var i: int = 0;
    while (i < o.length) {
        print(o[i], newLine=true);
        i++;
    };

    // encode, then decode back
    var codes: int[] = enc.transform(data);
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

    // save, load into a fresh encoder, use it
    enc.save("ord_test.db");
    var enc2: OrdinalEncoder = OrdinalEncoder();
    enc2.load("ord_test.db");
    var one: str[] = ["high"];
    var c2: int[] = enc2.transform(one);
    print(c2[0], newLine=true);
    var o2: str[] = enc2.get_order();
    var k: int = 0;
    while (k < o2.length) {
        print(o2[k], newLine=true);
        k++;
    };
};