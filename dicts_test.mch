
function section_dict(didLoad) -> null {
    print("--- 6. Dictionary ---", newLine=true);

    var d: dict = {
        "name": "Shiv",
        "age": 16,
        "gpa": 9.8,
        "active": true,
    };

    print(d["name"], newLine=true);   // Shiv
    print(d["age"], newLine=true);    // 16

    d["name"] = "Mocha";
    print(d["name"], newLine=true);   // Mocha

    d["lang"] = "Mocha Lang";
    print(d["lang"], newLine=true);   // Mocha Lang

    print(d.has("name"), newLine=true);    // true
    print(d.has("missing"), newLine=true); // false
    print(d.length, newLine=true);         // 5

    var keys: str[] = d.allKeys();
    for each k in keys {
        print(k, newLine=true);
    };

    var vals: str[] = d.allValues();
    for each v in vals {
        print(v, newLine=true);
    };

    d.remove("age");
    print(d.length, newLine=true);    // 4

    var nest: dict = {
        "person": {
            "name": "Shiv",
            "age": 16,
        },
    };
    print(nest["person"]["name"], newLine=true);  // Shiv
    print(nest["person"]["age"], newLine=true);   // 16

    // fatal error tests — uncomment to test error messages
    """
    d.clean();
    print(d["naem"], newLine=true);  // MochaRuntimeError: did you mean 'name'?
    """
};