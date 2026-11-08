function test_set_operations(didLoad) -> null {
    print("=== 2. Set operations ===");

    var a: set<int> = <1, 2, 3, 4, 5>;
    var b: set<int> = <3, 4, 5, 6, 7>;

    var u: set<int> = a.union(b);
    print("--- union ---");
    for each c in <u> {
        print(c, newLine=true);
    };

    var i: set<int> = a.intersect(b);
    print("--- intersect ---");
    for each d in <i> {
        print(d, newLine=true);
    };

    var x: set<int> = a.xor(b);
    print("--- xor ---");
    for each el in <x> {
        print(el, newLine=true);
    };

    var rd: set<int> = a.rel_diff(b);
    print("--- rel_diff a-b ---");
    for each el1 in <rd> {
        print(el1, newLine=true);
    };

    var rd2: set<int> = b.rel_diff(a);
    print("--- rel_diff b-a ---");
    for each el2 in <rd2> {
        print(el2, newLine=true);
    };
};