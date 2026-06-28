// mocha-lib-deps: mocha-stats, mocha-string

//Const
const RAND: int = -999999;

// =============================================
// NATIVE WRAPPERS FOR SQLite3
// =============================================

function sqlite3_open(path: str) -> null native mocha_sqlite3_open;
function sqlite3_exec(db: null, sql: str) -> int native mocha_sqlite3_exec;
function sqlite3_query(db: null, sql: str) -> int native mocha_sqlite3_query;
function sqlite3_close(db: null) -> null native mocha_sqlite3_close;
function sqlite3_query_run(db: null, sql: str) -> int native mocha_sqlite3_query_run;
function sqlite3_query_rows(db: null) -> int native mocha_sqlite3_query_rows;
function sqlite3_query_cols(db: null) -> int native mocha_sqlite3_query_cols;
function sqlite3_query_cell(db: null, row: int, col: int) -> str native mocha_sqlite3_query_cell;
function sqlite3_query_colname(db: null, col: int) -> str native mocha_sqlite3_query_colname;
function sqlite3_errmsg(db: null) -> str native mocha_sqlite3_errmsg;
function sqlite3_last_rowid(db: null) -> int native mocha_sqlite3_last_rowid;
function sqlite3_changes(db: null) -> int native mocha_sqlite3_changes;
function sqlite3_table_exists(db: null, table: str) -> int native mocha_sqlite3_table_exists;

// =============================================
// Helpers for .save()/.load()
// =============================================

function forge_db_open(path: str) -> null {
    var db: null = sqlite3_open(path);
    return db;
};

function forge_db_setup(db: null) -> null {
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);");
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS arrays (name TEXT, idx INT, value TEXT);");
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS trees (name TEXT, node_id INT, is_leaf INT, value REAL, feature INT, threshold REAL, left_id INT, right_id INT);");
};

function forge_db_write_meta(db: null, key: str, value: str) -> null {
    sqlite3_exec(db, "INSERT OR REPLACE INTO meta (key, value) VALUES ('" + key + "', '" + value + "');");
};

function forge_db_read_meta(db: null, key: str) -> str {
    sqlite3_query_run(db, "SELECT value FROM meta WHERE key = '" + key + "';");
    return sqlite3_query_cell(db, 0, 0);
};

function forge_db_write_array(db: null, name: str, idx: int, value: str) -> null {
    sqlite3_exec(db, "INSERT INTO arrays (name, idx, value) VALUES ('" + name + "', " + str(idx) + ", '" + value + "');");
};

function forge_db_read_array_len(db: null, name: str) -> int {
    sqlite3_query_run(db, "SELECT COUNT(*) FROM arrays WHERE name = '" + name + "';");
    return sqlite3_query_cell(db, 0, 0).toInt();
};

function forge_db_read_array_cell(db: null, name: str, idx: int) -> str {
    sqlite3_query_run(db, "SELECT value FROM arrays WHERE name = '" + name + "' AND idx = " + str(idx) + ";");
    return sqlite3_query_cell(db, 0, 0);
};

function forge_db_write_tree_node(db: null, name: str, node_id: int, is_leaf: int, value: float, feature: int, threshold: float, left_id: int, right_id: int) -> null {
    sqlite3_exec(db, "INSERT INTO trees (name, node_id, is_leaf, value, feature, threshold, left_id, right_id) VALUES ('" + name + "', " + str(node_id) + ", " + str(is_leaf) + ", " + str(value) + ", " + str(feature) + ", " + str(threshold) + ", " + str(left_id) + ", " + str(right_id) + ");");
};

function forge_db_read_tree_node_isleaf(db: null, name: str, node_id: int) -> int {
    sqlite3_query_run(db, "SELECT is_leaf FROM trees WHERE name = '" + name + "' AND node_id = " + str(node_id) + ";");
    return sqlite3_query_cell(db, 0, 0).toInt();
};

function forge_db_read_tree_node_value(db: null, name: str, node_id: int) -> float {
    sqlite3_query_run(db, "SELECT value FROM trees WHERE name = '" + name + "' AND node_id = " + str(node_id) + ";");
    return sqlite3_query_cell(db, 0, 0).toFloat();
};

function forge_db_read_tree_node_feature(db: null, name: str, node_id: int) -> int {
    sqlite3_query_run(db, "SELECT feature FROM trees WHERE name = '" + name + "' AND node_id = " + str(node_id) + ";");
    return sqlite3_query_cell(db, 0, 0).toInt();
};

function forge_db_read_tree_node_threshold(db: null, name: str, node_id: int) -> float {
    sqlite3_query_run(db, "SELECT threshold FROM trees WHERE name = '" + name + "' AND node_id = " + str(node_id) + ";");
    return sqlite3_query_cell(db, 0, 0).toFloat();
};

function forge_db_read_tree_node_leftid(db: null, name: str, node_id: int) -> int {
    sqlite3_query_run(db, "SELECT left_id FROM trees WHERE name = '" + name + "' AND node_id = " + str(node_id) + ";");
    return sqlite3_query_cell(db, 0, 0).toInt();
};

function forge_db_read_tree_node_rightid(db: null, name: str, node_id: int) -> int {
    sqlite3_query_run(db, "SELECT right_id FROM trees WHERE name = '" + name + "' AND node_id = " + str(node_id) + ";");
    return sqlite3_query_cell(db, 0, 0).toInt();
};

function forge_serialize_dtnode(db: null, name: str, node: DTNode, node_id: int, counter: int[]) -> null {
    if (node.is_leaf == 1) {
        forge_db_write_tree_node(db, name, node_id, 1, float(node.label), 0, 0.0, -1, -1);
        return;
    };
    var left_id: int = counter[0];
    counter[0]++;
    var right_id: int = counter[0];
    counter[0]++;
    forge_db_write_tree_node(db, name, node_id, 0, 0.0, node.feature_idx, node.threshold, left_id, right_id);
    forge_serialize_dtnode(db, name, node.left, left_id, counter);
    forge_serialize_dtnode(db, name, node.right, right_id, counter);
};

function forge_serialize_surrogatenode(db: null, name: str, node: SurrogateNode, node_id: int, counter: int[]) -> null {
    if (node.is_leaf == 1) {
        forge_db_write_tree_node(db, name, node_id, 1, node.value, 0, 0.0, -1, -1);
        return;
    };
    var left_id: int = counter[0];
    counter[0]++;
    var right_id: int = counter[0];
    counter[0]++;
    forge_db_write_tree_node(db, name, node_id, 0, 0.0, node.feature_idx, node.threshold, left_id, right_id);
    forge_serialize_surrogatenode(db, name, node.left, left_id, counter);
    forge_serialize_surrogatenode(db, name, node.right, right_id, counter);
};

function forge_deserialize_dtnode(db: null, name: str, node_id: int) -> DTNode {
    var is_leaf: int = forge_db_read_tree_node_isleaf(db, name, node_id);
    if (is_leaf == 1) {
        var label: int = int(forge_db_read_tree_node_value(db, name, node_id));
        return dt_leaf(label);
    };
    var feature: int = forge_db_read_tree_node_feature(db, name, node_id);
    var threshold: float = forge_db_read_tree_node_threshold(db, name, node_id);
    var left_id: int = forge_db_read_tree_node_leftid(db, name, node_id);
    var right_id: int = forge_db_read_tree_node_rightid(db, name, node_id);
    var left_node: DTNode = forge_deserialize_dtnode(db, name, left_id);
    var right_node: DTNode = forge_deserialize_dtnode(db, name, right_id);
    return dt_node(feature, threshold, left_node, right_node);
};

function forge_deserialize_surrogatenode(db: null, name: str, node_id: int) -> SurrogateNode {
    var is_leaf: int = forge_db_read_tree_node_isleaf(db, name, node_id);
    if (is_leaf == 1) {
        var value: float = forge_db_read_tree_node_value(db, name, node_id);
        return surrogate_leaf(value);
    };
    var feature: int = forge_db_read_tree_node_feature(db, name, node_id);
    var threshold: float = forge_db_read_tree_node_threshold(db, name, node_id);
    var left_id: int = forge_db_read_tree_node_leftid(db, name, node_id);
    var right_id: int = forge_db_read_tree_node_rightid(db, name, node_id);
    var left_node: SurrogateNode = forge_deserialize_surrogatenode(db, name, left_id);
    var right_node: SurrogateNode = forge_deserialize_surrogatenode(db, name, right_id);
    return surrogate_node(feature, threshold, left_node, right_node);
};

class OneHotEncoder {
    var categories: str[];
    var n_categories: int;
    var fitted: int;  // 0 = not fitted, 1 = fitted

    function constructor() -> null {
        this.categories = alloc str[0];
        this.n_categories = 0;
        this.fitted = 0;
    };

    // ─────────────────────────────────────────
    // fit: learn unique categories from data
    // ─────────────────────────────────────────
    function fit(data: str[]) -> null {
        var seen: str[] = [];
        var i: int = 0;
        while (i < data.length) {
            var found: int = 0;
            var j: int = 0;
            while (j < seen.length) {
                if (seen[j] == data[i]) { found = 1; };
                j++;
            };
            if (found == 0) {
                seen.push(data[i]);
            };
            i++;
        };
        this.categories = seen;
        this.n_categories = seen.length;
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // transform: encode str[] → int[][]
    // each row is a one-hot vector
    // ─────────────────────────────────────────
    function transform(data: str[]) -> int[][] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (OneHotEncoder): transform called before fit.");
            c_exit(2);
        };
        var result: int[][] = alloc int[data.length][this.n_categories];
            var i: int = 0;
            while (i < data.length) {
                // find category index
                var idx: int = -1;
                var j: int = 0;
                while (j < this.n_categories) {
                    if (this.categories[j] == data[i]) { idx = j; };
                    j++;
                };
                if (idx == -1) {
                    c_print_err("MochaForgeError (OneHotEncoder): unknown category '" + data[i] + "' — fit did not see this value.");
                    c_exit(2);
                };
                // fill row with zeros then set the hot index
                var k: int = 0;
                while (k < this.n_categories) {
                    result[i][k] = 0;
                    k++;
                };
                result[i][idx] = 1;
                i++;
            };
        return result;
    };

    // ─────────────────────────────────────────
    // inverse_transform: int[][] → str[]
    // ─────────────────────────────────────────
    function inverse_transform(encoded: int[][]) -> str[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (OneHotEncoder): inverse_transform called before fit.");
            c_exit(2);
        };
        var result: str[] = alloc str[encoded.length];
        var i: int = 0;
        while (i < encoded.length) {
            var idx: int = -1;
            var j: int = 0;
            while (j < this.n_categories) {
                if (encoded[i][j] == 1) { idx = j; };
                j++;
            };
            if (idx == -1) {
                c_print_err("MochaForgeError (OneHotEncoder): invalid one-hot vector at row " + str(i) + " — no hot bit found.");
                c_exit(2);
            };
            result[i] = this.categories[idx];
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // get_feature_names: returns category labels
    // useful for printing column headers
    // ─────────────────────────────────────────
    function get_feature_names() -> str[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (OneHotEncoder): get_feature_names called before fit.");
            c_exit(2);
        };
        return this.categories;
    };

    // OneHotEncoder
    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "OneHotEncoder");
        forge_db_write_meta(db, "n_categories", str(this.n_categories));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        var i: int = 0;
        while (i < this.n_categories) {
            forge_db_write_array(db, "categories", i, this.categories[i]);
            i++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.n_categories = forge_db_read_meta(db, "n_categories").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.categories = alloc str[this.n_categories];
        var i: int = 0;
        while (i < this.n_categories) {
            this.categories[i] = forge_db_read_array_cell(db, "categories", i);
            i++;
        };
        sqlite3_close(db);
    };
};

class OrdinalEncoder {
    var order: str[];
    var n_categories: int;
    var fitted: int;

    function constructor() -> null {
        this.order = [];
        this.n_categories = 0;
        this.fitted = 0;
    };

