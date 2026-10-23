"""
    Mocha v0.7 — Combined Feature Tests
    =====================================
    Tests only NEW features introduced in v0.7.
    Legacy v0.5/v0.6 features omitted.

    Sections:
     1.  Complex numbers       — basics, float promotion, str set dedup, conjugate
     2.  Set operations        — union, intersect, xor, rel_diff
     3.  Collections           — dict merge, hashtable
     4.  Comprehension         — list comprehension (int, float, str)
     5.  Tags                  — enum-style tagged unions
     6.  OOP                   — lambda sort, interface diamond, self-referential class
     7.  I/O                   — tell(), File (write/read/readline/append/exists)
     8.  Strings               — substring (inclusive), StringBuilder
     9.  mocha-stats           — distances, statistical functions
    10.  mocha-processing      — StandardScaler, MinMaxScaler, RobustScaler
    11.  mocha-SymCha           — symbolic differentiation + simplification
"""

from "mocha-stats" import *;
from "mocha-processing" import *;
import mochaSymcha from "mocha-SymCha" as Sym;
from "mocha-string" import *;

function print(s: str) -> int native print;

// =============================================================================
// SECTION 1 — Complex Numbers
// =============================================================================

function test_complex_basics( ) -> null {
    print("=== 1a. Complex basics ===");

    var z1: Complex = 2+3im;
    var z2: Complex = 1+1im;
    var z3: Complex = z1.add(z2);
    print(z3.toString(), newLine=true);   // 3+4im

    // Direct literal arithmetic
    var z4: Complex = 2+3im + 1+1im;
    print(z4.toString(), newLine=true);   // 3+4im (same)
};

function test_complex_promotion() -> null {
    print("=== 1b. float -> Complex promotion ===");

    var a: float = 2.0;
    var d: float = 5.0;
    var tr: float = a + d;
    var half_tr: float = tr / 2.0;

    // float promoted to Complex via + 0im
    var z: Complex = half_tr + 0im;
    print(tr, newLine=true);            // 7.0
    print(z.toString(), newLine=true);  // 3.5+0im

    // scalar * imaginary unit
    var sq: float = 2.0;
    var ab: Complex = sq * 1im;
    print(ab.toString(), newLine=true); // 0+2im
};

function test_complex_str_set() -> null {
    print("=== 1c. str set dedup ===");

    var s: set<str> = <>;
    s.insert("bag");
    s.insert("bag");
    print(s.size, newLine=true);  // 1
};

function test_conjugate() -> null {
    print("=== 1d. Conjugate ===");

    var z: Complex = 3 + 4im;
    var zc: Complex = z.conjugate();
    print(z.toString(), newLine=true);    // 3+4im
    print(zc.toString(), newLine=true);   // 3-4im

    var z2: Complex = 5 - 2im;
    var z2c: Complex = z2.conjugate();
    print(z2c.toString(), newLine=true);  // 5+2im
};


// =============================================================================
// SECTION 2 — Set Operations
// =============================================================================

function test_set_operations() -> null {
    print("=== 2. Set operations ===");

    var a: set<int> = <1, 2, 3, 4, 5>;
    var b: set<int> = <3, 4, 5, 6, 7>;

    var u: set<int> = a.union(b);
    print("--- union ---");
    for each c in <u> {
        print(c, newLine=true);
    };

    var i: set<int> = a.intersect(b);
    print("--- intersect ---");
    for each d in <i> {
        print(d, newLine=true);
    };

    var x: set<int> = a.xor(b);
    print("--- xor ---");
    for each el in <x> {
        print(el, newLine=true);
    };

    var rd: set<int> = a.rel_diff(b);
    print("--- rel_diff a-b ---");
    for each el1 in <rd> {
        print(el1, newLine=true);
    };

    var rd2: set<int> = b.rel_diff(a);
    print("--- rel_diff b-a ---");
    for each el2 in <rd2> {
        print(el2, newLine=true);
    };
};


// =============================================================================
// SECTION 3 — Collections
// =============================================================================

