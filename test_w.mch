class Person {
    var name: str;
    var age: int;
    function constructor(n: str, a: int) -> null {
        this.name = n;
        this.age = a;
    };
};

function main(didLoad) -> null {
    var i: int = 0;
    while (i < 2000000) {
        var p: Person = Person("alice", i);
        var d: dict = {
            "seed": 1,
        };
        d["k"] = p.name;
        d[p.name] = 1;
        i++;
    };
    print("done", newLine=true);
};