    // ─────────────────────────────────────────
    // fit: learn categories with explicit order
    // ─────────────────────────────────────────
    function fit(data: str[], order: str[]) -> null {
        // check all data values exist in order
        var i: int = 0;
        while (i < data.length) {
            var found: int = 0;
            var j: int = 0;
            while (j < order.length) {
                if (data[i] == order[j]) { found = 1; };
                j++;
            };
            if (found == 0) {
                c_print_err("MochaForgeError (OrdinalEncoder): value '" + data[i] + "' not found in order list. Fix your data or update the order.");
                c_exit(2);
            };
            i++;
        };
        this.order = order;
        this.n_categories = order.length;
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // transform: str[] → int[]
    // ─────────────────────────────────────────
    function transform(data: str[]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (OrdinalEncoder): transform called before fit.");
            c_exit(2);
        };
        var result: int[] = alloc int[data.length];
        var i: int = 0;
        while (i < data.length) {
            var idx: int = -1;
            var j: int = 0;
            while (j < this.n_categories) {
                if (this.order[j] == data[i]) { idx = j; };
                j++;
            };
            if (idx == -1) {
                c_print_err("MochaForgeError (OrdinalEncoder): unknown value '" + data[i] + "' at transform time. Fix your data.");
                c_exit(2);
            };
            result[i] = idx;
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // inverse_transform: int[] → str[]
    // ─────────────────────────────────────────
    function inverse_transform(encoded: int[]) -> str[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (OrdinalEncoder): inverse_transform called before fit.");
            c_exit(2);
        };
        var result: str[] = alloc str[encoded.length];
        var i: int = 0;
        while (i < encoded.length) {
            if (encoded[i] < 0 || encoded[i] >= this.n_categories) {
                c_print_err("MochaForgeError (OrdinalEncoder): encoded value " + str(encoded[i]) + " out of range.");
                c_exit(2);
            };
            result[i] = this.order[encoded[i]];
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // get_order: return the order
    // ─────────────────────────────────────────
    function get_order() -> str[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (OrdinalEncoder): get_order called before fit.");
            c_exit(2);
        };
        return this.order;
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "OrdinalEncoder");
        forge_db_write_meta(db, "n_categories", str(this.n_categories));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        var i: int = 0;
        while (i < this.n_categories) {
            forge_db_write_array(db, "order", i, this.order[i]);
            i++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.n_categories = forge_db_read_meta(db, "n_categories").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.order = alloc str[this.n_categories];
        var i: int = 0;
        while (i < this.n_categories) {
            this.order[i] = forge_db_read_array_cell(db, "order", i);
            i++;
        };
        sqlite3_close(db);
    };
};

class TargetEncoder {
    var categories: str[];
    var n_categories: int;
    var fitted: int;

    function constructor() -> null {
        this.categories = [];
        this.n_categories = 0;
        this.fitted = 0;
    };

    // ─────────────────────────────────────────
    // fit: learn unique labels
    // ─────────────────────────────────────────
    function fit(data: str[]) -> null {
        var seen: str[] = [];
        var i: int = 0;
        while (i < data.length) {
            var found: int = 0;
            var j: int = 0;
            while (j < seen.length) {
                if (seen[j] == data[i]) { found = 1; };
                j++;
            };
            if (found == 0) {
                seen.push(data[i]);
            };
            i++;
        };
        this.categories = seen;
        this.n_categories = seen.length;
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // transform: str[] → int[]
    // ─────────────────────────────────────────
    function transform(data: str[]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (TargetEncoder): transform called before fit.");
            c_exit(2);
        };
        var result: int[] = alloc int[data.length];
        var i: int = 0;
        while (i < data.length) {
            var idx: int = -1;
            var j: int = 0;
            while (j < this.n_categories) {
                if (this.categories[j] == data[i]) { idx = j; };
                j++;
            };
            if (idx == -1) {
                c_print_err("MochaForgeError (TargetEncoder): unknown label '" + data[i] + "' — fit did not see this value.");
                c_exit(2);
            };
            result[i] = idx;
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // inverse_transform: int[] → str[]
    // ─────────────────────────────────────────
    function inverse_transform(encoded: int[]) -> str[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (TargetEncoder): inverse_transform called before fit.");
            c_exit(2);
        };
        var result: str[] = alloc str[encoded.length];
        var i: int = 0;
        while (i < encoded.length) {
            if (encoded[i] < 0 || encoded[i] >= this.n_categories) {
                c_print_err("MochaForgeError (TargetEncoder): encoded value " + str(encoded[i]) + " out of range.");
                c_exit(2);
            };
            result[i] = this.categories[encoded[i]];
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // get_categories: return learned labels
    // ─────────────────────────────────────────
    function get_categories() -> str[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (TargetEncoder): get_categories called before fit.");
            c_exit(2);
        };
        return this.categories;
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "TargetEncoder");
        forge_db_write_meta(db, "n_categories", str(this.n_categories));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        var i: int = 0;
        while (i < this.n_categories) {
            forge_db_write_array(db, "categories", i, this.categories[i]);
            i++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.n_categories = forge_db_read_meta(db, "n_categories").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.categories = alloc str[this.n_categories];
        var i: int = 0;
        while (i < this.n_categories) {
            this.categories[i] = forge_db_read_array_cell(db, "categories", i);
            i++;
        };
        sqlite3_close(db);
    };
};

class LinearRegression {
    var weights: float[];
    var bias: float;
    var lr: float;
    var iterations: int;
    var fitted: int;
    var reg_type: str;
    var reg_lambda: float;

    function constructor(lr: float, iterations: int) -> null {
        this.weights = [];
        this.bias = 0.0;
        this.lr = lr;
        this.iterations = iterations;
        this.fitted = 0;
        this.reg_type = "none";
        this.reg_lambda = 0.0;
    };

    function ridge(lamb_da: float) -> null {
        this.reg_type = "ridge";
        this.reg_lambda = lamb_da;
    };

    function lasso(lamb_da: float) -> null {
        this.reg_type = "lasso";
        this.reg_lambda = lamb_da;
    };

    // ─────────────────────────────────────────
    // fit: gradient descent
    // ─────────────────────────────────────────
    function fit(x: float[][], y: float[]) -> null {
        var n: int = x.length;
        var n_features: int = x.cols;

        // initialise weights to 0
        this.weights = alloc float[n_features];
        var wi: int = 0;
        while (wi < n_features) {
            this.weights[wi] = 0.0;
            wi++;
        };
        this.bias = 0.0;

        var iter: int = 0;
        while (iter < this.iterations) {

            // ── forward pass: compute predictions ──
            var preds: float[] = alloc float[n];
            var i: int = 0;
            while (i < n) {
                var pred: float = this.bias;
                var j: int = 0;
                while (j < n_features) {
                    pred = pred + x[i][j] * this.weights[j];
                    j++;
                };
                preds[i] = pred;
                i++;
            };

            // ── compute residuals: (ŷ - y) ──
            var residuals: float[] = alloc float[n];
            var r: int = 0;
            while (r < n) {
                residuals[r] = preds[r] - y[r];
                r++;
            };

            // ── gradients ──
            // dL/dw = (2/n) * xᵀ(ŷ - y)
            var dw: float[] = alloc float[n_features];
            var k: int = 0;
            while (k < n_features) {
                var grad: float = 0.0;
                var m: int = 0;
                while (m < n) {
                    grad = grad + x[m][k] * residuals[m];
                    m++;
                };
                dw[k] = (2.0 / float(n)) * grad;

                // regularization
                if (this.reg_type == "ridge") {
                    dw[k] = dw[k] + 2.0 * this.reg_lambda * this.weights[k];
                };
                if (this.reg_type == "lasso") {
                    var sign: float = 0.0;
                    if (this.weights[k] > 0.0) { sign = 1.0; };
                    if (this.weights[k] < 0.0) { sign = -1.0; };
                    dw[k] = dw[k] + this.reg_lambda * sign;
                };

                k++;
            };

            // dL/db = (2/n) * sum(ŷ - y)
            var db: float = 0.0;
            var s: int = 0;
            while (s < n) {
                db = db + residuals[s];
                s++;
            };
            db = (2.0 / float(n)) * db;

            // ── update weights and bias ──
            var u: int = 0;
            while (u < n_features) {
                this.weights[u] = this.weights[u] - this.lr * dw[u];
                u++;
            };
            this.bias = this.bias - this.lr * db;

            iter++;
        };
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // predict: xw + b
    // ─────────────────────────────────────────
    function predict(x: float[][]) -> float[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LinearRegression): predict called before fit.");
            c_exit(2);
        };
        var n: int = x.length;
        var n_features: int = x.cols;
        var preds: float[] = alloc float[n];
        var i: int = 0;
        while (i < n) {
            var pred: float = this.bias;
            var j: int = 0;
            while (j < n_features) {
                pred = pred + x[i][j] * this.weights[j];
                j++;
            };
            preds[i] = pred;
            i++;
        };
        return preds;
    };

    // ─────────────────────────────────────────
    // mse: mean squared error
    // ─────────────────────────────────────────
    function mse(x: float[][], y: float[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LinearRegression): mse called before fit.");
            c_exit(2);
        };
        var preds: float[] = this.predict(x);
        var n: int = y.length;
        var sum: float = 0.0;
        var i: int = 0;
        while (i < n) {
            var diff: float = preds[i] - y[i];
            sum = sum + diff * diff;
            i++;
        };
        return sum / float(n);
    };

    // ─────────────────────────────────────────
    // rmse: root mean squared error
    // ─────────────────────────────────────────
    function rmse(x: float[][], y: float[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LinearRegression): rmse called before fit.");
            c_exit(2);
        };
        return c_sqrt(this.mse(x, y));
    };

    // ─────────────────────────────────────────
    // r2: R² coefficient of determination
    // ─────────────────────────────────────────
    function r2(x: float[][], y: float[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LinearRegression): r2 called before fit.");
            c_exit(2);
        };
        var preds: float[] = this.predict(x);
        var n: int = y.length;

        // mean of y
        var y_mean: float = 0.0;
        var i: int = 0;
        while (i < n) {
            y_mean = y_mean + y[i];
            i++;
        };
        y_mean = y_mean / float(n);

        // SS_res and SS_tot
        var ss_res: float = 0.0;
        var ss_tot: float = 0.0;
        var j: int = 0;
        while (j < n) {
            var diff_res: float = y[j] - preds[j];
            var diff_tot: float = y[j] - y_mean;
            ss_res = ss_res + diff_res * diff_res;
            ss_tot = ss_tot + diff_tot * diff_tot;
            j++;
        };

        if (ss_tot == 0.0) { return 1.0; };
        return 1.0 - (ss_res / ss_tot);
    };
    // ─────────────────────────────────────────
    // summary: OLS results table
    // ─────────────────────────────────────────
    function summary(x: float[][], y: float[]) -> null {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LinearRegression): summary called before fit.");
            c_exit(2);
        };
        var r2_val: float = this.r2(x, y);
        var n: int = y.length;
        var n_features: int = x.cols;
        var mse_val: float = this.mse(x, y);
        var rmse_val: float = this.rmse(x, y);
        var denom: int = n - n_features - 1;
        var adj_r2: float = 0.0;
        if (denom != 0) {
            adj_r2 = 1.0 - (1.0 - r2_val) * float(n - 1) / float(denom);
        };

        print("==============================================", newLine=true);
        print("        OLS Regression Results", newLine=true);
        print("==============================================", newLine=true);
        print("R²:          " + str(r2_val), newLine=true);
        if (denom == 0) {
            print("Adj. R²:     N/A (too few samples)", newLine=true);
        };
        if (denom != 0) {
            print("Adj. R²:     " + str(adj_r2), newLine=true);
        };
        print("MSE:         " + str(mse_val), newLine=true);
        print("RMSE:        " + str(rmse_val), newLine=true);
        print("n:           " + str(n), newLine=true);
        print("Features:    " + str(n_features), newLine=true);
        print("----------------------------------------------", newLine=true);
        print("Coef         Value", newLine=true);
        print("----------------------------------------------", newLine=true);
        print("bias         " + str(this.bias), newLine=true);
        var wi: int = 0;
        while (wi < n_features) {
            print("w[" + str(wi) + "]          " + str(this.weights[wi]), newLine=true);
            wi++;
        };
        if (this.reg_type != "none") {
            print("----------------------------------------------", newLine=true);
            print("Regularization: " + this.reg_type + "  λ=" + str(this.reg_lambda), newLine=true);
        };
        print("==============================================", newLine=true);
    };
    
    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "LinearRegression");
        forge_db_write_meta(db, "bias", str(this.bias));
        forge_db_write_meta(db, "lr", str(this.lr));
        forge_db_write_meta(db, "iterations", str(this.iterations));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "reg_type", this.reg_type);
        forge_db_write_meta(db, "reg_lambda", str(this.reg_lambda));
        forge_db_write_meta(db, "weights_len", str(this.weights.length));
        var i: int = 0;
        while (i < this.weights.length) {
            forge_db_write_array(db, "weights", i, str(this.weights[i]));
            i++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.bias = forge_db_read_meta(db, "bias").toFloat();
        this.lr = forge_db_read_meta(db, "lr").toFloat();
        this.iterations = forge_db_read_meta(db, "iterations").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.reg_type = forge_db_read_meta(db, "reg_type");
        this.reg_lambda = forge_db_read_meta(db, "reg_lambda").toFloat();
        var wlen: int = forge_db_read_meta(db, "weights_len").toInt();
        this.weights = alloc float[wlen];
        var i: int = 0;
        while (i < wlen) {
            this.weights[i] = forge_db_read_array_cell(db, "weights", i).toFloat();
            i++;
        };
        sqlite3_close(db);
    };
};

class LogisticClassification {
    var weights: float[];
    var bias: float;
    var lr: float;
    var iterations: int;
    var fitted: int;

    function constructor(lr: float, iterations: int) -> null {
        this.weights = [];
        this.bias = 0.0;
        this.lr = lr;
        this.iterations = iterations;
        this.fitted = 0;
    };

    //Helper function
    function confusion(x: float[][], y: int[]) -> int[] {
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var tp: int = 0;
        var fp: int = 0;
        var fn_count: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 1 && y[i] == 0) { fp++; };
            if (preds[i] == 0 && y[i] == 1) { fn_count++; };
            i++;
        };
        var result: int[] = alloc int[3];
        result[0] = tp;
        result[1] = fp;
        result[2] = fn_count;
        return result;
    };

    // ─────────────────────────────────────────
    // sigmoid: 1 / (1 + e^(-z))
    // ─────────────────────────────────────────
    function sigmoid(z: float) -> float {
        return 1.0 / (1.0 + c_exp(0.0 - z));
    };

    // ─────────────────────────────────────────
    // fit: gradient descent with log loss
    // ─────────────────────────────────────────
    function fit(x: float[][], y: int[]) -> null {
        var n: int = x.length;
        var n_features: int = x.cols;

        this.weights = alloc float[n_features];
        var wi: int = 0;
        while (wi < n_features) {
            this.weights[wi] = 0.0;
            wi++;
        };
        this.bias = 0.0;

        var iter: int = 0;
        while (iter < this.iterations) {

            // ── forward pass: sigmoid(Xw + b) ──
            var probs: float[] = alloc float[n];
            var i: int = 0;
            while (i < n) {
                var z: float = this.bias;
                var j: int = 0;
                while (j < n_features) {
                    z = z + x[i][j] * this.weights[j];
                    j++;
                };
                probs[i] = this.sigmoid(z);
                i++;
            };

            // ── residuals: (ŷ - y) ──
            var residuals: float[] = alloc float[n];
            var r: int = 0;
            while (r < n) {
                residuals[r] = probs[r] - float(y[r]);
                r++;
            };

            // ── gradients ──
            var dw: float[] = alloc float[n_features];
            var k: int = 0;
            while (k < n_features) {
                var grad: float = 0.0;
                var m: int = 0;
                while (m < n) {
                    grad = grad + x[m][k] * residuals[m];
                    m++;
                };
                dw[k] = (1.0 / float(n)) * grad;
                k++;
            };

            var db: float = 0.0;
            var s: int = 0;
            while (s < n) {
                db = db + residuals[s];
                s++;
            };
            db = (1.0 / float(n)) * db;

            // ── update ──
            var u: int = 0;
            while (u < n_features) {
                this.weights[u] = this.weights[u] - this.lr * dw[u];
                u++;
            };
            this.bias = this.bias - this.lr * db;

            iter++;
        };
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // predict_probab: raw sigmoid probabilities
    // ─────────────────────────────────────────
    function predict_probab(x: float[][]) -> float[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LogisticClassification): predict_probab called before fit.");
            c_exit(2);
        };
        var n: int = x.length;
        var n_features: int = x.cols;
        var probs: float[] = alloc float[n];
        var i: int = 0;
        while (i < n) {
            var z: float = this.bias;
            var j: int = 0;
            while (j < n_features) {
                z = z + x[i][j] * this.weights[j];
                j++;
            };
            probs[i] = this.sigmoid(z);
            i++;
        };
        return probs;
    };

    // ─────────────────────────────────────────
    // predict: threshold at 0.5
    // ─────────────────────────────────────────
    function predict(x: float[][]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LogisticClassification): predict called before fit.");
            c_exit(2);
        };
        var probs: float[] = this.predict_probab(x);
        var n: int = probs.length;
        var preds: int[] = alloc int[n];
        var i: int = 0;
        while (i < n) {
            if (probs[i] >= 0.5) { preds[i] = 1; };
            if (probs[i] < 0.5)  { preds[i] = 0; };
            i++;
        };
        return preds;
    };

    // ─────────────────────────────────────────
    // accuracy: correct / total
    // ─────────────────────────────────────────
    function accuracy(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LogisticClassification): accuracy called before fit.");
            c_exit(2);
        };
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var correct: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == y[i]) { correct = correct + 1; };
            i++;
        };
        return float(correct) / float(n);
    };

    // ─────────────────────────────────────────
    // precision: TP / (TP + FP)
    // ─────────────────────────────────────────
    function precision(x: float[][], y: int[]) -> float {
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1];
        if (tp + fp == 0) { return 0.0; };
        return float(tp) / float(tp + fp);
    };

    // ─────────────────────────────────────────
    // recall: TP / (TP + FN)
    // ─────────────────────────────────────────
    function recall(x: float[][], y: int[]) -> float {
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fn_count: int = c[2];
        if (tp + fn_count == 0) { return 0.0; };
        return float(tp) / float(tp + fn_count);
    };

    // ─────────────────────────────────────────
    // f1: 2 * precision * recall / (precision + recall)
    // ─────────────────────────────────────────
    function f1(x: float[][], y: int[]) -> float {
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1]; var fn_count: int = c[2];
        var p: float = 0.0; var r: float = 0.0;
        if (tp + fp > 0) { p = float(tp) / float(tp + fp); };
        if (tp + fn_count > 0) { r = float(tp) / float(tp + fn_count); };
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    // ─────────────────────────────────────────
    // summary: classification report
    // ─────────────────────────────────────────
    function summary(x: float[][], y: int[]) -> null {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (LogisticClassification): summary called before fit.");
            c_exit(2);
        };

        var c: int[] = this.confusion(x, y);
        var tp: int = c[0];
        var fp: int = c[1];
        var fn_count: int = c[2];
        var n: int = y.length;
        var tn: int = n - tp - fp - fn_count;
        var n_features: int = x.cols;

        var acc: float = this.accuracy(x, y);
        var prec: float = this.precision(x, y);
        var rec: float = this.recall(x, y);
        var f1_val: float = this.f1(x, y);

        print("==============================================", newLine=true);
        print("     Classification Report", newLine=true);
        print("==============================================", newLine=true);
        print("Accuracy:    " + str(acc), newLine=true);
        print("Precision:   " + str(prec), newLine=true);
        print("Recall:      " + str(rec), newLine=true);
        print("F1 Score:    " + str(f1_val), newLine=true);
        print("n:           " + str(n), newLine=true);
        print("Features:    " + str(n_features), newLine=true);
        print("----------------------------------------------", newLine=true);
        print("Confusion Matrix:", newLine=true);
        print("                 Predicted 0   Predicted 1", newLine=true);
        print("Actual 0         " + str(tn) + "             " + str(fp), newLine=true);
        print("Actual 1         " + str(fn_count) + "             " + str(tp), newLine=true);
        print("----------------------------------------------", newLine=true);
        print("Coef         Value", newLine=true);
        print("----------------------------------------------", newLine=true);
        print("bias         " + str(this.bias), newLine=true);
        var wi: int = 0;
        while (wi < n_features) {
            print("w[" + str(wi) + "]          " + str(this.weights[wi]), newLine=true);
            wi++;
        };
        print("==============================================", newLine=true);
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "LogisticClassification");
        forge_db_write_meta(db, "bias", str(this.bias));
        forge_db_write_meta(db, "lr", str(this.lr));
        forge_db_write_meta(db, "iterations", str(this.iterations));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "weights_len", str(this.weights.length));
        var i: int = 0;
        while (i < this.weights.length) {
            forge_db_write_array(db, "weights", i, str(this.weights[i]));
            i++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.bias = forge_db_read_meta(db, "bias").toFloat();
        this.lr = forge_db_read_meta(db, "lr").toFloat();
        this.iterations = forge_db_read_meta(db, "iterations").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        var wlen: int = forge_db_read_meta(db, "weights_len").toInt();
        this.weights = alloc float[wlen];
        var i: int = 0;
        while (i < wlen) {
            this.weights[i] = forge_db_read_array_cell(db, "weights", i).toFloat();
            i++;
        };
        sqlite3_close(db);
    };
};

