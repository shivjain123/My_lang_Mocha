class Holder {
    var data: int[];
    function constructor(a: int[]) -> null {
        this.data = a;
    };
};

function main(didLoad) -> null {
    var share_d: int[] = [1, 2, 3, 4];
    var i: int = 0;
    while (i < 2000000) {
        var h: Holder = Holder(share_d);
        i++;
    };
    print("done", newLine=true);
};