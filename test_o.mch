class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function make() -> null {
    var arr: Item[] = alloc Item[2];
    arr[0] = Item(1);
    var x: Item = arr[0];
    print(x.n, newLine=true);
};

function main(didLoad) -> null {
    make();
    print("done", newLine=true);
};