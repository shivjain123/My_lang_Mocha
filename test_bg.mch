class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var c: Item = Item(1);
    c = c;
    print("ok", newLine=true);
};