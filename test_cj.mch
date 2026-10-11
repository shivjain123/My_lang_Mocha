class Holder {
    var a: float[];
    var b: float[];

    function constructor(v: int) -> null {
        this.a = [];
        this.b = [];
    };
};

function main(didLoad) -> null {
    var h: Holder = Holder(1);
    print("ok", newLine=true);
};