class KNNClassifier {
    var k: int;
    var x_train: float[][];
    var y_train: int[];
    var n_train: int;
    var fitted: int;
    var distance_metric: str;
    // add these two fields to the class
    var y_train_reg: float[];
    var reg_mode: int;

    function constructor(k: int) -> null {
        this.k = k;
        this.x_train = alloc float[0][0];
        this.y_train = alloc int[0];
        this.n_train = 0;
        this.fitted = 0;
        this.distance_metric = "euclidean";
        this.y_train_reg = [];
        this.reg_mode = 0;
    };

    //Helper function
    function confusion(x: float[][], y: int[]) -> int[] {
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var tp: int = 0;
        var fp: int = 0;
        var fn_count: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 1 && y[i] == 0) { fp++; };
            if (preds[i] == 0 && y[i] == 1) { fn_count++; };
            i++;
        };
        var result: int[] = alloc int[3];
        result[0] = tp;
        result[1] = fp;
        result[2] = fn_count;
        return result;
    };

    // ─────────────────────────────────────────
    // distance metric selectors
    // ─────────────────────────────────────────
    function use_euclidean() -> null { this.distance_metric = "euclidean"; };
    function use_manhattan() -> null { this.distance_metric = "manhattan"; };
    function use_cosine()    -> null { this.distance_metric = "cosine"; };
    function use_chebyshev() -> null { this.distance_metric = "chebyshev"; };

    // ─────────────────────────────────────────
    // fit: just store training data
    // ─────────────────────────────────────────
    function fit(x: float[][], y: int[]) -> null {
        this.x_train = x;
        this.y_train = y;
        this.n_train = x.length;
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // compute_distance: dispatches to stats lib
    // ─────────────────────────────────────────
    function compute_distance(a: float[], b: float[]) -> float {
        if (this.distance_metric == "euclidean") { return euclidean(a, b); };
        if (this.distance_metric == "manhattan") { return manhattan(a, b); };
        if (this.distance_metric == "cosine")    { return cosine(a, b); };
        if (this.distance_metric == "chebyshev") { return chebyshev(a, b); };
        return euclidean(a, b);
    };

    // ─────────────────────────────────────────
    // predict_one: classify a single sample
    // ─────────────────────────────────────────
    function predict_one(sample: float[]) -> int {
        var n_features: int = sample.length;

        // compute distances to all training points
        var dists: float[] = alloc float[this.n_train];
        var i: int = 0;
        while (i < this.n_train) {
            var row: float[] = this.x_train[i];
            dists[i] = this.compute_distance(sample, row);
            i++;
        };

        // find k nearest — selection sort style
        var visited: int[] = alloc int[this.n_train];
        var vi: int = 0;
        while (vi < this.n_train) { visited[vi] = 0; vi++; };

        var neighbor_labels: int[] = alloc int[this.k];
        var ki: int = 0;
        while (ki < this.k) {
            var min_dist: float = -1.0;
            var min_idx: int = -1;
            var si: int = 0;
            while (si < this.n_train) {
                if (visited[si] == 0) {
                    if (min_idx == -1 || dists[si] < min_dist) {
                        min_dist = dists[si];
                        min_idx = si;
                    };
                };
                si++;
            };
            visited[min_idx] = 1;
            neighbor_labels[ki] = this.y_train[min_idx];
            ki++;
        };

        // majority vote
        var best_label: int = neighbor_labels[0];
        var best_count: int = 0;
        var li: int = 0;
        while (li < this.k) {
            var label: int = neighbor_labels[li];
            var count: int = 0;
            var ci: int = 0;
            while (ci < this.k) {
                if (neighbor_labels[ci] == label) { count++; };
                ci++;
            };
            if (count > best_count) {
                best_count = count;
                best_label = label;
            };
            li++;
        };
        return best_label;
    };

    // ─────────────────────────────────────────
    // predict: classify all samples
    // ─────────────────────────────────────────
    function predict(x: float[][]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (KNNClassification): predict called before fit.");
            c_exit(2);
        };
        var n: int = x.length;
        var preds: int[] = alloc int[n];
        var i: int = 0;
        while (i < n) {
            preds[i] = this.predict_one(x[i]);
            i++;
        };
        return preds;
    };

    // ─────────────────────────────────────────
    // accuracy
    // ─────────────────────────────────────────
    function accuracy(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (KNNClassification): accuracy called before fit.");
            c_exit(2);
        };
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var correct: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == y[i]) { correct++; };
            i++;
        };
        return float(correct) / float(n);
    };

    // ─────────────────────────────────────────
    // precision
    // ─────────────────────────────────────────
    function precision(x: float[][], y: int[]) -> float {
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1];
        if (tp + fp == 0) { return 0.0; };
        return float(tp) / float(tp + fp);
    };

    // ─────────────────────────────────────────
    // recall
    // ─────────────────────────────────────────
    function recall(x: float[][], y: int[]) -> float {
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fn_count: int = c[2];
        if (tp + fn_count == 0) { return 0.0; };
        return float(tp) / float(tp + fn_count);
    };

    // ─────────────────────────────────────────
    // f1
    // ─────────────────────────────────────────
    function f1(x: float[][], y: int[]) -> float {
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1]; var fn_count: int = c[2];
        var p: float = 0.0; var r: float = 0.0;
        if (tp + fp > 0) { p = float(tp) / float(tp + fp); };
        if (tp + fn_count > 0) { r = float(tp) / float(tp + fn_count); };
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    // ─────────────────────────────────────────
    // fit_reg: store training data for regression
    // ─────────────────────────────────────────
    function fit_reg(x: float[][], y: float[]) -> null {
        this.x_train = x;
        this.y_train_reg = y;
        this.n_train = x.length;
        this.reg_mode = 1;
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // predict_reg: mean of k neighbors
    // ─────────────────────────────────────────
    function predict_reg(x: float[][]) -> float[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (KNNClassification): predict_reg called before fit_reg.");
            c_exit(2);
        };
        if (this.reg_mode == 0) {
            c_print_err("MochaForgeError (KNNClassification): predict_reg called but model was fit with fit() not fit_reg(). Use predict() instead.");
            c_exit(2);
        };
        var n: int = x.length;
        var preds: float[] = alloc float[n];
        var i: int = 0;
        while (i < n) {
            // compute distances to all training points
            var dists: float[] = alloc float[this.n_train];
            var ti: int = 0;
            while (ti < this.n_train) {
                dists[ti] = this.compute_distance(x[i], this.x_train[ti]);
                ti++;
            };

            // find k nearest
            var visited: int[] = alloc int[this.n_train];
            var vi: int = 0;
            while (vi < this.n_train) { visited[vi] = 0; vi++; };

            var neighbor_vals: float[] = alloc float[this.k];
            var ki: int = 0;
            while (ki < this.k) {
                var min_dist: float = -1.0;
                var min_idx: int = -1;
                var si: int = 0;
                while (si < this.n_train) {
                    if (visited[si] == 0) {
                        if (min_idx == -1 || dists[si] < min_dist) {
                            min_dist = dists[si];
                            min_idx = si;
                        };
                    };
                    si++;
                };
                visited[min_idx] = 1;
                neighbor_vals[ki] = this.y_train_reg[min_idx];
                ki++;
            };

            // mean of neighbor values
            var sum: float = 0.0;
            var ni: int = 0;
            while (ni < this.k) {
                sum = sum + neighbor_vals[ni];
                ni++;
            };
            preds[i] = sum / float(this.k);
            i++;
        };
        return preds;
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "KNNClassifier");
        forge_db_write_meta(db, "k", str(this.k));
        forge_db_write_meta(db, "n_train", str(this.n_train));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "distance_metric", this.distance_metric);
        forge_db_write_meta(db, "reg_mode", str(this.reg_mode));
        forge_db_write_meta(db, "n_features", str(this.x_train.cols));
        var i: int = 0;
        while (i < this.n_train) {
            forge_db_write_array(db, "y_train", i, str(this.y_train[i]));
            var fi: int = 0;
            while (fi < this.x_train.cols) {
                forge_db_write_array(db, "x_train_" + str(i), fi, str(this.x_train[i][fi]));
                fi++;
            };
            i++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.k = forge_db_read_meta(db, "k").toInt();
        this.n_train = forge_db_read_meta(db, "n_train").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.distance_metric = forge_db_read_meta(db, "distance_metric");
        this.reg_mode = forge_db_read_meta(db, "reg_mode").toInt();
        var n_features: int = forge_db_read_meta(db, "n_features").toInt();
        this.x_train = alloc float[this.n_train][n_features];
        this.y_train = alloc int[this.n_train];
        var i: int = 0;
        while (i < this.n_train) {
            this.y_train[i] = forge_db_read_array_cell(db, "y_train", i).toInt();
            var fi: int = 0;
            while (fi < n_features) {
                this.x_train[i][fi] = forge_db_read_array_cell(db, "x_train_" + str(i), fi).toFloat();
                fi++;
            };
            i++;
        };
        sqlite3_close(db);
    };
};

class KMeans {
    var k: int;
    var centroids: float[][];
    var cluster_labels: int[];
    var n_samples: int;
    var n_features: int;
    var fitted: int;
    var threshold: float;

    function constructor(k: int) -> null {
        this.k = k;
        this.centroids = alloc float[0][0];
        this.cluster_labels = [];
        this.n_samples = 0;
        this.n_features = 0;
        this.fitted = 0;
        this.threshold = 0.0001;
    };

    // ─────────────────────────────────────────
    // set_threshold: override default convergence threshold
    // ─────────────────────────────────────────
    function set_threshold(t: float) -> null {
        this.threshold = t;
    };

    // ─────────────────────────────────────────
    // fit: run KMeans until convergence
    // ─────────────────────────────────────────
    function fit(x: float[][]) -> null {
        var n: int = x.length;
        var n_feat: int = x.cols;
        this.n_samples = n;
        this.n_features = n_feat;

        // ── init: pick k random samples as centroids ──
        rand_seed(42);
        this.centroids = alloc float[this.k][n_feat];
        var used: int[] = alloc int[n];
        var ui: int = 0;
        while (ui < n) { used[ui] = 0; ui++; };

        var ki: int = 0;
        while (ki < this.k) {
            var idx: int = rand_int(0, n - 1);
            // avoid duplicate centroids
            while (used[idx] == 1) {
                idx = rand_int(0, n - 1);
            };
            used[idx] = 1;
            var fi: int = 0;
            var x_ref: float[][] = x;
            while (fi < n_feat) {
                this.centroids[ki][fi] = x_ref[idx][fi];
                fi++;
            };
            ki++;
        };

        // ── iterate until convergence ──
        this.cluster_labels = alloc int[n];
        var converged: int = 0;
        while (converged == 0) {

            // ── assign each sample to nearest centroid ──
            var i: int = 0;
            while (i < n) {
                var best_dist: float = -1.0;
                var best_k: int = 0;
                var ck: int = 0;
                while (ck < this.k) {
                    var dist_sum: float = 0.0;
                    var di: int = 0;
                    var x_r: float[][] = x;
                    var c_r: float[][] = this.centroids;
                    while (di < n_feat) {
                        var diff: float = x_r[i][di] - c_r[ck][di];
                        dist_sum = dist_sum + diff * diff;
                        di++;
                    };
                    if (best_dist < 0.0 || dist_sum < best_dist) {
                        best_dist = dist_sum;
                        best_k = ck;
                    };
                    ck++;
                };
                this.cluster_labels[i] = best_k;
                i++;
            };

            // ── recompute centroids ──
            var new_centroids: float[][] = alloc float[this.k][n_feat];
            var counts: int[] = alloc int[this.k];
            var ci: int = 0;
            while (ci < this.k) {
                counts[ci] = 0;
                var fi2: int = 0;
                while (fi2 < n_feat) {
                    new_centroids[ci][fi2] = 0.0;
                    fi2++;
                };
                ci++;
            };

            var si: int = 0;
            while (si < n) {
                var label: int = this.cluster_labels[si];
                counts[label] = counts[label] + 1;
                var fj: int = 0;
                var x_r2: float[][] = x;
                while (fj < n_feat) {
                    new_centroids[label][fj] = new_centroids[label][fj] + x_r2[si][fj];
                    fj++;
                };
                si++;
            };

            var ck2: int = 0;
            while (ck2 < this.k) {
                if (counts[ck2] > 0) {
                    var fk: int = 0;
                    while (fk < n_feat) {
                        new_centroids[ck2][fk] = new_centroids[ck2][fk] / float(counts[ck2]);
                        fk++;
                    };
                };
                ck2++;
            };

            // ── check convergence ──
            var total_move: float = 0.0;
            var ck3: int = 0;
            var c_r2: float[][] = this.centroids;
            while (ck3 < this.k) {
                var fk2: int = 0;
                while (fk2 < n_feat) {
                    var diff2: float = new_centroids[ck3][fk2] - c_r2[ck3][fk2];
                    if (diff2 < 0.0) { diff2 = 0.0 - diff2; };
                    total_move = total_move + diff2;
                    fk2++;
                };
                ck3++;
            };

            this.centroids = new_centroids;

            if (total_move < this.threshold) {
                converged = 1;
            };
        };
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // labels: return cluster assignments
    // ─────────────────────────────────────────
    function get_labels() -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (KMeans): labels() called before fit.");
            c_exit(2);
        };
        return this.cluster_labels;
    };

    // ─────────────────────────────────────────
    // centroids: return cluster centers
    // ─────────────────────────────────────────
    function get_centroids() -> float[][] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (KMeans): centroids() called before fit.");
            c_exit(2);
        };
        return this.centroids;
    };

    // ─────────────────────────────────────────
    // inertia: sum of squared distances to centroids
    // useful for elbow method to pick k
    // ─────────────────────────────────────────
    function inertia(x: float[][]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (KMeans): inertia() called before fit.");
            c_exit(2);
        };
        var total: float = 0.0;
        var n: int = x.length;
        var i: int = 0;
        while (i < n) {
            var label: int = this.cluster_labels[i];
            var di: int = 0;
            var x_r: float[][] = x;
            var c_r: float[][] = this.centroids;
            while (di < this.n_features) {
                var diff: float = x_r[i][di] - c_r[label][di];
                total = total + diff * diff;
                di++;
            };
            i++;
        };
        return total;
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "KMeans");
        forge_db_write_meta(db, "k", str(this.k));
        forge_db_write_meta(db, "n_samples", str(this.n_samples));
        forge_db_write_meta(db, "n_features", str(this.n_features));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "threshold", str(this.threshold));
        forge_db_write_meta(db, "labels_len", str(this.cluster_labels.length));
        var i: int = 0;
        while (i < this.cluster_labels.length) {
            forge_db_write_array(db, "labels", i, str(this.cluster_labels[i]));
            i++;
        };
        var ci: int = 0;
        while (ci < this.k) {
            var fi: int = 0;
            while (fi < this.n_features) {
                forge_db_write_array(db, "centroids_" + str(ci), fi, str(this.centroids[ci][fi]));
                fi++;
            };
            ci++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.k = forge_db_read_meta(db, "k").toInt();
        this.n_samples = forge_db_read_meta(db, "n_samples").toInt();
        this.n_features = forge_db_read_meta(db, "n_features").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.threshold = forge_db_read_meta(db, "threshold").toFloat();
        var llen: int = forge_db_read_meta(db, "labels_len").toInt();
        this.cluster_labels = alloc int[llen];
        var i: int = 0;
        while (i < llen) {
            this.cluster_labels[i] = forge_db_read_array_cell(db, "labels", i).toInt();
            i++;
        };
        this.centroids = alloc float[this.k][this.n_features];
        var ci: int = 0;
        while (ci < this.k) {
            var fi: int = 0;
            while (fi < this.n_features) {
                this.centroids[ci][fi] = forge_db_read_array_cell(db, "centroids_" + str(ci), fi).toFloat();
                fi++;
            };
            ci++;
        };
        sqlite3_close(db);
    };
};

