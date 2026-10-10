class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var a: Item[] = [];
    a.push(Item(1));
    var b: Item[] = a;
    b = [];
    print(a[0].n, newLine=true);
};