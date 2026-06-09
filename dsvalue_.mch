from "mocha-ds" import *;

function main(didLoad) -> null {

    // ============================================================
    // TEST 1 — DSValue smart constructors and ds_to_str
    // ============================================================
    var vi: DSValue = ds_int(42);
    var vf: DSValue = ds_float(3.14);
    var vs: DSValue = ds_str("hello");
    var vb: DSValue = ds_bool(true);

    print(ds_to_str(vi), newLine=true);  // 42
    print(ds_to_str(vf), newLine=true);  // 3.14
    print(ds_to_str(vs), newLine=true);  // hello
    print(ds_to_str(vb), newLine=true);  // true

    // ============================================================
    // TEST 2 — ds_equals
    // ============================================================
    print(ds_equals(ds_int(42), ds_int(42)), newLine=true);    // true
    print(ds_equals(ds_int(42), ds_int(99)), newLine=true);    // false
    print(ds_equals(ds_int(42), ds_float(42.0)), newLine=true); // false — different kinds
    print(ds_equals(ds_str("hi"), ds_str("hi")), newLine=true); // true

    // ============================================================
    // TEST 3 — prepend and print_all
    // ============================================================
    var list: SinglyLL = SinglyLL();
    list.prepend(ds_int(3));
    list.prepend(ds_int(2));
    list.prepend(ds_int(1));
    list.print_all();  // 1 -> 2 -> 3
    print(list.size, newLine=true);  // 3

    // ============================================================
    // TEST 4 — append
    // ============================================================
    var list2: SinglyLL = SinglyLL();
    list2.append(ds_str("a"));
    list2.append(ds_str("b"));
    list2.append(ds_str("c"));
    list2.print_all();  // a -> b -> c
    print(list2.size, newLine=true);  // 3

    // ============================================================
    // TEST 5 — get
    // ============================================================
    print(ds_to_str(list2.get(0)), newLine=true);  // a
    print(ds_to_str(list2.get(1)), newLine=true);  // b
    print(ds_to_str(list2.get(2)), newLine=true);  // c

    // ============================================================
    // TEST 6 — contains
    // ============================================================
    print(list2.contains(ds_str("b")), newLine=true);  // true
    print(list2.contains(ds_str("z")), newLine=true);  // false

    // ============================================================
    // TEST 7 — remove
    // ============================================================
    // Remove middle
    list2.remove(ds_str("b"));
    list2.print_all();  // a -> c
    print(list2.size, newLine=true);  // 2

    // Remove head
    list2.remove(ds_str("a"));
    list2.print_all();  // c
    print(list2.size, newLine=true);  // 1

    // Remove nonexistent — should return false
    print(list2.remove(ds_str("z")), newLine=true);  // false

    // ============================================================
    // TEST 8 — is_empty
    // ============================================================
    print(list2.is_empty(), newLine=true);  // false
    list2.remove(ds_str("c"));
    print(list2.is_empty(), newLine=true);  // true
    list2.print_all();  // (empty line)

    // ============================================================
    // TEST 9 — mixed types in same list
    // ============================================================
    var mixed: SinglyLL = SinglyLL();
    mixed.append(ds_int(1));
    mixed.append(ds_float(2.5));
    mixed.append(ds_str("three"));
    mixed.append(ds_bool(false));
    mixed.print_all();  // 1 -> 2.5 -> three -> false
    print(mixed.size, newLine=true);  // 4

    // ============================================================
    // TEST 10 — out of bounds get — should error and exit
    // ============================================================
    var oob: DSValue = list2.get(5);

};