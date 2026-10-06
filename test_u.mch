class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var x: Item = Item(0);
    var i: int = 0;
    while (i < 2000000) {
        x = Item(i);
        i++;
    };
    print("done", newLine=true);
};