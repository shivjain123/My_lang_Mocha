// mocha-native: C:\Users\shiv jain\Coding_Projects\My_Codes\Rust\graceful_windows\target\release\libgraceful_windows.a

// Rust FFI — graceful_windows (file I/O)
function file_open(path: str, mode: str) -> null native mocha_rust_file_open;
function file_close(handle: null) -> int native mocha_rust_file_close;
function file_free(handle: null) -> null native mocha_rust_file_free;
function file_read(handle: null) -> str native mocha_rust_file_read;
function file_read_line(handle: null) -> str native mocha_rust_file_read_line;
function file_write(handle: null, content: str) -> int native mocha_rust_file_write;
function file_reopen(handle: null, mode: str) -> int native mocha_rust_file_reopen;
function file_exists(path: str) -> int native mocha_rust_file_exists;
function file_is_file(path: str) -> int native mocha_rust_file_is_file;
function file_is_directory(path: str) -> int native mocha_rust_file_is_directory;
function file_last_error() -> str native mocha_rust_file_last_error;
function file_eof(handle: null) -> int native mocha_rust_file_eof;

// Note: file_free_string is completely gone.

function tested(didLoad) -> null {
    print("=== graceful_windows FFI Test ===");
    
    // --- Write ---
    print("--- Write ---");
    var w: null = file_open("graceful_test.txt", "write");
    if (w == null) {
        print("Error: " + file_last_error());
        return;
    };
    file_write(w, "Hello from Rust via Mocha!\n");
    file_write(w, "Second line.\n");
    file_write(w, "Third line.\n");
    file_close(w);
    file_free(w);
    print("Written successfully.");
    
    // --- Exists ---
    print("--- Exists ---");
    if (file_exists("graceful_test.txt") == 1) {
        print("graceful_test.txt exists!");
    };
    if (file_exists("ghost_file.txt") == 0) {
        print("ghost_file.txt correctly not found.");
    };
    
    // --- Read all ---
    print("--- Read all ---");
    var r: null = file_open("graceful_test.txt", "read");
    if (r == null) {
        print("Error: " + file_last_error());
        return;
    };
    var content: str = file_read(r);
    file_free(r);
    print(content);
    
    // --- ReadLine ---
    print("--- ReadLine ---");
    var rl: null = file_open("graceful_test.txt", "read");
    var count: int = 0;
    while (file_eof(rl) == 0) {
        file_read_line(rl); // We call it, but don't assign it to a variable.
        count++;
    };
    file_free(rl);
    print("Lines read: " + str(count));
    
    // --- Append ---
    print("--- Append ---");
    var a: null = file_open("graceful_test.txt", "append");
    if (a == null) {
        print("Error: " + file_last_error());
        return;
    };
    file_write(a, "Appended line.\n");
    file_free(a);
    
    // --- Read after append ---
    print("--- Read after append ---");
    var r2: null = file_open("graceful_test.txt", "read");
    var content2: str = file_read(r2);
    file_free(r2);
    print(content2);
    
    print("=== Test complete ===");
};