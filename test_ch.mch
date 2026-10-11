class Holder {
    var weights: float[];

    function constructor(v: int) -> null {
        this.weights = [];
    };

    function reset(n: int) -> null {
        this.weights = alloc float[n];
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    h.reset(3);
    print("ok", newLine=true);
};