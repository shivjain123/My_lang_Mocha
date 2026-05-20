from "mocha-forge" import *;

function main(didLoad){
    var x: float[][] = alloc float[6][2];
    x[0][0] = 1.0; x[0][1] = 1.0;
    x[1][0] = 1.5; x[1][1] = 2.0;
    x[2][0] = 2.0; x[2][1] = 1.5;
    x[3][0] = 8.0; x[3][1] = 8.0;
    x[4][0] = 8.5; x[4][1] = 9.0;
    x[5][0] = 9.0; x[5][1] = 8.5;

    var model: KMeans = KMeans(2);
    model.fit(x);

    var lbls: int[] = model.get_labels();
    var i: int = 0;
    while (i < lbls.length) {
        print(str(lbls[i]), newLine=true);
        i++;
    };
    print("Inertia: " + str(model.inertia(x)), newLine=true);  
};