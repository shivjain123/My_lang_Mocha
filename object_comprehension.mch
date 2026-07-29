class User {
    var name: str;
    var age: int;
};

function did(didLoad){
    var users: User[] = [
        User("Alice", 30),
        User("Bob", 25),
        User("Charlie", 35)
    ];
        // Direct object iteration — NO IMPORTS
    var names: str[] = [u.name for each u in users];
    var over_30: str[] = [u.name if u.age > 30 for each u in users];

    // Nested object comprehension — also NO IMPORTS
    var pairs: int[][] = [[u.age + v.age for each v in users] for each u in users];

    // and even (This is a prototype. this syntax does not work yet)
    var something: bool[] = [u.age if u.age >= 30 for each u in users];
};