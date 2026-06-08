from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // one BERT layer: d_model=8, d_k=4, d_ff=16
    var layer: BertLayer = BertLayer(8, 4, 16);

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

    // forward
    var output: Tensor = layer.forward(x);
    print("BertLayer output [4 x 8]:", newLine=true);
    output.show();

    // loss
    var loss: float = mocha_tensor_mse_loss(output.ptr, x.ptr);
    print("Loss: ", newLine=false);
    print(loss, newLine=true);

    // backward
    var dout: Tensor = Tensor(4, 8);
    mocha_tensor_free(dout.ptr);
    dout.ptr = mocha_tensor_mse_grad(output.ptr, x.ptr);
    var dx: Tensor = layer.backward(dout, 0.01);

    print("Backward done! dx [", newLine=false);
    print(dx.nrows, newLine=false);
    print(" x ", newLine=false);
    print(dx.ncols, newLine=false);
    print("]", newLine=true);

    x.dispose();
    output.dispose();
    dout.dispose();
    dx.dispose();
    layer.dispose();
};