class DTNode {
    var feature_idx: int;
    var threshold: float;
    var left: DTNode;
    var right: DTNode;
    var is_leaf: int;
    var label: int;

    function constructor(feature_idx: int, threshold: float, left: DTNode, right: DTNode, is_leaf: int, label: int) -> null {
        this.feature_idx = feature_idx;
        this.threshold = threshold;
        this.left = left;
        this.right = right;
        this.is_leaf = is_leaf;
        this.label = label;
    };
};

function dt_leaf(label: int) -> DTNode {
    return DTNode(-1, 0.0, null, null, 1, label);
};

function dt_node(feature_idx: int, threshold: float, left: DTNode, right: DTNode) -> DTNode {
    return DTNode(feature_idx, threshold, left, right, 0, -1);
};

class DecisionTree {
    var max_depth: int;
    var root: DTNode;
    var fitted: int;
    var use_gini: int;

    function constructor(max_depth: int) -> null {
        this.max_depth = max_depth;
        this.root = null;
        this.fitted = 0;
        this.use_gini = 0;
    };

    // ─────────────────────────────────────────
    // fast_gini: switch to gini impurity
    // ─────────────────────────────────────────
    function fast_gini() -> null {
        this.use_gini = 1;
    };

    // ─────────────────────────────────────────
    // gini impurity of a label array
    // ─────────────────────────────────────────
    function gini(y: int[], n: int) -> float {
        if (n == 0) { return 0.0; };
        var n0: int = 0;
        var i: int = 0;
        while (i < n) {
            if (y[i] == 0) { n0++; };
            i++;
        };
        var n1: int = n - n0;
        var p0: float = float(n0) / float(n);
        var p1: float = float(n1) / float(n);
        return 1.0 - (p0 * p0 + p1 * p1);
    };

    // ─────────────────────────────────────────
    // entropy of a label array
    // ─────────────────────────────────────────
    function entropy(y: int[], n: int) -> float {
        if (n == 0) { return 0.0; };
        var n0: int = 0;
        var i: int = 0;
        while (i < n) {
            if (y[i] == 0) { n0++; };
            i++;
        };
        var n1: int = n - n0;
        var p0: float = float(n0) / float(n);
        var p1: float = float(n1) / float(n);
        var result: float = 0.0;
        if (p0 > 0.0) { result = result - p0 * p0.log().real; };
        if (p1 > 0.0) { result = result - p1 * p1.log().real; };
        return result;
    };

    // ─────────────────────────────────────────
    // impurity: dispatches to gini or entropy
    // ─────────────────────────────────────────
    function impurity(y: int[], n: int) -> float {
        if (this.use_gini == 1) { return this.gini(y, n); };
        return this.entropy(y, n);
    };

    // ─────────────────────────────────────────
    // majority label in a set
    // ─────────────────────────────────────────
    function majority(y: int[], n: int) -> int {
        var n0: int = 0;
        var i: int = 0;
        while (i < n) {
            if (y[i] == 0) { n0++; };
            i++;
        };
        var n1: int = n - n0;
        if (n1 >= n0) { return 1; };
        return 0;
    };

    // ─────────────────────────────────────────
    // build: recursive tree construction
    // ─────────────────────────────────────────
    function build(x: float[][], y: int[], n: int, depth: int) -> DTNode {
        var n_features: int = x.cols;

        // ── stop conditions ──
        var n0: int = 0;
        var si: int = 0;
        while (si < n) {
            if (y[si] == 0) { n0++; };
            si++;
        };
        if (n0 == 0) { return dt_leaf(1); };
        if (n0 == n) { return dt_leaf(0); };
        if (depth >= this.max_depth) {
            return dt_leaf(this.majority(y, n));
        };

        // ── find best split ──
        var best_impurity: float = -1.0;
        var best_feature: int = 0;
        var best_threshold: float = 0.0;

        var fi: int = 0;
        while (fi < n_features) {
            var ti: int = 0;
            while (ti < n) {
                var threshold: float = x[ti][fi];

                // split into left and right — pre-allocated to avoid arena corruption
                var left_y: int[] = alloc int[n];
                var right_y: int[] = alloc int[n];
                var nl: int = 0;
                var nr: int = 0;
                var li: int = 0;
                while (li < n) {
                    if (x[li][fi] < threshold) {
                        left_y[nl] = y[li];
                        nl++;
                    };
                    if (x[li][fi] >= threshold) {
                        right_y[nr] = y[li];
                        nr++;
                    };
                    li++;
                };

                if (nl == 0 || nr == 0) {
                    ti++;
                    continue;
                };

                // weighted impurity
                var weighted: float = float(nl) / float(n) * this.impurity(left_y, nl) +
                                    float(nr) / float(n) * this.impurity(right_y, nr);

                if (best_impurity < 0.0 || weighted < best_impurity) {
                    best_impurity = weighted;
                    best_feature = fi;
                    best_threshold = threshold;
                };
                ti++;
            };
            fi++;
        };

        // no valid split found
        if (best_impurity < 0.0) {
            return dt_leaf(this.majority(y, n));
        };

        // ── split data on best feature/threshold ──
        var left_x_list: int[] = alloc int[n];
        var right_x_list: int[] = alloc int[n];
        var left_y2: int[] = alloc int[n];
        var right_y2: int[] = alloc int[n];
        var nl2: int = 0;
        var nr2: int = 0;

        var si2: int = 0;
        while (si2 < n) {
            if (x[si2][best_feature] < best_threshold) {
                left_x_list[nl2] = si2;
                left_y2[nl2] = y[si2];
                nl2++;
            };
            if (x[si2][best_feature] >= best_threshold) {
                right_x_list[nr2] = si2;
                right_y2[nr2] = y[si2];
                nr2++;
            };
            si2++;
        };

        // build left and right submatrices
        var left_x: float[][] = alloc float[nl2][n_features];
        var right_x: float[][] = alloc float[nr2][n_features];

        var lxi: int = 0;
        while (lxi < nl2) {
            var orig_idx: int = left_x_list[lxi];
            var fj: int = 0;
            while (fj < n_features) {
                left_x[lxi][fj] = x[orig_idx][fj];
                fj++;
            };
            lxi++;
        };

        var rxi: int = 0;
        while (rxi < nr2) {
            var orig_idx2: int = right_x_list[rxi];
            var fk: int = 0;
            while (fk < n_features) {
                right_x[rxi][fk] = x[orig_idx2][fk];
                fk++;
            };
            rxi++;
        };

        // ── recurse ──
        var left_node: DTNode = this.build(left_x, left_y2, nl2, depth + 1);
        var right_node: DTNode = this.build(right_x, right_y2, nr2, depth + 1);

        return dt_node(best_feature, best_threshold, left_node, right_node);
    };
    // ─────────────────────────────────────────
    // fit
    // ─────────────────────────────────────────
    function fit(x: float[][], y: int[]) -> null {
        var n: int = x.length;
        var n_feat: int = x.cols;
        this.root = this.build(x, y, n, 0);
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // predict_one: traverse tree for one sample
    // ─────────────────────────────────────────
    function predict_one(sample: float[], node: DTNode) -> int {
        if (node.is_leaf == 1) {
            return node.label;
        };
        var s_r: float[] = sample;
        if (s_r[node.feature_idx] < node.threshold) {
            return this.predict_one(sample, node.left);
        };
        return this.predict_one(sample, node.right);
    };

    // ─────────────────────────────────────────
    // predict
    // ─────────────────────────────────────────
    function predict(x: float[][]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (DecisionTree): predict called before fit.");
            c_exit(2);
        };
        var n: int = x.length;
        var n_features: int = x.cols;
        var preds: int[] = alloc int[n];
        var x_r: float[][] = x;
        var i: int = 0;
        while (i < n) {
            var sample: float[] = alloc float[n_features];
            var j: int = 0;
            while (j < n_features) {
                sample[j] = x_r[i][j];
                j++;
            };
            preds[i] = this.predict_one(sample, this.root);
            i++;
        };
        return preds;
    };

    // ─────────────────────────────────────────
    // confusion helper
    // ─────────────────────────────────────────
    function confusion(x: float[][], y: int[]) -> int[] {
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var tp: int = 0;
        var fp: int = 0;
        var fn_count: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 1 && y[i] == 0) { fp++; };
            if (preds[i] == 0 && y[i] == 1) { fn_count++; };
            i++;
        };
        var result: int[] = alloc int[3];
        result[0] = tp;
        result[1] = fp;
        result[2] = fn_count;
        return result;
    };

    // ─────────────────────────────────────────
    // accuracy
    // ─────────────────────────────────────────
    function accuracy(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (DecisionTree): accuracy called before fit.");
            c_exit(2);
        };
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var correct: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == y[i]) { correct++; };
            i++;
        };
        return float(correct) / float(n);
    };

    // ─────────────────────────────────────────
    // precision, recall, f1
    // ─────────────────────────────────────────
    function precision(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (DecisionTree): precision called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1];
        if (tp + fp == 0) { return 0.0; };
        return float(tp) / float(tp + fp);
    };

    function recall(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (DecisionTree): recall called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fn_count: int = c[2];
        if (tp + fn_count == 0) { return 0.0; };
        return float(tp) / float(tp + fn_count);
    };

    function f1(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (DecisionTree): f1 called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1]; var fn_count: int = c[2];
        var p: float = 0.0; var r: float = 0.0;
        if (tp + fp > 0) { p = float(tp) / float(tp + fp); };
        if (tp + fn_count > 0) { r = float(tp) / float(tp + fn_count); };
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "DecisionTree");
        forge_db_write_meta(db, "max_depth", str(this.max_depth));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "use_gini", str(this.use_gini));
        var counter: int[] = alloc int[1];
        counter[0] = 1;
        forge_serialize_dtnode(db, "root", this.root, 0, counter);
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.max_depth = forge_db_read_meta(db, "max_depth").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.use_gini = forge_db_read_meta(db, "use_gini").toInt();
        this.root = forge_deserialize_dtnode(db, "root", 0);
        sqlite3_close(db);
    };
};

class RandomForest {
    var n_trees: int;
    var max_depth: int;
    var roots: DTNode[];
    var fitted: int;
    var use_gini: int;
    var n_features_total: int;

    function constructor(n_trees: int, max_depth: int) -> null {
        this.n_trees = n_trees;
        this.max_depth = max_depth;
        this.roots = [];
        this.fitted = 0;
        this.use_gini = 0;
        this.n_features_total = 0;
    };

    function fast_gini() -> null {
        this.use_gini = 1;
    };

    // ─────────────────────────────────────────
    // impurity helpers
    // ─────────────────────────────────────────
    function gini(y: int[], n: int) -> float {
        if (n == 0) { return 0.0; };
        var n0: int = 0;
        var i: int = 0;
        while (i < n) {
            if (y[i] == 0) { n0++; };
            i++;
        };
        var n1: int = n - n0;
        var p0: float = float(n0) / float(n);
        var p1: float = float(n1) / float(n);
        return 1.0 - (p0 * p0 + p1 * p1);
    };

    function entropy(y: int[], n: int) -> float {
        if (n == 0) { return 0.0; };
        var n0: int = 0;
        var i: int = 0;
        while (i < n) {
            if (y[i] == 0) { n0++; };
            i++;
        };
        var n1: int = n - n0;
        var p0: float = float(n0) / float(n);
        var p1: float = float(n1) / float(n);
        var result: float = 0.0;
        if (p0 > 0.0) { result = result - p0 * p0.log().real; };
        if (p1 > 0.0) { result = result - p1 * p1.log().real; };
        return result;
    };

    function impurity(y: int[], n: int) -> float {
        if (this.use_gini == 1) { return this.gini(y, n); };
        return this.entropy(y, n);
    };

    function majority(y: int[], n: int) -> int {
        var n0: int = 0;
        var i: int = 0;
        while (i < n) {
            if (y[i] == 0) { n0++; };
            i++;
        };
        var n1: int = n - n0;
        if (n1 >= n0) { return 1; };
        return 0;
    };

    // ─────────────────────────────────────────
    // build_tree: like DT build but with feature subsampling
    // ─────────────────────────────────────────
    function build_tree(x: float[][], y: int[], n: int, depth: int) -> DTNode {
    var n_features: int = x.cols;

    // stop conditions
    var n0: int = 0;
    var si: int = 0;
    while (si < n) {
        if (y[si] == 0) { n0++; };
        si++;
    };
    if (n0 == 0) { return dt_leaf(1); };
    if (n0 == n) { return dt_leaf(0); };
    if (depth >= this.max_depth) {
        return dt_leaf(this.majority(y, n));
    };

    // ── feature subsampling: pick sqrt(n_features) features ──
    var k: int = int(c_sqrt(float(n_features)));
    if (k < 1) { k = 1; };

    var feature_mask: int[] = alloc int[n_features];
    var mi: int = 0;
    while (mi < n_features) { feature_mask[mi] = 0; mi++; };

    var selected: int = 0;
    while (selected < k) {
        var fi: int = rand_int(0, n_features - 1);
        if (feature_mask[fi] == 0) {
            feature_mask[fi] = 1;
            selected++;
        };
    };

    // ── find best split among selected features ──
    var best_impurity: float = -1.0;
    var best_feature: int = 0;
    var best_threshold: float = 0.0;

    var fii: int = 0;
    while (fii < n_features) {
        if (feature_mask[fii] == 0) { fii++; continue; };
        var ti: int = 0;
        while (ti < n) {
            var threshold: float = x[ti][fii];

            var left_y: int[] = alloc int[n];
            var right_y: int[] = alloc int[n];
            var nl: int = 0;
            var nr: int = 0;
            var li: int = 0;
            while (li < n) {
                if (x[li][fii] < threshold) {
                    left_y[nl] = y[li];
                    nl++;
                };
                if (x[li][fii] >= threshold) {
                    right_y[nr] = y[li];
                    nr++;
                };
                li++;
            };

            if (nl == 0 || nr == 0) { ti++; continue; };

            var weighted: float = float(nl) / float(n) * this.impurity(left_y, nl) +
                                  float(nr) / float(n) * this.impurity(right_y, nr);
            if (best_impurity < 0.0 || weighted < best_impurity) {
                best_impurity = weighted;
                best_feature = fii;
                best_threshold = threshold;
            };
            ti++;
        };
        fii++;
    };

    if (best_impurity < 0.0) {
        return dt_leaf(this.majority(y, n));
    };

    // ── split data ──
    var left_x_list: int[] = alloc int[n];
    var right_x_list: int[] = alloc int[n];
    var left_y2: int[] = alloc int[n];
    var right_y2: int[] = alloc int[n];
    var nl2: int = 0;
    var nr2: int = 0;

    var si2: int = 0;
    while (si2 < n) {
        if (x[si2][best_feature] < best_threshold) {
            left_x_list[nl2] = si2;
            left_y2[nl2] = y[si2];
            nl2++;
        };
        if (x[si2][best_feature] >= best_threshold) {
            right_x_list[nr2] = si2;
            right_y2[nr2] = y[si2];
            nr2++;
        };
        si2++;
    };

    var left_x: float[][] = alloc float[nl2][n_features];
    var right_x: float[][] = alloc float[nr2][n_features];

    var lxi: int = 0;
    while (lxi < nl2) {
        var orig_idx: int = left_x_list[lxi];
        var fj: int = 0;
        while (fj < n_features) {
            left_x[lxi][fj] = x[orig_idx][fj];
            fj++;
        };
        lxi++;
    };

    var rxi: int = 0;
    while (rxi < nr2) {
        var orig_idx2: int = right_x_list[rxi];
        var fk: int = 0;
        while (fk < n_features) {
            right_x[rxi][fk] = x[orig_idx2][fk];
            fk++;
        };
        rxi++;
    };

    var left_node: DTNode = this.build_tree(left_x, left_y2, nl2, depth + 1);
    var right_node: DTNode = this.build_tree(right_x, right_y2, nr2, depth + 1);
    return dt_node(best_feature, best_threshold, left_node, right_node);
};

