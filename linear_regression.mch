from "mocha-forge" import *;

function main(didLoad) -> null {
    var f: File = open("score.csv", "read");
    var line: str = f.readLine();

    var toefl: float[][] = [[]];
    var chance: float[] = [];

    line = f.readLine();
    while (line != "") {
        var parts: str[] = line.split(",");
        var row: float[] = [];
        row.push(parts[2].toFloat());
        toefl.push(row);
        chance.push(parts[8].toFloat());
        line = f.readLine();
    };
    f.close();

    var t_min: float = toefl.col_min(0);
    var t_max: float = toefl.col_max(0);
    var toefl_n: float[][] = toefl.normalize_col(0);

    var model: LinearRegression = LinearRegression(0.01, 1000);
    model.fit(toefl_n, chance);
    model.summary(toefl_n, chance);

    var norm_120: float = (120.0 - t_min) / (t_max - t_min);
    var input: float[][] = [[]];
    var sample: float[] = [];
    sample.push(norm_120);
    input.push(sample);
    var pred: float[] = model.predict(input);
    print("Predicted admission chance for TOEFL 120: $0|2f".format(pred[0]), newLine=true);
};