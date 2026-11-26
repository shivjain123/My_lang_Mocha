from "mocha-matvec" import *;

function ds_test(didLoad) -> null {
    var d: dict = {"a": 1, "b": 2};
    var n: int = d["b"];
    print(n, newLine=true);
    if (d.has("a")) { print(1, newLine=true); };
    d.remove("a");
    if (d.has("a")) { print(1, newLine=true); } else { print(0, newLine=true); };
    var s: set<int> = <1, 2, 3>;
    if (s.has(2)) { print(7, newLine=true); };
    s.insert(9);
    if (s.has(9)) { print(8, newLine=true); };
    s.delete(1);
    if (s.has(1)) { print(5, newLine=true); } else { print(6, newLine=true); };
};
