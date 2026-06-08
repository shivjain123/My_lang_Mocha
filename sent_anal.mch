from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);
    mocha_cuda_init();

    // ── Dataset ──────────────────────────────────────────────
    var texts: str[] = [
        "i love this movie",
        "this film is great",
        "amazing wonderful brilliant",
        "i really enjoyed it",
        "best movie ever",
        "fantastic performance",
        "i loved every moment",
        "absolutely brilliant film",
        "this was terrible",
        "i hated this movie",
        "awful boring film",
        "worst movie ever",
        "complete waste of time",
        "i did not enjoy this",
        "terrible acting bad story",
        "so boring and awful"
    ];

    var labels: float[] = [
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    ];

    // ── Hyperparameters ───────────────────────────────────────
    var d_model: int = 32;
    var d_k:     int = 16;
    var d_ff:    int = 64;
    var max_len: int = 20;
    var lr:      float = 0.0001;
    var epochs:  int = 2000;

    // ── Build tokenizer ───────────────────────────────────────
    var tok: Tokenizer = Tokenizer();
    tok.fit(texts);
    print("Vocab size: ", tok.size(), "\n");

    // ── Build model ───────────────────────────────────────────
    var emb: Embedding = Embedding(tok.size(), d_model);
    var pe: PositionalEncoding = PositionalEncoding(max_len, d_model);
    var bert: BertLayer = BertLayer(d_model, d_k, d_ff);
    var head: Dense = Dense(d_model, 1, Activation.SIGMOID);

    // ── Training loop ─────────────────────────────────────────
    var epoch: int = 0;
    while (epoch < epochs) {
        var total_loss: float = 0.0;
        var i: int = 0;
        while (i < texts.length) {
            var ids: int[] = tok.encode(texts[i]);

            var embedded: Tensor = emb.forward(ids);
            var encoded: Tensor = pe.encode(embedded);
            embedded.dispose();

            var seq_len: int = encoded.nrows;

            var bert_out: Tensor = bert.forward(encoded);
            var cls: Tensor = bert_out.get_row(0);
            bert_out.dispose();

            var pred: Tensor = head.forward(cls);

            var label: Tensor = Tensor(1, 1);
            label.put(0, 0, labels[i]);

            var loss: float = mocha_tensor_mse_loss(pred.ptr, label.ptr);
            total_loss = total_loss + loss;

            var dout: Tensor = Tensor(1, 1);
            mocha_tensor_free(dout.ptr);
            dout.ptr = mocha_tensor_mse_grad(pred.ptr, label.ptr);

            var dcls: Tensor = head.backward(dout, lr);
            dout.dispose();

            var denc_full: Tensor = Tensor(seq_len, d_model);
            denc_full.zeros();
            var col: int = 0;
            while (col < d_model) {
                denc_full.put(0, col, dcls.at(0, col));
                col = col + 1;
            };
            dcls.dispose();

            var denc: Tensor = bert.backward(denc_full, lr);
            denc_full.dispose();

            emb.backward(denc, ids, lr);
            denc.dispose();

            pred.dispose();
            label.dispose();
            cls.dispose();
            encoded.dispose();

            i++;
        };

        if (epoch % 100 == 0) {
            var avg_loss: float = total_loss / 16.0;
            print("Epoch ", epoch, " loss: ", avg_loss, "\n");
        };
        epoch = epoch + 1;
    };

    // ── Test ──────────────────────────────────────────────────
    print("\nTest predictions:\n");
    var test_texts: str[] = [
        "i love this film",
        "terrible awful movie",
        "brilliant amazing story",
        "i hated every moment"
    ];

    var t: int = 0;
    while (t < test_texts.length) {
        var ids: int[] = tok.encode(test_texts[t]);
        var embedded: Tensor = emb.forward(ids);
        var encoded:  Tensor = pe.encode(embedded);
        embedded.dispose();
        var bert_out: Tensor = bert.forward(encoded);
        var cls: Tensor = bert_out.get_row(0);
        bert_out.dispose();
        encoded.dispose();
        var pred: Tensor = head.forward(cls);
        var score: float = pred.at(0, 0);
        print(test_texts[t], " → ", score, "\n");
        pred.dispose();
        cls.dispose();
        t = t + 1;
    };

    emb.dispose();
    bert.dispose();
    head.dispose();
};