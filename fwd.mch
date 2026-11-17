function main(didLoad) -> null {
    var b: B = B();
    var n: int = b.get();
    print(n, newLine=true);
};

class B {
    function constructor() -> null { };
    function get() -> int { return 7; };
};