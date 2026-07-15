class Person {
    var name: str;
    function constructor(n: str) -> null {
        this.name = n;
    };
};

class Team {
    var teamName: str;
    var scores: int[];
    function constructor(n: str) -> null {
        this.teamName = n;
    };
};

class Wrapper {
    var inner: Person;
    function constructor(p: Person) -> null {
        this.inner = p;
    };
};

class Base {
    var label: str;
    function constructor(l: str) -> null {
        this.label = l;
    };
};

class Derived extends Base {
};

function main(didLoad) -> null {
    // Stage 1: fresh construction + reassignment
    // Exercises: rc_alloc constructor, mocha_release_Person on reassign
    var p1: Person = Person("Alice");
    var i: int = 0;
    while (i < 200000) {
        p1 = Person("Alice");
        i++;
    };
    print("stage 1 done", newLine=true);

    // Stage 2: this.field = value with a FRESH string, repeated overwrite
    // Exercises Step 88's MemberAccess release-old logic
    var p2: Person = Person("start");
    var j: int = 0;
    while (j < 200000) {
        p2.name = "x" + "y";
        j++;
    };
    print("stage 2 done", newLine=true);

    // Stage 3: this.field = value with a BORROWED string, repeated overwrite
    var val: str = "hello";
    var p3: Person = Person("start");
    var k: int = 0;
    while (k < 200000) {
        p3.name = val;
        k++;
    };
    print("stage 3 done", newLine=true);
    print(val, newLine=true); // sanity: val should still read "hello"

    // Stage 4: class with an array field, construction + reassignment
    var t1: Team = Team("Reds");
    var m: int = 0;
    while (m < 200000) {
        t1 = Team("Reds");
        t1.scores = [1, 2, 3];
        m++;
    };
    print("stage 4 done", newLine=true);

    // Stage 5: nested object field — one class holding another class instance
    // Exercises the recursive mocha_release_X call for %struct.* fields
    var innerP: Person = Person("Inner");
    var w1: Wrapper = Wrapper(innerP);
    var n: int = 0;
    while (n < 200000) {
        w1 = Wrapper(innerP);
        n++;
    };
    print("stage 5 done", newLine=true);
    print(innerP.name, newLine=true); // sanity: innerP should still read "Inner"

    // Stage 6: inherited class, construction + field assignment via
    // inherited constructor (Derived has no own constructor)
    var d1: Derived = Derived("base label");
    var q: int = 0;
    while (q < 200000) {
        d1 = Derived("base label");
        d1.label = "changed";
        q++;
    };
    print("stage 6 done", newLine=true);

    print("all stages done", newLine=true);
};