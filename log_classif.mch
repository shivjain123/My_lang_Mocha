from "mocha-forge" import *;

function main(didLoad) -> null {
    var f: File = open("escape_velocity.csv", "read");
    var line: str = f.readLine();

    var x: float[][] = [[]];
    var y: int[] = [];

    line = f.readLine();
    while (line != "") {
        var parts: str[] = line.split(",");
        var row: float[] = [];
        row.push(parts[0].toFloat());
        x.push(row);
        y.push(parts[1].toInt());
        line = f.readLine();
    };
    f.close();

    var x_n: float[][] = x.normalize_col(0);

    var model: LogisticClassification = LogisticClassification(0.01, 1000);
    model.fit(x_n, y);
    model.summary(x_n, y);

    var velocity: float = tell("Enter velocity: ").toFloat();
    var norm_v: float = x.normalize_val(0, velocity);

    var input: float[][] = [[]];
    var sample: float[] = [];
    sample.push(norm_v);
    input.push(sample);

    var prob: float[] = model.predict_probab(input);
    var confidence: float = prob[0];

    if (confidence < 0.5) {
        print("We cannot escape gravity. (confidence: $0|2f)".format(confidence), newLine=true);
    };
    if (confidence >= 0.5 && confidence < 0.7) {
        print("We might escape gravity. (confidence: $0|2f)".format(confidence), newLine=true);
    };
    if (confidence >= 0.7) {
        print("We can escape gravity! (confidence: $0|2f)".format(confidence), newLine=true);
    };
};