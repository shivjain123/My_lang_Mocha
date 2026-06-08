from "mocha-neuron" import *;

function main(didLoad) -> null {
    mocha_cuda_init();

    // simple XOR-like dataset
    var x: Tensor = Tensor(4, 2);
    x.put(0, 0, 0.0); x.put(0, 1, 0.0);
    x.put(1, 0, 0.0); x.put(1, 1, 1.0);
    x.put(2, 0, 1.0); x.put(2, 1, 0.0);
    x.put(3, 0, 1.0); x.put(3, 1, 1.0);
    mocha_tensor_upload(x.ptr);

    var y: Tensor = Tensor(4, 1);
    y.put(0, 0, 0.0);
    y.put(1, 0, 1.0);
    y.put(2, 0, 1.0);
    y.put(3, 0, 0.0);
    mocha_tensor_upload(y.ptr);

    // build and train network
    var net: Network = Network();
    net.add(Dense(2, 4, Activation.RELU));
    net.add(Dense(4, 1, Activation.SIGMOID));

    var ep: int = 0;
    while (ep < 500) {
        net.fit_step(x, y, 0.01, "mse");
        ep++;
    };

    // predictions before save
    print("=== Before Save ===", newLine=true);
    var p1: Tensor = net.predict(x);
    mocha_tensor_download(p1.ptr);
    var i: int = 0;
    while (i < 4) {
        print("pred=" + str(p1.at(i, 0)), newLine=true);
        i++;
    };

    // save
    net.save("network.db");

    // load into fresh network
    var net2: Network = Network();
    net2.load("network.db");

    // predictions after load
    print("=== After Load ===", newLine=true);
    var p2: Tensor = net2.predict(x);
    mocha_tensor_download(p2.ptr);
    var j: int = 0;
    while (j < 4) {
        print("pred=" + str(p2.at(j, 0)), newLine=true);
        j++;
    };

    net.dispose();
    net2.dispose();
    x.dispose();
    y.dispose();
    p1.dispose();
    p2.dispose();
};