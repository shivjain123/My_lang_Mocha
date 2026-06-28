"""
    Mocha v0.5 — FFI Tests
    
    Entry point: runFFITests(didLoad)
    
    Sections:
     1. C++ FFI        (cpp_add, cpp_power, cpp_greet, cpp_strlen)
     2. Lua FFI        (lua_new, lua_dostring, lua_getnumber, lua_getstring)
     3. Rust FFI       (rust_add, rust_multiply, rust_fibonacci, rust_factorial)
     4. Shell          (system())
     5. SQLite3 Write  (open, exec, close)
     6. SQLite3 Read   (open, query, close)
    
    Requirements:
     - mocha_cpp.o     (C++ functions compiled with extern "C")
     - lua lib         (lua-5.5.0_Win64_dllw6_lib)
     - rust lib        (mocha_rust.o compiled with no_std + no_mangle)
     - sqlite3.o       (sqlite-amalgamation)
     - All linked via mocha_runtime.c
    
    Run:
     mocha mocha_ffi_tests.mch
     mocha_ffi_tests.exe
"""

// ============================================================
// FFI DECLARATIONS
// ============================================================

// C stdlib
function puts(s: str) -> int native puts;

// C++ FFI
function cpp_add(a: int, b: int) -> int native mocha_cpp_add;
function cpp_power(base: float, exp: float) -> float native mocha_cpp_power;
function cpp_greet(name: str) -> str native mocha_cpp_greet;
function cpp_strlen(s: str) -> int native mocha_cpp_strlen;

// Lua FFI
function lua_new() -> null native mocha_lua_new;
function lua_dostring(lua: null, code: str) -> int native mocha_lua_dostring;
function lua_close(lua: null) -> null native mocha_lua_close;
function lua_getnumber(lua: null, varname: str) -> float native mocha_lua_getnumber;
function lua_getstring(lua: null, varname: str) -> str native mocha_lua_getstring;

// Rust FFI
function rust_add(a: int, b: int) -> int native mocha_rust_add;
function rust_multiply(a: int, b: int) -> int native mocha_rust_multiply;
function rust_fibonacci(n: int) -> int native mocha_rust_fibonacci;
function rust_factorial(n: int) -> int native mocha_rust_factorial;

// Shell
function system(cmd: str) -> int native mocha_wrap_system;

// SQLite3
function sqlite3_open(path: str) -> null native mocha_sqlite3_open;
function sqlite3_exec(db: null, sql: str) -> int native mocha_sqlite3_exec;
function sqlite3_query(db: null, sql: str) -> int native mocha_sqlite3_query;
function sqlite3_close(db: null) -> null native mocha_sqlite3_close;


// ============================================================
// SECTION 1 — C++ FFI
// ============================================================

function section_cpp() -> null {
    puts("--- 1. C++ FFI ---");

    var sum: int = cpp_add(21, 21);
    puts(str(sum));           // 42

    var p: float = cpp_power(2.0, 10.0);
    puts(str(p));             // 1024.0

    var greeting: str = cpp_greet("Mocha");
    puts(greeting);           // Hello from C++!

    var len: int = cpp_strlen("Hello Mocha!");
    puts(str(len));           // 12
};


// ============================================================
// SECTION 2 — Lua FFI
// ============================================================

function section_lua() -> null {
    puts("--- 2. Lua FFI ---");

    var state: null = lua_new();

    // Arithmetic
    var r1: int = lua_dostring(state, "x = 6 * 7");
    puts(str(r1));            // 0 (success)
    var x: float = lua_getnumber(state, "x");
    puts(str(x));             // 42.0

    // String
    var r2: int = lua_dostring(state, "msg = 'Hello from Lua!'");
    var msg: str = lua_getstring(state, "msg");
    puts(msg);                // Hello from Lua!

    // Fibonacci in Lua
    var r3: int = lua_dostring(state,
        "function fib(n) if n <= 1 then return n end return fib(n-1) + fib(n-2) end result = fib(20)");
    var result: float = lua_getnumber(state, "result");
    puts(str(result));        // 6765.0

    lua_close(state);
    puts("Done!");
};


// ============================================================
// SECTION 3 — Rust FFI
// ============================================================

function section_rust() -> null {
    puts("--- 3. Rust FFI ---");

    puts(str(rust_add(21, 21)));        // 42
    puts(str(rust_multiply(6, 7)));     // 42
    puts(str(rust_fibonacci(40)));      // 102334155
    puts(str(rust_factorial(10)));      // 3628800
};


// ============================================================
// SECTION 4 — Shell (system())
// ============================================================

function section_shell() -> null {
    puts("--- 4. Shell ---");

    var r1: int = system("echo Hello from Mocha via shell!");
    puts(str(r1));    // 0 (success) — echo output appears before this

    var r2: int = system("dir /b *.mch");
    puts(str(r2));    // 0 (success) — dir listing appears before this
};


// ============================================================
// SECTION 5 — SQLite3 Write
// ============================================================

function section_sqlite_write() -> null {
    puts("--- 5. SQLite3 Write ---");

    var db: null = sqlite3_open("mocha_test.db");

    var r1: int = sqlite3_exec(db,
        "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT);");
    puts(str(r1));    // 0 (success)

    var r2: int = sqlite3_exec(db,
        "INSERT INTO users (name) VALUES ('Mocha');");
    puts(str(r2));    // 0

    var r3: int = sqlite3_exec(db,
        "INSERT INTO users (name) VALUES ('Shiv');");
    puts(str(r3));    // 0

    sqlite3_close(db);
    puts("Done!");
};


// ============================================================
// SECTION 6 — SQLite3 Read
// ============================================================

function section_sqlite_read() -> null {
    puts("--- 6. SQLite3 Read ---");

    var db: null = sqlite3_open("mocha_test.db");

    var r1: int = sqlite3_query(db, "SELECT * FROM users;");
    puts(str(r1));    // 0 — rows printed by callback before this

    sqlite3_close(db);
    puts("Done!");
};


// ============================================================
// ENTRY POINT
// ============================================================

function runFFITests(didLoad) -> null {
    puts("Mocha v0.5 — FFI Tests");
    puts("==========================");

    section_cpp();
    section_lua();
    section_rust();
    section_shell();
    section_sqlite_write();
    section_sqlite_read();

    puts("==========================");
    puts("All FFI Tests Complete!");
};