    // ─────────────────────────────────────────
    // fit: bootstrap + build one tree per iteration
    // ─────────────────────────────────────────
    function fit(x: float[][], y: int[]) -> null {
        var n: int = x.length;
        var n_features: int = x.cols;
        this.n_features_total = n_features;
        rand_seed(42);

        var ti: int = 0;
        while (ti < this.n_trees) {
            // bootstrap sample — draw n samples with replacement
            var boot_x: float[][] = alloc float[n][n_features];
            var boot_y: int[] = alloc int[n];
            var x_r: float[][] = x;
            var bi: int = 0;
            while (bi < n) {
                var idx: int = rand_int(0, n - 1);
                var fj: int = 0;
                while (fj < n_features) {
                    boot_x[bi][fj] = x_r[idx][fj];
                    fj++;
                };
                boot_y[bi] = y[idx];
                bi++;
            };

            // build tree on bootstrap sample
            var root: DTNode = this.build_tree(boot_x, boot_y, n, 0);
            this.roots.push(root);
            ti++;
        };
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // predict_one: traverse one tree
    // ─────────────────────────────────────────
    function predict_one_tree(sample: float[], node: DTNode) -> int {
        if (node.is_leaf == 1) { return node.label; };
        var s_r: float[] = sample;
        if (s_r[node.feature_idx] < node.threshold) {
            return this.predict_one_tree(sample, node.left);
        };
        return this.predict_one_tree(sample, node.right);
    };

    // ─────────────────────────────────────────
    // predict: majority vote across all trees
    // ─────────────────────────────────────────
    function predict(x: float[][]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (RandomForest): predict called before fit.");
            c_exit(2);
        };
        var n: int = x.length;
        var n_features: int = x.cols;
        var preds: int[] = alloc int[n];
        var x_r: float[][] = x;
        var i: int = 0;
        while (i < n) {
            // extract sample
            var sample: float[] = alloc float[n_features];
            var j: int = 0;
            while (j < n_features) {
                sample[j] = x_r[i][j];
                j++;
            };
            // vote across trees
            var votes: int = 0;
            var ti: int = 0;
            while (ti < this.n_trees) {
                var root: DTNode = this.roots[ti];
                var vote: int = this.predict_one_tree(sample, root);
                votes = votes + vote;
                ti++;
            };
            // majority vote
            if (votes * 2 >= this.n_trees) {
                preds[i] = 1;
            };
            if (votes * 2 < this.n_trees) {
                preds[i] = 0;
            };
            i++;
        };
        return preds;
    };

    // ─────────────────────────────────────────
    // confusion helper
    // ─────────────────────────────────────────
    function confusion(x: float[][], y: int[]) -> int[] {
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var tp: int = 0;
        var fp: int = 0;
        var fn_count: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 1 && y[i] == 0) { fp++; };
            if (preds[i] == 0 && y[i] == 1) { fn_count++; };
            i++;
        };
        var result: int[] = alloc int[3];
        result[0] = tp;
        result[1] = fp;
        result[2] = fn_count;
        return result;
    };

    // ─────────────────────────────────────────
    // accuracy, precision, recall, f1
    // ─────────────────────────────────────────
    function accuracy(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (RandomForest): accuracy called before fit.");
            c_exit(2);
        };
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var correct: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == y[i]) { correct++; };
            i++;
        };
        return float(correct) / float(n);
    };

    function precision(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (RandomForest): precision called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1];
        if (tp + fp == 0) { return 0.0; };
        return float(tp) / float(tp + fp);
    };

    function recall(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (RandomForest): recall called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fn_count: int = c[2];
        if (tp + fn_count == 0) { return 0.0; };
        return float(tp) / float(tp + fn_count);
    };

    function f1(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (RandomForest): f1 called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1]; var fn_count: int = c[2];
        var p: float = 0.0; var r: float = 0.0;
        if (tp + fp > 0) { p = float(tp) / float(tp + fp); };
        if (tp + fn_count > 0) { r = float(tp) / float(tp + fn_count); };
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "RandomForest");
        forge_db_write_meta(db, "n_trees", str(this.n_trees));
        forge_db_write_meta(db, "max_depth", str(this.max_depth));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "use_gini", str(this.use_gini));
        forge_db_write_meta(db, "n_features_total", str(this.n_features_total));
        var ti: int = 0;
        while (ti < this.n_trees) {
            var counter: int[] = alloc int[1];
            counter[0] = 1;
            var root: DTNode = this.roots[ti];
            forge_serialize_dtnode(db, "tree_" + str(ti), root, 0, counter);
            ti++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.n_trees = forge_db_read_meta(db, "n_trees").toInt();
        this.max_depth = forge_db_read_meta(db, "max_depth").toInt();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.use_gini = forge_db_read_meta(db, "use_gini").toInt();
        this.n_features_total = forge_db_read_meta(db, "n_features_total").toInt();
        this.roots = alloc DTNode[this.n_trees];
        var ti: int = 0;
        while (ti < this.n_trees) {
            this.roots[ti] = forge_deserialize_dtnode(db, "tree_" + str(ti), 0);
            ti++;
        };
        sqlite3_close(db);
    };
};

class Svm {
    // shared
    var mode: str;
    var fitted: int;
    var max_iter: int;
    var bias: float;

    // linear mode
    var weights: float[];
    var lr: float;
    var reg_lamb_da: float;

    // rbf mode
    var alphas: float[];
    var support_x: float[][];
    var support_y: float[];
    var kernel_matrix: float[][];
    var n_train: int;
    var c_param: float;
    var gamma: float;

    function constructor(max_iter: int) -> null {
        this.mode = "lin";
        this.fitted = 0;
        this.max_iter = max_iter;
        this.bias = 0.0;
        this.weights = [];
        this.lr = 0.01;
        this.reg_lamb_da = 0.0;
        this.alphas = [];
        this.support_x = alloc float[0][0];
        this.support_y = [];
        this.kernel_matrix = alloc float[0][0];
        this.n_train = 0;
        this.c_param = 1.0;
        this.gamma = 0.1;
    };

    // ─────────────────────────────────────────
    // mode selectors
    // ─────────────────────────────────────────
    function linear(lr: float) -> null {
        this.mode = "lin";
        this.lr = lr;
    };

    function rbf(c_param: float, gamma: float) -> null {
        this.mode = "rbf";
        this.c_param = c_param;
        this.gamma = gamma;
    };

    function ridge(lamb_da: float) -> null {
        this.reg_lamb_da = lamb_da;
    };

    // ─────────────────────────────────────────
    // rbf kernel
    // ─────────────────────────────────────────
    function kernel(a: float[], b: float[], n_feat: int) -> float {
        var dist: float = 0.0;
        var i: int = 0;
        while (i < n_feat) {
            var diff: float = a[i] - b[i];
            dist = dist + diff * diff;
            i++;
        };
        return c_exp(0.0 - this.gamma * dist);
    };

    // ─────────────────────────────────────────
    // fit
    // ─────────────────────────────────────────
    function fit(x: float[][], y: int[]) -> null {
        if (this.mode == "lin") {
            this.fit_linear(x, y);
        };
        if (this.mode == "rbf") {
            this.fit_rbf(x, y);
        };
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // fit_linear: hinge loss gradient descent
    // ─────────────────────────────────────────
    function fit_linear(x: float[][], y: int[]) -> null {
        var n: int = x.length;
        var n_features: int = x.cols;

        this.weights = alloc float[n_features];
        var wi: int = 0;
        while (wi < n_features) {
            this.weights[wi] = 0.0;
            wi++;
        };
        this.bias = 0.0;

        var iter: int = 0;
        while (iter < this.max_iter) {
            var dw: float[] = alloc float[n_features];
            var db: float = 0.0;
            var ki: int = 0;
            while (ki < n_features) { dw[ki] = 0.0; ki++; };

            var i: int = 0;
            var x_r: float[][] = x;
            var w_r: float[] = this.weights;
            while (i < n) {
                var yi: float = -1.0;
                if (y[i] == 1) { yi = 1.0; };

                var z: float = this.bias;
                var j: int = 0;
                while (j < n_features) {
                    z = z + w_r[j] * x_r[i][j];
                    j++;
                };

                if (yi * z < 1.0) {
                    var k: int = 0;
                    while (k < n_features) {
                        dw[k] = dw[k] - yi * x_r[i][k];
                        k++;
                    };
                    db = db - yi;
                };
                i++;
            };

            var ai: int = 0;
            while (ai < n_features) {
                dw[ai] = dw[ai] / float(n);
                if (this.reg_lamb_da > 0.0) {
                    dw[ai] = dw[ai] + 2.0 * this.reg_lamb_da * this.weights[ai];
                };
                ai++;
            };
            db = db / float(n);

            var ui: int = 0;
            var w_r2: float[] = this.weights;
            while (ui < n_features) {
                w_r2[ui] = w_r2[ui] - this.lr * dw[ui];
                ui++;
            };
            this.bias = this.bias - this.lr * db;
            iter++;
        };
    };

    // ─────────────────────────────────────────
    // fit_rbf: SMO algorithm
    // ─────────────────────────────────────────
    function fit_rbf(x: float[][], y: int[]) -> null {
        var n: int = x.length;
        var n_feat: int = x.cols;
        this.n_train = n;
        this.support_x = x;

        // convert labels to -1/+1
        this.support_y = alloc float[n];
        var li: int = 0;
        while (li < n) {
            if (y[li] == 1) { this.support_y[li] = 1.0; };
            if (y[li] == 0) { this.support_y[li] = -1.0; };
            li++;
        };

        // init alphas to 0
        this.alphas = alloc float[n];
        var ai: int = 0;
        while (ai < n) { this.alphas[ai] = 0.0; ai++; };
        this.bias = 0.0;

        // precompute kernel matrix
        this.kernel_matrix = alloc float[n][n];
        var ki: int = 0;
        while (ki < n) {
            var row_i: float[] = alloc float[n_feat];
            var fi: int = 0;
            var x_r: float[][] = x;
            while (fi < n_feat) {
                row_i[fi] = x_r[ki][fi];
                fi++;
            };
            var kj: int = 0;
            while (kj < n) {
                var row_j: float[] = alloc float[n_feat];
                var fj: int = 0;
                while (fj < n_feat) {
                    row_j[fj] = x_r[kj][fj];
                    fj++;
                };
                this.kernel_matrix[ki][kj] = this.kernel(row_i, row_j, n_feat);
                kj++;
            };
            ki++;
        };

        // SMO iterations
        var iter: int = 0;
        while (iter < this.max_iter) {
            var num_changed: int = 0;
            var i: int = 0;
            while (i < n) {
                // compute error for i
                var ei: float = this.decision_rbf(i) - this.support_y[i];

                // check KKT violation
                var yi: float = this.support_y[i];
                var ai_val: float = this.alphas[i];
                var kkt_violated: int = 0;
                if (yi * ei < -0.001 && ai_val < this.c_param) { kkt_violated = 1; };
                if (yi * ei > 0.001 && ai_val > 0.0) { kkt_violated = 1; };

                if (kkt_violated == 1) {
                    // pick j != i with max |ei - ej|
                    var j: int = 0;
                    var best_j: int = -1;
                    var best_diff: float = -1.0;
                    while (j < n) {
                        if (j != i) {
                            var ej: float = this.decision_rbf(j) - this.support_y[j];
                            var diff: float = ei - ej;
                            if (diff < 0.0) { diff = 0.0 - diff; };
                            if (diff > best_diff) {
                                best_diff = diff;
                                best_j = j;
                            };
                        };
                        j++;
                    };

                    if (best_j == -1) { i++; continue; };

                    var ej2: float = this.decision_rbf(best_j) - this.support_y[best_j];
                    var ai_old: float = this.alphas[i];
                    var aj_old: float = this.alphas[best_j];
                    var yi2: float = this.support_y[i];
                    var yj: float = this.support_y[best_j];

                    // compute bounds L and H
                    var lo: float = 0.0;
                    var hi: float = this.c_param;
                    if (yi2 == yj) {
                        lo = ai_old + aj_old - this.c_param;
                        if (lo < 0.0) { lo = 0.0; };
                        hi = ai_old + aj_old;
                        if (hi > this.c_param) { hi = this.c_param; };
                    };
                    if (yi2 != yj) {
                        lo = aj_old - ai_old;
                        if (lo < 0.0) { lo = 0.0; };
                        hi = this.c_param + aj_old - ai_old;
                        if (hi > this.c_param) { hi = this.c_param; };
                    };

                    if (lo >= hi) { i++; continue; };

                    // eta
                    var eta: float = 2.0 * this.kernel_matrix[i][best_j] -
                                     this.kernel_matrix[i][i] -
                                     this.kernel_matrix[best_j][best_j];
                    if (eta >= 0.0) { i++; continue; };

                    // update aj
                    var aj_new: float = aj_old - yj * (ei - ej2) / eta;
                    if (aj_new < lo) { aj_new = lo; };
                    if (aj_new > hi) { aj_new = hi; };

                    if (aj_new - aj_old < 0.0) {
                        if (aj_old - aj_new < 0.00001) { i++; continue; };
                    };
                    if (aj_new - aj_old >= 0.0) {
                        if (aj_new - aj_old < 0.00001) { i++; continue; };
                    };

                    // update ai
                    var ai_new: float = ai_old + yi2 * yj * (aj_old - aj_new);
                    this.alphas[i] = ai_new;
                    this.alphas[best_j] = aj_new;

                    // update bias
                    var b1: float = this.bias - ei
                                  - yi2 * (ai_new - ai_old) * this.kernel_matrix[i][i]
                                  - yj  * (aj_new - aj_old) * this.kernel_matrix[i][best_j];
                    var b2: float = this.bias - ej2
                                  - yi2 * (ai_new - ai_old) * this.kernel_matrix[i][best_j]
                                  - yj  * (aj_new - aj_old) * this.kernel_matrix[best_j][best_j];

                    if (ai_new > 0.0 && ai_new < this.c_param) {
                        this.bias = b1;
                    };
                    if (aj_new > 0.0 && aj_new < this.c_param) {
                        this.bias = b2;
                    };
                    if (ai_new <= 0.0 || ai_new >= this.c_param) {
                        if (aj_new <= 0.0 || aj_new >= this.c_param) {
                            this.bias = (b1 + b2) / 2.0;
                        };
                    };

                    num_changed++;
                };
                i++;
            };

            if (num_changed == 0) {
                iter = this.max_iter;
            };
            iter++;
        };
    };

    // ─────────────────────────────────────────
    // decision_rbf: f(xᵢ) using precomputed kernel
    // ─────────────────────────────────────────
    function decision_rbf(idx: int) -> float {
        var result: float = this.bias;
        var i: int = 0;
        var a_r: float[] = this.alphas;
        var sy_r: float[] = this.support_y;
        while (i < this.n_train) {
            if (a_r[i] > 0.0) {
                result = result + a_r[i] * sy_r[i] * this.kernel_matrix[idx][i];
            };
        i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // predict
    // ─────────────────────────────────────────
    function predict(x: float[][]) -> int[] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (SVM): predict called before fit.");
            c_exit(2);
        };
        if (this.mode == "lin") { return this.predict_linear(x); };
        return this.predict_rbf(x);
    };

    function predict_linear(x: float[][]) -> int[] {
        var n: int = x.length;
        var n_features: int = x.cols;
        var preds: int[] = alloc int[n];
        var x_r: float[][] = x;
        var w_r: float[] = this.weights;
        var i: int = 0;
        while (i < n) {
            var z: float = this.bias;
            var j: int = 0;
            while (j < n_features) {
                z = z + w_r[j] * x_r[i][j];
                j++;
            };
            if (z >= 0.0) { preds[i] = 1; };
            if (z < 0.0)  { preds[i] = 0; };
            i++;
        };
        return preds;
    };

    function predict_rbf(x: float[][]) -> int[] {
        var n: int = x.length;
        var n_feat: int = x.cols;
        var preds: int[] = alloc int[n];
        var x_r: float[][] = x;
        var sx_r: float[][] = this.support_x;
        var i: int = 0;
        while (i < n) {
            // extract sample
            var sample: float[] = alloc float[n_feat];
            var fi: int = 0;
            while (fi < n_feat) {
                sample[fi] = x_r[i][fi];
                fi++;
            };
            // compute f(x) = sum(alpha_i * y_i * K(x, x_i)) + b
            var result: float = this.bias;
            var j: int = 0;
            var a_r: float[] = this.alphas;
            var sy_r: float[] = this.support_y;
            while (j < this.n_train) {
                if (a_r[j] > 0.0) {
                    var train_row: float[] = alloc float[n_feat];
                    var fj: int = 0;
                    while (fj < n_feat) {
                        train_row[fj] = sx_r[j][fj];
                        fj++;
                    };
                    result = result + a_r[j] * sy_r[j] * this.kernel(sample, train_row, n_feat);
                };
                j++;
            };
            if (result >= 0.0) { preds[i] = 1; };
            if (result < 0.0)  { preds[i] = 0; };
            i++;
        };
        return preds;
    };

    // ─────────────────────────────────────────
    // confusion helper
    // ─────────────────────────────────────────
    function confusion(x: float[][], y: int[]) -> int[] {
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var tp: int = 0;
        var fp: int = 0;
        var fn_count: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 1 && y[i] == 0) { fp++; };
            if (preds[i] == 0 && y[i] == 1) { fn_count++; };
            i++;
        };
        var result: int[] = alloc int[3];
        result[0] = tp;
        result[1] = fp;
        result[2] = fn_count;
        return result;
    };

    // ─────────────────────────────────────────
    // accuracy, precision, recall, f1
    // ─────────────────────────────────────────
    function accuracy(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (SVM): accuracy called before fit.");
            c_exit(2);
        };
        var preds: int[] = this.predict(x);
        var n: int = y.length;
        var correct: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == y[i]) { correct++; };
            i++;
        };
        return float(correct) / float(n);
    };

    function precision(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (SVM): precision called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1];
        if (tp + fp == 0) { return 0.0; };
        return float(tp) / float(tp + fp);
    };

    function recall(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (SVM): recall called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fn_count: int = c[2];
        if (tp + fn_count == 0) { return 0.0; };
        return float(tp) / float(tp + fn_count);
    };

    function f1(x: float[][], y: int[]) -> float {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (SVM): f1 called before fit.");
            c_exit(2);
        };
        var c: int[] = this.confusion(x, y);
        var tp: int = c[0]; var fp: int = c[1]; var fn_count: int = c[2];
        var p: float = 0.0; var r: float = 0.0;
        if (tp + fp > 0) { p = float(tp) / float(tp + fp); };
        if (tp + fn_count > 0) { r = float(tp) / float(tp + fn_count); };
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "Svm");
        forge_db_write_meta(db, "mode", this.mode);
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "max_iter", str(this.max_iter));
        forge_db_write_meta(db, "bias", str(this.bias));
        forge_db_write_meta(db, "lr", str(this.lr));
        forge_db_write_meta(db, "reg_lamb_da", str(this.reg_lamb_da));
        forge_db_write_meta(db, "n_train", str(this.n_train));
        forge_db_write_meta(db, "c_param", str(this.c_param));
        forge_db_write_meta(db, "gamma", str(this.gamma));
        forge_db_write_meta(db, "weights_len", str(this.weights.length));
        forge_db_write_meta(db, "n_support", str(this.support_y.length));
        forge_db_write_meta(db, "n_features", str(this.support_x.cols));
        var i: int = 0;
        while (i < this.weights.length) {
            forge_db_write_array(db, "weights", i, str(this.weights[i]));
            i++;
        };
        var ai: int = 0;
        while (ai < this.alphas.length) {
            forge_db_write_array(db, "alphas", ai, str(this.alphas[ai]));
            ai++;
        };
        var si: int = 0;
        while (si < this.support_y.length) {
            forge_db_write_array(db, "support_y", si, str(this.support_y[si]));
            var fi: int = 0;
            while (fi < this.support_x.cols) {
                forge_db_write_array(db, "support_x_" + str(si), fi, str(this.support_x[si][fi]));
                fi++;
            };
            si++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.mode = forge_db_read_meta(db, "mode");
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.max_iter = forge_db_read_meta(db, "max_iter").toInt();
        this.bias = forge_db_read_meta(db, "bias").toFloat();
        this.lr = forge_db_read_meta(db, "lr").toFloat();
        this.reg_lamb_da = forge_db_read_meta(db, "reg_lamb_da").toFloat();
        this.n_train = forge_db_read_meta(db, "n_train").toInt();
        this.c_param = forge_db_read_meta(db, "c_param").toFloat();
        this.gamma = forge_db_read_meta(db, "gamma").toFloat();
        var wlen: int = forge_db_read_meta(db, "weights_len").toInt();
        var n_support: int = forge_db_read_meta(db, "n_support").toInt();
        var n_features: int = forge_db_read_meta(db, "n_features").toInt();
        this.weights = alloc float[wlen];
        this.alphas = alloc float[n_support];
        this.support_y = alloc float[n_support];
        this.support_x = alloc float[n_support][n_features];
        var i: int = 0;
        while (i < wlen) {
            this.weights[i] = forge_db_read_array_cell(db, "weights", i).toFloat();
            i++;
        };
        var ai: int = 0;
        while (ai < n_support) {
            this.alphas[ai] = forge_db_read_array_cell(db, "alphas", ai).toFloat();
            ai++;
        };
        var si: int = 0;
        while (si < n_support) {
            this.support_y[si] = forge_db_read_array_cell(db, "support_y", si).toFloat();
            var fi: int = 0;
            while (fi < n_features) {
                this.support_x[si][fi] = forge_db_read_array_cell(db, "support_x_" + str(si), fi).toFloat();
                fi++;
            };
            si++;
        };
        sqlite3_close(db);
    };
};

