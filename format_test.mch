"""function test(didLoad) -> null {

    // Basic positional
    var s1: str = "Hello, $0! You are $1 years old.".format("Shiv", 18);
    print(s1, newLine=true);

    // Float and int
    var s2: str = "Pi is $0 and answer is $1".format(3.14, 42);
    print(s2, newLine=true);

    // Bool
    var s3: str = "Flag is $0".format(true);
    print(s3, newLine=true);

    // Vast
    var big: vast = 9999999999;
    var s4: str = "Big number: $0".format(big);
    print(s4, newLine=true);

    // Multidigit index
    var s5: str = "$0 $1 $2 $3 $4 $5 $6 $7 $8 $9 $10".format("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten");
    print(s5, newLine=true);

    // Escaped dollar
    var s6: str = "Price is \$0 not substituted".format("ignored");
    print(s6, newLine=true);
};"""

function test(didLoad) -> null {

    // Basic named
    var s1: str = "Hello, $nm! You are $ag years old.".format(nm="Shiv", ag=18);
    print(s1, newLine=true);
    // Expected: Hello, Shiv! You are 18 years old.

    // Float and vast
    var big: vast = 9999999999;
    var s2: str = "Pi is $pi and big is $num".format(pi=3.14, num=big);
    print(s2, newLine=true);
    // Expected: Pi is 3.14 and big is 9999999999

    // Bool
    var s3: str = "Flag is $fl".format(fl=true);
    print(s3, newLine=true);
    // Expected: Flag is true

    // Underscore in name
    var s4: str = "Value is $my_var".format(my_var=42);
    print(s4, newLine=true);
    // Expected: Value is 42

    // Escaped dollar
    var s5: str = "Price is \$nm not substituted".format(nm="ignored");
    print(s5, newLine=true);
    // Expected: Price is $nm not substituted

    // Same key used twice in template
    var s6: str = "$who said $who again".format(who="Shiv");
    print(s6, newLine=true);
    // Expected: Shiv said Shiv again

};