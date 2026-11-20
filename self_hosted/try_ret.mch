from "mocha-matvec" import *;

function find_first(limit: int) -> int {
    var i: int = 0;
    while (i < limit) {
        try {
            if (i == 2) { return i; };
        } rescue {
            print("WRONG", newLine=true);
        };
        i = i + 1;
    };
    return 0;
};

function try_return_tests(didLoad) -> null {
    print("found " + str(find_first(5)), newLine=true);
};