//Utilities
class TrainTestSplit {
    var x_train: float[][];
    var x_test: float[][];
    var y_train: int[];
    var y_test: int[];
    var n_train: int;
    var n_test: int;

    function constructor(x_train: float[][], x_test: float[][], y_train: int[], y_test: int[], n_train: int, n_test: int) -> null {
        this.x_train = x_train;
        this.x_test = x_test;
        this.y_train = y_train;
        this.y_test = y_test;
        this.n_train = n_train;
        this.n_test = n_test;
    };
};

function train_test_split(x: float[][], y: int[], test_size: float, seed: int) -> TrainTestSplit {
    var n: int = x.length;
    var n_features: int = x.cols;
    var n_test: int = int(float(n) * test_size);
    var n_train: int = n - n_test;

    if (n_test < 1) {
        c_print_err("MochaForgeError (train_test_split): test_size too small, results in 0 test samples.");
        c_exit(2);
    };
    if (n_train < 1) {
        c_print_err("MochaForgeError (train_test_split): test_size too large, results in 0 train samples.");
        c_exit(2);
    };

    // ── shuffle indices ──
    // in train_test_split and cross_val_split
    if (seed == -999999) { rand_seed(crypto_rand_seed()); };
    if (seed != -999999) { rand_seed(seed); };
    var indices: int[] = alloc int[n];
    var ii: int = 0;
    while (ii < n) { indices[ii] = ii; ii++; };

    // Fisher-Yates shuffle
    var si: int = n - 1;
    while (si > 0) {
        var rj: int = rand_int(0, si);
        var tmp: int = indices[si];
        indices[si] = indices[rj];
        indices[rj] = tmp;
        si--;
    };

    // ── split into train and test ──
    var x_train: float[][] = alloc float[n_train][n_features];
    var x_test: float[][] = alloc float[n_test][n_features];
    var y_train: int[] = alloc int[n_train];
    var y_test: int[] = alloc int[n_test];

    var x_r: float[][] = x;
    var ti: int = 0;
    while (ti < n_train) {
        var orig: int = indices[ti];
        var fi: int = 0;
        while (fi < n_features) {
            x_train[ti][fi] = x_r[orig][fi];
            fi++;
        };
        y_train[ti] = y[orig];
        ti++;
    };

    var tsi: int = 0;
    while (tsi < n_test) {
        var orig2: int = indices[n_train + tsi];
        var fi2: int = 0;
        while (fi2 < n_features) {
            x_test[tsi][fi2] = x_r[orig2][fi2];
            fi2++;
        };
        y_test[tsi] = y[orig2];
        tsi++;
    };

    return TrainTestSplit(x_train, x_test, y_train, y_test, n_train, n_test);
};

function cross_val_split(x: float[][], y: int[], k: int, seed: int) -> TrainTestSplit[] {
    var n: int = x.length;
    var n_features: int = x.cols;

    if (k < 2) {
        c_print_err("MochaForgeError (cross_val_split): k must be at least 2.");
        c_exit(2);
    };
    if (k > n) {
        c_print_err("MochaForgeError (cross_val_split): k cannot be greater than number of samples.");
        c_exit(2);
    };

    // ── shuffle indices ──
    // in train_test_split and cross_val_split
    if (seed == -999999) { rand_seed(crypto_rand_seed()); };
    if (seed != -999999) { rand_seed(seed); };
    var indices: int[] = alloc int[n];
    var ii: int = 0;
    while (ii < n) { indices[ii] = ii; ii++; };

    var si: int = n - 1;
    while (si > 0) {
        var rj: int = rand_int(0, si);
        var tmp: int = indices[si];
        indices[si] = indices[rj];
        indices[rj] = tmp;
        si--;
    };

    var fold_size: int = n / k;
    var remainder: int = n % k;
    var folds: TrainTestSplit[] = alloc TrainTestSplit[k];

    var fi: int = 0;
    while (fi < k) {
        // test fold start and end
        var test_start: int = fi * fold_size;
        var test_end: int = test_start + fold_size;
        // last fold gets remainder
        if (fi == k - 1) { test_end = test_end + remainder; };

        var n_test: int = test_end - test_start;
        var n_train: int = n - n_test;

        var x_train: float[][] = alloc float[n_train][n_features];
        var x_test: float[][] = alloc float[n_test][n_features];
        var y_train: int[] = alloc int[n_train];
        var y_test: int[] = alloc int[n_test];

        // fill test
        var ti: int = 0;
        while (ti < n_test) {
            var orig: int = indices[test_start + ti];
            var fj: int = 0;
            while (fj < n_features) {
                x_test[ti][fj] = x[orig][fj];
                fj++;
            };
            y_test[ti] = y[orig];
            ti++;
        };

        // fill train — everything before and after test fold
        var tri: int = 0;
        var si2: int = 0;
        while (si2 < test_start) {
            var orig2: int = indices[si2];
            var fk: int = 0;
            while (fk < n_features) {
                x_train[tri][fk] = x[orig2][fk];
                fk++;
            };
            y_train[tri] = y[orig2];
            tri++;
            si2++;
        };
        var si3: int = test_end;
        while (si3 < n) {
            var orig3: int = indices[si3];
            var fl: int = 0;
            while (fl < n_features) {
                x_train[tri][fl] = x[orig3][fl];
                fl++;
            };
            y_train[tri] = y[orig3];
            tri++;
            si3++;
        };

        folds[fi] = TrainTestSplit(x_train, x_test, y_train, y_test, n_train, n_test);
        fi++;
    };

    return folds;
};

class ConfusionMatrix {
    var tp_val: int;
    var fp_val: int;
    var fn_val: int;
    var tn_val: int;

    function constructor(tp: int, fp: int, fn: int, tn: int) -> null {
        this.tp_val = tp;
        this.fp_val = fp;
        this.fn_val = fn;
        this.tn_val = tn;
    };

    function tp() -> int { return this.tp_val; };
    function fp() -> int { return this.fp_val; };
    function fn() -> int { return this.fn_val; };
    function tn() -> int { return this.tn_val; };

    function accuracy() -> float {
        var total: int = this.tp_val + this.fp_val + this.fn_val + this.tn_val;
        if (total == 0) { return 0.0; };
        return float(this.tp_val + this.tn_val) / float(total);
    };

    function precision() -> float {
        if (this.tp_val + this.fp_val == 0) { return 0.0; };
        return float(this.tp_val) / float(this.tp_val + this.fp_val);
    };

    function recall() -> float {
        if (this.tp_val + this.fn_val == 0) { return 0.0; };
        return float(this.tp_val) / float(this.tp_val + this.fn_val);
    };

    function f1() -> float {
        var p: float = this.precision();
        var r: float = this.recall();
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    function pad(n: int, width: int) -> str {
        var s: str = str(n);
        var result: str = s;
        var i: int = s.length;
        while (i < width) {
            result = " " + result;
            i++;
        };
        return result;
    };

    function print_matrix() -> null {
        var tn: str = this.pad(this.tn_val, 5);
        var fp: str = this.pad(this.fp_val, 5);
        var fn_: str = this.pad(this.fn_val, 5);
        var tp: str = this.pad(this.tp_val, 5);

        print("┌──────────────────────────────────┐", newLine=true);
        print("│         Confusion Matrix         │", newLine=true);
        print("├────────────────┬────────┬────────┤", newLine=true);
        print("│                │  Pred 0│  Pred 1│", newLine=true);
        print("├────────────────┼────────┼────────┤", newLine=true);
        print("│ Actual 0       │" + tn + "   │" + fp + "   │", newLine=true);
        print("│ Actual 1       │" + fn_ + "   │" + tp + "   │", newLine=true);
        print("└────────────────┴────────┴────────┘", newLine=true);
        print("Accuracy:  " + str(this.accuracy()), newLine=true);
        print("Precision: " + str(this.precision()), newLine=true);
        print("Recall:    " + str(this.recall()), newLine=true);
        print("F1:        " + str(this.f1()), newLine=true);
    };
};

function confusion_matrix(y_true: int[], y_pred: int[]) -> ConfusionMatrix {
    if (y_true.length != y_pred.length) {
        c_print_err("MochaForgeError (confusion_matrix): y_true and y_pred must be same length.");
        c_exit(2);
    };
    var tp: int = 0;
    var fp: int = 0;
    var fn: int = 0;
    var tn: int = 0;
    var i: int = 0;
    while (i < y_true.length) {
        if (y_pred[i] == 1 && y_true[i] == 1) { tp++; };
        if (y_pred[i] == 1 && y_true[i] == 0) { fp++; };
        if (y_pred[i] == 0 && y_true[i] == 1) { fn++; };
        if (y_pred[i] == 0 && y_true[i] == 0) { tn++; };
        i++;
    };
    return ConfusionMatrix(tp, fp, fn, tn);
};

class PolynomialFeatures {
    var degree: int;
    var use_inter_only: int;
    var n_input_features: int;
    var n_output_features: int;
    var fitted: int;
    // store feature pairs/triples as encoded indices
    // each combo stored as "i,j" or "i,j,k" in a str[]
    var combos: str[];
    var n_combos: int;

    function constructor(degree: int) -> null {
        this.degree = degree;
        this.use_inter_only = 0;
        this.n_input_features = 0;
        this.n_output_features = 0;
        this.fitted = 0;
        this.combos = [];
        this.n_combos = 0;
    };

    function inter_only() -> null {
        this.use_inter_only = 1;
    };

