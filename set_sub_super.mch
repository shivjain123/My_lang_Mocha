"""function test(didLoad){
    var a: set<int> = <1, 2>;
    var b: set<int> = <1, 2, 3>;
    print(a.subset(b), newLine=true);      // true
    print(b.superset(a), newLine=true);    // true
    print(a.subset(a), newLine=true);      // false (equal, not proper)
    print(b.subset(a), newLine=true);      // false
};"""

"""function test(didLoad){
    var e: set<int> = <>;          // adjust if empty sets are written differently
    var a: set<int> = <1, 2>;
    print(e.subset(a), newLine=true);              // true  (empty is a proper subset of non-empty)
    print(e.subset(e), newLine=true);              // false (equal)
    print(a.subset(a.union(e)), newLine=true);     // false (union of a and empty equals a)
    print(a.subset(a.union(<3>)), newLine=true);   // true
};"""

function test(didLoad){
    var a: set<str> = <"x", "y">;
    var b: set<str> = <"x", "y", "z">;
    print(a.subset(b), newLine=true);      // true
    print(b.superset(a), newLine=true);    // true
    print(a.subset(a), newLine=true);      // false
};