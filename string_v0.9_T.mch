from "mocha-string" import *;
function main(didLoad) -> null {
    // repeat
    print(("ha").repeat(3), newLine=true);              // hahaha
    print(("=-").repeat(5), newLine=true);              // =-=-=-=-=-=-=-=-=-=-

    // padLeft / padRight
    print(("42").padLeft(6, "0"), newLine=true);        // 000042
    print(("hi").padRight(8, "-"), newLine=true);       // hi------
    print(("99").padLeft(5, " "), newLine=true);        //    99

    // isAlpha
    print(("hello").isAlpha(), newLine=true);           // true
    print(("hello1").isAlpha(), newLine=true);          // false

    // isNumeric
    print(("123").isNumeric(), newLine=true);           // true
    print(("12.3").isNumeric(), newLine=true);          // false

    // isAlphaNumeric
    print(("hello123").isAlphaNumeric(), newLine=true); // true
    print(("hello!").isAlphaNumeric(), newLine=true);   // false

    // join
    var words: str[] = ["hello", "world", "mocha"];
    print(words.join(", "), newLine=true);              // hello, world, mocha
    print(words.join(" | "), newLine=true);             // hello | world | mocha
    print(words.join(""), newLine=true);                // helloworldmocha
};