    // ─────────────────────────────────────────
    // fit: compute output feature count
    // ─────────────────────────────────────────
    function fit(x: float[][]) -> null {
        var n_feat: int = x.cols;
        this.n_input_features = n_feat;

        // max possible combos = n³ is safe upper bound
        var max_combos: int = n_feat * n_feat * n_feat + n_feat * n_feat + n_feat;
        var combo_list: str[] = alloc str[max_combos];
        var n_found: int = 0;

        // degree 1
        var i: int = 0;
        while (i < n_feat) {
            combo_list[n_found] = str(i) + ",";
            n_found++;
            i++;
        };

        // degree 2
        if (this.degree >= 2) {
            var a: int = 0;
            while (a < n_feat) {
                var b: int = 0;
                if (this.use_inter_only == 1) { b = a + 1; };
                if (this.use_inter_only == 0) { b = a; };
                while (b < n_feat) {
                    combo_list[n_found] = str(a) + "," + str(b) + ",";
                    n_found++;
                    b++;
                };
                a++;
            };
        };

        // degree 3
        if (this.degree >= 3) {
            var p: int = 0;
            while (p < n_feat) {
                var q: int = 0;
                if (this.use_inter_only == 1) { q = p + 1; };
                if (this.use_inter_only == 0) { q = p; };
                while (q < n_feat) {
                    var r: int = 0;
                    if (this.use_inter_only == 1) { r = q + 1; };
                    if (this.use_inter_only == 0) { r = q; };
                    while (r < n_feat) {
                        combo_list[n_found] = str(p) + "," + str(q) + "," + str(r) + ",";
                        n_found++;
                        r++;
                    };
                    q++;
                };
                p++;
            };
        };

        this.combos = combo_list;
        this.n_combos = n_found;
        this.n_output_features = n_found;
        this.fitted = 1;
    };

    // ─────────────────────────────────────────
    // decode_index: extract i-th integer from
    // encoded combo string "a,b,c,"
    // ─────────────────────────────────────────
    function decode_index(encoded: str, idx: int) -> int {
        var current: str = "";
        var count: int = 0;
        var i: int = 0;
        while (i < encoded.length) {
            var ch: str = encoded.charAt(i);
            if (ch == ",") {
                if (count == idx) { return current.toInt(); };
                current = "";
                count++;
            } else {
                current = current + ch;
            };
            i++;
        };
        return -1;
    };

    // ─────────────────────────────────────────
    // count_indices: count how many indices
    // are in an encoded combo string
    // ─────────────────────────────────────────
    function count_indices(encoded: str) -> int {
        var count: int = 0;
        var i: int = 0;
        while (i < encoded.length) {
            if (encoded.charAt(i) == ",") { count++; };
            i++;
        };
        return count;
    };

    // ─────────────────────────────────────────
    // transform: apply polynomial expansion
    // ─────────────────────────────────────────
    function transform(x: float[][]) -> float[][] {
        if (this.fitted == 0) {
            c_print_err("MochaForgeError (PolynomialFeatures): transform called before fit.");
            c_exit(2);
        };
        var n: int = x.length;
        var result: float[][] = alloc float[n][this.n_output_features];

        var i: int = 0;
        while (i < n) {
            var ci: int = 0;
            while (ci < this.n_combos) {
                var encoded: str = this.combos[ci];
                var n_idx: int = this.count_indices(encoded);
                var val: float = 1.0;
                var ii: int = 0;
                while (ii < n_idx) {
                    var feat_idx: int = this.decode_index(encoded, ii);
                    val = val * x[i][feat_idx];
                    ii++;
                };
                result[i][ci] = val;
                ci++;
            };
            i++;
        };
        return result;
    };

    // ─────────────────────────────────────────
    // fit_transform: fit then transform
    // ─────────────────────────────────────────
    function fit_transform(x: float[][]) -> float[][] {
        this.fit(x);
        return this.transform(x);
    };
};

// =============================================
// SURROGATE NODE
// =============================================
class SurrogateNode {
    var is_leaf: int;
    var value: float;
    var feature_idx: int;
    var threshold: float;
    var left: SurrogateNode;
    var right: SurrogateNode;

    function constructor(is_leaf: int, value: float, feature_idx: int, threshold: float, left: SurrogateNode, right: SurrogateNode) -> null {
        this.is_leaf = is_leaf;
        this.value = value;
        this.feature_idx = feature_idx;
        this.threshold = threshold;
        this.left = left;
        this.right = right;
    };
};

function surrogate_leaf(value: float) -> SurrogateNode {
    return SurrogateNode(1, value, 0, 0.0, null, null);
};

function surrogate_node(feature_idx: int, threshold: float, left: SurrogateNode, right: SurrogateNode) -> SurrogateNode {
    return SurrogateNode(0, 0.0, feature_idx, threshold, left, right);
};

// =============================================
// SURROGATE RF
// =============================================
class SurrogateRF {
    var n_trees: int;
    var max_depth: int;
    var roots: SurrogateNode[];
    var n_features: int;
    var fitted: int;

    function constructor(n_trees: int, max_depth: int) -> null {
        this.n_trees = n_trees;
        this.max_depth = max_depth;
        this.roots = alloc SurrogateNode[n_trees];
        this.n_features = 0;
        this.fitted = 0;
    };

    function build_surrogate(x: float[][], y: float[], n: int, depth: int) -> SurrogateNode {
        var n_features: int = x.cols;

        // leaf conditions
        if (n <= 1 || depth >= this.max_depth) {
            var sum: float = 0.0;
            var i: int = 0;
            while (i < n) { sum = sum + y[i]; i++; };
            return surrogate_leaf(sum / float(n));
        };

        // feature subsampling
        var k: int = int(c_sqrt(float(n_features)));
        if (k < 1) { k = 1; };
        var feature_mask: int[] = alloc int[n_features];
        var mi: int = 0;
        while (mi < n_features) { feature_mask[mi] = 0; mi++; };
        var selected: int = 0;
        while (selected < k) {
            var fi: int = rand_int(0, n_features - 1);
            if (feature_mask[fi] == 0) {
                feature_mask[fi] = 1;
                selected++;
            };
        };

        // find best split by variance reduction
        var best_score: float = -1.0;
        var best_feature: int = 0;
        var best_threshold: float = 0.0;

        var fii: int = 0;
        while (fii < n_features) {
            if (feature_mask[fii] == 0) { fii++; continue; };
            var ti: int = 0;
            while (ti < n) {
                var threshold: float = x[ti][fii];
                var left_y: float[] = alloc float[n];
                var right_y: float[] = alloc float[n];
                var nl: int = 0;
                var nr: int = 0;
                var li: int = 0;
                while (li < n) {
                    if (x[li][fii] < threshold) {
                        left_y[nl] = y[li]; nl++;
                    };
                    if (x[li][fii] >= threshold) {
                        right_y[nr] = y[li]; nr++;
                    };
                    li++;
                };
                if (nl == 0 || nr == 0) { ti++; continue; };

                var lsum: float = 0.0;
                var rsum: float = 0.0;
                var li2: int = 0;
                while (li2 < nl) { lsum = lsum + left_y[li2]; li2++; };
                var ri2: int = 0;
                while (ri2 < nr) { rsum = rsum + right_y[ri2]; ri2++; };
                var lmean: float = lsum / float(nl);
                var rmean: float = rsum / float(nr);

                var lvar: float = 0.0;
                var li3: int = 0;
                while (li3 < nl) {
                    var d: float = left_y[li3] - lmean;
                    lvar = lvar + d * d;
                    li3++;
                };
                var rvar: float = 0.0;
                var ri3: int = 0;
                while (ri3 < nr) {
                    var d2: float = right_y[ri3] - rmean;
                    rvar = rvar + d2 * d2;
                    ri3++;
                };

                var score: float = 0.0 - (lvar + rvar);
                if (best_score < 0.0 || score > best_score) {
                    best_score = score;
                    best_feature = fii;
                    best_threshold = threshold;
                };
                ti++;
            };
            fii++;
        };

        // no valid split
        if (best_score < 0.0) {
            var sum2: float = 0.0;
            var i2: int = 0;
            while (i2 < n) { sum2 = sum2 + y[i2]; i2++; };
            return surrogate_leaf(sum2 / float(n));
        };

        // split data
        var left_x_list: int[] = alloc int[n];
        var right_x_list: int[] = alloc int[n];
        var left_y2: float[] = alloc float[n];
        var right_y2: float[] = alloc float[n];
        var nl2: int = 0;
        var nr2: int = 0;
        var si2: int = 0;
        while (si2 < n) {
            if (x[si2][best_feature] < best_threshold) {
                left_x_list[nl2] = si2;
                left_y2[nl2] = y[si2];
                nl2++;
            };
            if (x[si2][best_feature] >= best_threshold) {
                right_x_list[nr2] = si2;
                right_y2[nr2] = y[si2];
                nr2++;
            };
            si2++;
        };

        var left_x: float[][] = alloc float[nl2][n_features];
        var right_x: float[][] = alloc float[nr2][n_features];
        var lxi: int = 0;
        while (lxi < nl2) {
            var orig: int = left_x_list[lxi];
            var fj: int = 0;
            while (fj < n_features) {
                left_x[lxi][fj] = x[orig][fj];
                fj++;
            };
            lxi++;
        };
        var rxi: int = 0;
        while (rxi < nr2) {
            var orig2: int = right_x_list[rxi];
            var fk: int = 0;
            while (fk < n_features) {
                right_x[rxi][fk] = x[orig2][fk];
                fk++;
            };
            rxi++;
        };

        var left_node: SurrogateNode = this.build_surrogate(left_x, left_y2, nl2, depth + 1);
        var right_node: SurrogateNode = this.build_surrogate(right_x, right_y2, nr2, depth + 1);
        return surrogate_node(best_feature, best_threshold, left_node, right_node);
    };

    function predict_one_surrogate(sample: float[], node: SurrogateNode) -> float {
        if (node.is_leaf == 1) { return node.value; };
        if (sample[node.feature_idx] < node.threshold) {
            return this.predict_one_surrogate(sample, node.left);
        };
        return this.predict_one_surrogate(sample, node.right);
    };

    function fit_surrogate(x: float[][], y: float[], n: int) -> null {
        this.n_features = x.cols;
        var ti: int = 0;
        while (ti < this.n_trees) {
            var boot_x: float[][] = alloc float[n][this.n_features];
            var boot_y: float[] = alloc float[n];
            var bi: int = 0;
            while (bi < n) {
                var idx: int = rand_int(0, n - 1);
                var fj: int = 0;
                while (fj < this.n_features) {
                    boot_x[bi][fj] = x[idx][fj];
                    fj++;
                };
                boot_y[bi] = y[idx];
                bi++;
            };
            this.roots[ti] = this.build_surrogate(boot_x, boot_y, n, 0);
            ti++;
        };
        this.fitted = 1;
    };

    function predict_mean(sample: float[]) -> float {
        var sum: float = 0.0;
        var ti: int = 0;
        while (ti < this.n_trees) {
            sum = sum + this.predict_one_surrogate(sample, this.roots[ti]);
            ti++;
        };
        return sum / float(this.n_trees);
    };

    function predict_variance(sample: float[]) -> float {
        var mean: float = this.predict_mean(sample);
        var var_sum: float = 0.0;
        var ti: int = 0;
        while (ti < this.n_trees) {
            var pred: float = this.predict_one_surrogate(sample, this.roots[ti]);
            var diff: float = pred - mean;
            var_sum = var_sum + diff * diff;
            ti++;
        };
        return var_sum / float(this.n_trees);
    };
};

// =============================================
// PARAM SPEC
// =============================================
class ParamSpec {
    var name: str;
    var low: float;
    var high: float;
    var is_int: int;

    function constructor(name: str, low: float, high: float, is_int: int) -> null {
        this.name = name;
        this.low = low;
        this.high = high;
        this.is_int = is_int;
    };
};

// =============================================
// SEARCH RESULT
// =============================================
class SearchResult {
    var best_params: float[];
    var best_score: float;
    var n_params: int;

    function constructor(best_params: float[], best_score: float, n_params: int) -> null {
        this.best_params = best_params;
        this.best_score = best_score;
        this.n_params = n_params;
    };

    function print_result() -> null {
        print("Best score: " + str(this.best_score), newLine=true);
        var i: int = 0;
        while (i < this.n_params) {
            print("  param[" + str(i) + "]: " + str(this.best_params[i]), newLine=true);
            i++;
        };
    };
};

// =============================================
// BAYESIAN SEARCH
// =============================================
class BayesianSearch {
    var n_warmup: int;
    var n_iterations: int;
    var params: ParamSpec[];
    var n_params: int;
    var history_x: float[][];
    var history_y: float[];
    var n_history: int;
    var max_history: int;

    function constructor(n_warmup: int, n_iterations: int) -> null {
        this.n_warmup = n_warmup;
        this.n_iterations = n_iterations;
        this.n_params = 0;
        this.params = alloc ParamSpec[16];
        this.max_history = n_warmup + n_iterations;
        this.history_x = alloc float[this.max_history][16];
        this.history_y = alloc float[this.max_history];
        this.n_history = 0;
    };

    function add_int_param(name: str, low: int, high: int) -> null {
        this.params[this.n_params] = ParamSpec(name, float(low), float(high), 1);
        this.n_params = this.n_params + 1;
    };

    function add_float_param(name: str, low: float, high: float) -> null {
        this.params[this.n_params] = ParamSpec(name, low, high, 0);
        this.n_params = this.n_params + 1;
    };

    function sample_random() -> float[] {
        var point: float[] = alloc float[this.n_params];
        var i: int = 0;
        while (i < this.n_params) {
            var p: ParamSpec = this.params[i];
            if (p.is_int == 1) {
                point[i] = float(rand_int(int(p.low), int(p.high)));
            };
            if (p.is_int == 0) {
                point[i] = rand_float(p.low, p.high);
            };
            i++;
        };
        return point;
    };

    function ei(mean: float, variance: float, best: float) -> float {
        if (variance <= 0.0) { return 0.0; };
        var std: float = c_sqrt(variance);
        var z: float = (mean - best) / std;
        var phi_z: float = 1.0 / (1.0 + c_exp(0.0 - 1.7 * z));
        var pdf_z: float = c_exp(0.0 - 0.5 * z * z) / 2.506628;
        return (mean - best) * phi_z + std * pdf_z;
    };

    function next_point(surrogate: SurrogateRF, best_score: float) -> float[] {
        var n_candidates: int = 100;
        var best_ei: float = -1.0;
        var best_point: float[] = this.sample_random();
        var ci: int = 0;
        while (ci < n_candidates) {
            var candidate: float[] = this.sample_random();
            var mean: float = surrogate.predict_mean(candidate);
            var variance: float = surrogate.predict_variance(candidate);
            var ei_val: float = this.ei(mean, variance, best_score);
            if (best_ei < 0.0 || ei_val > best_ei) {
                best_ei = ei_val;
                best_point = candidate;
            };
            ci++;
        };
        return best_point;
    };

    function eval_knn(params: float[], x: float[][], y: int[], folds: TrainTestSplit[]) -> float {
        var k: int = int(params[0]);
        if (k < 1) { k = 1; };
        var n_folds: int = folds.length;
        var score_sum: float = 0.0;
        var fi: int = 0;
        while (fi < n_folds) {
            var fold: TrainTestSplit = folds[fi];
            var safe_k: int = k;
            if (safe_k > fold.n_train) { safe_k = fold.n_train; };
            var model: KNNClassifier = KNNClassifier(safe_k);
            model.fit(fold.x_train, fold.y_train);
            var acc: float = model.accuracy(fold.x_test, fold.y_test);
            score_sum = score_sum + acc;
            fi++;
        };
        return score_sum / float(n_folds);
    };

    function eval_dt(params: float[], x: float[][], y: int[], folds: TrainTestSplit[]) -> float {
        var max_depth: int = int(params[0]);
        if (max_depth < 1) { max_depth = 1; };
        var n_folds: int = folds.length;
        var score_sum: float = 0.0;
        var fi: int = 0;
        while (fi < n_folds) {
            var fold: TrainTestSplit = folds[fi];
            var model: DecisionTree = DecisionTree(max_depth);
            model.fit(fold.x_train, fold.y_train);
            var acc: float = model.accuracy(fold.x_test, fold.y_test);
            score_sum = score_sum + acc;
            fi++;
        };
        return score_sum / float(n_folds);
    };

    function eval_svm(params: float[], x: float[][], y: int[], folds: TrainTestSplit[]) -> float {
        var lr: float = params[0];
        var iterations: int = int(params[1]);
        if (iterations < 1) { iterations = 1; };
        var n_folds: int = folds.length;
        var score_sum: float = 0.0;
        var fi: int = 0;
        while (fi < n_folds) {
            var fold: TrainTestSplit = folds[fi];
            var model: Svm = Svm(iterations);
            model.linear(lr);
            model.fit(fold.x_train, fold.y_train);
            var acc: float = model.accuracy(fold.x_test, fold.y_test);
            score_sum = score_sum + acc;
            fi++;
        };
        return score_sum / float(n_folds);
    };