function test_dict_merge() -> null {
    print("=== 3a. Dict merge ===");

    var d1: dict = {
        "name": "Shiv",
        "lang": "Mocha",
        "version": "0.7",
    };
    var d2: dict = {
        "city": "Pilani",
        "status": "cooking",
    };

    var d3: dict = d1.merge(d2);
    print(d3["name"],    newLine=true);  // Shiv
    print(d3["lang"],    newLine=true);  // Mocha
    print(d3["city"],    newLine=true);  // Pilani
    print(d3["status"],  newLine=true);  // cooking
    print(d3["version"], newLine=true);  // 0.7

    // override=true — d5 wins on conflict
    var d4: dict = {"name": "Shiv", "lang": "Mocha"};
    var d5: dict = {"name": "Bob",  "city": "Pilani"};

    var d6: dict = d4.merge(d5, override=true);
    print(d6["name"], newLine=true);  // Bob
    print(d6["city"], newLine=true);  // Pilani
    print(d6["lang"], newLine=true);  // Mocha
};

function runHashTableTests() -> null {
    print("=== 3b. HashTable ===");
    print("--- 1. Basic put / get / has ---");

    var ht: HashTable = HashTable();
    ht.put("name", "Shiv");
    ht.put("lang", "Mocha");
    ht.put("version", "0.7");

    print(ht.get("name"));
    print(ht.get("lang"));
    print(ht.get("version"));

    if (ht.has("name")) {
        print("has name: true");
    };
    if (ht.has("missing") == false) {
        print("has missing: false");
    };

    print("--- 2. Update existing key ---");
    ht.put("name", "Shiv Jain");
    print(ht.get("name"));  // Shiv Jain
    print(ht.get("lang"));  // Mocha

    print("--- 3. Remove + has after remove ---");
    ht.put("temp", "delete me");
    if (ht.has("temp")) {
        print("has temp: true");
    };
    ht.remove("temp");
    if (ht.has("temp") == false) {
        print("temp gone: true");
    };
    print(ht.get("name"));  // Shiv Jain
    print(ht.get("lang"));  // Mocha

    print("--- 4. size() ---");
    var ht2: HashTable = HashTable();
    print(str(ht2.size()));  // 0
    ht2.put("a", "1");
    print(str(ht2.size()));  // 1
    ht2.put("b", "2");
    ht2.put("c", "3");
    print(str(ht2.size()));  // 3
    ht2.remove("b");
    print(str(ht2.size()));  // 2
    ht2.put("b", "back");
    print(str(ht2.size()));  // 3

    print("--- 5. clear() ---");
    var ht3: HashTable = HashTable();
    ht3.put("x", "1");
    ht3.put("y", "2");
    ht3.put("z", "3");
    print(str(ht3.size()));  // 3
    ht3.clear();
    print(str(ht3.size()));  // 0
    if (ht3.has("x") == false) {
        print("x gone after clear: true");
    };
    ht3.put("fresh", "start");
    print(ht3.get("fresh")); // start
    print(str(ht3.size()));  // 1

    print("--- 6. keys() and values() ---");
    var ht4: HashTable = HashTable();
    ht4.put("apple",  "fruit");
    ht4.put("carrot", "vegetable");
    ht4.put("salmon", "fish");
    print(str(ht4.size()));  // 3
    var keys: str[] = ht4.keys();
    print(str(keys.length)); // 3
    for each k in keys {
        print(k);
    };
    var vals: str[] = ht4.values();
    print(str(vals.length)); // 3
    for each v in vals {
        print(v);
    };

    print("--- 7. Collision stress (20 keys, forces resize) ---");
    var ht5: HashTable = HashTable();
    ht5.put("k0",  "v0");  ht5.put("k1",  "v1");  ht5.put("k2",  "v2");
    ht5.put("k3",  "v3");  ht5.put("k4",  "v4");  ht5.put("k5",  "v5");
    ht5.put("k6",  "v6");  ht5.put("k7",  "v7");  ht5.put("k8",  "v8");
    ht5.put("k9",  "v9");  ht5.put("k10", "v10"); ht5.put("k11", "v11");
    ht5.put("k12", "v12"); ht5.put("k13", "v13"); ht5.put("k14", "v14");
    ht5.put("k15", "v15"); ht5.put("k16", "v16"); ht5.put("k17", "v17");
    ht5.put("k18", "v18"); ht5.put("k19", "v19");
    print(str(ht5.size()));  // 20
    print(ht5.get("k0"));   // v0
    print(ht5.get("k5"));   // v5
    print(ht5.get("k10"));  // v10
    print(ht5.get("k15"));  // v15
    print(ht5.get("k19"));  // v19

    print("--- 8. MARKED slot reuse ---");
    var ht6: HashTable = HashTable();
    ht6.put("alpha", "1");
    ht6.put("beta",  "2");
    ht6.put("gamma", "3");
    ht6.remove("beta");
    print(str(ht6.size()));  // 2
    ht6.put("beta", "new");
    print(str(ht6.size()));  // 3
    print(ht6.get("beta"));  // new
    print(ht6.get("alpha")); // 1
    print(ht6.get("gamma")); // 3
    ht6.remove("alpha");
    ht6.remove("beta");
    ht6.remove("gamma");
    print(str(ht6.size()));  // 0
    ht6.put("alpha", "back");
    ht6.put("beta",  "back");
    ht6.put("gamma", "back");
    print(str(ht6.size()));  // 3
    print(ht6.get("alpha")); // back
    print(ht6.get("beta"));  // back
    print(ht6.get("gamma")); // back

    // TEST 9 — Levenshtein hint (fatal — uncomment to test)
    // var ht7: HashTable = HashTable();
    // ht7.put("name", "Shiv");
    // ht7.put("lang", "Mocha");
    // print(ht7.get("naem"));  // MochaRuntimeError: Key 'naem' not found. Did you mean 'name'?
    // print(ht7.get("lnag"));  // MochaRuntimeError: Key 'lnag' not found. Did you mean 'lang'?

    print("All HashTable tests done!");
};


