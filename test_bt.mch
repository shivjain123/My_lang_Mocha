class Item {
    var n: int;
    function constructor(v: int) -> null {
        this.n = v;
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var d: dict = {"k": Item(i)};
        i++;
    };
    print("done", newLine=true);
};