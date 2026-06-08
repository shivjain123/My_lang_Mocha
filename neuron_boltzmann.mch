from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // RBM: 6 visible, 3 hidden
    // train on two patterns: [1,1,1,0,0,0] and [0,0,0,1,1,1]
    var rbm: Rbm = Rbm(6, 3);

    // create training patterns
    var p1: Tensor = Tensor(1, 6);
    p1.put(0, 0, 1.0); p1.put(0, 1, 1.0); p1.put(0, 2, 1.0);
    p1.put(0, 3, 0.0); p1.put(0, 4, 0.0); p1.put(0, 5, 0.0);

    var p2: Tensor = Tensor(1, 6);
    p2.put(0, 0, 0.0); p2.put(0, 1, 0.0); p2.put(0, 2, 0.0);
    p2.put(0, 3, 1.0); p2.put(0, 4, 1.0); p2.put(0, 5, 1.0);

    // train 500 epochs alternating patterns
    var epoch: int = 0;
    while (epoch < 500) {
        rbm.train_step(p1, 0.01);
        rbm.train_step(p2, 0.01);
        epoch = epoch + 1;
    };

    // check reconstruction error
    var err1: float = rbm.reconstruction_error(p1);
    var err2: float = rbm.reconstruction_error(p2);
    print("Reconstruction error p1: ", err1, "\n");
    print("Reconstruction error p2: ", err2, "\n");

    // reconstruct and print
    var r1: Tensor = rbm.reconstruct(p1);
    var r2: Tensor = rbm.reconstruct(p2);
    print("p1 reconstruction: ");
    r1.show();
    print("p2 reconstruction: ");
    r2.show();

    p1.dispose(); p2.dispose();
    r1.dispose(); r2.dispose();
    rbm.dispose();
};