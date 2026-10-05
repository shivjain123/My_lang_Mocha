class Child {
    var v: int;
    function constructor(x: int) -> null {
        this.v = x;
    };
};

class Parent {
    var child: Child;
    var n: int;
    function constructor(k: int) -> null {
        this.child = Child(k);
        this.n = k;
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var p: Parent = Parent(i);
        i++;
    };
    print("done", newLine=true);
};