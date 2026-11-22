from "mocha-forge" import *;

function main(didLoad) -> null {
    var data: str[] = ["red", "green", "blue", "green", "red"];

    var enc: OneHotEncoder = OneHotEncoder();
    enc.fit(data);
    print(enc.n_categories, newLine=true);

    var names: str[] = enc.get_feature_names();
    var i: int = 0;
    while (i < names.length) {
        print(names[i], newLine=true);
        i++;
    };

    // one-hot rows, each printed as "a,b,c"
    var e: int[][] = enc.transform(data);
    var r: int = 0;
    while (r < e.length) {
        print(str(e[r][0]) + "," + str(e[r][1]) + "," + str(e[r][2]), newLine=true);
        r++;
    };

    // back to strings
    var back: str[] = enc.inverse_transform(e);
    var b: int = 0;
    while (b < back.length) {
        print(back[b], newLine=true);
        b++;
    };

    // save, load into a fresh encoder, and use it
    enc.save("enc_test.db");
    var enc2: OneHotEncoder = OneHotEncoder();
    enc2.load("enc_test.db");
    print(enc2.n_categories, newLine=true);
    var names2: str[] = enc2.get_feature_names();
    var k: int = 0;
    while (k < names2.length) {
        print(names2[k], newLine=true);
        k++;
    };
    var one: str[] = ["blue"];
    var e2: int[][] = enc2.transform(one);
    print(str(e2[0][0]) + "," + str(e2[0][1]) + "," + str(e2[0][2]), newLine=true);
    var back2: str[] = enc2.inverse_transform(e2);
    print(back2[0], newLine=true);
};