// =============================================================================
// SECTION 4 — Comprehension
// =============================================================================

function test_comprehension() -> null {
    print("=== 4. List Comprehension ===");

    var nums: int[] = [1, 2, 3, 4, 5];
    var doubled: int[] = [x*2 for each x in nums];
    var evens: int[]   = [x if x%2==0 for each x in nums];

    print(doubled[0], newLine=true);  // 2
    print(doubled[4], newLine=true);  // 10
    print(evens[0],   newLine=true);  // 2
    print(evens[1],   newLine=true);  // 4

    var prices: float[]     = [1.5, 2.5, 3.5];
    var discounted: float[] = [x*0.9 for each x in prices];
    print(discounted[0], newLine=true);  // 1.35

    var words: str[]    = ["hello", "world", "mocha"];
    var lengths: int[]  = [x.length for each x in words];
    var same: str[]     = [x for each x in words];
    print(lengths[0], newLine=true);  // 5
    print(same[0],    newLine=true);  // hello
};


// =============================================================================
// SECTION 5 — Tags
// =============================================================================

tag Direction {
    NORTH,
    SOUTH,
    EAST,
    WEST,
};

tag TokenType {
    IDENTIFIER,
    INT_LIT,
    FLOAT_LIT,
    PLUS,
    MINUS,
    STAR,
    SLASH,
    SEMICOLON,
};

tag Status {
    PENDING,
    RUNNING,
    DONE,
    FAILED,
};

function test_tags() -> null {
    print("=== 5. Tags ===");

    print("--- 1. Basic access + equality ---");
    var d: Direction = Direction.NORTH;
    if (d == Direction.NORTH) {
        print("NORTH correct");
    };
    if (d != Direction.SOUTH) {
        print("not SOUTH correct");
    };

    print("--- 2. Reassign ---");
    var s: Status = Status.PENDING;
    print(s.name());   // PENDING
    s = Status.RUNNING;
    print(s.name());   // RUNNING
    s = Status.DONE;
    print(s.name());   // DONE

    print("--- 3. Match ---");
    var tok: TokenType = TokenType.PLUS;
    match(tok) {
        case (TokenType.PLUS):       print("plus");
        case (TokenType.MINUS):      print("minus");
        case (TokenType.IDENTIFIER): print("ident");
        case (TokenType.INT_LIT):    print("int lit");
        default:                     print("other");
    };

    var tok2: TokenType = TokenType.IDENTIFIER;
    match(tok2) {
        case (TokenType.PLUS):       print("plus");
        case (TokenType.MINUS):      print("minus");
        case (TokenType.IDENTIFIER): print("ident");
        case (TokenType.INT_LIT):    print("int lit");
        default:                     print("other");
    };

    print("--- 4. .name() ---");
    var n: Direction  = Direction.NORTH;
    var s2: Direction = Direction.SOUTH;
    var e: Direction  = Direction.EAST;
    var w: Direction  = Direction.WEST;
    print(n.name());   // NORTH
    print(s2.name());  // SOUTH
    print(e.name());   // EAST
    print(w.name());   // WEST

    print("--- 5. Tag in array ---");
    var tokens: TokenType[] = [
        TokenType.IDENTIFIER,
        TokenType.PLUS,
        TokenType.INT_LIT,
        TokenType.SEMICOLON
    ];
    print(tokens.length, newLine=true);  // 4
    var i: int = 0;
    while (i < tokens.length) {
        var t: TokenType = tokens[i];
        match(t) {
            case (TokenType.IDENTIFIER): print("IDENTIFIER");
            case (TokenType.PLUS):       print("PLUS");
            case (TokenType.INT_LIT):    print("INT_LIT");
            case (TokenType.SEMICOLON):  print("SEMICOLON");
            default:                     print("OTHER");
        };
        i++;
    };

    print("--- 6. Tag as function arg ---");
    var st: Status = Status.FAILED;
    print(st.name());  // FAILED

    print("--- 7. Cross-variable equality ---");
    var a: TokenType = TokenType.PLUS;
    var b: TokenType = TokenType.PLUS;
    var c: TokenType = TokenType.MINUS;
    if (a == b) {
        print("a == b correct");
    };
    if (a != c) {
        print("a != c correct");
    };

    print("All tag tests done!");
};


