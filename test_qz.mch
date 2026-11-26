from "mocha-string" import *;

function check(name: str, ok: bool) -> null {
    if (ok) {
        print("PASS ", name, newLine=true);
    } else {
        print("FAIL ", name, newLine=true);
    };
};

function main(didLoad) -> null {
    // fix 2: replace at the very end of the string
    var r1: str = "abc".replace("c", "X", 1);
    print("replace end: [", r1, "] length ", r1.length, newLine=true);
    check("replace at end of string", r1 == "abX" && r1.length == 3);
    check("replace first occurrence only", "abcabc".replace("b", "X", 1) == "aXcabc");
    check("replace two occurrences", "abcabc".replace("c", "X", 2) == "abXabX");
    check("replaceAll to empty", "abcabc".replaceAll("b", "") == "acac");

    // fix 3: greedy ?
    var g1: str = "abb".regex_find("ab?");
    var g2: str = "abb ab a".regex_replace_all("ab?", "X");
    print("greedy find [", g1, "] replace_all [", g2, "]", newLine=true);
    check("? is greedy in regex_find", g1 == "ab");
    check("? is greedy in regex_replace_all", g2 == "Xb X X");

    // fix 4: escaped dollar at the end of a pattern
    var d1: str = "a$b".regex_find("a\\$");
    print("escaped dollar [", d1, "]", newLine=true);
    check("escaped $ is a literal", d1 == "a$");
    check("real $ still anchors", "cat dog".regex_find("dog$") == "dog" && "dog cat".regex_find("dog$") == "");

    // fix 5: carriage return trimming
    var t1: str = "  hi\r\n".rip();
    print("rip length ", t1.length, newLine=true);
    check("rip strips carriage return", t1 == "hi" && t1.length == 2);

    // unchanged behaviour, sanity checks
    check("padLeft", "7".padLeft(3, "0") == "007");
    check("padRight", "7".padRight(3, ".") == "7..");
    check("substring is inclusive", "hippo".substring(0, 2) == "hip");
    check("empty-range substring", "hippo".substring(3, 2) == "");
    check("regex \\d+", "abc123".regex_find("\\d+") == "123");
    check("regex_full", "abc".regex_full("a.c") && !"abcd".regex_full("a.c"));
    var parts: str[] = "a1b22c".regex_split("\\d+");
    check("regex_split", parts.length == 3 && parts[0] == "a" && parts[2] == "c");
    var sp: str[] = "a,b,,c".split(",");
    check("split keeps empty fields", sp.length == 4);
    check("occurs", "aaaa".occurs("aa") == 2);

    // readCsv: does [[]] leave a phantom empty first row?
    var w: File = open("csv_test_qz.csv", "write");
    w.write("x,y\n1,2\n3,4\n");
    w.close();
    var rf: File = open("csv_test_qz.csv", "read");
    var data: float[][] = rf.readCsv();
    rf.close();
    print("readCsv rows ", data.length, newLine=true);
    check("readCsv returns exactly the 2 data rows", data.length == 2);
};