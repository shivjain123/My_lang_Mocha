from "mocha-forge" import *;

function main(didLoad) -> null {
    var f: File = open("score.csv", "read");
    var line: str = f.readLine();

    var x: float[][] = [[]];
    var y: float[] = [];

    line = f.readLine();
    while (line != "") {
        var parts: str[] = line.split(",");
        var row: float[] = [];
        row.push(parts[1].toFloat());
        row.push(parts[2].toFloat());
        row.push(parts[3].toFloat());
        row.push(parts[4].toFloat());
        row.push(parts[5].toFloat());
        row.push(parts[6].toFloat());
        row.push(parts[7].toFloat());
        x.push(row);
        y.push(parts[8].toFloat());
        line = f.readLine();
    };
    f.close();

    var x_n: float[][] = x.normalize_col(0);
    x_n = x_n.normalize_col(1);
    x_n = x_n.normalize_col(2);
    x_n = x_n.normalize_col(3);
    x_n = x_n.normalize_col(4);
    x_n = x_n.normalize_col(5);
    x_n = x_n.normalize_col(6);

    var model: LinearRegression = LinearRegression(0.01, 2000);
    model.fit(x_n, y);
    model.summary(x_n, y);

    var sample: float[] = [];
    sample.push(x.normalize_val(0, 320.0));
    sample.push(x.normalize_val(1, 110.0));
    sample.push(x.normalize_val(2, 3.0));
    sample.push(x.normalize_val(3, 3.5));
    sample.push(x.normalize_val(4, 3.5));
    sample.push(x.normalize_val(5, 8.5));
    sample.push(x.normalize_val(6, 1.0));

    var input: float[][] = [[]];
    input.push(sample);
    var pred: float[] = model.predict(input);
    print("Predicted admission chance: $0|2f".format(pred[0]), newLine=true);
};