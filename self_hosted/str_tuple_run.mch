from "mocha-matvec" import *;

function str_tuple_run(didLoad) -> null {
    var w: (str, 2) = ("x", "yz");
    var s: str = w#1;
    print(s, newLine=true);
};