    function run_search(x: float[][], y: int[], folds: TrainTestSplit[], mode: int) -> SearchResult {
        rand_seed(42);
        var best_score: float = -1.0;
        var best_params: float[] = alloc float[this.n_params];

        // warmup
        var wi: int = 0;
        while (wi < this.n_warmup) {
            var point: float[] = this.sample_random();
            var score: float = 0.0;
            if (mode == 0) { score = this.eval_knn(point, x, y, folds); };
            if (mode == 1) { score = this.eval_dt(point, x, y, folds); };
            if (mode == 2) { score = this.eval_svm(point, x, y, folds); };

            var hi: int = 0;
            while (hi < this.n_params) {
                this.history_x[this.n_history][hi] = point[hi];
                hi++;
            };
            this.history_y[this.n_history] = score;
            this.n_history = this.n_history + 1;

            if (best_score < 0.0 || score > best_score) {
                best_score = score;
                var bi: int = 0;
                while (bi < this.n_params) {
                    best_params[bi] = point[bi];
                    bi++;
                };
            };
            wi++;
        };

        // bayesian iterations
        var surrogate: SurrogateRF = SurrogateRF(10, 3);
        var ii: int = 0;
        while (ii < this.n_iterations) {
            var hist_x: float[][] = alloc float[this.n_history][this.n_params];
            var hist_y: float[] = alloc float[this.n_history];
            var hci: int = 0;
            while (hci < this.n_history) {
                var hfi: int = 0;
                while (hfi < this.n_params) {
                    hist_x[hci][hfi] = this.history_x[hci][hfi];
                    hfi++;
                };
                hist_y[hci] = this.history_y[hci];
                hci++;
            };

            surrogate.fit_surrogate(hist_x, hist_y, this.n_history);
            var next: float[] = this.next_point(surrogate, best_score);

            var score2: float = 0.0;
            if (mode == 0) { score2 = this.eval_knn(next, x, y, folds); };
            if (mode == 1) { score2 = this.eval_dt(next, x, y, folds); };
            if (mode == 2) { score2 = this.eval_svm(next, x, y, folds); };

            var hi2: int = 0;
            while (hi2 < this.n_params) {
                this.history_x[this.n_history][hi2] = next[hi2];
                hi2++;
            };
            this.history_y[this.n_history] = score2;
            this.n_history = this.n_history + 1;

            if (score2 > best_score) {
                best_score = score2;
                var bi2: int = 0;
                while (bi2 < this.n_params) {
                    best_params[bi2] = next[bi2];
                    bi2++;
                };
            };
            ii++;
        };

        return SearchResult(best_params, best_score, this.n_params);
    };

    function search_knn(x: float[][], y: int[], folds: TrainTestSplit[]) -> SearchResult {
        return this.run_search(x, y, folds, 0);
    };

    function search_dt(x: float[][], y: int[], folds: TrainTestSplit[]) -> SearchResult {
        return this.run_search(x, y, folds, 1);
    };

    function search_svm(x: float[][], y: int[], folds: TrainTestSplit[]) -> SearchResult {
        return this.run_search(x, y, folds, 2);
    };
};

function subsample_indices(n: int, k: int) -> int[] {
    var indices: int[] = alloc int[n];
    var i: int = 0;
    while (i < n) { indices[i] = i; i++; };

    // Fisher-Yates shuffle first k elements
    var j: int = 0;
    while (j < k) {
        var r: int = rand_int(j, n - 1);
        var tmp: int = indices[j];
        indices[j] = indices[r];
        indices[r] = tmp;
        j++;
    };

    var result: int[] = alloc int[k];
    var ri: int = 0;
    while (ri < k) { result[ri] = indices[ri]; ri++; };
    return result;
};

function gb_build_tree(x: float[][], y: float[], n: int, max_depth: int, depth: int) -> SurrogateNode {
    var n_features: int = x.cols;

    if (n <= 1 || depth >= max_depth) {
        var sum: float = 0.0;
        var i: int = 0;
        while (i < n) { sum = sum + y[i]; i++; };
        return surrogate_leaf(sum / float(n));
    };

    var best_score: float = 0.0;
    var best_feature: int = 0;
    var best_threshold: float = 0.0;
    var found_split: int = 0;

    var fii: int = 0;
    while (fii < n_features) {
        var ti: int = 0;
        while (ti < n) {
            var threshold: float = x[ti][fii];
            var nl: int = 0;
            var nr: int = 0;
            var lsum: float = 0.0;
            var rsum: float = 0.0;
            var si: int = 0;
            while (si < n) {
                if (x[si][fii] < threshold) {
                    lsum = lsum + y[si];
                    nl++;
                };
                if (x[si][fii] >= threshold) {
                    rsum = rsum + y[si];
                    nr++;
                };
                si++;
            };
            if (nl == 0 || nr == 0) { ti++; continue; };

            var lmean: float = lsum / float(nl);
            var rmean: float = rsum / float(nr);
            var lvar: float = 0.0;
            var rvar: float = 0.0;
            var vi: int = 0;
            while (vi < n) {
                if (x[vi][fii] < threshold) {
                    var d: float = y[vi] - lmean;
                    lvar = lvar + d * d;
                };
                if (x[vi][fii] >= threshold) {
                    var d2: float = y[vi] - rmean;
                    rvar = rvar + d2 * d2;
                };
                vi++;
            };

            var score: float = 0.0 - (lvar + rvar);
            if (found_split == 0 || score > best_score) {
                best_score = score;
                best_feature = fii;
                best_threshold = threshold;
                found_split = 1;
            };
            ti++;
        };
        fii++;
    };

    if (found_split == 0) {
        var sum2: float = 0.0;
        var i2: int = 0;
        while (i2 < n) { sum2 = sum2 + y[i2]; i2++; };
        return surrogate_leaf(sum2 / float(n));
    };

    var left_x: float[][] = alloc float[n][n_features];
    var right_x: float[][] = alloc float[n][n_features];
    var left_y: float[] = alloc float[n];
    var right_y: float[] = alloc float[n];
    var nl2: int = 0;
    var nr2: int = 0;
    var si2: int = 0;
    while (si2 < n) {
        if (x[si2][best_feature] < best_threshold) {
            var fj: int = 0;
            while (fj < n_features) {
                left_x[nl2][fj] = x[si2][fj];
                fj++;
            };
            left_y[nl2] = y[si2];
            nl2++;
        };
        if (x[si2][best_feature] >= best_threshold) {
            var fk: int = 0;
            while (fk < n_features) {
                right_x[nr2][fk] = x[si2][fk];
                fk++;
            };
            right_y[nr2] = y[si2];
            nr2++;
        };
        si2++;
    };

    var left_node: SurrogateNode = gb_build_tree(left_x, left_y, nl2, max_depth, depth + 1);
    var right_node: SurrogateNode = gb_build_tree(right_x, right_y, nr2, max_depth, depth + 1);
    return surrogate_node(best_feature, best_threshold, left_node, right_node);
};

function gb_predict_one(sample: float[], node: SurrogateNode) -> float {
    if (node.is_leaf == 1) { return node.value; };
    if (node.left == null || node.right == null) { return node.value; };
    if (sample[node.feature_idx] < node.threshold) {
        return gb_predict_one(sample, node.left);
    };
    return gb_predict_one(sample, node.right);
};

function gb_sigmoid(z: float) -> float {
    return 1.0 / (1.0 + c_exp(0.0 - z));
};

class GradientBoosting {
    var n_trees: int;
    var max_depth: int;
    var lr: float;
    var subsample: float;
    var roots: SurrogateNode[];
    var base_pred: float;
    var fitted: int;
    var mode: str;

    function constructor(n_trees: int, max_depth: int, lr: float, subsample: float) -> null {
        this.n_trees = n_trees;
        this.max_depth = max_depth;
        this.lr = lr;
        this.subsample = subsample;
        this.roots = alloc SurrogateNode[n_trees];
        this.base_pred = 0.0;
        this.fitted = 0;
        this.mode = "regression";
    };

    function use_classification() -> null {
        this.mode = "classification";
    };

    function fit(x: float[][], y: int[]) -> null {
        var n: int = x.rows;
        var n_features: int = x.cols;
        var k: int = int(float(n) * this.subsample);
        if (k < 1) { k = 1; };

        // base prediction = log odds
        var pos: float = 0.0;
        var pi2: int = 0;
        while (pi2 < n) {
            if (y[pi2] == 1) { pos = pos + 1.0; };
            pi2++;
        };
        var p: float = pos / float(n);
        if (p <= 0.0) { p = 0.0001; };
        if (p >= 1.0) { p = 0.9999; };
        var ratio: float = p / (1.0 - p);
        this.base_pred = ratio.log().real;

        // initialize predictions
        var preds: float[] = alloc float[n];
        var pi: int = 0;
        while (pi < n) { preds[pi] = this.base_pred; pi++; };

        // boost
        var ti: int = 0;
        while (ti < this.n_trees) {
            // compute residuals = y - sigmoid(pred)
            var residuals: float[] = alloc float[n];
            var ri: int = 0;
            while (ri < n) {
                var prob: float = gb_sigmoid(preds[ri]);
                residuals[ri] = float(y[ri]) - prob;
                ri++;
            };

            // subsample rows
            var idx: int[] = subsample_indices(n, k);

            // build subsampled x and residuals
            var sub_x: float[][] = alloc float[k][n_features];
            var sub_r: float[] = alloc float[k];
            var si: int = 0;
            while (si < k) {
                var orig: int = idx[si];
                var fj: int = 0;
                while (fj < n_features) {
                    sub_x[si][fj] = x[orig][fj];
                    fj++;
                };
                sub_r[si] = residuals[orig];
                si++;
            };

            // build tree on residuals
            var root: SurrogateNode = gb_build_tree(sub_x, sub_r, k, this.max_depth, 0);
            this.roots[ti] = root;

            // update predictions
            var ui: int = 0;
            while (ui < n) {
                var cur_root: SurrogateNode = this.roots[ti];
                preds[ui] = preds[ui] + this.lr * gb_predict_one(x[ui], cur_root);
                ui++;
            };

            ti++;
        };
        this.fitted = 1;
    };

    function predict(x: float[][]) -> float[] {
        var n: int = x.rows;
        var result: float[] = alloc float[n];
        var i: int = 0;
        while (i < n) {
            var pred: float = this.base_pred;
            var ti: int = 0;
            while (ti < this.n_trees) {
                var cur_root: SurrogateNode = this.roots[ti];
                var tree_contrib: float = gb_predict_one(x[i], cur_root);
                pred = pred + this.lr * tree_contrib;
                ti++;
            };
            result[i] = pred;
            i++;
        };
        return result;
    };

    function mse(x: float[][], y: float[]) -> float {
        var preds: float[] = this.predict(x);
        var n: int = x.rows;
        var sum: float = 0.0;
        var i: int = 0;
        while (i < n) {
            var diff: float = y[i] - preds[i];
            sum = sum + diff * diff;
            i++;
        };
        return sum / float(n);
    };

    function rmse(x: float[][], y: float[]) -> float {
        return c_sqrt(this.mse(x, y));
    };

    function r2(x: float[][], y: float[]) -> float {
        var preds: float[] = this.predict(x);
        var n: int = x.rows;
        var ysum: float = 0.0;
        var i: int = 0;
        while (i < n) { ysum = ysum + y[i]; i++; };
        var ymean: float = ysum / float(n);
        var ss_tot: float = 0.0;
        var ss_res: float = 0.0;
        var j: int = 0;
        while (j < n) {
            var dt: float = y[j] - ymean;
            var dr: float = y[j] - preds[j];
            ss_tot = ss_tot + dt * dt;
            ss_res = ss_res + dr * dr;
            j++;
        };
        if (ss_tot == 0.0) { return 1.0; };
        return 1.0 - (ss_res / ss_tot);
    };

    function predict_proba(x: float[][]) -> float[] {
        var n: int = x.rows;
        var result: float[] = alloc float[n];
        var i: int = 0;
        while (i < n) {
            var score: float = this.base_pred;
            var ti: int = 0;
            while (ti < this.n_trees) {
                var cur_root: SurrogateNode = this.roots[ti];
                score = score + this.lr * gb_predict_one(x[i], cur_root);
                ti++;
            };
            result[i] = gb_sigmoid(score);
            i++;
        };
        return result;
    };

    function predict_class(x: float[][]) -> int[] {
        var proba: float[] = this.predict_proba(x);
        var n: int = x.rows;
        var result: int[] = alloc int[n];
        var i: int = 0;
        while (i < n) {
            if (proba[i] >= 0.5) {
                result[i] = 1;
            };
            if (proba[i] < 0.5) {
                result[i] = 0;
            };
            i++;
        };
        return result;
    };

    function accuracy(x: float[][], y: int[]) -> float {
        var preds: int[] = this.predict_class(x);
        var n: int = x.rows;
        var correct: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == y[i]) { correct++; };
            i++;
        };
        return float(correct) / float(n);
    };

    function precision(x: float[][], y: int[]) -> float {
        var preds: int[] = this.predict_class(x);
        var n: int = x.rows;
        var tp: int = 0;
        var fp: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 1 && y[i] == 0) { fp++; };
            i++;
        };
        if (tp + fp == 0) { return 0.0; };
        return float(tp) / float(tp + fp);
    };

    function recall(x: float[][], y: int[]) -> float {
        var preds: int[] = this.predict_class(x);
        var n: int = x.rows;
        var tp: int = 0;
        var fn: int = 0;
        var i: int = 0;
        while (i < n) {
            if (preds[i] == 1 && y[i] == 1) { tp++; };
            if (preds[i] == 0 && y[i] == 1) { fn++; };
            i++;
        };
        if (tp + fn == 0) { return 0.0; };
        return float(tp) / float(tp + fn);
    };

    function f1(x: float[][], y: int[]) -> float {
        var p: float = this.precision(x, y);
        var r: float = this.recall(x, y);
        if (p + r == 0.0) { return 0.0; };
        return 2.0 * p * r / (p + r);
    };

    function save(path: str) -> null {
        var db: null = sqlite3_open(path);
        forge_db_setup(db);
        forge_db_write_meta(db, "model_type", "GradientBoosting");
        forge_db_write_meta(db, "n_trees", str(this.n_trees));
        forge_db_write_meta(db, "max_depth", str(this.max_depth));
        forge_db_write_meta(db, "lr", str(this.lr));
        forge_db_write_meta(db, "subsample", str(this.subsample));
        forge_db_write_meta(db, "base_pred", str(this.base_pred));
        forge_db_write_meta(db, "fitted", str(this.fitted));
        forge_db_write_meta(db, "mode", this.mode);
        var ti: int = 0;
        while (ti < this.n_trees) {
            var counter: int[] = alloc int[1];
            counter[0] = 1;
            var root: SurrogateNode = this.roots[ti];
            forge_serialize_surrogatenode(db, "tree_" + str(ti), root, 0, counter);
            ti++;
        };
        sqlite3_close(db);
    };

    function load(path: str) -> null {
        var db: null = sqlite3_open(path);
        this.n_trees = forge_db_read_meta(db, "n_trees").toInt();
        this.max_depth = forge_db_read_meta(db, "max_depth").toInt();
        this.lr = forge_db_read_meta(db, "lr").toFloat();
        this.subsample = forge_db_read_meta(db, "subsample").toFloat();
        this.base_pred = forge_db_read_meta(db, "base_pred").toFloat();
        this.fitted = forge_db_read_meta(db, "fitted").toInt();
        this.mode = forge_db_read_meta(db, "mode");
        this.roots = alloc SurrogateNode[this.n_trees];
        var ti: int = 0;
        while (ti < this.n_trees) {
            var root: SurrogateNode = forge_deserialize_surrogatenode(db, "tree_" + str(ti), 0);
            this.roots[ti] = root;
            ti++;
        };
        sqlite3_close(db);
    };
};