class Person {
    var name: str;
    function constructor(n: str) -> null {
        this.name = n;
    };
};

function main(didLoad) -> null {
    var p: Person = Person("Alice");
    print(p.name, newLine=true);
};