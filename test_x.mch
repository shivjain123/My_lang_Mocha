class Holder {
    var inner: dict;
    function constructor(v: int) -> null {
        this.inner = {
            "a": v,
        };
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(i);
        var outer: dict = {
            "seed": 1,
        };
        outer["x"] = h.inner;
        i++;
    };
    print("done", newLine=true);
};