function div_assign_tests(didLoad) -> null {
    var a: int = 10;
    var b: int = 0;
    a /= 2;
    print("10 /= 2 (want 5):");
    print(a);
    print("about to do /= 0...");
    a /= b;
    print(a);
};