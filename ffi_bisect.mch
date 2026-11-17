// mocha-native: C:\Users\shiv jain\Coding_Projects\My_Codes\Rust\graceful_windows\target\release\libgraceful_windows.a

function file_open(path: str, mode: str) -> null native mocha_rust_file_open;
function file_last_error() -> str native mocha_rust_file_last_error;

function main(didLoad) {
    var h: null = file_open("no_such_file_zzz.txt", "read");
    var e: str = file_last_error();
    print(e);
    print("--- done ---");
};