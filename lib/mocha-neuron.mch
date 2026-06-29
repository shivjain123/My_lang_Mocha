// mocha-lib-deps: mocha-math, mocha-string
from "mocha-sqlite" import *;
// =============================================
// CUDA NATIVE BINDINGS (internal)
// =============================================

function mocha_cuda_init() -> int native mocha_cuda_init;
function mocha_tensor_new(rows: int, cols: int) -> vast native mocha_tensor_new;
function mocha_tensor_free(t: vast) -> null native mocha_tensor_free;
function mocha_tensor_set(t: vast, row: int, col: int, val: float) -> null native mocha_tensor_set;
function mocha_tensor_get(t: vast, row: int, col: int) -> float native mocha_tensor_get;
function mocha_tensor_rows(t: vast) -> int native mocha_tensor_rows;
function mocha_tensor_cols(t: vast) -> int native mocha_tensor_cols;
function mocha_tensor_print(t: vast) -> null native mocha_tensor_print;
function mocha_tensor_matmul(a: vast, b: vast) -> vast native mocha_tensor_matmul;
function mocha_tensor_add(a: vast, b: vast) -> vast native mocha_tensor_add;
function mocha_tensor_scale(t: vast, val: float) -> null native mocha_tensor_scale;
function mocha_tensor_fill(t: vast, val: float) -> null native mocha_tensor_fill;
function mocha_tensor_zeros(t: vast) -> null native mocha_tensor_zeros;
function mocha_tensor_ones(t: vast) -> null native mocha_tensor_ones;
function mocha_tensor_relu(t: vast) -> null native mocha_tensor_relu;
function mocha_tensor_sigmoid(t: vast) -> null native mocha_tensor_sigmoid;
function mocha_tensor_tanh(t: vast) -> null native mocha_tensor_tanh;
function mocha_tensor_softmax(t: vast) -> null native mocha_tensor_softmax;
function mocha_tensor_relu_bias(t: vast, bias: vast) -> null native mocha_tensor_relu_bias;
function mocha_tensor_add_bias(t: vast, bias: vast) -> null native mocha_tensor_add_bias;
function mocha_tensor_transpose(t: vast) -> vast native mocha_tensor_transpose;
function mocha_tensor_relu_grad(dout: vast, out: vast) -> vast native mocha_tensor_relu_grad;
function mocha_tensor_sigmoid_grad(dout: vast, out: vast) -> vast native mocha_tensor_sigmoid_grad;
function mocha_tensor_tanh_grad(dout: vast, out: vast) -> vast native mocha_tensor_tanh_grad;
function mocha_tensor_softmax_ce_grad(out: vast, labels: vast) -> vast native mocha_tensor_softmax_ce_grad;
function mocha_tensor_bias_grad(dout: vast) -> vast native mocha_tensor_bias_grad;
function mocha_tensor_mse_loss(out: vast, labels: vast) -> float native mocha_tensor_mse_loss;
function mocha_tensor_mse_grad(out: vast, labels: vast) -> vast native mocha_tensor_mse_grad;
function mocha_tensor_ce_loss(out: vast, labels: vast) -> float native mocha_tensor_ce_loss;
function mocha_adam_update(w: vast, m: vast, v: vast, dw: vast, lr: float, beta1: float, beta2: float, eps: float, beta1t: float, beta2t: float) -> null native mocha_adam_update;
function mocha_tensor_concat(a: vast, b: vast) -> vast native mocha_tensor_concat;
function mocha_tensor_one_minus_mul(a: vast, b: vast) -> vast native mocha_tensor_one_minus_mul;
function mocha_tensor_split_a(grad: vast, cols_a: int) -> vast native mocha_tensor_split_a;
function mocha_tensor_split_b(grad: vast, cols_a: int) -> vast native mocha_tensor_split_b;
function mocha_tensor_mul(a: vast, b: vast) -> vast native mocha_tensor_mul;
function mocha_tensor_clone(t: vast) -> vast native mocha_tensor_clone;
function mocha_tensor_sign(t: vast) -> vast native mocha_tensor_sign;
function mocha_tensor_outer(a: vast, b: vast) -> vast native mocha_tensor_outer;
function mocha_tensor_zero_diagonal(t: vast) -> null native mocha_tensor_zero_diagonal;
function mocha_tensor_add_inplace(a: vast, b: vast) -> null native mocha_tensor_add_inplace;
function mocha_tensor_equal(a: vast, b: vast) -> int native mocha_tensor_equal;
function mocha_layer_norm(x: vast, gamma: vast, beta: vast, eps: float) -> vast native mocha_layer_norm;
function mocha_layer_norm_grad(dout: vast, x: vast, gamma: vast, dx: vast, dgamma: vast, dbeta: vast, eps: float) -> null native mocha_layer_norm_grad;
function mocha_tensor_upload(t: vast) -> int native mocha_tensor_upload;
function mocha_tensor_download(t: vast) -> int native mocha_tensor_download;
function mocha_lsm_scale_reservoir(w: vast, target_sr: float) -> null native mocha_lsm_scale_reservoir;
function mocha_ridge_regression(x: vast, y: vast, lamb_da: float, max_iter: int) -> vast native mocha_ridge_regression;
function mocha_tensor_get_row(t: vast, row: int) -> vast native mocha_tensor_get_row;

function c_print_err(msg: str) -> null native mocha_print_stderr;
// =============================================
// TENSOR CLASS
// =============================================

class Tensor {
    var ptr:  vast;
    var nrows: int;
    var ncols: int;

    function constructor(rows: int, cols: int) -> null {
        mocha_cuda_init();
        this.ptr  = mocha_tensor_new(rows, cols);
        this.nrows = rows;
        this.ncols = cols;
    };

    function put(row: int, col: int, val: float) -> null {
        mocha_tensor_set(this.ptr, row, col, val);
    };

    function at(row: int, col: int) -> float {
        return mocha_tensor_get(this.ptr, row, col);
    };

    function show() -> null {
        mocha_tensor_print(this.ptr);
    };

    function dispose() -> null {
        mocha_tensor_free(this.ptr);
    };

