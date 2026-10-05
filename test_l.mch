class Holder {
    var a: Complex;
    var b: Complex;
    function constructor(v: Complex) -> null {
        this.a = Complex(1.0, 2.0);
        this.b = v;
    };
};

function main(didLoad) -> null {
    var share_d: Complex = Complex(3.0, 4.0);
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(share_d);
        i++;
    };
    print("done", newLine=true);
};