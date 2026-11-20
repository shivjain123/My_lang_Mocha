extend File {
    function twice(n: int = 2) -> int {
        return n * 2;
    };
};

function main(didLoad) -> null {
    var f: File = open("ext_named_test.txt", "write");
    var a: int = f.twice();
    var b: int = f.twice(n=5);
    print(a, " ", b, newLine=true);
    f.close();
};