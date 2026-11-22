from "mocha-forge" import *;

function main(didLoad) -> null {
    var yt: int[] = [1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1];
    var yp: int[] = [1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1];

    var cm: ConfusionMatrix = confusion_matrix(yt, yp);
    print(cm.tp(), newLine=true);
    print(cm.fp(), newLine=true);
    print(cm.fn(), newLine=true);
    print(cm.tn(), newLine=true);
    print(cm.accuracy(), newLine=true);
    print(cm.precision(), newLine=true);
    print(cm.recall(), newLine=true);
    print(cm.f1(), newLine=true);

    cm.print_matrix();
};