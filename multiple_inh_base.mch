class Animal {
    var age: int = 0;
    function set_age(n: int) -> null { this.age = n; };
    function get_age() -> int { return this.age; };
};

class Bird extends Animal {};
class Horse extends Animal {};
class Pegasus extends Bird, Horse {};

function test(didLoad) -> null {
    var p: Pegasus = Pegasus();
    Bird.p.set_age(10);
    print(Horse.p.get_age());   // ← the whole answer is here
};