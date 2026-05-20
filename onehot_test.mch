from "mocha-forge" import *;
function hot(didLoad){
    var enc: OneHotEncoder = OneHotEncoder();
    var cats: str[] = ["cat", "dog", "bird", "cat", "bird"];
    enc.fit(cats);
    var names: str[] = enc.get_feature_names();

    var encoded: int[][] = enc.transform(cats);
    var i: int = 0;
    while (i < encoded.length) {
        print(str(encoded[i][0]) + " " + str(encoded[i][1]) + " " + str(encoded[i][2]), newLine=true);
        i++;
    };

    var decoded: str[] = enc.inverse_transform(encoded);
    var j: int = 0;
    while (j < decoded.length) {
        print(decoded[j], newLine=true);
        j++;
    };
};