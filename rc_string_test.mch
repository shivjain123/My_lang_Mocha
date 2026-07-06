function test(didLoad) -> null {
    var result: str = "";
    var i: int = 0;
    while (i < 500000) {
        result = result + "a";
        i++;
    };
    print(result.length, newLine=true);
};

"""function test(didLoad) -> null {
    var s: str = "";
    var i: int = 0;
    while (i < 500000) {
        s = "hello" + "world";
        i++;
    };
    print(s.length, newLine=true);
};"""

"""function main(didLoad){
    var x: str = "hi!";
    var y: str = x;
    print(x, y, newLine=true);
};"""