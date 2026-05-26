function test(didLoad) -> null {

    // Basic 2 decimal places
    var s1: str = "Pi is $0|2f".format(3.14159);
    print(s1, newLine=true);
    // Expected: Pi is 3.14

    // 3 decimal places
    var s2: str = "Pi is $0|3f".format(3.14159);
    print(s2, newLine=true);
    // Expected: Pi is 3.142

    // Half-up rounding — .5 rounds up
    var s3: str = "Rounded: $0|0f".format(2.5);
    print(s3, newLine=true);
    // Expected: Rounded: 3

    // Half-up rounding — below .5 rounds down
    var s4: str = "Rounded: $0|0f".format(2.4);
    print(s4, newLine=true);
    // Expected: Rounded: 2

    // Zero padding decimals
    var s5: str = "Value: $0|4f".format(3.14);
    print(s5, newLine=true);
    // Expected: Value: 3.1400

    // Int auto-converted to float
    var s6: str = "Int as float: $0|2f".format(42);
    print(s6, newLine=true);
    // Expected: Int as float: 42.00

    // Mixed — some with specifier, some without
    var s7: str = "Name: $0, Score: $1|2f".format("Shiv", 98.5678);
    print(s7, newLine=true);
    // Expected: Name: Shiv, Score: 98.57

};