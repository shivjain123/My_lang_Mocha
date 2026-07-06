function make_num_tuple() -> null {
    var t: (int, 2) = (1, 2);
};

function make_str_tuple() -> null {
    var t: (str, 2) = ("hello", "world");
};

function test(didLoad) -> null {
    var i: int = 0;
    while (i < 200000) {
        make_num_tuple();
        make_str_tuple();
        i++;
    };
    print("done", newLine=true);
};