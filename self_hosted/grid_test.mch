from "mocha-matvec" import *;

class Grid {
    var cells: float[][];
    function constructor() -> null {
    };
    function at(r: int, c: int) -> float {
        return this.cells[r][c];
    };
};

function sum_diag(g: int[][], n: int) -> int {
    var total: int = 0;
    var i: int = 0;
    while (i < n) {
        total = total + g[i][i];
        i = i + 1;
    };
    return total;
};

function one_float(g: float[][]) -> float {
    var f: float = g[0][1];
    return f;
};

function grid_tests(didLoad) -> null {
    print("ok", newLine=true);
};
