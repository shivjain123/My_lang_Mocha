function deep(n: int) -> int {
    var x: int = deep(n + 1);
    return x + n;
};

function crash_tests(didLoad) -> null {
    print("about to recurse forever...");
    print(deep(0));
};