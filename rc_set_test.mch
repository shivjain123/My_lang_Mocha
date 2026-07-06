function main(didLoad) -> null {
    // Stage 1: fresh string elements via set literal + reassignment
    // Exercises: mocha_set_new, rc_strdup on insert, mocha_set_release on reassign
    var s1: set<str> = <"a", "b", "c">;
    var i: int = 0;
    while (i < 200000) {
        s1 = <"a", "b", "c">;
        i++;
    };
    print("stage 1 done", newLine=true);

    // Stage 2: .insert() with a FRESH (non-borrowed) string — this is the
    // format()/concat-style leak we fixed in gen_set_method_call
    var s2: set<str> = <>;
    var j: int = 0;
    while (j < 200000) {
        s2.insert("x" + "y");
        s2.clean();
        j++;
    };
    print("stage 2 done", newLine=true);

    // Stage 3: .insert() with a BORROWED variable (already-owned string) —
    // should NOT be double-released
    var name: str = "hello";
    var s3: set<str> = <>;
    var k: int = 0;
    while (k < 200000) {
        s3.insert(name);
        s3.delete(name);
        k++;
    };
    print("stage 3 done", newLine=true);
    print(name, newLine=true); // sanity: name should still be readable, not corrupted

    // Stage 4: .has() with a fresh string arg — checks the has() leak fix
    var s4: set<str> = <"cat", "dog">;
    var m: int = 0;
    while (m < 200000) {
        var found: bool = s4.has("c" + "at");
        m++;
    };
    print("stage 4 done", newLine=true);

    // Stage 5: union/intersect with a FRESH set argument — checks the
    // set-op leak fix (mocha_set_release on non-Identifier args)
    var base: set<int> = <1, 2, 3>;
    var n: int = 0;
    while (n < 200000) {
        var combined: set<int> = base.union(<4, 5, 6>);
        n++;
    };
    print("stage 5 done", newLine=true);

    // Stage 6: min/max on a str set — checks rc_retain in mocha_set_min_str/max_str
    var s6: set<str> = <"pear", "apple", "kiwi">;
    var p: int = 0;
    while (p < 200000) {
        var mn: str = s6.min();
        var mx: str = s6.max();
        p++;
    };
    print("stage 6 done", newLine=true);

    print("all stages done", newLine=true);
};