from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // simple GRU test: process a sequence of 3 timesteps
    // input size = 1, hidden size = 4, output size = 1

    var gru: Gru = Gru(1, 4);
    var dense: Dense = Dense(4, 1, Activation.SIGMOID);

    // sequence: [1, 0, 1] → parity at each step: [1, 1, 0]
    var x0: Tensor = Tensor(1, 1); x0.put(0, 0, 1.0);
    var x1: Tensor = Tensor(1, 1); x1.put(0, 0, 0.0);
    var x2: Tensor = Tensor(1, 1); x2.put(0, 0, 1.0);

    var y0: Tensor = Tensor(1, 1); y0.put(0, 0, 1.0);
    var y1: Tensor = Tensor(1, 1); y1.put(0, 0, 1.0);
    var y2: Tensor = Tensor(1, 1); y2.put(0, 0, 0.0);

    // train for 1000 epochs
    var epoch: int = 0;
    while (epoch < 1000) {
        // forward pass through sequence
        var h: Tensor = Tensor(1, 4);
        h.zeros();

        var h0: Tensor = gru.forward(x0, h);
        var h1: Tensor = gru.forward(x1, h0);
        var h2: Tensor = gru.forward(x2, h1);

        var o0: Tensor = dense.forward(h0);
        var o1: Tensor = dense.forward(h1);
        var o2: Tensor = dense.forward(h2);

        // compute loss (mse on last output only for simplicity)
        var loss: float = mocha_tensor_mse_loss(o2.ptr, y2.ptr);

        // backward
        var do2: Tensor = Tensor(1, 1);
        mocha_tensor_free(do2.ptr);
        do2.ptr = mocha_tensor_mse_grad(o2.ptr, y2.ptr);

        var dh2: Tensor = dense.backward(do2, 0.01);
        var dx2: Tensor = gru.backward(dh2, 0.01);

        // cleanup
        h.dispose();
        h0.dispose(); h1.dispose(); h2.dispose();
        o0.dispose(); o1.dispose();
        o2.dispose();
        do2.dispose();
        dh2.dispose();
        dx2.dispose();

        if (epoch % 100 == 0) {
            print("\nEpoch: ", epoch);
            print(" Loss: ", loss);
        };

        epoch = epoch + 1;
    };

    // final prediction
    var h: Tensor = Tensor(1, 4);
    h.zeros();
    var h0: Tensor = gru.forward(x0, h);
    var h1: Tensor = gru.forward(x1, h0);
    var h2: Tensor = gru.forward(x2, h1);
    var out: Tensor = dense.forward(h2);
    print("Final prediction (expect ~0): ");
    out.show();

    // cleanup
    h.dispose(); h0.dispose(); h1.dispose(); h2.dispose();
    out.dispose();
    x0.dispose(); x1.dispose(); x2.dispose();
    y0.dispose(); y1.dispose(); y2.dispose();
    gru.dispose();
    dense.dispose();
};