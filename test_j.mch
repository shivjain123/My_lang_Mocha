class Holder {
    var a: set<int>;
    var b: set<int>;
    function constructor(v: set<int>) -> null {
        this.a = <1, 2, 3>;
        this.b = v;
    };
};

function main(didLoad) -> null {
    var share_d: set<int> = <7, 8, 9>;
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(share_d);
        i++;
    };
    print("done", newLine=true);
};