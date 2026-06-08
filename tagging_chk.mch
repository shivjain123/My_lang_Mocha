tag Activation {
    RELU,
    SIGMOID,
    TANH,
    SOFTMAX,
    NONE,
};

class Layer {
    var activation: Activation;

    function constructor(act: Activation) -> null {
        this.activation = act;
    };

    function test() -> null {
        if (this.activation == Activation.RELU) {
            print("relu!", newLine=true);
        };
        if (this.activation == Activation.SIGMOID) {
            print("sigmoid!", newLine=true);
        };
    };
};

function main(didLoad) -> null {
    var l: Layer = Layer(Activation.RELU);
    l.test();
};