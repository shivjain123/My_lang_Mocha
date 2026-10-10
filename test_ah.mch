class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var arr: Item[] = alloc Item[2];
    var i: int = 0;
    while (i < 2000000) {
        var x: Item = Item(i);
        arr[0] = x;
        i++;
    };
    print("done", newLine=true);
};