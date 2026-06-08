from "mocha-neuron" import *;

function main(didLoad){
    rand_seed(42);

    // sequence of 4 timesteps, input size 2, hidden size 3
    // output at each step will be [1 x 6] (3 fwd + 3 bwd concatenated)
    var bigru: BiGru = BiGru(2, 3);

    // build input sequence
    var xs: Tensor[] = [];
    var x0: Tensor = Tensor(1, 2); x0.put(0, 0, 1.0); x0.put(0, 1, 0.0);
    var x1: Tensor = Tensor(1, 2); x1.put(0, 0, 0.0); x1.put(0, 1, 1.0);
    var x2: Tensor = Tensor(1, 2); x2.put(0, 0, 1.0); x2.put(0, 1, 1.0);
    var x3: Tensor = Tensor(1, 2); x3.put(0, 0, 0.0); x3.put(0, 1, 0.0);
    xs.push(x0); xs.push(x1); xs.push(x2); xs.push(x3);

    // forward pass
    var outputs: Tensor[] = bigru.forward(xs);

    // print all outputs — each should be [1 x 6]
    print("BiGru outputs (4 timesteps, hidden*2=6):", newLine=true);
    var i: int = 0;
    while (i < outputs.length) {
        print("t=", newLine=false);
        print(i, newLine=false);
        print(": ");
        var out_i: Tensor = outputs[i];
        out_i.show();
        out_i.dispose();
        i = i + 1;
    };

    x0.dispose(); x1.dispose(); x2.dispose(); x3.dispose();
    bigru.dispose();
};