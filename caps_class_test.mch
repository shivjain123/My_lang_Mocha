"""class T {
    var val: int;
    function constructor(v: int) -> null {
        this.val = v;
    };
    function speak() -> str { return "base"; };
};

class Dog extends T {
    function speak() -> str { return "Woof"; };
};

function main(didLoad) -> null {
    var d: Dog = Dog(9);
    print("val: ", d.val, " says: ", d.speak(), newLine=true);
};"""

class T {
    var val: int;
    function constructor(v: int) -> null {
        this.val = v;
    };
};

function main(didLoad) -> null {
    var arr: T[] = alloc T[3];
    print("allocated", newLine=true);
};