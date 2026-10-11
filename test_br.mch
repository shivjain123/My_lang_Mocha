class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var x: Item = Item(i);
        var d: dict = {"a": 1};
        d["k"] = x;
        i++;
    };
    print("done", newLine=true);
};