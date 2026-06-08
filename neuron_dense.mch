from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    var layer: Dense = Dense(3, 2, "relu");
    
    var input: Tensor = Tensor(1, 3);
    input.put(0, 0, 1.0);
    input.put(0, 1, 2.0);
    input.put(0, 2, 3.0);

    var output: Tensor = layer.forward(input);
    output.show();

    input.dispose();
    output.dispose();
    layer.dispose();
};