// =============================================================================
// SECTION 6 — OOP
// =============================================================================

class Point {
    var x: int;
    var y: int;

    function constructor(x: int, y: int) -> null {
        this.x = x;
        this.y = y;
    };
};

function test_sort_objects() -> null {
    print("=== 6a. Lambda sort on objects ===");

    var points: Point[] = [];
    points.push(Point(3, 9));
    points.push(Point(1, 2));
    points.push(Point(5, 6));

    sort(points, lambda (a: Point, b: Point) -> bool: a.x < b.x);

    print(points[0].x, newLine=true);  // 1
    print(points[1].x, newLine=true);  // 3
    print(points[2].x, newLine=true);  // 5
};

// NOTE: interface cannot implement other interfaces; they are contracts only

"""
WILL NOT WORK, AS IT CORRECTLY SHOULD NOT 
INTERFACE RETURN IS DIFFERENT. ERROR WILL BE:
 MochaTypeError at line 485, col 1:  : 'Duck.speak' return type 'null' doesn't match interface 'str'

interface Speakable {
    function speak() -> null;
};

interface Utterable {
    function speak() -> str;
};

class Duck implements Speakable, Utterable {
    function speak() -> null {
        print("Quack!", newLine=true);
    };
};

function test_interface_diamond() -> null {
    print("=== 6b. Interface diamond ===");
    var duck: Duck = Duck();
    duck.speak();  // Quack!
};

"""

class ASTNode {
    var kind:     str;
    var value:    str;
    var left:     ASTNode;
    var right:    ASTNode;
    var children: ASTNode[];

    function constructor() -> null {
        this.kind     = "";
        this.value    = "";
        this.left     = null;
        this.right    = null;
        this.children = [];
    };
};

function test_self_referential() -> null {
    print("=== 6c. Self-referential class (ASTNode) ===");

    var node: ASTNode = ASTNode();
    node.kind  = "IntLiteral";
    node.value = "42";

    var child: ASTNode = ASTNode();
    child.kind  = "Identifier";
    child.value = "x";

    node.children.push(child);

    print(node.kind,             newLine=true);  // IntLiteral
    print(node.children[0].kind, newLine=true);  // Identifier
};


// =============================================================================
// SECTION 7 — I/O
// =============================================================================

function test_tell() -> null {
    print("=== 7a. tell() ===");
    var name: str = tell("What is your name? ");
    var age: str  = tell("Your age: ");
    print("Hello " + name + ", you are " + age, newLine=true);
};

function test_file_io() -> null {
    print("=== 7b. File I/O ===");

    print("--- Write ---");
    var w: File = open("test_io.txt", "write");
    w.write("Hello from Mocha!\n");
    w.write("Second line here.\n");
    w.write("Third line here.\n");
    w.free();
    print("Written successfully.");

    print("--- Exists ---");
    if (exists("test_io.txt")) {
        print("test_io.txt exists!");
    };
    if (!exists("ghost_file.txt")) {
        print("ghost_file.txt correctly not found.");
    };

    print("--- Read ---");
    var r: File = open("test_io.txt", "read");
    var content: str = r.read();
    r.free();
    print(content);

    print("--- ReadLine ---");
    var rl: File = open("test_io.txt", "read");
    var line: str = rl.readLine();
    while (!rl.eof()) {
        print(line);
        line = rl.readLine();
    };
    rl.free();

    print("--- Append ---");
    var a: File = open("test_io.txt", "append");
    a.write("Appended line.\n");
    a.free();
    var r2: File = open("test_io.txt", "read");
    var content2: str = r2.read();
    r2.free();
    print(content2);
};


