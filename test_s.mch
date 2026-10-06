class Holder {
    var a: int[];
    var d: dict;
    var t: (int, 2);
    var c: Complex;
    function constructor(k: int) -> null {
        this.a = [1, 2, 3];
        this.d = {"x": 1};
        this.t = (1, 2);
        this.c = Complex(1.0, 2.0);
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    var a: int[] = h.a;
    var d: dict = h.d;
    var t: (int, 2) = h.t;
    var c: Complex = h.c;
    print(a[0], newLine=true);
    print("done", newLine=true);
};