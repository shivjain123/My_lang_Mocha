class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var arr: Item[] = [];
    var i: int = 0;
    while (i < 1000) {
        arr.push(Item(i));
        i++;
    };
    print("done", newLine=true);
};