from "mocha-stats" import *;

function main(didLoad) -> null {
    var data: float[][] = [[5.1, 3.5, 1.4], [4.9, 3.0, 1.4], [6.2, 3.4, 5.4], [5.9, 3.0, 5.1], [6.7, 3.1, 4.4]];

    print(data.col_min(0), newLine=true);
    print(data.col_max(0), newLine=true);
    print(data.col_min(2), newLine=true);
    print(data.col_max(2), newLine=true);

    print(data.normalize_val(1, 3.25), newLine=true);
    print(data.normalize_val(2, 10.0), newLine=true);
    print(data.normalize_val(0, 4.9), newLine=true);

    var r: float[][] = data.normalize_col(0);
    print(r.length, newLine=true);
    var i: int = 0;
    while (i < r.length) {
        print(r[i].length, newLine=true);
        if (r[i].length > 0) {
            print(r[i][0], newLine=true);
            print(r[i][1], newLine=true);
        };
        i++;
    };
};