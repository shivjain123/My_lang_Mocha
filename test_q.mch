class Child {
    var v: int;
    function constructor(x: int) -> null {
        this.v = x;
    };
};

class Parent {
    var child: Child;
    function constructor(k: int) -> null {
        this.child = Child(k);
    };
    function get() -> Child {
        return this.child;
    };
};

function main(didLoad) -> null {
    var p: Parent = Parent(5);
    var c: Child = p.get();
    print(c.v, newLine=true);
    print("done", newLine=true);
};