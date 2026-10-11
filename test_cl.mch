class Holder {
    var g1: float[][];
    var g2: float[][];

    function constructor(v: int) -> null {
        this.g1 = alloc float[0][0];
        this.g2 = alloc float[0][0];
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    print("ok", newLine=true);
};