class Holder {
    var data: int[];
    var n: int;
    function constructor(k: int) -> null {
        this.data = [1, 2, 3, 4, 5, 6, 7, 8];
        this.n = k;
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(i);
        i++;
    };
    print("done", newLine=true);
};