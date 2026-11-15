function system(cmd: str) -> int native mocha_wrap_system;
function shell(didLoad) -> null {
    print("--- Shell ---");

    var r1: int = system("echo Hello from Mocha via shell!");
    print(r1);    // 0 (success) — echo output appears before this

    print(system("time /t"));    // 0 (success) — time output appears before this

    //var r2: int = system("dir /b *.mch");
    //print(r2);    // 0 (success) — dir listing appears before this
};