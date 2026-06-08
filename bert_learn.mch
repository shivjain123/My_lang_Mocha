from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // one BERT layer: d_model=8, d_k=4, d_ff=16
    var layer: BertLayer = BertLayer(8, 4, 16);

    // target: learn to output zeros for any input
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

    var target: Tensor = Tensor(4, 8);
    target.zeros();

    // train for 600 epochs
    var epoch: int = 0;
    while (epoch < 600) {
        var output: Tensor = layer.forward(x);
        var loss: float = mocha_tensor_mse_loss(output.ptr, target.ptr);

        var dout: Tensor = Tensor(4, 8);
        mocha_tensor_free(dout.ptr);
        dout.ptr = mocha_tensor_mse_grad(output.ptr, target.ptr);
        var dx: Tensor = layer.backward(dout, 0.01);

        output.dispose();
        dout.dispose();
        dx.dispose();

        if (epoch % 20 == 0) {
            print("Epoch: ", newLine=false);
            print(epoch, newLine=false);
            print(" Loss: ", newLine=false);
            print(loss, newLine=true);
        };
        epoch = epoch + 1;
    };

    // final output
    var final_out: Tensor = layer.forward(x);
    print("Final output (expect ~zeros):", newLine=true);
    final_out.show();

    x.dispose();
    target.dispose();
    final_out.dispose();
    layer.dispose();
};