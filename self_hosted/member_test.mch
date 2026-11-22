from "mocha-matvec" import *;

class Box {
    var n: int;
    var items: int[];
    function constructor() -> null {
        this.n = 0;
        this.items = [];
    };
    function bump() -> null {
        this.n = this.n + 5;
    };
};

function member_tests(didLoad) -> null {
    var b: Box = Box();
    b.bump();
    b.n = 9;
    print(str(b.n), newLine=true);
};
