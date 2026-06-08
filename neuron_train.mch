from "mocha-neuron" import *;
from "mocha-stopwatch" import *;

function main(didLoad) -> null {
    rand_seed(123);

    var sw: Stopwatch = Stopwatch();
    print("Starting now!");
    sw.begin();

    // XOR problem — classic neural net test
    // inputs: [0,0], [0,1], [1,0], [1,1]
    // outputs: [0], [1], [1], [0]

    var x: Tensor = Tensor(4, 2);
    x.put(0, 0, 0.0); x.put(0, 1, 0.0);
    x.put(1, 0, 0.0); x.put(1, 1, 1.0);
    x.put(2, 0, 1.0); x.put(2, 1, 0.0);
    x.put(3, 0, 1.0); x.put(3, 1, 1.0);

    var y: Tensor = Tensor(4, 1);
    y.put(0, 0, 0.0);
    y.put(1, 0, 1.0);
    y.put(2, 0, 1.0);
    y.put(3, 0, 0.0);

    var net: Network = Network();
    net.add(Dense(2, 8, Activation.RELU));
    net.add(Dense(8, 1, Activation.SIGMOID));

    // train for 50_000 epochs and uses Adam's optim
    var epoch: int = 0;
    while (epoch < 50000) {
        var loss: float = net.fit_step(x, y, 0.1, "mse");
        if (epoch % 1000 == 0) {
            print("\nEpoch: ", epoch, " Loss: ", loss);
        };
        epoch++;
    };

    print("\n");
    // predict
    print("Predictions:", newLine=true);
    var pred: Tensor = net.predict(x);
    pred.show();

    sw.end();
    print("Done!");
    print("Time elapsed: " + str(sw.elapsed_ms()) + "ms", newLine=true);

    x.dispose();
    y.dispose();
    pred.dispose();
    net.dispose();
};