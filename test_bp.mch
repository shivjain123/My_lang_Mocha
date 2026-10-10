function main(didLoad) -> null {
    var t: (int, 2) = (1, 2);
    var u: (int, 2) = t;
    t = (3, 4);
    u = u;
    print("ok", newLine=true);
};