from "mocha-matvec" import *;

function try_tests(didLoad) -> null {
    try {
        fail "boom";
    } rescue, e {
        print("caught: " + e, newLine=true);
    };

    try {
        try {
            fail "inner";
        } rescue, e1 {
            rethrow;
        };
    } rescue, e2 {
        print("outer caught: " + e2, newLine=true);
    };

    var i: int = 0;
    while (i < 3) {
        i = i + 1;
        try {
            if (i == 2) { continue; };
            print("loop body " + str(i), newLine=true);
        } rescue {
            print("WRONG", newLine=true);
        };
    };
};
