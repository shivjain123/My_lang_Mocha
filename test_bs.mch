class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var x: Item = Item(1);
    var d: dict = {"a": 1};
    d["k"] = x;
    d["k"] = x;
    print("ok", newLine=true);
};