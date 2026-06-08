from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // sequence of 4 tokens, each with d_model=8
    // attention projects to d_k=4
    var attn: Attention = Attention(8, 4);

    // input: 4 tokens, each 8-dimensional
    var x: Tensor = Tensor(4, 8);
    var i: int = 0;
    while (i < 4) {
        var j: int = 0;
        while (j < 8) {
            x.put(i, j, rand_float(0.0 - 1.0, 1.0));
            j = j + 1;
        };
        i = i + 1;
    };

    print("Input [4 x 8]:", newLine=true);
    x.show();

    var output: Tensor = attn.forward(x);
    print("Attention output [4 x 8]:", newLine=true);
    output.show();

    // simple training step — try to make output match input
    var loss: float = mocha_tensor_mse_loss(output.ptr, x.ptr);
    print("Loss: ", newLine=false);
    print(loss, newLine=true);

    var dout: Tensor = Tensor(4, 8);
    mocha_tensor_free(dout.ptr);
    dout.ptr = mocha_tensor_mse_grad(output.ptr, x.ptr);
    var dx: Tensor = attn.backward(dout, 0.01);

    print("Backward done, dx shape matches input: ", newLine=false);
    print(dx.nrows, newLine=false);
    print(" x ", newLine=false);
    print(dx.ncols, newLine=true);

    x.dispose();
    output.dispose();
    dout.dispose();
    dx.dispose();
    attn.dispose();
};