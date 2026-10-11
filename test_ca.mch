class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var g: Item[][] = alloc Item[2][2];
    var i: int = 0;
    while (i < 2000000) {
        g[0][0] = Item(i);
        i++;
    };
    print("done", newLine=true);
};