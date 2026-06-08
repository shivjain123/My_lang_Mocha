from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    var net: Network = Network();
    net.add(Dense(3, 4, Activation.RELU));
    net.add(Dense(4, 2, Activation.SOFTMAX));

    var input: Tensor = Tensor(4, 3);
    input.put(0, 0, 1.0); input.put(0, 1, 2.0); input.put(0, 2, 3.0);
    input.put(1, 0, 4.0); input.put(1, 1, 5.0); input.put(1, 2, 6.0);
    input.put(2, 0, 7.0); input.put(2, 1, 8.0); input.put(2, 2, 9.0);
    input.put(3, 0, 0.1); input.put(3, 1, 0.2); input.put(3, 2, 0.3);

    var output: Tensor = net.predict(input);
    output.show();

    input.dispose();
    output.dispose();
    net.dispose();
};