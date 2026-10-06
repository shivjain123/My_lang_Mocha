class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function make(i: int) -> null {
    var arr: Item[] = alloc Item[3];
    arr[0] = Item(i);
    arr[1] = Item(i + 1);
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        make(i);
        i++;
    };
    print("done", newLine=true);
};