from "mocha-matvec" import *;

function bt_test(didLoad) -> null {
    var a: int[] = [];
    var i: int = 0;
    while (i < 5) {
        a.push(i);
        i += 1;
    };
    print(a.length, newLine=true);
    print(a.occs(3), newLine=true);
};