// =============================================================================
// SECTION 8 — Strings
// =============================================================================

function test_substring() -> null {
    print("=== 8a. Substring (inclusive, Lua-style) ===");
    var s: str = "Hello";
    var sub: str = s.substring(1, 3);  // inclusive both ends
    print(sub, newLine=true);           // Hel
};

function test_string_builder() -> null {
    print("=== 8b. StringBuilder ===");

    var sb: StringBuilder = StringBuilder();
    sb.append("Mocha");
    sb.append(" is");
    sb.append(" fast!");
    var result: str = sb.toString();
    print(result, newLine=true);   // Mocha is fast!

    var reversed: str = sb.reverse();
    print(reversed, newLine=true); // !tsaf si ahcoM

    sb.clear();
    sb.append("After clear: ");
    sb.append("still works!");
    print(sb.toString(), newLine=true);  // After clear: still works!
};

// =============================================================================
// SECTION 9 — mocha-stats
// =============================================================================

function test_distances() -> null {
    print("=== 9a. Distances ===");

    var a: float[] = [0.0, 0.0];
    var b: float[] = [3.0, 4.0];

    print("Euclidean [0,0] [3,4]: ",   newLine=true);
    print(euclidean(a, b),             newLine=true);  // 5.0
    print("Manhattan [0,0] [3,4]: ",   newLine=true);
    print(manhattan(a, b),             newLine=true);  // 7.0
    print("Chebyshev [0,0] [3,4]: ",   newLine=true);
    print(chebyshev(a, b),             newLine=true);  // 4.0
    print("Minkowski p=1 [0,0] [3,4]: ", newLine=true);
    print(minkowski(a, b, 1.0),        newLine=true);  // 7.0 (== Manhattan)
    print("Minkowski p=2 [0,0] [3,4]: ", newLine=true);
    print(minkowski(a, b, 2.0),        newLine=true);  // 5.0 (== Euclidean)

    var x: float[] = [1.0, 0.0];
    var y: float[] = [0.0, 1.0];
    print("Cosine perpendicular: ",    newLine=true);
    print(cosine(x, y),                newLine=true);  // 0.0
    print("Cosine identical: ",        newLine=true);
    print(cosine(x, x),                newLine=true);  // 1.0
    var neg_x: float[] = [-1.0, 0.0];
    print("Cosine opposite: ",         newLine=true);
    print(cosine(x, neg_x),            newLine=true);  // -1.0

    // Haversine — London to Paris (~340 km)
    print("Haversine London->Paris (km): ", newLine=true);
    print(haversine(51.5074, -0.1278, 48.8566, 2.3522), newLine=true);

    print("Hamming karolin/kathrin: ", newLine=true);
    print(hamming("karolin", "kathrin"), newLine=true);
    print("Hamming 1011101/1001001: ", newLine=true);
    print(hamming("1011101", "1001001"), newLine=true);
};

function test_stats() -> null {
    print("=== 9b. Statistical functions ===");

    var data: float[] = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];

    print("Mean: ",       newLine=true);
    print(data.mean(),    newLine=true);       // 5.0
    print("Median: ",     newLine=true);
    print(data.median(),  newLine=true);       // 4.5

    var modes: float[] = data.mode();
    print("Mode: ",       newLine=true);
    print(modes[0],       newLine=true);       // 4.0

    print("Var popu: ",      newLine=true);
    print(data.var_popu(),   newLine=true);    // 3.5
    print("Var sample: ",    newLine=true);
    print(data.var_sample(), newLine=true);    // 4.0
    print("Std popu: ",      newLine=true);
    print(data.std_popu(),   newLine=true);    // 1.870...
    print("Std sample: ",    newLine=true);
    print(data.std_sample(), newLine=true);    // 2.0

    print("Q1: ",               newLine=true);
    print(data.first_quart(),   newLine=true);
    print("Q3: ",               newLine=true);
    print(data.third_quart(),   newLine=true);
    print("IQR: ",              newLine=true);
    print(data.range_of_quart(), newLine=true);

    var bounds: float[] = data.outlier_bounds();
    print("Lower bound: ", newLine=true);
    print(bounds[0],       newLine=true);
    print("Upper bound: ", newLine=true);
    print(bounds[1],       newLine=true);

    print("Z-score of 7.0: ",  newLine=true);
    print(data.z_score(7.0),   newLine=true);
    print("T-score of 7.0: ",  newLine=true);
    print(data.t_score(7.0),   newLine=true);

    var normed: float[] = data.normalize();
    print("Normalized[0]: ",   newLine=true);
    print(normed[0],           newLine=true);  // 0.0
    print("Normalized[7]: ",   newLine=true);
    print(normed[7],           newLine=true);  // 1.0

    var xs: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var ys: float[] = [2.0, 4.0, 5.0, 4.0, 5.0];
    print("Covar: ",     newLine=true);
    print(covar(xs, ys), newLine=true);
    print("Corr: ",      newLine=true);
    print(corr(xs, ys),  newLine=true);

    var observed: float[] = [10.0, 20.0, 30.0];
    var expected: float[]  = [15.0, 20.0, 25.0];
    print("Chi: ",              newLine=true);
    print(chi(observed, expected), newLine=true);
};


