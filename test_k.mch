class Holder {
    var a: (int, 2);
    var b: (int, 2);
    function constructor(v: (int, 2)) -> null {
        this.a = (1, 2);
        this.b = v;
    };
};

function main(didLoad) -> null {
    var share_d: (int, 2) = (5, 6);
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(share_d);
        i++;
    };
    print("done", newLine=true);
};