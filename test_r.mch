class Holder {
    var data: int[];
    function constructor(k: int) -> null {
        this.data = [1, 2, 3];
    };
    function get() -> int[] {
        return this.data;
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    var a: int[] = h.get();
    print(a[0], newLine=true);
    print("done", newLine=true);
};