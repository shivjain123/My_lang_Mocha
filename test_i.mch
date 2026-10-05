class Holder {
    var a: dict;
    var b: dict;
    function constructor(v: dict) -> null {
        this.a = {"x": 1, "y": 2};
        this.b = v;
    };
};

function main(didLoad) -> null {
    var share_d: dict = {"k": 10};
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(share_d);
        i++;
    };
    print("done", newLine=true);
};