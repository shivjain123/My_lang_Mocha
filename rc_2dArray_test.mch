"""function main(didLoad) -> null {
    // Stage 1: fresh 2D int literal + reassignment
    // Exercises: mocha_array2d_new, mocha_array2d_release on reassign
    var a1: int[][] = [[1, 2], [3, 4]];
    var i: int = 0;
    while (i < 200000) {
        a1 = [[1, 2], [3, 4]];
        i++;
    };
    print("stage 1 done", newLine=true);

    // Stage 2: 2D str literal + reassignment
    // Exercises: elem_is_str threading through the constructor + release
    var a2: str[][] = [["a", "b"], ["c", "d"]];
    var j: int = 0;
    while (j < 200000) {
        a2 = [["a", "b"], ["c", "d"]];
        j++;
    };
    print("stage 2 done", newLine=true);

    // Stage 3: arr[r][c] = value with a FRESH str value
    // Exercises Step 75's string-safe index2d assignment path
    var a3: str[][] = [["x", "y"], ["z", "w"]];
    var k: int = 0;
    while (k < 200000) {
        a3[0][0] = "p" + "q";
        k++;
    };
    print("stage 3 done", newLine=true);

    // Stage 4: arr[r][c] = value with a BORROWED string, repeated overwrite
    var val: str = "hello";
    var a4: str[][] = [["a", "b"], ["c", "d"]];
    var m: int = 0;
    while (m < 200000) {
        a4[1][1] = val;
        m++;
    };
    print("stage 4 done", newLine=true);
    print(val, newLine=true); // sanity: val should still read "hello"

    // Stage 5: get_row storing the result — exercises Step 68's retain fix
    var a5: int[][] = [[1, 2, 3], [4, 5, 6]];
    var row: int[] = a5[0];
    var n: int = 0;
    while (n < 200000) {
        row = a5[0];
        n++;
    };
    print("stage 5 done", newLine=true);

    // Stage 6: push_row with a FRESH row, then push_row with a BORROWED row
    // Exercises Step 70's push_row retain-if-borrowed logic
    var a6: int[][] = [[1, 2]];
    var newRow: int[] = [9, 9];
    var p: int = 0;
    while (p < 200000) {
        a6 = [[1, 2]];
        a6.push([7, 7]);
        a6.push(newRow);
        p++;
    };
    print("stage 6 done", newLine=true);
    print(newRow[0], newLine=true); // sanity: newRow should still read 9

    print("all stages done", newLine=true);
};"""

function main(didLoad) -> null {
    var a: int[][] = [[1, 2], [3, 4], [5, 6]];
    var i: int = 0;
    while (i < 200000) {
        a = [[1, 2], [3, 4], [5, 6]];
        a.drop(row=1);
        i++;
    };
    print("done", newLine=true);
};