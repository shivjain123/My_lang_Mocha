from "mocha-matvec" import *;

function str_tests(didLoad) -> null {
    var a: str = "say \"hi\"\tback\\slash";
    var b: str = "café";
    print(a, newLine=true);
    print(b, newLine=true);
};