// =============================================================================
// SECTION 10 — mocha-processing
// =============================================================================

function test_scalers() -> null {
    print("=== 10. Scalers ===");

    var train: float[] = [1.0, 2.0, 3.0, 4.0, 5.0];
    var test: float[]  = [0.0, 3.0, 6.0];

    print("--- StandardScaler ---");
    var ss: StandardScaler = StandardScaler();
    var ss_train: float[]  = ss.fit_transform(train);
    print("Transformed train:");
    var i: int = 0;
    while (i < ss_train.length) {
        print(ss_train[i], newLine=true);
        i++;
    };
    print("Transformed test:");
    var ss_test: float[] = ss.transform(test);
    i = 0;
    while (i < ss_test.length) {
        print(ss_test[i], newLine=true);
        i++;
    };

    print("--- MinMaxScaler ---");
    var mms: MinMaxScaler  = MinMaxScaler();
    var mms_train: float[] = mms.fit_transform(train);
    print("Transformed train:");
    i = 0;
    while (i < mms_train.length) {
        print(mms_train[i], newLine=true);
        i++;
    };
    print("Transformed test:");
    var mms_test: float[] = mms.transform(test);
    i = 0;
    while (i < mms_test.length) {
        print(mms_test[i], newLine=true);
        i++;
    };

    print("--- RobustScaler (with outlier 100.0) ---");
    var outlier_data: float[] = [1.0, 2.0, 3.0, 4.0, 5.0, 100.0];
    var rs: RobustScaler      = RobustScaler();
    var rs_train: float[]     = rs.fit_transform(outlier_data);
    print("Transformed:");
    i = 0;
    while (i < rs_train.length) {
        print(rs_train[i], newLine=true);
        i++;
    };
};


// =============================================================================
// SECTION 11 — mocha-SymCha
// =============================================================================

function test_sym_diff() -> null {
    print("=== 11. Symbolic differentiation ===");

    // d/dx(x/x) should simplify to 0
    var expr: Expr = Sym.div_e(Sym.var_e("x"), Sym.var_e("x"));
    var d: Expr    = Sym.sym_simplify(Sym.sym_diff(expr, "x"));
    print("d/dx(x/x) = ", Sym.sym_print(d), newLine=true);  // d/dx(x/x) = 0
};

// =============================================================================
// MAIN
// =============================================================================

function main(didLoad){
    print("\n");
    // --- Complex ---
    test_complex_basics(); print("\n");
    test_complex_promotion(); print("\n");
    test_complex_str_set(); print("\n");
    test_conjugate(); print("\n");

    // --- Sets ---
    test_set_operations(); print("\n");

    // --- Collections ---
    test_dict_merge(); print("\n");
    runHashTableTests(); print("\n");

    // --- Comprehension ---
    test_comprehension(); print("\n");

    // --- Tags ---
    test_tags(); print("\n");

    // --- OOP ---
    test_sort_objects(); print("\n");
    //test_interface_diamond();
    test_self_referential(); print("\n");

    // --- I/O (interactive — comment out for non-interactive runs) ---
    test_tell(); print("\n");
    test_file_io(); print("\n");

    // --- Strings ---
    test_substring(); print("\n");
    test_string_builder(); print("\n");

    // --- mocha-stats ---
    test_distances(); print("\n");
    test_stats(); print("\n");

    // --- mocha-processing ---
    test_scalers(); print("\n");

    // --- mocha-SymCha ---
    test_sym_diff(); print("\n");
};