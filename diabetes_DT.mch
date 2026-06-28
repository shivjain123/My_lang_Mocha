from "mocha-forge" import *;

function main(didLoad) -> null {
    var f: File = open("diabetes.csv", "read");
    var line: str = f.readLine();

    var x: float[][] = [[]];
    var y: int[] = [];

    line = f.readLine();
    while (line != "") {
        var parts: str[] = line.split(",");
        var row: float[] = [];
        row.push(parts[0].toFloat());
        row.push(parts[1].toFloat());
        row.push(parts[2].toFloat());
        row.push(parts[3].toFloat());
        row.push(parts[4].toFloat());
        row.push(parts[5].toFloat());
        row.push(parts[6].toFloat());
        row.push(parts[7].toFloat());
        x.push(row);
        y.push(parts[8].toInt());
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
    x_n = x_n.normalize_col(7);

    var split: TrainTestSplit = train_test_split(x_n, y, 0.3, 0);

    var model: DecisionTree = DecisionTree(5);
    model.fit(split.x_train, split.y_train);

    var preds: int[] = model.predict(split.x_test);
    var acc: float = model.accuracy(split.x_test, split.y_test);
    var cm: ConfusionMatrix = confusion_matrix(split.y_test, preds);

    print("Model accuracy: $0|2f".format(acc), newLine=true);
    cm.print_matrix();
};