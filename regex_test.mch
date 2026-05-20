from "mocha-string" import *;

function main(didLoad) -> null {
    print("=== Regex Engine Tests ===", newLine=true);

    // ══════════════════════════════════════════
    // SECTION 1 — regex_match (pattern anywhere)
    // ══════════════════════════════════════════
    print("--- 1. regex_match ---", newLine=true);

    print(str(("hello123").regex_match("\\d+")), newLine=true);      // true
    print(str(("hello").regex_match("\\d+")), newLine=true);          // false
    print(str(("hello world").regex_match("wor")), newLine=true);     // true
    print(str(("hello").regex_match(".")), newLine=true);             // true
    print(str(("").regex_match(".")), newLine=true);                  // false
    print(str(("abc123").regex_match("[a-z]+")), newLine=true);       // true
    print(str(("123").regex_match("[a-z]+")), newLine=true);          // false
    print(str(("hello").regex_match("^hel")), newLine=true);          // true
    print(str(("world").regex_match("^hel")), newLine=true);          // false
    print(str(("hello").regex_match("llo$")), newLine=true);          // true
    print(str(("hello!").regex_match("llo$")), newLine=true);         // false

    // ══════════════════════════════════════════
    // SECTION 2 — regex_full (entire string)
    // ══════════════════════════════════════════
    print("--- 2. regex_full ---", newLine=true);

    print(str(("hello").regex_full("hel+o")), newLine=true);          // true
    print(str(("hello world").regex_full("hel+o")), newLine=true);    // false
    print(str(("abc").regex_full("[a-z]+")), newLine=true);           // true
    print(str(("abc123").regex_full("[a-z]+")), newLine=true);        // false
    print(str(("12345").regex_full("\\d+")), newLine=true);           // true
    print(str(("123a5").regex_full("\\d+")), newLine=true);           // false

    // email-like validation
    print(str(("user@mail.com").regex_full("[\\w]+")), newLine=true); // false (has @ and .)
    print(str(("username").regex_full("\\w+")), newLine=true);        // true

    // ══════════════════════════════════════════
    // SECTION 3 — regex_find (first match)
    // ══════════════════════════════════════════
    print("--- 3. regex_find ---", newLine=true);

    print(("hello123world").regex_find("\\d+"), newLine=true);        // 123
    print(("abc def ghi").regex_find("\\w+"), newLine=true);          // abc
    print(("   hello").regex_find("\\S+"), newLine=true);             // hello
    var found: str = ("no digits here").regex_find("\\d+");
    if (found.length > 0) { print(found, newLine=true); } else { print("(no match)", newLine=true); };
    print(("color: red").regex_find("[a-z]+$"), newLine=true);        // red
    print(("2026-05-17").regex_find("\\d+"), newLine=true);           // 2026

    // ══════════════════════════════════════════
    // SECTION 4 — regex_find_all (all matches)
    // ══════════════════════════════════════════
    print("--- 4. regex_find_all ---", newLine=true);
    print("\n");

    var nums: str[] = ("a1b2c3d4").regex_find_all("\\d");
    print("digits: " + str(nums.length) + " → ");
    var ni: int = 0;
    while (ni < nums.length) {
        print(nums[ni] + " ", newLine=false);
        ni++;
    };
    print("", newLine=true);                                        // 1 2 3 4

    var words: str[] = ("one two three").regex_find_all("\\w+");
    print("words: " + str(words.length)+ " → ");               // 3
    var wi: int = 0;
    while (wi < words.length) {
        print(words[wi] + " ", newLine=false);
        wi++;
    };
    print("", newLine=true);                                          // one two three

    var caps: str[] = ("aAbBcC").regex_find_all("[A-Z]");
    print("capitals: " + str(caps.length) + " → ");             // 3
    var ci: int = 0;
    while (ci < caps.length) {
        print(caps[ci] + " ", newLine=false);
        ci++;
    };
    print("", newLine=true);                                          // A B C

    // ══════════════════════════════════════════
    // SECTION 5 — regex_replace_all
    // ══════════════════════════════════════════
    print("--- 5. regex_replace_all ---", newLine=true);
    print("\n");

    print(("hello world").regex_replace_all("\\s+", "_"), newLine=true);     // hello_world
    print(("a1b2c3").regex_replace_all("\\d", "X"), newLine=true);           // aXbXcX
    print(("  too  many  spaces  ").regex_replace_all("\\s+", " "), newLine=true); // " too many spaces "
    print(("2026-05-17").regex_replace_all("-", "/"), newLine=true);          // 2026/05/17
    print(("camelCaseWord").regex_replace_all("[A-Z]", "_$"), newLine=true);  // camel_$ase_$ord — literal replacement

    // ══════════════════════════════════════════
    // SECTION 6 — regex_split
    // ══════════════════════════════════════════
    print("--- 6. regex_split ---", newLine=true);
    print("\n");

    var parts: str[] = ("one1two2three").regex_split("\\d");
    print("parts: " + str(parts.length) + " → ");              // 3
    var pi: int = 0;
    while (pi < parts.length) {
        print(parts[pi] + " ", newLine=false);
        pi++;
    };
    print("", newLine=true);                                          // one two three

    var csv: str[] = ("a,b,,c,d").regex_split(",");
    print("csv parts: " + str(csv.length) + " → ");   //5
    var csi: int = 0;
    while (csi < csv.length) {
        print("'" + csv[csi] + "' ", newLine=false);
        csi++;
    };
    print("", newLine=true);                                          // 'a' 'b' '' 'c' 'd'

    var lines: str[] = ("line1\nline2\nline3").regex_split("\\s");
    print("lines: " + str(lines.length), newLine=true);               // 3

    // ══════════════════════════════════════════
    // SECTION 7 — Real use cases
    // ══════════════════════════════════════════
    print("--- 7. Real use cases ---", newLine=true);
    print("\n");

    // extract all numbers from a string
    var data: str = "temp=23.5 humidity=67 pressure=1013";
    var values: str[] = data.regex_find_all("\\d+");
    print("extracted numbers: ", newLine=false);
    var vi: int = 0;
    while (vi < values.length) {
        print(values[vi] + " ", newLine=false);
        vi++;
    };
    print("", newLine=true);                                          // 23 5 67 1013

    // check if string is a valid identifier
    var id1: str = "myVariable123";
    var id2: str = "123invalid";
    print(id1 + " is identifier: " + str(id1.regex_full("[a-zA-Z_]\\w*")), newLine=true);  // true
    print(id2 + " is identifier: " + str(id2.regex_full("[a-zA-Z_]\\w*")), newLine=true);  // false

    // clean whitespace
    var messy: str = "  hello   world  ";
   var cleaned: str = messy.rip();
    var cleaned2: str = cleaned.regex_replace_all("\\s+", " ");
    print("'" + cleaned2 + "'", newLine=true);

    // check if string contains only digits
    print(str(("12345").regex_full("\\d+")), newLine=true);           // true
    print(str(("123a5").regex_full("\\d+")), newLine=true);           // false

    print("=== Regex Tests Done ===", newLine=true);
};