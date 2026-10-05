class Child {
    var v: int;
    function constructor(x: int) -> null {
        this.v = x;
    };
};

class Parent {
    var child: Child;
    function constructor(c: Child) -> null {
        this.child = c;
    };
};

function main(didLoad) -> null {
    var share_d: Child = Child(7);
    var i: int = 0;
    while (i < 2000000) {
        var p: Parent = Parent(share_d);
        i++;
    };
    print("done", newLine=true);
};