    function matmul(other: Tensor) -> Tensor {
        var result: Tensor = Tensor(this.nrows, other.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_matmul(this.ptr, other.ptr);
        return result;
    };

    function transpose() -> Tensor {
        var result: Tensor = Tensor(this.ncols, this.nrows);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_transpose(this.ptr);
        return result;
    };

    function add(other: Tensor) -> Tensor {
        var result: Tensor = Tensor(this.nrows, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_add(this.ptr, other.ptr);
        return result;
    };

    function relu() -> null {
        mocha_tensor_relu(this.ptr);
    };

    function sigmoid() -> null {
        mocha_tensor_sigmoid(this.ptr);
    };

    function tanh() -> null {
        mocha_tensor_tanh(this.ptr);
    };

    function softmax() -> null {
        mocha_tensor_softmax(this.ptr);
    };

    function scale(val: float) -> null {
        mocha_tensor_scale(this.ptr, val);
    };

    function fill(val: float) -> null {
        mocha_tensor_fill(this.ptr, val);
    };

    function zeros() -> null {
        mocha_tensor_zeros(this.ptr);
    };

    function ones() -> null {
        mocha_tensor_ones(this.ptr);
    };

    function concat(other: Tensor) -> Tensor {
        var result: Tensor = Tensor(this.nrows, this.ncols + other.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_concat(this.ptr, other.ptr);
        return result;
    };

    function one_minus_mul(other: Tensor) -> Tensor {
        var result: Tensor = Tensor(this.nrows, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_one_minus_mul(this.ptr, other.ptr);
        return result;
    };

    function mul(other: Tensor) -> Tensor {
        var result: Tensor = Tensor(this.nrows, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_mul(this.ptr, other.ptr);
        return result;
    };

    function clone_tensor() -> Tensor {
        var result: Tensor = Tensor(this.nrows, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_clone(this.ptr);
        return result;
    };

    function sign() -> Tensor {
        var result: Tensor = Tensor(this.nrows, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_sign(this.ptr);
        return result;
    };

    function outer(other: Tensor) -> Tensor {
        var result: Tensor = Tensor(this.ncols, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_outer(this.ptr, other.ptr);
        return result;
    };

    function zero_diagonal() -> null {
        mocha_tensor_zero_diagonal(this.ptr);
    };

    function add_inplace(other: Tensor) -> null {
        mocha_tensor_add_inplace(this.ptr, other.ptr);
    };

    function equals(other: Tensor) -> bool {
        return mocha_tensor_equal(this.ptr, other.ptr) == 1;
    };

    function get_row(row: int) -> Tensor {
        var result: Tensor = Tensor(1, this.ncols);
        mocha_tensor_free(result.ptr);
        result.ptr = mocha_tensor_get_row(this.ptr, row);
        return result;
    };
};

// ── neuron persistence helpers ──
function neuron_db_setup(db: null) -> null {
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);");
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS arrays (name TEXT, idx INT, value TEXT);");
};

function neuron_db_write_meta(db: null, key: str, value: str) -> null {
    sqlite3_exec(db, "INSERT OR REPLACE INTO meta (key, value) VALUES ('" + key + "', '" + value + "');");
};

function neuron_db_read_meta(db: null, key: str) -> str {
    sqlite3_query_run(db, "SELECT value FROM meta WHERE key = '" + key + "';");
    return sqlite3_query_cell(db, 0, 0);
};

function neuron_db_write_array(db: null, name: str, idx: int, value: str) -> null {
    sqlite3_exec(db, "INSERT INTO arrays (name, idx, value) VALUES ('" + name + "', " + str(idx) + ", '" + value + "');");
};

function neuron_db_read_array_cell(db: null, name: str, idx: int) -> str {
    sqlite3_query_run(db, "SELECT value FROM arrays WHERE name = '" + name + "' AND idx = " + str(idx) + ";");
    return sqlite3_query_cell(db, 0, 0);
};

function neuron_save_tensor(db: null, name: str, t: Tensor) -> null {
    mocha_tensor_download(t.ptr);
    var rows: int = t.nrows;
    var cols: int = t.ncols;
    neuron_db_write_meta(db, name + "_rows", str(rows));
    neuron_db_write_meta(db, name + "_cols", str(cols));
    var i: int = 0;
    while (i < rows) {
        var j: int = 0;
        while (j < cols) {
            neuron_db_write_array(db, name, i * cols + j, str(t.at(i, j)));
            j++;
        };
        i++;
    };
};

function neuron_load_tensor(db: null, name: str) -> Tensor {
    var rows: int = neuron_db_read_meta(db, name + "_rows").toInt();
    var cols: int = neuron_db_read_meta(db, name + "_cols").toInt();
    var t: Tensor = Tensor(rows, cols);
    var i: int = 0;
    while (i < rows) {
        var j: int = 0;
        while (j < cols) {
            var val: float = neuron_db_read_array_cell(db, name, i * cols + j).toFloat();
            t.put(i, j, val);
            j++;
        };
        i++;
    };
    mocha_tensor_upload(t.ptr);
    return t;
};

// =============================================
// DENSE LAYER
// =============================================

// =============================================
// ACTIVATION TAG
// =============================================

tag Activation {
    RELU,
    SIGMOID,
    TANH,
    SOFTMAX,
    NONE,
};

// =============================================
// DENSE LAYER
// =============================================

class Dense {
    var weights:     Tensor;
    var bias:        Tensor;
    var mw:          Tensor;
    var vw:          Tensor;
    var mb:          Tensor;
    var vb:          Tensor;
    var input_size:  int;
    var output_size: int;
    var activation:  Activation;
    var last_input:  Tensor;
    var last_output: Tensor;
    var has_input:   bool;
    var t:           int;

    function constructor(input_size: int, output_size: int, activation: Activation) -> null {
        this.input_size  = input_size;
        this.output_size = output_size;
        this.activation  = activation;
        this.has_input   = false;

        var limit: float = ((6.0 / (input_size + output_size)).sqrt()).real;

        this.weights = Tensor(input_size, output_size);
        var i: int = 0;
        while (i < input_size) {
            var j: int = 0;
            while (j < output_size) {
                this.weights.put(i, j, rand_float(0.0 - limit, limit));
                j = j + 1;
            };
            i = i + 1;
        };

        this.bias = Tensor(1, output_size);
        this.bias.zeros();

        this.mw = Tensor(input_size, output_size);
        this.mw.zeros();
        this.vw = Tensor(input_size, output_size);
        this.vw.zeros();
        this.mb = Tensor(1, output_size);
        this.mb.zeros();
        this.vb = Tensor(1, output_size);
        this.vb.zeros();
        this.t = 0;
    };

    function forward(input: Tensor) -> Tensor {
        this.last_input = input;
        this.has_input  = true;

        var out: Tensor = input.matmul(this.weights);
        mocha_tensor_add_bias(out.ptr, this.bias.ptr);

        if (this.activation == Activation.RELU)    { out.relu(); };
        if (this.activation == Activation.SIGMOID) { out.sigmoid(); };
        if (this.activation == Activation.TANH)    { out.tanh(); };
        if (this.activation == Activation.SOFTMAX) { out.softmax(); };

        this.last_output = out;
        return out;
    };

    function backward(dout: Tensor, lr: float) -> Tensor {
        var dact: Tensor = dout;
        var dact_is_new: bool = false;

        if (this.activation == Activation.RELU) {
            dact = Tensor(dout.nrows, dout.ncols);
            mocha_tensor_free(dact.ptr);
            dact.ptr = mocha_tensor_relu_grad(dout.ptr, this.last_output.ptr);
            dact_is_new = true;
        };
        if (this.activation == Activation.SIGMOID) {
            dact = Tensor(dout.nrows, dout.ncols);
            mocha_tensor_free(dact.ptr);
            dact.ptr = mocha_tensor_sigmoid_grad(dout.ptr, this.last_output.ptr);
            dact_is_new = true;
        };
        if (this.activation == Activation.TANH) {
            dact = Tensor(dout.nrows, dout.ncols);
            mocha_tensor_free(dact.ptr);
            dact.ptr = mocha_tensor_tanh_grad(dout.ptr, this.last_output.ptr);
            dact_is_new = true;
        };

        var input_t: Tensor = this.last_input.transpose();
        var dw: Tensor = input_t.matmul(dact);

        var db: Tensor = Tensor(1, this.output_size);
        mocha_tensor_free(db.ptr);
        db.ptr = mocha_tensor_bias_grad(dact.ptr);

        var weights_t: Tensor = this.weights.transpose();
        var din: Tensor = dact.matmul(weights_t);

        this.t = this.t + 1;
        var beta1t: float = fast_pow(0.9, this.t);
        var beta2t: float = fast_pow(0.999, this.t);

        mocha_adam_update(this.weights.ptr, this.mw.ptr, this.vw.ptr, dw.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.bias.ptr, this.mb.ptr, this.vb.ptr, db.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);

        input_t.dispose();
        dw.dispose();
        db.dispose();
        weights_t.dispose();
        if (dact_is_new) {
            dact.dispose();
        };

        return din;
    };

    function dispose() -> null {
        this.weights.dispose();
        this.bias.dispose();
        this.mw.dispose();
        this.vw.dispose();
        this.mb.dispose();
        this.vb.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Dense");
        neuron_db_write_meta(db, "input_size", str(this.input_size));
        neuron_db_write_meta(db, "output_size", str(this.output_size));
        neuron_db_write_meta(db, "activation", str(this.activation));
        neuron_db_write_meta(db, "t", str(this.t));
        neuron_save_tensor(db, "weights", this.weights);
        neuron_save_tensor(db, "bias", this.bias);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.input_size = neuron_db_read_meta(db, "input_size").toInt();
        this.output_size = neuron_db_read_meta(db, "output_size").toInt();
        this.activation = neuron_db_read_meta(db, "activation").toInt();
        this.t = neuron_db_read_meta(db, "t").toInt();
        this.weights = neuron_load_tensor(db, "weights");
        this.bias = neuron_load_tensor(db, "bias");
        sqlite3_close(db);
    };
};

// =============================================
// NETWORK CLASS
// =============================================

class Network {
    var layers: Dense[];

    function constructor() -> null {
        this.layers = [];
    };

    function add(layer: Dense) -> null {
        this.layers.push(layer);
    };

    function fit_step(input: Tensor, labels: Tensor, lr: float, loss: str) -> float {
        // forward pass
        var output: Tensor = this.predict(input);

        // compute loss
        var loss_val: float = 0.0;
        var dout: Tensor = Tensor(output.nrows, output.ncols);
        mocha_tensor_free(dout.ptr);

        if (loss == "mse") {
            loss_val = mocha_tensor_mse_loss(output.ptr, labels.ptr);
            dout.ptr = mocha_tensor_mse_grad(output.ptr, labels.ptr);
        };
        if (loss == "crossentropy") {
            loss_val = mocha_tensor_ce_loss(output.ptr, labels.ptr);
            dout.ptr = mocha_tensor_softmax_ce_grad(output.ptr, labels.ptr);
        };

        // backward pass — reverse through layers
        var i: int = this.layers.length - 1;
        var grad: Tensor = dout;
        while (i >= 0) {
            var prev_grad: Tensor = this.layers[i].backward(grad, lr);
            grad = prev_grad;
            i = i - 1;
        };

        output.dispose();
        dout.dispose();

        return loss_val;
    };

    function predict(input: Tensor) -> Tensor {
        var current: Tensor = input;
        var i: int = 0;
        while (i < this.layers.length) {
            var next: Tensor = this.layers[i].forward(current);
            current = next;
            i = i + 1;
        };
        return current;
    };

    function dispose() -> null {
        var i: int = 0;
        while (i < this.layers.length) {
            this.layers[i].dispose();
            i = i + 1;
        };
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "model_type", "Network");
        neuron_db_write_meta(db, "n_layers", str(this.layers.length));
        var i: int = 0;
        while (i < this.layers.length) {
            var prefix: str = "layer_" + str(i) + "_";
            neuron_db_write_meta(db, prefix + "input_size", str(this.layers[i].input_size));
            neuron_db_write_meta(db, prefix + "output_size", str(this.layers[i].output_size));
            neuron_db_write_meta(db, prefix + "activation", str(this.layers[i].activation));
            neuron_db_write_meta(db, prefix + "t", str(this.layers[i].t));
            neuron_save_tensor(db, prefix + "weights", this.layers[i].weights);
            neuron_save_tensor(db, prefix + "bias", this.layers[i].bias);
            i++;
        };
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        var n_layers: int = neuron_db_read_meta(db, "n_layers").toInt();
        this.layers = [];
        var i: int = 0;
        while (i < n_layers) {
            var prefix: str = "layer_" + str(i) + "_";
            var input_size: int = neuron_db_read_meta(db, prefix + "input_size").toInt();
            var output_size: int = neuron_db_read_meta(db, prefix + "output_size").toInt();
            var activation: int = neuron_db_read_meta(db, prefix + "activation").toInt();
            var layer: Dense = Dense(input_size, output_size, activation);
            layer.t = neuron_db_read_meta(db, prefix + "t").toInt();
            layer.weights = neuron_load_tensor(db, prefix + "weights");
            layer.bias = neuron_load_tensor(db, prefix + "bias");
            this.layers.push(layer);
            i++;
        };
        sqlite3_close(db);
    };
};

// =============================================
// GRU LAYER
// =============================================

class Gru {
    // Gated Recurrent Unit layer
    // @param input_size: size of input vector
    // @param hidden_size: size of hidden state
    var Wr: Tensor;
    var Wz: Tensor;
    var Wh: Tensor;
    var br: Tensor;
    var bz: Tensor;
    var bh: Tensor;
    var mWr: Tensor; var vWr: Tensor;
    var mWz: Tensor; var vWz: Tensor;
    var mWh: Tensor; var vWh: Tensor;
    var mbr: Tensor; var vbr: Tensor;
    var mbz: Tensor; var vbz: Tensor;
    var mbh: Tensor; var vbh: Tensor;
    var input_size:  int;
    var hidden_size: int;
    var t:           int;

    // cached values for backprop
    var last_x:    Tensor;
    var last_h:    Tensor;
    var last_r:    Tensor;
    var last_z:    Tensor;
    var last_cand: Tensor;
    var last_hx:   Tensor;
    var last_rhx:  Tensor;
    var has_input: bool;

    function constructor(input_size: int, hidden_size: int) -> null {
        this.input_size  = input_size;
        this.hidden_size = hidden_size;
        this.t           = 0;
        this.has_input   = false;

        var combined: int = input_size + hidden_size;
        var limit: float = ((6.0 / (combined + hidden_size)).sqrt()).real;

        // weight matrices: [input+hidden x hidden]
        this.Wr = Tensor(combined, hidden_size);
        c_print_err("Wr created: ptr=" + str(this.Wr.ptr) + " rows=" + str(this.Wr.nrows) + " cols=" + str(this.Wr.ncols) + "\n");
        this.Wz = Tensor(combined, hidden_size);
        this.Wh = Tensor(combined, hidden_size);

        // xavier init all weights
        var i: int = 0;
        while (i < combined) {
            var j: int = 0;
            while (j < hidden_size) {
                this.Wr.put(i, j, rand_float(0.0 - limit, limit));
                this.Wz.put(i, j, rand_float(0.0 - limit, limit));
                this.Wh.put(i, j, rand_float(0.0 - limit, limit));
                j = j + 1;
            };
            i = i + 1;
        };

        // biases: [1 x hidden]
        this.br = Tensor(1, hidden_size);
        this.bz = Tensor(1, hidden_size);
        this.bh = Tensor(1, hidden_size);
        this.br.zeros();
        this.bz.zeros();
        this.bh.zeros();

        // adam moments
        this.mWr = Tensor(combined, hidden_size); this.mWr.zeros();
        this.vWr = Tensor(combined, hidden_size); this.vWr.zeros();
        this.mWz = Tensor(combined, hidden_size); this.mWz.zeros();
        this.vWz = Tensor(combined, hidden_size); this.vWz.zeros();
        this.mWh = Tensor(combined, hidden_size); this.mWh.zeros();
        this.vWh = Tensor(combined, hidden_size); this.vWh.zeros();
        this.mbr = Tensor(1, hidden_size); this.mbr.zeros();
        this.vbr = Tensor(1, hidden_size); this.vbr.zeros();
        this.mbz = Tensor(1, hidden_size); this.mbz.zeros();
        this.vbz = Tensor(1, hidden_size); this.vbz.zeros();
        this.mbh = Tensor(1, hidden_size); this.mbh.zeros();
        this.vbh = Tensor(1, hidden_size); this.vbh.zeros();
    };

    // forward one timestep
    // @param x: input [batch x input_size]
    // @param h: hidden state [batch x hidden_size]
    // @return: new hidden state [batch x hidden_size]
    function forward(x: Tensor, h: Tensor) -> Tensor {
        c_print_err("Entered forward\n");
        // concat [h, x] → [batch x (hidden+input)]
        c_print_err("Before hx\n");
        var hx: Tensor = h.concat(x);
        c_print_err("After hx\n");

        // reset gate: r = sigmoid(hx @ Wr + br)
        c_print_err("Before r_pre\n");
        c_print_err("Before Wr.matmul\n");
        c_print_err("Wr.ptr = " + str(this.Wr.ptr) + "\n");
        c_print_err("Wr.rows = " + str(this.Wr.nrows) + "\n");
        c_print_err("Wr.cols = " + str(this.Wr.ncols) + "\n");
        c_print_err("hx.ptr = " + str(hx.ptr) + "\n");
        c_print_err("hx.rows = " + str(hx.nrows) + "\n");
        c_print_err("hx.cols = " + str(hx.ncols) + "\n");
        c_print_err("Wr before matmul: ptr=" + str(this.Wr.ptr) + " rows=" + str(this.Wr.nrows) + " cols=" + str(this.Wr.ncols) + "\n");
        var r_pre: Tensor = hx.matmul(this.Wr);
        c_print_err("After Wr.matmul\n");
        c_print_err("After r_pre\n");
        mocha_tensor_add_bias(r_pre.ptr, this.br.ptr);
        r_pre.sigmoid();

        // update gate: z = sigmoid(hx @ Wz + bz)
        c_print_err("Before z_pre\n");
        var z_pre: Tensor = hx.matmul(this.Wz);
        c_print_err("After z_pre\n");
        mocha_tensor_add_bias(z_pre.ptr, this.bz.ptr);
        z_pre.sigmoid();

        // candidate: h~ = tanh([r*h, x] @ Wh + bh)
        c_print_err("Before rh\n");
        var rh: Tensor = r_pre.mul(h);
        c_print_err("After rh\n");
        c_print_err("Before rhx\n");
        var rhx: Tensor = rh.concat(x);
        c_print_err("After rhx\n");
        c_print_err("Before cand\n");
        var cand: Tensor = rhx.matmul(this.Wh);
        c_print_err("After cand\n");
        mocha_tensor_add_bias(cand.ptr, this.bh.ptr);
        cand.tanh();

        // new hidden: h_new = (1-z)*h + z*h~
        c_print_err("Before one_minus_z_h\n");
        var one_minus_z_h: Tensor = z_pre.one_minus_mul(h);
        c_print_err("After one_minus_z_h\n");
        c_print_err("Before z_cand\n");
        var z_cand: Tensor = z_pre.mul(cand);
        c_print_err("After z_cand\n");
        c_print_err("Before h_new\n");
        var h_new: Tensor = one_minus_z_h.add(z_cand);
        c_print_err("After h_new\n");

        // cache for backprop — CLONE so caller can dispose originals safely
        this.last_x    = x.clone_tensor();
        this.last_h    = h.clone_tensor();
        this.last_r    = r_pre.clone_tensor();
        this.last_z    = z_pre.clone_tensor();
        this.last_cand = cand.clone_tensor();
        this.last_hx   = hx.clone_tensor();
        this.last_rhx  = rhx.clone_tensor();
        this.has_input = true;

        // cleanup intermediates not needed after caching
        rh.dispose();
        one_minus_z_h.dispose();
        z_cand.dispose();

        return h_new;
    };

    // backward one timestep
    // @param dh_new: gradient of loss w.r.t h_new [batch x hidden_size]
    // @param lr: learning rate
    // @return: gradient w.r.t input x [batch x input_size]
    function backward(dh_new: Tensor, lr: float) -> Tensor {
        this.t = this.t + 1;
        var beta1t: float = fast_pow(0.9, this.t);
        var beta2t: float = fast_pow(0.999, this.t);

        // dh_new splits into two paths: (1-z)*h and z*h~
        // d((1-z)*h)/dz = -h,  d(z*h~)/dz = h~
        // dz = dh_new * (h~ - h)
        var cand_minus_h: Tensor = this.last_cand.add(this.last_h);
        cand_minus_h.scale(0.0 - 1.0);
        var h_neg: Tensor = this.last_h.clone_tensor();
        h_neg.scale(0.0 - 1.0);
        var cand_sub_h: Tensor = this.last_cand.add(h_neg);
        var dz_raw: Tensor = dh_new.mul(cand_sub_h);
        cand_minus_h.dispose();
        h_neg.dispose();
        cand_sub_h.dispose();

        // sigmoid grad for z
        var dz: Tensor = Tensor(dz_raw.nrows, dz_raw.ncols);
        dz.ptr = mocha_tensor_sigmoid_grad(dz_raw.ptr, this.last_z.ptr);
        dz_raw.dispose();

        // dcand = dh_new * z
        var dcand_raw: Tensor = dh_new.mul(this.last_z);

        // tanh grad for candidate
        var dcand: Tensor = Tensor(dcand_raw.nrows, dcand_raw.ncols);
        dcand.ptr = mocha_tensor_tanh_grad(dcand_raw.ptr, this.last_cand.ptr);
        dcand_raw.dispose();

        // gradients for Wh, bh
        var Wh_t: Tensor = this.Wh.transpose();
        var drhx: Tensor = dcand.matmul(Wh_t);
        var dWh: Tensor = this.last_rhx.transpose().matmul(dcand);
        var dbh: Tensor = Tensor(1, this.hidden_size);
        mocha_tensor_free(dbh.ptr);
        dbh.ptr = mocha_tensor_bias_grad(dcand.ptr);
        Wh_t.dispose();
        dcand.dispose();

        // split drhx into dr_h and dx_from_cand
        var dr_h: Tensor = Tensor(drhx.nrows, this.hidden_size);
        mocha_tensor_free(dr_h.ptr);
        dr_h.ptr = mocha_tensor_split_a(drhx.ptr, this.hidden_size);
        var dx_cand: Tensor = Tensor(drhx.nrows, this.input_size);
        mocha_tensor_free(dx_cand.ptr);
        dx_cand.ptr = mocha_tensor_split_b(drhx.ptr, this.hidden_size);
        drhx.dispose();

        // dr = dr_h * h (element-wise, then sigmoid grad)
        var dr_raw: Tensor = dr_h.mul(this.last_h);
        dr_h.dispose();
        var dr: Tensor = Tensor(dr_raw.nrows, dr_raw.ncols);
        mocha_tensor_free(dr.ptr);
        dr.ptr = mocha_tensor_sigmoid_grad(dr_raw.ptr, this.last_r.ptr);
        dr_raw.dispose();

        // gradients for Wr, Wz, br, bz
        var Wr_t: Tensor = this.Wr.transpose();
        var Wz_t: Tensor = this.Wz.transpose();
        var dhx_r: Tensor = dr.matmul(Wr_t);
        var dhx_z: Tensor = dz.matmul(Wz_t);
        var dWr: Tensor = this.last_hx.transpose().matmul(dr);
        var dWz: Tensor = this.last_hx.transpose().matmul(dz);
        var dbr: Tensor = Tensor(1, this.hidden_size);
        mocha_tensor_free(dbr.ptr);
        dbr.ptr = mocha_tensor_bias_grad(dr.ptr);
        var dbz: Tensor = Tensor(1, this.hidden_size);
        mocha_tensor_free(dbz.ptr);
        dbz.ptr = mocha_tensor_bias_grad(dz.ptr);
        Wr_t.dispose();
        Wz_t.dispose();
        dr.dispose();
        dz.dispose();

        // total gradient w.r.t hx = dhx_r + dhx_z
        var dhx: Tensor = dhx_r.add(dhx_z);
        dhx_r.dispose();
        dhx_z.dispose();

        // split dhx into dh_prev and dx_from_gates
        var dh_prev: Tensor = Tensor(dhx.nrows, this.hidden_size);
        mocha_tensor_free(dh_prev.ptr);
        dh_prev.ptr = mocha_tensor_split_a(dhx.ptr, this.hidden_size);
        var dx_gates: Tensor = Tensor(dhx.nrows, this.input_size);
        mocha_tensor_free(dx_gates.ptr);
        dx_gates.ptr = mocha_tensor_split_b(dhx.ptr, this.hidden_size);
        dhx.dispose();

        // total dx = dx_gates + dx_cand
        var dx: Tensor = dx_gates.add(dx_cand);
        dx_gates.dispose();
        dx_cand.dispose();

        // also: dh_new flows back through (1-z)*h path
        var dh_direct: Tensor = dh_new.one_minus_mul(this.last_z);
        var dh_prev_total: Tensor = dh_prev.add(dh_direct);
        dh_prev.dispose();
        dh_direct.dispose();

        // adam updates for all 6 weight matrices
        mocha_adam_update(this.Wr.ptr, this.mWr.ptr, this.vWr.ptr, dWr.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.Wz.ptr, this.mWz.ptr, this.vWz.ptr, dWz.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.Wh.ptr, this.mWh.ptr, this.vWh.ptr, dWh.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.br.ptr, this.mbr.ptr, this.vbr.ptr, dbr.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.bz.ptr, this.mbz.ptr, this.vbz.ptr, dbz.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.bh.ptr, this.mbh.ptr, this.vbh.ptr, dbh.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);

        // cleanup
        c_print_err("Disposing dWr\n"); dWr.dispose();
        c_print_err("Disposing dWz\n"); dWz.dispose();
        c_print_err("Disposing dWh\n"); dWh.dispose();
        c_print_err("Disposing dbr\n"); dbr.dispose();
        c_print_err("Disposing dbz\n"); dbz.dispose();
        c_print_err("Disposing dbh\n"); dbh.dispose();
        c_print_err("Disposing dh_prev_total\n"); dh_prev_total.dispose();

        // dispose cached tensors now that backward is done
        c_print_err("Disposing last_x\n"); this.last_x.dispose();
        c_print_err("Disposing last_h\n"); this.last_h.dispose();
        c_print_err("Disposing last_r\n"); this.last_r.dispose();
        c_print_err("Disposing last_z\n"); this.last_z.dispose();
        c_print_err("Disposing last_cand\n"); this.last_cand.dispose();
        c_print_err("Disposing last_hx\n"); this.last_hx.dispose();
        c_print_err("Disposing last_rhx\n"); this.last_rhx.dispose();
        this.has_input = false;

        c_print_err("Returning dx\n");
        return dx;
    };

    function dispose() -> null {
        c_print_err("Disposing Wr\n"); this.Wr.dispose();
        c_print_err("Disposing Wz\n"); this.Wz.dispose();
        c_print_err("Disposing Wh\n"); this.Wh.dispose();
        c_print_err("Disposing br\n"); this.br.dispose();
        c_print_err("Disposing bz\n"); this.bz.dispose();
        c_print_err("Disposing bh\n"); this.bh.dispose();
        c_print_err("Disposing mWr\n"); this.mWr.dispose();
        c_print_err("Disposing vWr\n"); this.vWr.dispose();
        c_print_err("Disposing mWz\n"); this.mWz.dispose();
        c_print_err("Disposing vWz\n"); this.vWz.dispose();
        c_print_err("Disposing mWh\n"); this.mWh.dispose();
        c_print_err("Disposing vWh\n"); this.vWh.dispose();
        c_print_err("Disposing mbr\n"); this.mbr.dispose();
        c_print_err("Disposing vbr\n"); this.vbr.dispose();
        c_print_err("Disposing mbz\n"); this.mbz.dispose();
        c_print_err("Disposing vbz\n"); this.vbz.dispose();
        c_print_err("Disposing mbh\n"); this.mbh.dispose();
        c_print_err("Disposing vbh\n"); this.vbh.dispose();
        c_print_err("Finished dispose\n");
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Gru");
        neuron_db_write_meta(db, "input_size", str(this.input_size));
        neuron_db_write_meta(db, "hidden_size", str(this.hidden_size));
        neuron_db_write_meta(db, "t", str(this.t));
        neuron_save_tensor(db, "Wr", this.Wr);
        neuron_save_tensor(db, "Wz", this.Wz);
        neuron_save_tensor(db, "Wh", this.Wh);
        neuron_save_tensor(db, "br", this.br);
        neuron_save_tensor(db, "bz", this.bz);
        neuron_save_tensor(db, "bh", this.bh);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.input_size = neuron_db_read_meta(db, "input_size").toInt();
        this.hidden_size = neuron_db_read_meta(db, "hidden_size").toInt();
        this.t = neuron_db_read_meta(db, "t").toInt();
        this.Wr = neuron_load_tensor(db, "Wr");
        this.Wz = neuron_load_tensor(db, "Wz");
        this.Wh = neuron_load_tensor(db, "Wh");
        this.br = neuron_load_tensor(db, "br");
        this.bz = neuron_load_tensor(db, "bz");
        this.bh = neuron_load_tensor(db, "bh");
        sqlite3_close(db);
    };
};

class BiGru {
    var fwd:         Gru;
    var bwd:         Gru;
    var input_size:  int;
    var hidden_size: int;

    function constructor(input_size: int, hidden_size: int) -> null {
        this.input_size  = input_size;
        this.hidden_size = hidden_size;
        this.fwd = Gru(input_size, hidden_size);
        this.bwd = Gru(input_size, hidden_size);
    };

    ~~ Forward pass over a full sequence
    ~~ @param xs: array of input tensors [seq_len x (1 x input_size)]
    ~~ @return: array of output tensors [seq_len x (1 x hidden_size*2)]
    function forward(xs: Tensor[]) -> Tensor[] {
        var seq_len: int = xs.length;
        var outputs: Tensor[] = [];

        // forward pass left to right
        var fwd_states: Tensor[] = [];
        var h_fwd: Tensor = Tensor(1, this.hidden_size);
        h_fwd.zeros();
        var i: int = 0;
        while (i < seq_len) {
            var h_new: Tensor = this.fwd.forward(xs[i], h_fwd);
            h_fwd.dispose();
            h_fwd = h_new;
            fwd_states.push(h_fwd.clone_tensor());
            i = i + 1;
        };
        h_fwd.dispose();

        // backward pass right to left
        var bwd_states: Tensor[] = [];
        var h_bwd: Tensor = Tensor(1, this.hidden_size);
        h_bwd.zeros();
        var j: int = seq_len - 1;
        while (j >= 0) {
            var h_new: Tensor = this.bwd.forward(xs[j], h_bwd);
            h_bwd.dispose();
            h_bwd = h_new;
            bwd_states.push(h_bwd.clone_tensor());
            j = j - 1;
        };
        h_bwd.dispose();

        // bwd_states is in reverse order — concat at each timestep
        // fwd_states[i] + bwd_states[seq_len-1-i]
        var k: int = 0;
        while (k < seq_len) {
            var combined: Tensor = fwd_states[k].concat(bwd_states[seq_len - 1 - k]);
            outputs.push(combined);
            fwd_states[k].dispose();
            bwd_states[seq_len - 1 - k].dispose();
            k = k + 1;
        };

        return outputs;
    };

    function dispose() -> null {
        this.fwd.dispose();
        this.bwd.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "BiGru");
        neuron_db_write_meta(db, "input_size", str(this.input_size));
        neuron_db_write_meta(db, "hidden_size", str(this.hidden_size));
        neuron_db_write_meta(db, "fwd_t", str(this.fwd.t));
        neuron_db_write_meta(db, "bwd_t", str(this.bwd.t));
        neuron_save_tensor(db, "fwd_Wr", this.fwd.Wr);
        neuron_save_tensor(db, "fwd_Wz", this.fwd.Wz);
        neuron_save_tensor(db, "fwd_Wh", this.fwd.Wh);
        neuron_save_tensor(db, "fwd_br", this.fwd.br);
        neuron_save_tensor(db, "fwd_bz", this.fwd.bz);
        neuron_save_tensor(db, "fwd_bh", this.fwd.bh);
        neuron_save_tensor(db, "bwd_Wr", this.bwd.Wr);
        neuron_save_tensor(db, "bwd_Wz", this.bwd.Wz);
        neuron_save_tensor(db, "bwd_Wh", this.bwd.Wh);
        neuron_save_tensor(db, "bwd_br", this.bwd.br);
        neuron_save_tensor(db, "bwd_bz", this.bwd.bz);
        neuron_save_tensor(db, "bwd_bh", this.bwd.bh);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.input_size = neuron_db_read_meta(db, "input_size").toInt();
        this.hidden_size = neuron_db_read_meta(db, "hidden_size").toInt();
        this.fwd = Gru(this.input_size, this.hidden_size);
        this.bwd = Gru(this.input_size, this.hidden_size);
        this.fwd.t = neuron_db_read_meta(db, "fwd_t").toInt();
        this.bwd.t = neuron_db_read_meta(db, "bwd_t").toInt();
        this.fwd.Wr = neuron_load_tensor(db, "fwd_Wr");
        this.fwd.Wz = neuron_load_tensor(db, "fwd_Wz");
        this.fwd.Wh = neuron_load_tensor(db, "fwd_Wh");
        this.fwd.br = neuron_load_tensor(db, "fwd_br");
        this.fwd.bz = neuron_load_tensor(db, "fwd_bz");
        this.fwd.bh = neuron_load_tensor(db, "fwd_bh");
        this.bwd.Wr = neuron_load_tensor(db, "bwd_Wr");
        this.bwd.Wz = neuron_load_tensor(db, "bwd_Wz");
        this.bwd.Wh = neuron_load_tensor(db, "bwd_Wh");
        this.bwd.br = neuron_load_tensor(db, "bwd_br");
        this.bwd.bz = neuron_load_tensor(db, "bwd_bz");
        this.bwd.bh = neuron_load_tensor(db, "bwd_bh");
        sqlite3_close(db);
    };
};

// =============================================
// HOPFIELD NETWORK
// =============================================

class Hopfield {
    var weights:  Tensor;
    var size:     int;
    var n_stored: int;

    ~~ Inits state
    function constructor(size: int) -> null {
        this.size     = size;
        this.n_stored = 0;
        this.weights  = Tensor(size, size);
        this.weights.zeros();
    };

    ~~ Store a pattern in the network
    ~~ @param pattern: [1 x size] tensor with values +1 or -1
    function store(pattern: Tensor) -> null {
        // outer product of pattern with itself
        var op: Tensor = pattern.outer(pattern);
        // w += op
        this.weights.add_inplace(op);
        // zero diagonal
        this.weights.zero_diagonal();
        this.n_stored = this.n_stored + 1;
        op.dispose();
    };

    ~~ Normalize weights by number of stored patterns
    function normalize() -> null {
        mocha_tensor_scale(this.weights.ptr, 1.0 / this.n_stored);
    };

    ~~ Recall a pattern from a noisy/partial input
    ~~ @param input: [1 x size] tensor with values +1 or -1
    ~~ @param max_iter: maximum iterations before giving up
    ~~ @return: recalled pattern [1 x size]
    function recall(input: Tensor, max_iter: int) -> Tensor {
        var state: Tensor = input.clone_tensor();
        var iter: int = 0;

        while (iter < max_iter) {
            // new_state = sign(state @ w)
            var pre: Tensor = state.matmul(this.weights);
            var new_state: Tensor = pre.sign();
            pre.dispose();

            // check convergence
            var converged: bool = state.equals(new_state);
            state.dispose();
            state = new_state;

            if (converged) {
                iter = max_iter; // break
            };
            iter = iter + 1;
        };

        return state;
    };

    function dispose() -> null {
        this.weights.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Hopfield");
        neuron_db_write_meta(db, "size", str(this.size));
        neuron_db_write_meta(db, "n_stored", str(this.n_stored));
        neuron_save_tensor(db, "weights", this.weights);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.size = neuron_db_read_meta(db, "size").toInt();
        this.n_stored = neuron_db_read_meta(db, "n_stored").toInt();
        this.weights = neuron_load_tensor(db, "weights");
        sqlite3_close(db);
    };
};

// =============================================
// SELF ATTENTION (BERT-style, bidirectional)
// =============================================

class Attention {
    var Wq:      Tensor;
    var Wk:      Tensor;
    var Wv:      Tensor;
    var Wo:      Tensor;
    var mWq: Tensor; var vWq: Tensor;
    var mWk: Tensor; var vWk: Tensor;
    var mWv: Tensor; var vWv: Tensor;
    var mWo: Tensor; var vWo: Tensor;
    var d_model:  int;
    var d_k:      int;
    var scale:    float;
    var t:        int;

    // cached for backprop
    var last_x:       Tensor;
    var last_q:       Tensor;
    var last_k:       Tensor;
    var last_v:       Tensor;
    var last_scores:  Tensor;
    var last_weights: Tensor;

    function constructor(d_model: int, d_k: int) -> null {
        this.d_model = d_model;
        this.d_k     = d_k;
        this.scale   = ((1.0 / d_k).sqrt()).real;
        this.t       = 0;

        var limit: float = ((6.0 / (d_model + d_k)).sqrt()).real;

        this.Wq = Tensor(d_model, d_k);
        this.Wk = Tensor(d_model, d_k);
        this.Wv = Tensor(d_model, d_k);
        this.Wo = Tensor(d_k, d_model);

        var i: int = 0;
        while (i < d_model) {
            var j: int = 0;
            while (j < d_k) {
                this.Wq.put(i, j, rand_float(0.0 - limit, limit));
                this.Wk.put(i, j, rand_float(0.0 - limit, limit));
                this.Wv.put(i, j, rand_float(0.0 - limit, limit));
                j = j + 1;
            };
            i = i + 1;
        };

        var i2: int = 0;
        while (i2 < d_k) {
            var j2: int = 0;
            while (j2 < d_model) {
                this.Wo.put(i2, j2, rand_float(0.0 - limit, limit));
                j2 = j2 + 1;
            };
            i2 = i2 + 1;
        };

        this.mWq = Tensor(d_model, d_k); this.mWq.zeros();
        this.vWq = Tensor(d_model, d_k); this.vWq.zeros();
        this.mWk = Tensor(d_model, d_k); this.mWk.zeros();
        this.vWk = Tensor(d_model, d_k); this.vWk.zeros();
        this.mWv = Tensor(d_model, d_k); this.mWv.zeros();
        this.vWv = Tensor(d_model, d_k); this.vWv.zeros();
        this.mWo = Tensor(d_k, d_model); this.mWo.zeros();
        this.vWo = Tensor(d_k, d_model); this.vWo.zeros();
    };

    ~~ Forward pass — bidirectional self attention
    ~~ @param x: input sequence [seq_len x d_model]
    ~~ @return: output [seq_len x d_model]
    function forward(x: Tensor) -> Tensor {
        // Q = x @ Wq
        var q: Tensor = x.matmul(this.Wq);
        // K = x @ Wk
        var k: Tensor = x.matmul(this.Wk);
        // V = x @ Wv
        var v: Tensor = x.matmul(this.Wv);

        // scores = Q @ K^T / sqrt(d_k)
        var k_t: Tensor = k.transpose();
        var scores: Tensor = q.matmul(k_t);
        k_t.dispose();
        scores.scale(this.scale);

        // weights = softmax(scores)  [seq x seq]
        var weights: Tensor = scores.clone_tensor();
        weights.softmax();

        // context = weights @ V  [seq x d_k]
        var context: Tensor = weights.matmul(v);

        // output = context @ Wo  [seq x d_model]
        var output: Tensor = context.matmul(this.Wo);
        context.dispose();

        // cache for backprop
        this.last_x       = x;
        this.last_q       = q;
        this.last_k       = k;
        this.last_v       = v;
        this.last_scores  = scores;
        this.last_weights = weights;

        return output;
    };

    ~~ Backward pass
    ~~ @param dout: gradient [seq_len x d_model]
    ~~ @param lr: learning rate
    ~~ @return: gradient w.r.t input x [seq_len x d_model]
    function backward(dout: Tensor, lr: float) -> Tensor {
        this.t = this.t + 1;
        var beta1t: float = fast_pow(0.9, this.t);
        var beta2t: float = fast_pow(0.999, this.t);

        // dWo = context^T @ dout
        var context: Tensor = this.last_weights.matmul(this.last_v);
        var dWo: Tensor = context.transpose().matmul(dout);
        context.dispose();

        // dcontext = dout @ Wo^T
        var Wo_t: Tensor = this.Wo.transpose();
        var dcontext: Tensor = dout.matmul(Wo_t);
        Wo_t.dispose();

        // dweights = dcontext @ V^T
        var v_t: Tensor = this.last_v.transpose();
        var dweights: Tensor = dcontext.matmul(v_t);
        v_t.dispose();

        // dV = weights^T @ dcontext
        var weights_t: Tensor = this.last_weights.transpose();
        var dv: Tensor = weights_t.matmul(dcontext);
        weights_t.dispose();
        dcontext.dispose();

        // softmax backward: dscores = softmax_grad(dweights, weights)
        var dscores: Tensor = Tensor(dweights.nrows, dweights.ncols);
        mocha_tensor_free(dscores.ptr);
        dscores.ptr = mocha_tensor_sigmoid_grad(dweights.ptr, this.last_weights.ptr);
        dweights.dispose();

        // scale gradient
        dscores.scale(this.scale);

        // dQ = dscores @ K
        var dq: Tensor = dscores.matmul(this.last_k);

        // dK = dscores^T @ Q
        var dscores_t: Tensor = dscores.transpose();
        var dk: Tensor = dscores_t.matmul(this.last_q);
        dscores_t.dispose();
        dscores.dispose();

        // dWq = x^T @ dq
        var x_t: Tensor = this.last_x.transpose();
        var dWq: Tensor = x_t.matmul(dq);
        var dWk: Tensor = x_t.matmul(dk);
        var dWv: Tensor = x_t.matmul(dv);
        x_t.dispose();

        // dx = dq @ Wq^T + dk @ Wk^T + dv @ Wv^T
        var Wq_t: Tensor = this.Wq.transpose();
        var Wk_t: Tensor = this.Wk.transpose();
        var Wv_t: Tensor = this.Wv.transpose();
        var dx1: Tensor = dq.matmul(Wq_t);
        var dx2: Tensor = dk.matmul(Wk_t);
        var dx3: Tensor = dv.matmul(Wv_t);
        Wq_t.dispose(); Wk_t.dispose(); Wv_t.dispose();
        dq.dispose(); dk.dispose(); dv.dispose();

        var dx12: Tensor = dx1.add(dx2);
        dx1.dispose(); dx2.dispose();
        var dx: Tensor = dx12.add(dx3);
        dx12.dispose(); dx3.dispose();

        // adam updates
        mocha_adam_update(this.Wq.ptr, this.mWq.ptr, this.vWq.ptr, dWq.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.Wk.ptr, this.mWk.ptr, this.vWk.ptr, dWk.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.Wv.ptr, this.mWv.ptr, this.vWv.ptr, dWv.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.Wo.ptr, this.mWo.ptr, this.vWo.ptr, dWo.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);

        dWq.dispose(); dWk.dispose(); dWv.dispose(); dWo.dispose();

        return dx;
    };

    function dispose() -> null {
        this.Wq.dispose(); this.Wk.dispose();
        this.Wv.dispose(); this.Wo.dispose();
        this.mWq.dispose(); this.vWq.dispose();
        this.mWk.dispose(); this.vWk.dispose();
        this.mWv.dispose(); this.vWv.dispose();
        this.mWo.dispose(); this.vWo.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Attention");
        neuron_db_write_meta(db, "d_model", str(this.d_model));
        neuron_db_write_meta(db, "d_k", str(this.d_k));
        neuron_db_write_meta(db, "scale", str(this.scale));
        neuron_db_write_meta(db, "t", str(this.t));
        neuron_save_tensor(db, "Wq", this.Wq);
        neuron_save_tensor(db, "Wk", this.Wk);
        neuron_save_tensor(db, "Wv", this.Wv);
        neuron_save_tensor(db, "Wo", this.Wo);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.d_model = neuron_db_read_meta(db, "d_model").toInt();
        this.d_k = neuron_db_read_meta(db, "d_k").toInt();
        this.scale = neuron_db_read_meta(db, "scale").toFloat();
        this.t = neuron_db_read_meta(db, "t").toInt();
        this.Wq = neuron_load_tensor(db, "Wq");
        this.Wk = neuron_load_tensor(db, "Wk");
        this.Wv = neuron_load_tensor(db, "Wv");
        this.Wo = neuron_load_tensor(db, "Wo");
        sqlite3_close(db);
    };
};

// =============================================
// LAYER NORMALIZATION
// =============================================

class LayerNorm {
    var gamma:  Tensor;
    var beta:   Tensor;
    var mgamma: Tensor; var vgamma: Tensor;
    var mbeta:  Tensor; var vbeta:  Tensor;
    var size:   int;
    var t:      int;
    var last_x: Tensor;

    function constructor(size: int) -> null {
        this.size = size;
        this.t    = 0;

        this.gamma = Tensor(1, size);
        this.beta  = Tensor(1, size);
        this.gamma.ones();
        this.beta.zeros();

        this.mgamma = Tensor(1, size); this.mgamma.zeros();
        this.vgamma = Tensor(1, size); this.vgamma.zeros();
        this.mbeta  = Tensor(1, size); this.mbeta.zeros();
        this.vbeta  = Tensor(1, size); this.vbeta.zeros();
    };

    function forward(x: Tensor) -> Tensor {
        this.last_x = x;
        var out: Tensor = Tensor(x.nrows, x.ncols);
        mocha_tensor_free(out.ptr);
        out.ptr = mocha_layer_norm(x.ptr, this.gamma.ptr, this.beta.ptr, 0.000001);
        return out;
    };

    function backward(dout: Tensor, lr: float) -> Tensor {
        this.t = this.t + 1;
        var beta1t: float = fast_pow(0.9, this.t);
        var beta2t: float = fast_pow(0.999, this.t);

        var dx:     Tensor = Tensor(dout.nrows, dout.ncols);
        var dgamma: Tensor = Tensor(1, this.size);
        var dbeta:  Tensor = Tensor(1, this.size);
        dx.zeros(); dgamma.zeros(); dbeta.zeros();

        mocha_layer_norm_grad(dout.ptr, this.last_x.ptr, this.gamma.ptr,
                              dx.ptr, dgamma.ptr, dbeta.ptr, 0.000001);

        mocha_adam_update(this.gamma.ptr, this.mgamma.ptr, this.vgamma.ptr, dgamma.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);
        mocha_adam_update(this.beta.ptr, this.mbeta.ptr, this.vbeta.ptr, dbeta.ptr,
            lr, 0.9, 0.999, 0.00000001, beta1t, beta2t);

        dgamma.dispose();
        dbeta.dispose();

        return dx;
    };

    function dispose() -> null {
        this.gamma.dispose(); this.beta.dispose();
        this.mgamma.dispose(); this.vgamma.dispose();
        this.mbeta.dispose();  this.vbeta.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "LayerNorm");
        neuron_db_write_meta(db, "size", str(this.size));
        neuron_db_write_meta(db, "t", str(this.t));
        neuron_save_tensor(db, "gamma", this.gamma);
        neuron_save_tensor(db, "beta", this.beta);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.size = neuron_db_read_meta(db, "size").toInt();
        this.t = neuron_db_read_meta(db, "t").toInt();
        this.gamma = neuron_load_tensor(db, "gamma");
        this.beta = neuron_load_tensor(db, "beta");
        sqlite3_close(db);
    };
};

// =============================================
// BERT LAYER
// =============================================
// x → Attention → Add & Norm → FFN → Add & Norm → output
// FFN = Dense(d_model, d_ff, relu) → Dense(d_ff, d_model, none)

class BertLayer {
    var attn:   Attention;
    var norm1:  LayerNorm;
    var ffn1:   Dense;
    var ffn2:   Dense;
    var norm2:  LayerNorm;
    var d_model: int;

    function constructor(d_model: int, d_k: int, d_ff: int) -> null {
        this.d_model = d_model;
        this.attn  = Attention(d_model, d_k);
        this.norm1 = LayerNorm(d_model);
        this.ffn1  = Dense(d_model, d_ff, Activation.RELU);
        this.ffn2  = Dense(d_ff, d_model, Activation.NONE);
        this.norm2 = LayerNorm(d_model);
    };

    ~~ Forward pass — one BERT layer
    ~~ @param x: input [seq_len x d_model]
    ~~ @return: output [seq_len x d_model]
    function forward(x: Tensor) -> Tensor {
        // attn caches x as last_x — do NOT dispose x here, caller owns it
        var attn_out: Tensor = this.attn.forward(x);

        // res1 = x + attn_out
        var res1: Tensor = x.add(attn_out);
        attn_out.dispose();

        // norm1 caches res1 as last_x — do NOT dispose res1
        var norm1_out: Tensor = this.norm1.forward(res1);
        // res1 kept alive — norm1 cached it

        // ffn1 caches norm1_out as last_input — do NOT dispose norm1_out
        var ffn1_out: Tensor = this.ffn1.forward(norm1_out);
        // norm1_out kept alive — ffn1 cached it

        // ffn2 caches ffn1_out as last_input — do NOT dispose ffn1_out
        var ffn2_out: Tensor = this.ffn2.forward(ffn1_out);
        // ffn1_out kept alive — ffn2 cached it

        // res2 = norm1_out + ffn2_out
        var res2: Tensor = norm1_out.add(ffn2_out);
        ffn2_out.dispose();

        // norm2 caches res2 as last_x — do NOT dispose res2
        var out: Tensor = this.norm2.forward(res2);
        // res2 kept alive — norm2 cached it

        return out;
    };

    ~~ Backward pass
    ~~ @param dout: gradient [seq_len x d_model]
    ~~ @param lr: learning rate
    ~~ @return: gradient w.r.t input x
    function backward(dout: Tensor, lr: float) -> Tensor {
        // backward through norm2
        var dres2: Tensor = this.norm2.backward(dout, lr);

        // backward through ffn2
        var dffn2: Tensor = this.ffn2.backward(dres2, lr);

        // backward through ffn1
        var dffn1: Tensor = this.ffn1.backward(dffn2, lr);
        dffn2.dispose();

        // residual: grad splits — dffn1 goes to norm1_out path
        var dnorm1: Tensor = dffn1.add(dres2);
        dffn1.dispose();
        dres2.dispose();

        // backward through norm1
        var dres1: Tensor = this.norm1.backward(dnorm1, lr);
        dnorm1.dispose();

        // backward through attention
        var dattn: Tensor = this.attn.backward(dres1, lr);

        // residual: dx = dattn + dres1
        var dx: Tensor = dattn.add(dres1);
        dattn.dispose();
        dres1.dispose();

        return dx;
    };

    function dispose() -> null {
        this.attn.dispose();
        this.norm1.dispose();
        this.ffn1.dispose();
        this.ffn2.dispose();
        this.norm2.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "BertLayer");
        neuron_db_write_meta(db, "d_model", str(this.d_model));
        neuron_db_write_meta(db, "attn_d_k", str(this.attn.d_k));
        neuron_db_write_meta(db, "attn_scale", str(this.attn.scale));
        neuron_db_write_meta(db, "attn_t", str(this.attn.t));
        neuron_save_tensor(db, "attn_Wq", this.attn.Wq);
        neuron_save_tensor(db, "attn_Wk", this.attn.Wk);
        neuron_save_tensor(db, "attn_Wv", this.attn.Wv);
        neuron_save_tensor(db, "attn_Wo", this.attn.Wo);
        neuron_db_write_meta(db, "norm1_size", str(this.norm1.size));
        neuron_db_write_meta(db, "norm1_t", str(this.norm1.t));
        neuron_save_tensor(db, "norm1_gamma", this.norm1.gamma);
        neuron_save_tensor(db, "norm1_beta", this.norm1.beta);
        neuron_db_write_meta(db, "ffn1_input_size", str(this.ffn1.input_size));
        neuron_db_write_meta(db, "ffn1_output_size", str(this.ffn1.output_size));
        neuron_db_write_meta(db, "ffn1_activation", str(this.ffn1.activation));
        neuron_db_write_meta(db, "ffn1_t", str(this.ffn1.t));
        neuron_save_tensor(db, "ffn1_weights", this.ffn1.weights);
        neuron_save_tensor(db, "ffn1_bias", this.ffn1.bias);
        neuron_db_write_meta(db, "ffn2_input_size", str(this.ffn2.input_size));
        neuron_db_write_meta(db, "ffn2_output_size", str(this.ffn2.output_size));
        neuron_db_write_meta(db, "ffn2_activation", str(this.ffn2.activation));
        neuron_db_write_meta(db, "ffn2_t", str(this.ffn2.t));
        neuron_save_tensor(db, "ffn2_weights", this.ffn2.weights);
        neuron_save_tensor(db, "ffn2_bias", this.ffn2.bias);
        neuron_db_write_meta(db, "norm2_size", str(this.norm2.size));
        neuron_db_write_meta(db, "norm2_t", str(this.norm2.t));
        neuron_save_tensor(db, "norm2_gamma", this.norm2.gamma);
        neuron_save_tensor(db, "norm2_beta", this.norm2.beta);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.d_model = neuron_db_read_meta(db, "d_model").toInt();
        var attn_d_k: int = neuron_db_read_meta(db, "attn_d_k").toInt();
        this.attn = Attention(this.d_model, attn_d_k);
        this.attn.scale = neuron_db_read_meta(db, "attn_scale").toFloat();
        this.attn.t = neuron_db_read_meta(db, "attn_t").toInt();
        this.attn.Wq = neuron_load_tensor(db, "attn_Wq");
        this.attn.Wk = neuron_load_tensor(db, "attn_Wk");
        this.attn.Wv = neuron_load_tensor(db, "attn_Wv");
        this.attn.Wo = neuron_load_tensor(db, "attn_Wo");
        var norm1_size: int = neuron_db_read_meta(db, "norm1_size").toInt();
        this.norm1 = LayerNorm(norm1_size);
        this.norm1.t = neuron_db_read_meta(db, "norm1_t").toInt();
        this.norm1.gamma = neuron_load_tensor(db, "norm1_gamma");
        this.norm1.beta = neuron_load_tensor(db, "norm1_beta");
        var ffn1_in: int = neuron_db_read_meta(db, "ffn1_input_size").toInt();
        var ffn1_out: int = neuron_db_read_meta(db, "ffn1_output_size").toInt();
        var ffn1_act: int = neuron_db_read_meta(db, "ffn1_activation").toInt();
        this.ffn1 = Dense(ffn1_in, ffn1_out, ffn1_act);
        this.ffn1.t = neuron_db_read_meta(db, "ffn1_t").toInt();
        this.ffn1.weights = neuron_load_tensor(db, "ffn1_weights");
        this.ffn1.bias = neuron_load_tensor(db, "ffn1_bias");
        var ffn2_in: int = neuron_db_read_meta(db, "ffn2_input_size").toInt();
        var ffn2_out: int = neuron_db_read_meta(db, "ffn2_output_size").toInt();
        var ffn2_act: int = neuron_db_read_meta(db, "ffn2_activation").toInt();
        this.ffn2 = Dense(ffn2_in, ffn2_out, ffn2_act);
        this.ffn2.t = neuron_db_read_meta(db, "ffn2_t").toInt();
        this.ffn2.weights = neuron_load_tensor(db, "ffn2_weights");
        this.ffn2.bias = neuron_load_tensor(db, "ffn2_bias");
        var norm2_size: int = neuron_db_read_meta(db, "norm2_size").toInt();
        this.norm2 = LayerNorm(norm2_size);
        this.norm2.t = neuron_db_read_meta(db, "norm2_t").toInt();
        this.norm2.gamma = neuron_load_tensor(db, "norm2_gamma");
        this.norm2.beta = neuron_load_tensor(db, "norm2_beta");
        sqlite3_close(db);
    };
};

// =============================================
// LIQUID STATE MACHINE
// =============================================

class Lsm {
    var Win:         Tensor;
    var w:           Tensor;
    var Wout:        Tensor;
    var input_size:  int;
    var reservoir_size: int;
    var output_size: int;
    var state:       Tensor;

    function constructor(input_size: int, reservoir_size: int, output_size: int, spectral_radius: float) -> null {
        this.input_size     = input_size;
        this.reservoir_size = reservoir_size;
        this.output_size    = output_size;

        // Win: fixed random [input_size x reservoir_size]
        this.Win = Tensor(input_size, reservoir_size);
        var i: int = 0;
        while (i < input_size) {
            var j: int = 0;
            while (j < reservoir_size) {
                this.Win.put(i, j, rand_float(0.0 - 0.5, 0.5));
                j = j + 1;
            };
            i = i + 1;
        };

        // w: fixed random recurrent [reservoir_size x reservoir_size]
        // sparse — only ~10% connections
        this.w = Tensor(reservoir_size, reservoir_size);
        var i2: int = 0;
        while (i2 < reservoir_size) {
            var j2: int = 0;
            while (j2 < reservoir_size) {
                var r: float = rand_float(0.0, 1.0);
                if (r < 0.1) {
                    this.w.put(i2, j2, rand_float(0.0 - 1.0, 1.0));
                };
                j2 = j2 + 1;
            };
            i2 = i2 + 1;
        };

        // scale w to target spectral radius
        mocha_lsm_scale_reservoir(this.w.ptr, spectral_radius);

        // Wout: trained readout [reservoir_size x output_size] — initialized to zeros
        this.Wout = Tensor(reservoir_size, output_size);
        this.Wout.zeros();

        // initial reservoir state
        this.state = Tensor(1, reservoir_size);
        this.state.zeros();
    };

    ~~ Run one timestep
    ~~ @param u: input [1 x input_size]
    ~~ @return: output [1 x output_size]
    function step(u: Tensor) -> Tensor {
        // x = tanh(Win^T @ u^T + w @ x)
        // since u is [1 x input_size], u @ Win gives [1 x reservoir_size]
        var win_out: Tensor = u.matmul(this.Win);
        var w_out: Tensor = this.state.matmul(this.w);
        var pre: Tensor = win_out.add(w_out);
        win_out.dispose();
        w_out.dispose();
        pre.tanh();
        this.state.dispose();
        this.state = pre;

        // output = state @ Wout
        var out: Tensor = this.state.matmul(this.Wout);
        return out;
    };

    ~~ Reset reservoir state to zeros
    function reset() -> null {
        this.state.zeros();
    };

    ~~ Train readout weights using ridge regression
    ~~ @param states: collected reservoir states [T x reservoir_size]
    ~~ @param targets: target outputs [T x output_size]
    ~~ @param lambda: regularization strength
    function train(states: Tensor, targets: Tensor, lamb_da: float) -> null {
        var new_wout: Tensor = Tensor(this.reservoir_size, this.output_size);
        mocha_tensor_free(new_wout.ptr);
        new_wout.ptr = mocha_ridge_regression(states.ptr, targets.ptr, lamb_da, 100);
        this.Wout.dispose();
        this.Wout = new_wout;
    };

    function dispose() -> null {
        this.Win.dispose();
        this.w.dispose();
        this.Wout.dispose();
        this.state.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Lsm");
        neuron_db_write_meta(db, "input_size", str(this.input_size));
        neuron_db_write_meta(db, "reservoir_size", str(this.reservoir_size));
        neuron_db_write_meta(db, "output_size", str(this.output_size));
        neuron_save_tensor(db, "Win", this.Win);
        neuron_save_tensor(db, "w", this.w);
        neuron_save_tensor(db, "Wout", this.Wout);
        neuron_save_tensor(db, "state", this.state);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.input_size = neuron_db_read_meta(db, "input_size").toInt();
        this.reservoir_size = neuron_db_read_meta(db, "reservoir_size").toInt();
        this.output_size = neuron_db_read_meta(db, "output_size").toInt();
        this.Win = neuron_load_tensor(db, "Win");
        this.w = neuron_load_tensor(db, "w");
        this.Wout = neuron_load_tensor(db, "Wout");
        this.state = neuron_load_tensor(db, "state");
        sqlite3_close(db);
    };
};

// =============================================
// RESTRICTED BOLTZMANN MACHINE
// =============================================

class Rbm {
    var w:            Tensor;  // weights [visible x hidden]
    var bv:           Tensor;  // visible bias [1 x visible]
    var bh:           Tensor;  // hidden bias [1 x hidden]
    var visible_size: int;
    var hidden_size:  int;

    function constructor(visible_size: int, hidden_size: int) -> null {
        this.visible_size = visible_size;
        this.hidden_size  = hidden_size;

        // xavier init weights
        var limit: float = ((4.0 / (visible_size + hidden_size)).sqrt()).real;
        this.w = Tensor(visible_size, hidden_size);
        var i: int = 0;
        while (i < visible_size) {
            var j: int = 0;
            while (j < hidden_size) {
                this.w.put(i, j, rand_float(0.0 - limit, limit));
                j = j + 1;
            };
            i = i + 1;
        };

        // biases start at zero
        this.bv = Tensor(1, visible_size);
        this.bv.zeros();
        this.bh = Tensor(1, hidden_size);
        this.bh.zeros();
    };

    ~~ Compute hidden probabilities given visible: P(h=1|v)
    ~~ @param v: [1 x visible_size]
    ~~ @return: [1 x hidden_size] probabilities
    function sample_hidden(v: Tensor) -> Tensor {
        var pre: Tensor = v.matmul(this.w);
        mocha_tensor_add_bias(pre.ptr, this.bh.ptr);
        pre.sigmoid();
        return pre;
    };

    ~~ Compute visible probabilities given hidden: P(v=1|h)
    ~~ @param h: [1 x hidden_size]
    ~~ @return: [1 x visible_size] probabilities
    function sample_visible(h: Tensor) -> Tensor {
        var Wt: Tensor = this.w.transpose();
        var pre: Tensor = h.matmul(Wt);
        Wt.dispose();
        mocha_tensor_add_bias(pre.ptr, this.bv.ptr);
        pre.sigmoid();
        return pre;
    };

    ~~ Reconstruct visible from visible (one CD step)
    ~~ @param v: [1 x visible_size]
    ~~ @return: reconstructed [1 x visible_size]
    function reconstruct(v: Tensor) -> Tensor {
        var h_prob: Tensor = this.sample_hidden(v);
        var v_recon: Tensor = this.sample_visible(h_prob);
        h_prob.dispose();
        return v_recon;
    };

    ~~ Train one step using Contrastive Divergence (CD-1)
    ~~ @param v0: one data sample [1 x visible_size]
    ~~ @param lr: learning rate
    function train_step(v0: Tensor, lr: float) -> null {
        // positive phase: h0 = sigmoid(v0 @ w + bh)
        var h0: Tensor = this.sample_hidden(v0);
        this.binarize(h0);  // sample binary

        // reconstruct: v1 = sigmoid(h0 @ w^T + bv)
        var v1: Tensor = this.sample_visible(h0);
        this.binarize(v1);  // sample binary

        // negative phase: h1 = sigmoid(v1 @ w + bh)
        var h1: Tensor = this.sample_hidden(v1);

        // dW = v0^T @ h0 - v1^T @ h1
        var v0t: Tensor = v0.transpose();
        var v1t: Tensor = v1.transpose();
        var pos: Tensor = v0t.matmul(h0);
        var neg: Tensor = v1t.matmul(h1);

        // w += lr * (pos - neg)
        neg.scale(0.0 - 1.0);
        pos.add_inplace(neg);
        pos.scale(lr);
        this.w.add_inplace(pos);

        // dbv = lr * (v0 - v1)
        neg.scale(0.0 - 1.0);  // restore neg sign for reuse? no — do fresh
        var dv: Tensor = v0.add(v1);  // we need v0 - v1
        // can't subtract directly, scale v1 by -1 first
        v1.scale(0.0 - 1.0);
        var dbv: Tensor = v0.add(v1);
        dbv.scale(lr);
        this.bv.add_inplace(dbv);

        // dbh = lr * (h0 - h1)
        h1.scale(0.0 - 1.0);
        var dbh: Tensor = h0.add(h1);
        dbh.scale(lr);
        this.bh.add_inplace(dbh);

        // cleanup
        v0t.dispose();
        v1t.dispose();
        pos.dispose();
        neg.dispose();
        dv.dispose();
        dbv.dispose();
        dbh.dispose();
        h0.dispose();
        h1.dispose();
        v1.dispose();
    };

    ~~ Compute mean reconstruction error on a sample
    ~~ @param v: [1 x visible_size]
    ~~ @return: mean squared error as float
    function reconstruction_error(v: Tensor) -> float {
        var recon: Tensor = this.reconstruct(v);
        var err: float = mocha_tensor_mse_loss(v.ptr, recon.ptr);
        recon.dispose();
        return err;
    };

    ~~ Convert probability tensor to binary sample in-place
    ~~ @param probs: [1 x n] sigmoid probabilities, modified in place to 0/1
    function binarize(probs: Tensor) -> null {
        var n: int = probs.ncols;
        var i: int = 0;
        while (i < n) {
            var p: float = probs.at(0, i);
            var r: float = crypto_rand_float(0.0, 1.0);
            if (r < p) {
                probs.put(0, i, 1.0);
            };
            if (r >= p) {
                probs.put(0, i, 0.0);
            };
            i = i + 1;
        };
    };

    function dispose() -> null {
        this.w.dispose();
        this.bv.dispose();
        this.bh.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Rbm");
        neuron_db_write_meta(db, "visible_size", str(this.visible_size));
        neuron_db_write_meta(db, "hidden_size", str(this.hidden_size));
        neuron_save_tensor(db, "w", this.w);
        neuron_save_tensor(db, "bv", this.bv);
        neuron_save_tensor(db, "bh", this.bh);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.visible_size = neuron_db_read_meta(db, "visible_size").toInt();
        this.hidden_size = neuron_db_read_meta(db, "hidden_size").toInt();
        this.w = neuron_load_tensor(db, "w");
        this.bv = neuron_load_tensor(db, "bv");
        this.bh = neuron_load_tensor(db, "bh");
        sqlite3_close(db);
    };
};

// =============================================
// EMBEDDING LAYER
// =============================================

class Embedding {
    var table:      Tensor;   // [vocab_size x d_model]
    var grad_table: Tensor;   // accumulated gradients
    var vocab_size: int;
    var d_model:    int;

    function constructor(vocab_size: int, d_model: int) -> null {
        this.vocab_size = vocab_size;
        this.d_model    = d_model;

        // small random init — standard for embeddings
        var scale: float = 0.02;
        this.table = Tensor(vocab_size, d_model);
        var i: int = 0;
        while (i < vocab_size) {
            var j: int = 0;
            while (j < d_model) {
                this.table.put(i, j, rand_float(0.0 - scale, scale));
                j = j + 1;
            };
            i = i + 1;
        };

        this.grad_table = Tensor(vocab_size, d_model);
        this.grad_table.zeros();
    };

    ~~ Look up embeddings for a sequence of token IDs
    ~~ @param ids: int[] of token IDs
    ~~ @return: [seq_len x d_model] tensor
    function forward(ids: int[]) -> Tensor {
        var seq_len: int = ids.length;
        var out: Tensor = Tensor(seq_len, this.d_model);
        var i: int = 0;
        while (i < seq_len) {
            var token_id: int = ids[i];
            var j: int = 0;
            while (j < this.d_model) {
                var val: float = this.table.at(token_id, j);
                out.put(i, j, val);
                j = j + 1;
            };
            i = i + 1;
        };
        return out;
    };

    ~~ Backward — accumulate gradients into embedding rows
    ~~ @param dout: [seq_len x d_model] gradient
    ~~ @param ids: same int[] passed to forward
    function backward(dout: Tensor, ids: int[], lr: float) -> null {
        var seq_len: int = ids.length;
        var i: int = 0;
        while (i < seq_len) {
            var token_id: int = ids[i];
            var j: int = 0;
            while (j < this.d_model) {
                var grad: float = dout.at(i, j);
                var cur: float = this.table.at(token_id, j);
                this.table.put(token_id, j, cur - lr * grad);
                j = j + 1;
            };
            i = i + 1;
        };
    };

    function dispose() -> null {
        this.table.dispose();
        this.grad_table.dispose();
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        neuron_db_setup(db);
        sqlite3_exec(db, "BEGIN TRANSACTION;");
        neuron_db_write_meta(db, "layer_type", "Embedding");
        neuron_db_write_meta(db, "vocab_size", str(this.vocab_size));
        neuron_db_write_meta(db, "d_model", str(this.d_model));
        neuron_save_tensor(db, "table", this.table);
        sqlite3_exec(db, "COMMIT;");
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.vocab_size = neuron_db_read_meta(db, "vocab_size").toInt();
        this.d_model = neuron_db_read_meta(db, "d_model").toInt();
        this.table = neuron_load_tensor(db, "table");
        sqlite3_close(db);
    };
};

// =============================================
// POSITIONAL ENCODING
// =============================================

class PositionalEncoding {
    var table:   Tensor;   // [max_seq_len x d_model]
    var max_len: int;
    var d_model: int;

    function constructor(max_len: int, d_model: int) -> null {
        this.max_len = max_len;
        this.d_model = d_model;
        this.table = Tensor(max_len, d_model);

        var pos: int = 0;
        while (pos < max_len) {
            var i: int = 0;
            while (i < d_model) {
                var exp: float = float(i * 2) / float(d_model);
                var div: float = c_pow(10000.0, exp);
                var angle: float = float(pos) / div;
                if (i % 2 == 0) {
                    this.table.put(pos, i, angle.sin());
                };
                if (i % 2 != 0) {
                    this.table.put(pos, i, angle.cos());
                };
                i = i + 1;
            };
            pos = pos + 1;
        };
    };

    ~~ Add positional encoding to embedding output
    ~~ @param x: [seq_len x d_model] from Embedding
    ~~ @return: [seq_len x d_model] with position info added
    function encode(x: Tensor) -> Tensor {
        var seq_len: int = x.nrows;
        var out: Tensor = Tensor(seq_len, this.d_model);
        var i: int = 0;
        while (i < seq_len) {
            var j: int = 0;
            while (j < this.d_model) {
                var emb: float = x.at(i, j);
                var pos: float = this.table.at(i, j);
                out.put(i, j, emb + pos);
                j = j + 1;
            };
            i = i + 1;
        };
        return out;
    };

    // no backward needed — fixed encoding, no learned params

    function dispose() -> null {
        this.table.dispose();
    };
};