from "mocha-matvec" import *;

function set_test2(didLoad) -> null {
    var s: set<int> = <1, 2, 3>;
    var t: set<int> = <2, 3, 4>;
    var u: set<int> = s.union(t);
    if (u.has(4)) { print(1, newLine=true); };
    var i: set<int> = s.intersect(t);
    if (i.has(1)) { print(5, newLine=true); } else { print(6, newLine=true); };
    var mx: int = s.max();
    print(mx, newLine=true);
};
