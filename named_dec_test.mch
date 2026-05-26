function test(didLoad) -> null {
    // Basic named with 2 decimal places
    var s1: str = "Pi is $pi|2f".format(pi=3.14159);
    print(s1, newLine=true);
    // Expected: Pi is 3.14

    // 3 decimal places
    var s2: str = "Pi is $pi|3f".format(pi=3.14159);
    print(s2, newLine=true);
    // Expected: Pi is 3.142

    // Half-up rounding
    var s3: str = "Rounded: $val|0f".format(val=2.5);
    print(s3, newLine=true);
    // Expected: Rounded: 3

    // Zero padding
    var s4: str = "Value: $val|4f".format(val=3.14);
    print(s4, newLine=true);
    // Expected: Value: 3.1400

    // Int auto-converted
    var s5: str = "Int as float: $n|2f".format(n=42);
    print(s5, newLine=true);
    // Expected: Int as float: 42.00

    // Mixed — some with specifier, some without
    var s6: str = "Name: $nm, Score: $sc|2f".format(nm="Shiv", sc=98.5678);
    print(s6, newLine=true);
    // Expected: Name: Shiv, Score: 98.57

    // Underscore in name with specifier
    var s7: str = "Result: $my_val|3f".format(my_val=1.23456);
    print(s7, newLine=true);
    // Expected: Result: 1.235
};