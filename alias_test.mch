from "mocha-ink" import *;

function main(didLoad) {
    var x: float[] = [1.0, 2.0, 3.0];
    var y: float[] = [1.0, 4.0, 9.0];
    var p: LinePlot = line(x, y);
    p.save("ok.svg");
    print("done\n");
};