class Holder {
    var a: int[];
    var d: dict;
    var c: Complex;
    var label: str;
    function constructor(k: int) -> null {
        this.a = [1, 2, 3];
        this.d = {"x": 1};
        this.c = Complex(1.0, 2.0);
        this.label = "hello";
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    var a: int[] = [9];
    var d: dict = {"z": 2};
    var c: Complex = Complex(5.0, 6.0);
    var s: str = "start";
    a = h.a;
    d = h.d;
    c = h.c;
    s = h.label;
    print(a[0], newLine=true);
    print("done", newLine=true);
};