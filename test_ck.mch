class Holder {
    var g: float[][];

    function constructor(v: int) -> null {
        this.g = alloc float[0][0];
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    print("ok", newLine=true);
};