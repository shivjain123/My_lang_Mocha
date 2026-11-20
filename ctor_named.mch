class T {
    var n: int;
    function constructor(a: int, b: int = 7) -> null {
        this.n = a + b;
    };
};

function main(didLoad) -> null {
    var t1: T = T(1);
    var t2: T = T(1, b=2);
    print(t1.n, " ", t2.n, newLine=true);
};