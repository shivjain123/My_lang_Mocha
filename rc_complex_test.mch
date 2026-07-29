function main(didLoad) -> null {
    // Stage 1: fresh construction + reassignment
    // Exercises: rc_alloc constructor, mocha_complex_release on reassign
    var z1: Complex = 2+3im;
    var i: int = 0;
    while (i < 200000) {
        z1 = 2+3im;
        i++;
    };
    print("stage 1 done", newLine=true);

    // Stage 2: .add() producing a fresh Complex each time, reassigned
    // Exercises mocha_complex_add -> mocha_complex_new -> rc_alloc path
    var a: Complex = 1+1im;
    var b: Complex = 2+2im;
    var z2: Complex = a.add(b);
    var j: int = 0;
    while (j < 200000) {
        z2 = a.add(b);
        j++;
    };
    print("stage 2 done", newLine=true);
    print(z2.toString(), newLine=true); // sanity: should read 3+3im

    // Stage 3: borrowed Complex reassignment (z3 = a, repeatedly)
    var z3: Complex = 0+0im;
    var k: int = 0;
    while (k < 200000) {
        z3 = a;
        k++;
    };
    print("stage 3 done", newLine=true);
    print(a.toString(), newLine=true); // sanity: a should still read 1+1im

    // Stage 4: .toString() called and stored repeatedly
    // Exercises the rc_alloc fix in mocha_complex_tostring
    var s: str = "";
    var m: int = 0;
    while (m < 200000) {
        s = z2.toString();
        m++;
    };
    print("stage 4 done", newLine=true);

    // Stage 5: conjugate() producing a fresh Complex each time
    var z5: Complex = 3+4im;
    var zc: Complex = z5.conjugate();
    var n: int = 0;
    while (n < 200000) {
        zc = z5.conjugate();
        n++;
    };
    print("stage 5 done", newLine=true);
    print(zc.toString(), newLine=true); // sanity: should read 3-4im

    print("all stages done", newLine=true);
};