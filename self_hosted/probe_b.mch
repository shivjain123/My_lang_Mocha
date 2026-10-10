class K {
    var other_val: float;
    var real_val: float;
    var imag_val: float;
    var left:      K;
    var right:     K;
    var condition: K;
    var flag1:     bool;
    var flag2:     bool;
    var is_variadic: bool;

    function constructor() -> null {
        this.other_val = 0.0;
        this.real_val = 0.0;
        this.imag_val = 0.0;
        this.left      = null;
        this.right     = null;
        this.condition = null;
        this.flag1     = false;
        this.flag2     = false;
        this.is_variadic = false;
    };
};

function main(didLoad) -> null {
    print("step 1", newLine=true);
    var x: K = K();
    print("step 2", newLine=true);
    print("--- DONE ---", newLine=true);
};