function add_vast(a: vast, b: vast) -> vast {
    return a + b;
};

function flip(b: bool) -> bool {
    if (b) { return false; } else { return true; };
};

function pick(flag: bool, a: float, b: float) -> float {
    if (flag) { return a; } else { return b; };
};

function twice(n: int) -> int {
    return n + n;
};

function main(didLoad) -> null {
    print("types test", newLine=true);
};