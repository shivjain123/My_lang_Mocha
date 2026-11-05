from "mocha-matvec" import *;

function run(didLoad) {
    var f: float[][] = alloc float[2][3];
    f[0][0] = 1.0; f[0][1] = 1.0; f[0][2] = 1.0;
    f[1][0] = 1.0; f[1][1] = 1.0; f[1][2] = 1.0;
    print("1: float 2x3, expect 2.44949", newLine=true);
    var s1: float[] = f.singular_values();
    print(s1[0], newLine=true);

    var sq: int[][] = alloc int[2][2];
    sq[0][0] = 1; sq[0][1] = 1;
    sq[1][0] = 1; sq[1][1] = 1;
    print("2: int 2x2, expect 2.0", newLine=true);
    var s2: float[] = sq.singular_values();
    print(s2[0], newLine=true);

    var m: int[][] = alloc int[2][3];
    m[0][0] = 1; m[0][1] = 1; m[0][2] = 1;
    m[1][0] = 1; m[1][1] = 1; m[1][2] = 1;
    print("3: int 2x3, expect 2.44949", newLine=true);
    var s3: float[] = m.singular_values();
    print(s3[0], newLine=true);
};