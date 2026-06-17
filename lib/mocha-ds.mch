// mocha-lib-deps: mocha-math, mocha-string
"""
    mocha-ds v0.1 — Mocha Data Structures Library
    Sections:=
    1. Core Value Wrapper
    2. Singly Linked List
    3. Doubly Linked List
    4. Stack
    5. Queue
    6. Deque
    7. Heap
    8. BST / AVL
    9. Trie
    10. Patricia
    11. Graph
"""

// FFI
function c_print_err(msg: str) -> null native mocha_print_stderr;
function c_exit(code: int) -> null native mocha_exit;
function mocha_fnv1a(key: str) -> int native ht_fnv1a;
function mocha_djb2(key: str)  -> int native ht_djb2;

"""  ========================
     CORE VALUE WRAPPER
     ========================  """

tag DSKind {
    INT,
    FLOAT,
    STR,
    BOOL
};

class DSValue {
    var kind:     DSKind;
    var int_val:  int;
    var flt_val:  float;
    var str_val:  str;
    var bool_val: bool;

    function constructor(kind: DSKind, int_val: int, flt_val: float, str_val: str, bool_val: bool) -> null {
        this.kind     = kind;
        this.int_val  = int_val;
        this.flt_val  = flt_val;
        this.str_val  = str_val;
        this.bool_val = bool_val;
    };
};

~~ Smart constructors
function ds_int(v: int) -> DSValue {
    return DSValue(DSKind.INT, v, 0.0, "", false);
};

function ds_float(v: float) -> DSValue {
    return DSValue(DSKind.FLOAT, 0, v, "", false);
};

function ds_str(v: str) -> DSValue {
    return DSValue(DSKind.STR, 0, 0.0, v, false);
};

function ds_bool(v: bool) -> DSValue {
    return DSValue(DSKind.BOOL, 0, 0.0, "", v);
};

~~ DSValue equality check
function ds_equals(a: DSValue, b: DSValue) -> bool {
    if (a.kind != b.kind) {
        return false;
    };
    match(a.kind) {
        case DSKind.INT:   return a.int_val == b.int_val;
        case DSKind.FLOAT: return a.flt_val == b.flt_val;
        case DSKind.STR:   return a.str_val == b.str_val;
        case DSKind.BOOL:  return a.bool_val == b.bool_val;
        default:           return false;
    };
};

~~ DSValue to string for printing
function ds_to_str(v: DSValue) -> str {
    match(v.kind) {
        case DSKind.INT:   return str(v.int_val);
        case DSKind.FLOAT: return str(v.flt_val);
        case DSKind.STR:   return v.str_val;
        case DSKind.BOOL:
            if (v.bool_val) {
                return "true";
            };
            return "false";
        default: return "<unknown>";
    };
};

"""  ========================
     SINGLY LINKED LIST
     ========================  """

class SLNode {
    var data: DSValue;
    var next: SLNode;

    function constructor(data: DSValue, next: SLNode) -> null {
        this.data = data;
        this.next = next;
    };
};

class SinglyLL {
    var head: SLNode;
    var size: int;

    function constructor() -> null {
        this.head = null;
        this.size = 0;
    };

    // Prepend to front — O(1)
    function prepend(data: DSValue) -> null {
        var node: SLNode = SLNode(data, this.head);
        this.head = node;
        this.size = this.size + 1;
    };

    // Append to back — O(n)
    function append(data: DSValue) -> null {
        var node: SLNode = SLNode(data, null);
        if (this.head == null) {
            this.head = node;
            this.size = this.size + 1;
            return;
        };
        var cur: SLNode = this.head;
        while (cur.next != null) {
            cur = cur.next;
        };
        cur.next = node;
        this.size = this.size + 1;
    };

    // Remove first occurrence of value — O(n)
    function remove(data: DSValue) -> bool {
        if (this.head == null) {
            return false;
        };
        if (ds_equals(this.head.data, data)) {
            this.head = this.head.next;
            this.size = this.size - 1;
            return true;
        };
        var cur: SLNode = this.head;
        while (cur.next != null) {
            if (ds_equals(cur.next.data, data)) {
                cur.next = cur.next.next;
                this.size = this.size - 1;
                return true;
            };
            cur = cur.next;
        };
        return false;
    };

    // Search — O(n)
    function contains(data: DSValue) -> bool {
        var cur: SLNode = this.head;
        while (cur != null) {
            if (ds_equals(cur.data, data)) {
                return true;
            };
            cur = cur.next;
        };
        return false;
    };

    // Get value at index — O(n)
    function get(index: int) -> DSValue {
        if (index < 0 || index >= this.size) {
            c_print_err("MochaDSError (mocha-ds): index out of bounds.");
            c_exit(2);
            return ds_int(0);
        };
        var cur: SLNode = this.head;
        var i: int = 0;
        while (i < index) {
            cur = cur.next;
            i++;
        };
        return cur.data;
    };

    // Print all values
    function print_all() -> null {
        var cur: SLNode = this.head;
        while (cur != null) {
            print(ds_to_str(cur.data), newLine=false);
            if (cur.next != null) {
                print(" -> ", newLine=false);
            };
            cur = cur.next;
        };
        print("", newLine=true);
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     DOUBLY LINKED LIST
     ========================  """

class DLNode {
    var data: DSValue;
    var next: DLNode;
    var prev: DLNode;

    function constructor(data: DSValue, next: DLNode, prev: DLNode) -> null {
        this.data = data;
        this.next = next;
        this.prev = prev;
    };
};

class DoublyLL {
    var head: DLNode;
    var tail: DLNode;
    var size: int;

    function constructor() -> null {
        this.head = null;
        this.tail = null;
        this.size = 0;
    };

    // Prepend to front — O(1)
    function push_front(data: DSValue) -> null {
        var node: DLNode = DLNode(data, this.head, null);
        if (this.head == null) {
            this.head = node;
            this.tail = node;
            this.size = this.size + 1;
            return;
        };
        this.head.prev = node;
        this.head = node;
        this.size = this.size + 1;
    };

    // Append to back — O(1)
    function push_back(data: DSValue) -> null {
        var node: DLNode = DLNode(data, null, this.tail);
        if (this.tail == null) {
            this.head = node;
            this.tail = node;
            this.size = this.size + 1;
            return;
        };
        this.tail.next = node;
        this.tail = node;
        this.size = this.size + 1;
    };

    // Remove from front — O(1)
    function pop_front() -> DSValue {
        if (this.head == null) {
            c_print_err("MochaDSError (mocha-ds): pop_front on empty DoublyLL.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.head.data;
        this.head = this.head.next;
        if (this.head == null) {
            this.tail = null;
        };
        if (this.head != null) {
            this.head.prev = null;
        };
        this.size = this.size - 1;
        return val;
    };

    // Remove from back — O(1)
    function pop_back() -> DSValue {
        if (this.tail == null) {
            c_print_err("MochaDSError (mocha-ds): pop_back on empty DoublyLL.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.tail.data;
        this.tail = this.tail.prev;
        if (this.tail == null) {
            this.head = null;
        };
        if (this.tail != null) {
            this.tail.next = null;
        };
        this.size = this.size - 1;
        return val;
    };

    // Peek front without removing — O(1)
    function front() -> DSValue {
        if (this.head == null) {
            c_print_err("MochaDSError (mocha-ds): front() on empty DoublyLL.");
            c_exit(2);
            return ds_int(0);
        };
        return this.head.data;
    };

    // Peek back without removing — O(1)
    function back() -> DSValue {
        if (this.tail == null) {
            c_print_err("MochaDSError (mocha-ds): back() on empty DoublyLL.");
            c_exit(2);
            return ds_int(0);
        };
        return this.tail.data;
    };

    // Remove first occurrence of value — O(n)
    function remove(data: DSValue) -> bool {
        var cur: DLNode = this.head;
        while (cur != null) {
            if (ds_equals(cur.data, data)) {
                if (cur.prev != null) {
                    cur.prev.next = cur.next;
                };
                if (cur.next != null) {
                    cur.next.prev = cur.prev;
                };
                if (cur == this.head) {
                    this.head = cur.next;
                };
                if (cur == this.tail) {
                    this.tail = cur.prev;
                };
                this.size = this.size - 1;
                return true;
            };
            cur = cur.next;
        };
        return false;
    };

    // Search — O(n)
    function contains(data: DSValue) -> bool {
        var cur: DLNode = this.head;
        while (cur != null) {
            if (ds_equals(cur.data, data)) {
                return true;
            };
            cur = cur.next;
        };
        return false;
    };

    // Get value at index — O(n)
    function get(index: int) -> DSValue {
        if (index < 0 || index >= this.size) {
            c_print_err("MochaDSError (mocha-ds): index out of bounds.");
            c_exit(2);
            return ds_int(0);
        };
        var cur: DLNode = this.head;
        var i: int = 0;
        while (i < index) {
            cur = cur.next;
            i++;
        };
        return cur.data;
    };

    // Print all values front to back
    function print_all() -> null {
        var cur: DLNode = this.head;
        while (cur != null) {
            print(ds_to_str(cur.data), newLine=false);
            if (cur.next != null) {
                print(" <-> ", newLine=false);
            };
            cur = cur.next;
        };
        print("", newLine=true);
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     STACK
     ========================  """

class Stack {
    var list: SinglyLL;
    var top:  DSValue;
    var size: int;

    function constructor() -> null {
        this.list = SinglyLL();
        this.top  = null;
        this.size = 0;
    };

    // Push to top — O(1)
    function push(data: DSValue) -> null {
        this.list.prepend(data);
        this.top  = data;
        this.size = this.size + 1;
    };

    // Pop from top — O(1)
    function pop() -> DSValue {
        if (this.list.is_empty()) {
            c_print_err("MochaDSError (mocha-ds): pop on empty Stack.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.list.head.data;
        this.list.head   = this.list.head.next;
        this.list.size   = this.list.size - 1;
        if (this.list.is_empty()) {
            this.top = null;
        } else {
            this.top = this.list.head.data;
        };
        this.size = this.size - 1;
        return val;
    };

    // Print all values top to bottom
    function print_all() -> null {
        this.list.print_all();
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     QUEUE
     ========================  """

class Queue {
    var list:  DoublyLL;
    var front: DSValue;
    var size:  int;

    function constructor() -> null {
        this.list  = DoublyLL();
        this.front = null;
        this.size  = 0;
    };

    // Enqueue to back — O(1)
    function enqueue(data: DSValue) -> null {
        this.list.push_back(data);
        if (this.size == 0) {
            this.front = data;
        };
        this.size = this.size + 1;
    };

    // Dequeue from front — O(1)
    function dequeue() -> DSValue {
        if (this.list.is_empty()) {
            c_print_err("MochaDSError (mocha-ds): dequeue on empty Queue.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.list.pop_front();
        if (this.list.is_empty()) {
            this.front = null;
        } else {
            this.front = this.list.head.data;
        };
        this.size = this.size - 1;
        return val;
    };

    // Print all values front to back
    function print_all() -> null {
        this.list.print_all();
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     DECK
     ========================  """

class Deck {
    var list:  DoublyLL;
    var front: DSValue;
    var back:  DSValue;
    var size:  int;

    function constructor() -> null {
        this.list  = DoublyLL();
        this.front = null;
        this.back  = null;
        this.size  = 0;
    };

    // Push to front — O(1)
    function push_front(data: DSValue) -> null {
        this.list.push_front(data);
        this.front = data;
        if (this.size == 0) {
            this.back = data;
        };
        this.size = this.size + 1;
    };

    // Push to back — O(1)
    function push_back(data: DSValue) -> null {
        this.list.push_back(data);
        this.back = data;
        if (this.size == 0) {
            this.front = data;
        };
        this.size = this.size + 1;
    };

    // Pop from front — O(1)
    function pop_front() -> DSValue {
        if (this.list.is_empty()) {
            c_print_err("MochaDSError (mocha-ds): pop_front on empty Deck.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.list.pop_front();
        if (this.list.is_empty()) {
            this.front = null;
            this.back  = null;
        } else {
            this.front = this.list.head.data;
        };
        this.size = this.size - 1;
        return val;
    };

    // Pop from back — O(1)
    function pop_back() -> DSValue {
        if (this.list.is_empty()) {
            c_print_err("MochaDSError (mocha-ds): pop_back on empty Deck.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.list.pop_back();
        if (this.list.is_empty()) {
            this.front = null;
            this.back  = null;
        } else {
            this.back = this.list.tail.data;
        };
        this.size = this.size - 1;
        return val;
    };

    // Print all values front to back
    function print_all() -> null {
        this.list.print_all();
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     HEAP
     ========================  """

tag HeapKind {
    MIN,
    MAX
};

class Heap {
    var data: DSValue[];
    var kind: HeapKind;
    var top:  DSValue;
    var size: int;

    function constructor(kind: HeapKind) -> null {
        this.data = [];
        this.kind = kind;
        this.top  = null;
        this.size = 0;
    };

    // Returns true if a should be higher in heap than b
    function should_swap(a: DSValue, b: DSValue) -> bool {
        if (a.kind == DSKind.BOOL) {
            c_print_err("MochaDSError (mocha-ds): Heap does not support DSKind.BOOL.");
            c_exit(2);
            return false;
        };
        match(this.kind) {
            case HeapKind.MIN:
                match(a.kind) {
                    case DSKind.INT:   return a.int_val < b.int_val;
                    case DSKind.FLOAT: return a.flt_val < b.flt_val;
                    case DSKind.STR:   return a.str_val < b.str_val;
                    default:           return false;
                };
            case HeapKind.MAX:
                match(a.kind) {
                    case DSKind.INT:   return a.int_val > b.int_val;
                    case DSKind.FLOAT: return a.flt_val > b.flt_val;
                    case DSKind.STR:   return a.str_val > b.str_val;
                    default:           return false;
                };
            default: return false;
        };
    };

    // Sift up from index i
    function sift_up(i: int) -> null {
        while (i > 0) {
            var parent: int  = (i - 1) / 2;
            var should: bool = this.should_swap(this.data[i], this.data[parent]);
            if (should) {
                var tmp: DSValue  = this.data[parent];
                this.data[parent] = this.data[i];
                this.data[i]      = tmp;
                i                 = parent;
            } else {
                break;
            };
        };
    };

    // Sift down from index i
    function sift_down(i: int) -> null {
        var left: int = 2 * i + 1;
        while (left < this.size) {
            var best: int = i;
            var bl: bool  = this.should_swap(this.data[left], this.data[best]);
            if (bl) {
                best = left;
            };
            var right: int = left + 1;
            if (right < this.size) {
                var br: bool = this.should_swap(this.data[right], this.data[best]);
                if (br) {
                    best = right;
                };
            };
            if (best == i) {
                break;
            } else {
                var tmp: DSValue = this.data[i];
                this.data[i]     = this.data[best];
                this.data[best]  = tmp;
                i                = best;
                left             = 2 * i + 1;
            };
        };
    };

    // Insert — O(log n)
    function insert(data: DSValue) -> null {
        this.data.push(data);
        this.sift_up(this.size);
        this.size = this.size + 1;
        this.top  = this.data[0];
    };

    // Remove top — O(log n)
    function remove_top() -> DSValue {
        if (this.size == 0) {
            c_print_err("MochaDSError (mocha-ds): remove_top on empty Heap.");
            c_exit(2);
            return ds_int(0);
        };
        var val: DSValue = this.data[0];
        this.data[0]     = this.data[this.size - 1];
        this.data.pop();
        this.size        = this.size - 1;
        if (this.size == 0) {
            this.top = null;
        } else {
            this.sift_down(0);
            this.top = this.data[0];
        };
        return val;
    };

    function is_empty() -> bool {
        return this.size == 0;
    };

    // Build heap from existing array — O(n)
    function heapify(arr: DSValue[]) -> null {
        this.data = arr;
        this.size = arr.length;
        var i: int = (this.size / 2) - 1;
        while (i >= 0) {
            this.sift_down(i);
            i = i - 1;
        };
        if (this.size > 0) {
            this.top = this.data[0];
        };
    };
};

"""  ========================
     AVL TREE
     ========================  """

class AVLNode {
    var key:    DSValue;
    var left:   AVLNode;
    var right:  AVLNode;
    var height: int;

    function constructor(key: DSValue) -> null {
        this.key    = key;
        this.left   = null;
        this.right  = null;
        this.height = 1;
    };
};

class AVLTree {
    var root: AVLNode;
    var size: int;

    function constructor() -> null {
        this.root = null;
        this.size = 0;
    };

    // Node height — 0 if null
    function node_height(n: AVLNode) -> int {
        if (n == null) {
            return 0;
        };
        return n.height;
    };

    // Balance factor of a node
    function balance_factor(n: AVLNode) -> int {
        if (n == null) {
            return 0;
        };
        return this.node_height(n.left) - this.node_height(n.right);
    };

    // Update height of a node from its children
    function update_height(n: AVLNode) -> null {
        var lh: int = this.node_height(n.left);
        var rh: int = this.node_height(n.right);
        if (lh > rh) {
            n.height = lh + 1;
        } else {
            n.height = rh + 1;
        };
    };

    // Compare two DSValues — returns -1, 0, 1
    function cmp(a: DSValue, b: DSValue) -> int {
        if (a.kind == DSKind.BOOL) {
            c_print_err("MochaDSError (mocha-ds): AVLTree does not support DSKind.BOOL.");
            c_exit(2);
            return 0;
        };
        match(a.kind) {
            case DSKind.INT:
                if (a.int_val < b.int_val) { return -1; };
                if (a.int_val > b.int_val) { return 1; };
                return 0;
            case DSKind.FLOAT:
                if (a.flt_val < b.flt_val) { return -1; };
                if (a.flt_val > b.flt_val) { return 1; };
                return 0;
            case DSKind.STR:
                if (a.str_val < b.str_val) { return -1; };
                if (a.str_val > b.str_val) { return 1; };
                return 0;
            default: return 0;
        };
    };

    // Right rotation
    function rotate_right(y: AVLNode) -> AVLNode {
        var x:  AVLNode = y.left;
        var t2: AVLNode = x.right;
        x.right = y;
        y.left  = t2;
        this.update_height(y);
        this.update_height(x);
        return x;
    };

    // Left rotation
    function rotate_left(x: AVLNode) -> AVLNode {
        var y:  AVLNode = x.right;
        var t2: AVLNode = y.left;
        y.left  = x;
        x.right = t2;
        this.update_height(x);
        this.update_height(y);
        return y;
    };

    // Rebalance a node after insert/delete
    function rebalance(n: AVLNode) -> AVLNode {
        this.update_height(n);
        var bf: int = this.balance_factor(n);

        // LL
        if (bf > 1) {
            var lbf: int = this.balance_factor(n.left);
            if (lbf < 0) {
                n.left = this.rotate_left(n.left);
            };
            return this.rotate_right(n);
        };

        // RR
        if (bf < -1) {
            var rbf: int = this.balance_factor(n.right);
            if (rbf > 0) {
                n.right = this.rotate_right(n.right);
            };
            return this.rotate_left(n);
        };

        return n;
    };

    // Internal insert
    function insert_node(n: AVLNode, key: DSValue) -> AVLNode {
        if (n == null) {
            return AVLNode(key);
        };
        var c: int = this.cmp(key, n.key);
        if (c < 0) {
            n.left  = this.insert_node(n.left, key);
        } else {
            if (c > 0) {
                n.right = this.insert_node(n.right, key);
            };
        };
        return this.rebalance(n);
    };

    // Internal min node
    function min_node(n: AVLNode) -> AVLNode {
        var cur: AVLNode = n;
        while (cur.left != null) {
            cur = cur.left;
        };
        return cur;
    };

    // Internal max node
    function max_node(n: AVLNode) -> AVLNode {
        var cur: AVLNode = n;
        while (cur.right != null) {
            cur = cur.right;
        };
        return cur;
    };

    // Internal remove
    function remove_node(n: AVLNode, key: DSValue) -> AVLNode {
        if (n == null) {
            return null;
        };
        var c: int = this.cmp(key, n.key);
        if (c < 0) {
            n.left  = this.remove_node(n.left, key);
        } else {
            if (c > 0) {
                n.right = this.remove_node(n.right, key);
            } else {
                // Found — three cases
                if (n.left == null) {
                    return n.right;
                };
                if (n.right == null) {
                    return n.left;
                };
                // Two children — replace with inorder successor
                var succ: AVLNode   = this.min_node(n.right);
                n.key               = succ.key;
                n.right             = this.remove_node(n.right, succ.key);
            };
        };
        return this.rebalance(n);
    };

    // Internal contains
    function contains_node(n: AVLNode, key: DSValue) -> bool {
        if (n == null) {
            return false;
        };
        var c: int = this.cmp(key, n.key);
        if (c == 0) {
            return true;
        };
        if (c < 0) {
            return this.contains_node(n.left, key);
        };
        return this.contains_node(n.right, key);
    };

    // Internal inorder print
    function inorder_node(n: AVLNode) -> null {
        if (n == null) {
            return;
        };
        this.inorder_node(n.left);
        print(ds_to_str(n.key), newLine=true);
        this.inorder_node(n.right);
    };

    // Internal successor
    function successor_node(n: AVLNode, key: DSValue, best: AVLNode) -> AVLNode {
        if (n == null) {
            return best;
        };
        var c: int = this.cmp(key, n.key);
        if (c < 0) {
            return this.successor_node(n.left, key, n);
        };
        if (c >= 0) {
            return this.successor_node(n.right, key, best);
        };
        return best;
    };

    // Internal predecessor
    function predecessor_node(n: AVLNode, key: DSValue, best: AVLNode) -> AVLNode {
        if (n == null) {
            return best;
        };
        var c: int = this.cmp(key, n.key);
        if (c > 0) {
            return this.predecessor_node(n.right, key, n);
        };
        if (c <= 0) {
            return this.predecessor_node(n.left, key, best);
        };
        return best;
    };

    // Public API

    function insert(key: DSValue) -> null {
        this.root = this.insert_node(this.root, key);
        this.size = this.size + 1;
    };

    function remove(key: DSValue) -> null {
        this.root = this.remove_node(this.root, key);
        this.size = this.size - 1;
    };

    function contains(key: DSValue) -> bool {
        return this.contains_node(this.root, key);
    };

    function min() -> DSValue {
        if (this.root == null) {
            c_print_err("MochaDSError (mocha-ds): min() on empty AVLTree.");
            c_exit(2);
            return ds_int(0);
        };
        var mn: AVLNode = this.min_node(this.root);
        return mn.key;
    };

    function max() -> DSValue {
        if (this.root == null) {
            c_print_err("MochaDSError (mocha-ds): max() on empty AVLTree.");
            c_exit(2);
            return ds_int(0);
        };
        var mx: AVLNode = this.max_node(this.root);
        return mx.key;
    };

    function height() -> int {
        return this.node_height(this.root);
    }; //Node-based approach is followed. Empty tree is 0

    function inorder() -> null {
        this.inorder_node(this.root);
    };

    function successor(key: DSValue) -> DSValue {
        var s: AVLNode = this.successor_node(this.root, key, null);
        if (s == null) {
            c_print_err("MochaDSError (mocha-ds): no successor exists for given key.");
            c_exit(2);
            return ds_int(0);
        };
        return s.key;
    };

    function predecessor(key: DSValue) -> DSValue {
        var p: AVLNode = this.predecessor_node(this.root, key, null);
        if (p == null) {
            c_print_err("MochaDSError (mocha-ds): no predecessor exists for given key.");
            c_exit(2);
            return ds_int(0);
        };
        return p.key;
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     RED-BLACK TREE
     ========================  """

tag RBColor {
    RED,
    BLACK
};

class RBNode {
    var key:    DSValue;
    var color:  RBColor;
    var left:   RBNode;
    var right:  RBNode;
    var parent: RBNode;

    function constructor(key: DSValue, color: RBColor, left: RBNode, right: RBNode, parent: RBNode) -> null {
        this.key    = key;
        this.color  = color;
        this.left   = left;
        this.right  = right;
        this.parent = parent;
    };
};

class RBTree {
    var nil:  RBNode;
    var root: RBNode;
    var size: int;

    function constructor() -> null {
        // Sentinel nil node — BLACK, points to itself
        this.nil        = RBNode(ds_int(0), RBColor.BLACK, null, null, null);
        this.nil.left   = this.nil;
        this.nil.right  = this.nil;
        this.nil.parent = this.nil;
        this.root       = this.nil;
        this.size       = 0;
    };

    // Compare two DSValues — returns -1, 0, 1
    function cmp(a: DSValue, b: DSValue) -> int {
        if (a.kind == DSKind.BOOL) {
            c_print_err("MochaDSError (mocha-ds): RBTree does not support DSKind.BOOL.");
            c_exit(2);
            return 0;
        };
        match(a.kind) {
            case DSKind.INT:
                if (a.int_val < b.int_val) { return -1; };
                if (a.int_val > b.int_val) { return 1; };
                return 0;
            case DSKind.FLOAT:
                if (a.flt_val < b.flt_val) { return -1; };
                if (a.flt_val > b.flt_val) { return 1; };
                return 0;
            case DSKind.STR:
                if (a.str_val < b.str_val) { return -1; };
                if (a.str_val > b.str_val) { return 1; };
                return 0;
            default: return 0;
        };
    };

    // Left rotation
    function rotate_left(x: RBNode) -> null {
        var y: RBNode  = x.right;
        x.right        = y.left;
        if (y.left != this.nil) {
            y.left.parent = x;
        };
        y.parent = x.parent;
        if (x.parent == this.nil) {
            this.root = y;
        } else {
            if (x == x.parent.left) {
                x.parent.left = y;
            } else {
                x.parent.right = y;
            };
        };
        y.left   = x;
        x.parent = y;
    };

    // Right rotation
    function rotate_right(y: RBNode) -> null {
        var x: RBNode  = y.left;
        y.left         = x.right;
        if (x.right != this.nil) {
            x.right.parent = y;
        };
        x.parent = y.parent;
        if (y.parent == this.nil) {
            this.root = x;
        } else {
            if (y == y.parent.left) {
                y.parent.left = x;
            } else {
                y.parent.right = x;
            };
        };
        x.right  = y;
        y.parent = x;
    };

    // Fix insert violations
    function insert_fixup(z: RBNode) -> null {
        while (z.parent.color == RBColor.RED) {
            if (z.parent == z.parent.parent.left) {
                var y: RBNode = z.parent.parent.right;
                if (y.color == RBColor.RED) {
                    // Case 1 — uncle is red
                    z.parent.color          = RBColor.BLACK;
                    y.color                 = RBColor.BLACK;
                    z.parent.parent.color   = RBColor.RED;
                    z                       = z.parent.parent;
                } else {
                    if (z == z.parent.right) {
                        // Case 2 — uncle is black, z is right child
                        z = z.parent;
                        this.rotate_left(z);
                    };
                    // Case 3 — uncle is black, z is left child
                    z.parent.color        = RBColor.BLACK;
                    z.parent.parent.color = RBColor.RED;
                    this.rotate_right(z.parent.parent);
                };
            } else {
                var y: RBNode = z.parent.parent.left;
                if (y.color == RBColor.RED) {
                    // Case 1 mirror
                    z.parent.color          = RBColor.BLACK;
                    y.color                 = RBColor.BLACK;
                    z.parent.parent.color   = RBColor.RED;
                    z                       = z.parent.parent;
                } else {
                    if (z == z.parent.left) {
                        // Case 2 mirror
                        z = z.parent;
                        this.rotate_right(z);
                    };
                    // Case 3 mirror
                    z.parent.color        = RBColor.BLACK;
                    z.parent.parent.color = RBColor.RED;
                    this.rotate_left(z.parent.parent);
                };
            };
        };
        this.root.color = RBColor.BLACK;
    };

    // Transplant — replace subtree rooted at u with subtree rooted at v
    function transplant(u: RBNode, v: RBNode) -> null {
        if (u.parent == this.nil) {
            this.root = v;
        } else {
            if (u == u.parent.left) {
                u.parent.left = v;
            } else {
                u.parent.right = v;
            };
        };
        v.parent = u.parent;
    };

    // Fix delete violations
    function delete_fixup(x: RBNode) -> null {
        while (x != this.root && x.color == RBColor.BLACK) {
            if (x == x.parent.left) {
                var w: RBNode = x.parent.right;
                if (w.color == RBColor.RED) {
                    // Case 1
                    w.color          = RBColor.BLACK;
                    x.parent.color   = RBColor.RED;
                    this.rotate_left(x.parent);
                    w = x.parent.right;
                };
                if (w.left.color == RBColor.BLACK && w.right.color == RBColor.BLACK) {
                    // Case 2
                    w.color = RBColor.RED;
                    x       = x.parent;
                } else {
                    if (w.right.color == RBColor.BLACK) {
                        // Case 3
                        w.left.color = RBColor.BLACK;
                        w.color      = RBColor.RED;
                        this.rotate_right(w);
                        w = x.parent.right;
                    };
                    // Case 4
                    w.color        = x.parent.color;
                    x.parent.color = RBColor.BLACK;
                    w.right.color  = RBColor.BLACK;
                    this.rotate_left(x.parent);
                    x = this.root;
                };
            } else {
                var w: RBNode = x.parent.left;
                if (w.color == RBColor.RED) {
                    // Case 1 mirror
                    w.color          = RBColor.BLACK;
                    x.parent.color   = RBColor.RED;
                    this.rotate_right(x.parent);
                    w = x.parent.left;
                };
                if (w.right.color == RBColor.BLACK && w.left.color == RBColor.BLACK) {
                    // Case 2 mirror
                    w.color = RBColor.RED;
                    x       = x.parent;
                } else {
                    if (w.left.color == RBColor.BLACK) {
                        // Case 3 mirror
                        w.right.color = RBColor.BLACK;
                        w.color       = RBColor.RED;
                        this.rotate_left(w);
                        w = x.parent.left;
                    };
                    // Case 4 mirror
                    w.color        = x.parent.color;
                    x.parent.color = RBColor.BLACK;
                    w.left.color   = RBColor.BLACK;
                    this.rotate_right(x.parent);
                    x = this.root;
                };
            };
        };
        x.color = RBColor.BLACK;
    };

    // Internal min node
    function min_node(n: RBNode) -> RBNode {
        var cur: RBNode = n;
        while (cur.left != this.nil) {
            cur = cur.left;
        };
        return cur;
    };

    // Internal max node
    function max_node(n: RBNode) -> RBNode {
        var cur: RBNode = n;
        while (cur.right != this.nil) {
            cur = cur.right;
        };
        return cur;
    };

    // Internal inorder
    function inorder_node(n: RBNode) -> null {
        if (n == this.nil) {
            return;
        };
        this.inorder_node(n.left);
        print(ds_to_str(n.key), newLine=true);
        this.inorder_node(n.right);
    };

    // Internal height
    function height_node(n: RBNode) -> int {
        if (n == this.nil) {
            return 0;
        };
        var lh: int = this.height_node(n.left);
        var rh: int = this.height_node(n.right);
        if (lh > rh) {
            return lh + 1;
        };
        return rh + 1;
    };

    // Internal successor
    function successor_node(n: RBNode, key: DSValue, best: RBNode) -> RBNode {
        if (n == this.nil) {
            return best;
        };
        var c: int = this.cmp(key, n.key);
        if (c < 0) {
            return this.successor_node(n.left, key, n);
        };
        return this.successor_node(n.right, key, best);
    };

    // Internal predecessor
    function predecessor_node(n: RBNode, key: DSValue, best: RBNode) -> RBNode {
        if (n == this.nil) {
            return best;
        };
        var c: int = this.cmp(key, n.key);
        if (c > 0) {
            return this.predecessor_node(n.right, key, n);
        };
        return this.predecessor_node(n.left, key, best);
    };

    // Public API

    function insert(key: DSValue) -> null {
        var z: RBNode    = RBNode(key, RBColor.RED, this.nil, this.nil, this.nil);
        var y: RBNode    = this.nil;
        var x: RBNode    = this.root;
        while (x != this.nil) {
            y = x;
            var c: int = this.cmp(z.key, x.key);
            if (c < 0) {
                x = x.left;
            } else {
                x = x.right;
            };
        };
        z.parent = y;
        if (y == this.nil) {
            this.root = z;
        } else {
            var c: int = this.cmp(z.key, y.key);
            if (c < 0) {
                y.left = z;
            } else {
                y.right = z;
            };
        };
        this.insert_fixup(z);
        this.size = this.size + 1;
    };

    function remove(key: DSValue) -> null {
        // Find node
        var z: RBNode = this.root;
        while (z != this.nil) {
            var c: int = this.cmp(key, z.key);
            if (c == 0) {
                break;
            };
            if (c < 0) {
                z = z.left;
            } else {
                z = z.right;
            };
        };
        if (z == this.nil) {
            return;
        };
        var y: RBNode       = z;
        var y_orig: RBColor = y.color;
        var x: RBNode       = this.nil;
        if (z.left == this.nil) {
            x = z.right;
            this.transplant(z, z.right);
        } else {
            if (z.right == this.nil) {
                x = z.left;
                this.transplant(z, z.left);
            } else {
                y       = this.min_node(z.right);
                y_orig  = y.color;
                x       = y.right;
                if (y.parent == z) {
                    x.parent = y;
                } else {
                    this.transplant(y, y.right);
                    y.right         = z.right;
                    y.right.parent  = y;
                };
                this.transplant(z, y);
                y.left         = z.left;
                y.left.parent  = y;
                y.color        = z.color;
            };
        };
        if (y_orig == RBColor.BLACK) {
            this.delete_fixup(x);
        };
        this.size = this.size - 1;
    };

    function contains(key: DSValue) -> bool {
        var cur: RBNode = this.root;
        while (cur != this.nil) {
            var c: int = this.cmp(key, cur.key);
            if (c == 0) {
                return true;
            };
            if (c < 0) {
                cur = cur.left;
            } else {
                cur = cur.right;
            };
        };
        return false;
    };

    function min() -> DSValue {
        if (this.root == this.nil) {
            c_print_err("MochaDSError (mocha-ds): min() on empty RBTree.");
            c_exit(2);
            return ds_int(0);
        };
        var mn: RBNode = this.min_node(this.root);
        return mn.key;
    };

    function max() -> DSValue {
        if (this.root == this.nil) {
            c_print_err("MochaDSError (mocha-ds): max() on empty RBTree.");
            c_exit(2);
            return ds_int(0);
        };
        var mx: RBNode = this.max_node(this.root);
        return mx.key;
    };

    function height() -> int {
        return this.height_node(this.root);
    };

    function inorder() -> null {
        this.inorder_node(this.root);
    };

    function successor(key: DSValue) -> DSValue {
        var s: RBNode = this.successor_node(this.root, key, this.nil);
        if (s == this.nil) {
            c_print_err("MochaDSError (mocha-ds): no successor exists for given key.");
            c_exit(2);
            return ds_int(0);
        };
        return s.key;
    };

    function predecessor(key: DSValue) -> DSValue {
        var p: RBNode = this.predecessor_node(this.root, key, this.nil);
        if (p == this.nil) {
            c_print_err("MochaDSError (mocha-ds): no predecessor exists for given key.");
            c_exit(2);
            return ds_int(0);
        };
        return p.key;
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     MY BALL TREE
     ========================  """

class BallPoint {
    var coords: float[];
    var label:  DSValue;

    function constructor(coords: float[], label: DSValue) -> null {
        this.coords = coords;
        this.label  = label;
    };
};

class BallNode {
    var centroid:  float[];
    var radius:    float;
    var label:     DSValue;
    var point:     BallPoint;
    var left:      BallNode;
    var right:     BallNode;
    var is_leaf:   bool;

    function constructor(point: BallPoint, k: int) -> null {
        this.point    = point;
        this.centroid = point.coords;
        this.radius   = 0.0;
        this.label    = point.label;
        this.left     = null;
        this.right    = null;
        this.is_leaf  = true;
    };
};

class BallTree {
    var root:         BallNode;
    var k:            int;
    var size:         int;
    var threshold:    float;
    var insert_count: int;
    var ratio_sum:    float;
    var ratio_count:  int;

    function constructor(k: int) -> null {
        this.root         = null;
        this.k            = k;
        this.size         = 0;
        this.threshold    = 2.0;
        this.insert_count = 0;
        this.ratio_sum    = 0.0;
        this.ratio_count  = 0;
    };

    // Euclidean distance squared between two coordinate arrays
    function dist_sq(a: float[], b: float[]) -> float {
        var sum: float = 0.0;
        var i: int     = 0;
        while (i < this.k) {
            var diff: float = a[i] - b[i];
            sum = sum + diff * diff;
            i   = i + 1;
        };
        return sum;
    };

    // Euclidean distance
    function dist(a: float[], b: float[]) -> float {
        var sq: float = this.dist_sq(a, b);
        return sq.sqrt().real;
    };

    // Compute centroid of a set of points
    function compute_centroid(points: BallPoint[]) -> float[] {
        var result: float[] = [];
        var i: int          = 0;
        // Initialize result with zeros
        while (i < this.k) {
            result.push(0.0);
            i++;
        };
        var j: int = 0;
        while (j < points.length) {
            i = 0;
            while (i < this.k) {
                result[i] = result[i] + points[j].coords[i];
                i         = i + 1;
            };
            j = j + 1;
        };
        i = 0;
        while (i < this.k) {
            result[i] = result[i] / points.length;
            i         = i + 1;
        };
        return result;
    };

    // Compute radius — max distance from centroid to any point
    function compute_radius(centroid: float[], points: BallPoint[]) -> float {
        var max_d: float = 0.0;
        var i: int       = 0;
        while (i < points.length) {
            var d: float = this.dist(centroid, points[i].coords);
            if (d > max_d) {
                max_d = d;
            };
            i++;
        };
        return max_d;
    };

    // Find the dimension with the most spread
    function max_spread_dim(points: BallPoint[]) -> int {
        var best_dim:    int   = 0;
        var best_spread: float = 0.0;
        var d: int             = 0;
        while (d < this.k) {
            var mn: float = points[0].coords[d];
            var mx: float = points[0].coords[d];
            var i: int    = 1;
            while (i < points.length) {
                if (points[i].coords[d] < mn) {
                    mn = points[i].coords[d];
                };
                if (points[i].coords[d] > mx) {
                    mx = points[i].coords[d];
                };
                i++;
            };
            var spread: float = mx - mn;
            if (spread > best_spread) {
                best_spread = spread;
                best_dim    = d;
            };
            d = d + 1;
        };
        return best_dim;
    };

    // Build a subtree from a set of points
    function build_node(points: BallPoint[]) -> BallNode {
        if (points.length == 1) {
            return BallNode(points[0], this.k);
        };
        var centroid: float[] = this.compute_centroid(points);
        var radius: float     = this.compute_radius(centroid, points);
        // Split on dimension with most spread
        var dim: int          = this.max_spread_dim(points);
        // Partition around centroid value on split dim
        var left_pts:  BallPoint[] = [];
        var right_pts: BallPoint[] = [];
        var i: int = 0;
        while (i < points.length) {
            if (points[i].coords[dim] < centroid[dim]) {
                left_pts.push(points[i]);
            } else {
                right_pts.push(points[i]);
            };
            i++;
        };
        // Guard: if all points fall on one side, split evenly
        if (left_pts.length == 0 || right_pts.length == 0) {
            left_pts  = [];
            right_pts = [];
            i = 0;
            while (i < points.length) {
                if (i < points.length / 2) {
                    left_pts.push(points[i]);
                } else {
                    right_pts.push(points[i]);
                };
                i++;
            };
        };
        // Create internal node with most central point as label
        var node: BallNode    = BallNode(points[0], this.k);
        node.centroid         = centroid;
        node.radius           = radius;
        node.is_leaf          = false;
        node.left             = this.build_node(left_pts);
        node.right            = this.build_node(right_pts);
        return node;
    };

    // Collect all points in a subtree
    function collect_points(n: BallNode, out: BallPoint[]) -> null {
        if (n == null) {
            return;
        };
        if (n.is_leaf) {
            out.push(n.point);
            return;
        };
        this.collect_points(n.left, out);
        this.collect_points(n.right, out);
    };

    // Check balance ratio of a node — returns ratio of larger to smaller child radius
    function balance_ratio(n: BallNode) -> float {
        if (n.is_leaf) {
            return 1.0;
        };
        if (n.left == null || n.right == null) {
            return 1.0;
        };
        var lr: float = n.left.radius;
        var rr: float = n.right.radius;
        if (lr == 0.0 && rr == 0.0) {
            return 1.0;
        };
        if (lr == 0.0) {
            return rr;
        };
        if (rr == 0.0) {
            return lr;
        };
        if (lr > rr) {
            return lr / rr;
        };
        return rr / lr;
    };

    // Update adaptive threshold every 10 inserts
    function update_threshold(n: BallNode) -> null {
        if (n == null || n.is_leaf) {
            return;
        };
        var ratio: float = this.balance_ratio(n);
        this.ratio_sum   = this.ratio_sum + ratio;
        this.ratio_count = this.ratio_count + 1;
        this.update_threshold(n.left);
        this.update_threshold(n.right);
    };

    function recalibrate() -> null {
        if (this.ratio_count == 0) {
            return;
        };
        this.update_threshold(this.root);
        if (this.ratio_count == 0) {
            return;
        };
        var avg: float = this.ratio_sum / this.ratio_count;
        // If average ratio is low, tighten threshold
        // If average ratio is high, loosen threshold
        if (avg < this.threshold * 0.75) {
            this.threshold = this.threshold * 0.95;
        };
        if (avg > this.threshold * 1.25) {
            this.threshold = this.threshold * 1.05;
        };
        // Clamp between 1.5 and 4.0
        if (this.threshold < 1.5) {
            this.threshold = 1.5;
        };
        if (this.threshold > 4.0) {
            this.threshold = 4.0;
        };
        // Reset accumulators
        this.ratio_sum   = 0.0;
        this.ratio_count = 0;
    };

    // Insert into subtree, rebalance locally if needed
    function insert_node(n: BallNode, point: BallPoint) -> BallNode {
        if (n == null) {
            return BallNode(point, this.k);
        };
        if (n.is_leaf) {
            // Expand leaf into internal node
            var pts: BallPoint[] = [];
            pts.push(n.point);
            pts.push(point);
            return this.build_node(pts);
        };
        // Route to closer child
        var dl: float = this.dist(point.coords, n.left.centroid);
        var dr: float = this.dist(point.coords, n.right.centroid);
        if (dl <= dr) {
            n.left = this.insert_node(n.left, point);
        } else {
            n.right = this.insert_node(n.right, point);
        };
        // Update centroid and radius
        var pts: BallPoint[] = [];
        this.collect_points(n, pts);
        n.centroid = this.compute_centroid(pts);
        n.radius   = this.compute_radius(n.centroid, pts);
        // Check balance — rebalance locally if over threshold
        var ratio: float = this.balance_ratio(n);
        if (ratio > this.threshold) {
            var all_pts: BallPoint[] = [];
            this.collect_points(n, all_pts);
            return this.build_node(all_pts);
        };
        return n;
    };

    // Nearest neighbor search — returns best label and updates best_dist
    function nn_search(n: BallNode, query: float[], best_label: DSValue, best_dist: float) -> float[] {
        // We encode result as [best_dist, label_encoded] — but since we can't
        // return two values, we use a workaround: store best in tree-level fields
        // This is handled by the public wrapper instead
        return query;
    };

    // Internal NN — uses mutable approach via wrapper fields
    var nn_best_dist:  float;
    var nn_best_label: DSValue;

    function nn_node(n: BallNode, query: float[]) -> null {
        if (n == null) {
            return;
        };
        // Prune — if closest possible point in this ball is farther than best, skip
        var d_center: float = this.dist(query, n.centroid);
        if (d_center - n.radius > this.nn_best_dist) {
            return;
        };
        if (n.is_leaf) {
            var d: float = this.dist(query, n.point.coords);
            if (d < this.nn_best_dist) {
                this.nn_best_dist  = d;
                this.nn_best_label = n.point.label;
            };
            return;
        };
        // Visit closer child first
        var dl: float = this.dist(query, n.left.centroid);
        var dr: float = this.dist(query, n.right.centroid);
        if (dl <= dr) {
            this.nn_node(n.left, query);
            this.nn_node(n.right, query);
        } else {
            this.nn_node(n.right, query);
            this.nn_node(n.left, query);
        };
    };

    // Internal range search
    function range_node(n: BallNode, query: float[], radius: float, out: DSValue[]) -> null {
        if (n == null) {
            return;
        };
        // Prune — if closest point in ball is farther than radius, skip
        var d_center: float = this.dist(query, n.centroid);
        if (d_center - n.radius > radius) {
            return;
        };
        if (n.is_leaf) {
            var d: float = this.dist(query, n.point.coords);
            if (d <= radius) {
                out.push(n.point.label);
            };
            return;
        };
        this.range_node(n.left, query, radius, out);
        this.range_node(n.right, query, radius, out);
    };

    // Public API

    function insert(coords: float[], label: DSValue) -> null {
        var pt: BallPoint = BallPoint(coords, label);
        this.root         = this.insert_node(this.root, pt);
        this.size         = this.size + 1;
        this.insert_count = this.insert_count + 1;
        if (this.insert_count % 10 == 0) {
            this.recalibrate();
        };
    };

    function nearest_neighbor(query: float[]) -> DSValue {
        if (this.root == null) {
            c_print_err("MochaDSError (mocha-ds): nearest_neighbor on empty BallTree.");
            c_exit(2);
            return ds_int(0);
        };
        this.nn_best_dist  = 999999999.0;
        this.nn_best_label = this.root.point.label;
        this.nn_node(this.root, query);
        return this.nn_best_label;
    };

    function range_search(query: float[], radius: float) -> DSValue[] {
        var out: DSValue[] = [];
        this.range_node(this.root, query, radius, out);
        return out;
    };

    function contains(coords: float[]) -> bool {
        var cur: BallNode = this.root;
        while (cur != null) {
            if (cur.is_leaf) {
                var d: float = this.dist(coords, cur.point.coords);
                if (d == 0.0) {
                    return true;
                };
                return false;
            };
            var dl: float = this.dist(coords, cur.left.centroid);
            var dr: float = this.dist(coords, cur.right.centroid);
            if (dl <= dr) {
                cur = cur.left;
            } else {
                cur = cur.right;
            };
        };
        return false;
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     PATRICIA
     ========================  """

class PatriciaNode {
    var is_terminal:    bool;
    var value:          DSValue;
    var edge_labels:    str[];
    var edge_children:  PatriciaNode[];

    function constructor() -> null {
        this.is_terminal   = false;
        this.value         = null;
        this.edge_labels   = [];
        this.edge_children = [];
    };
};

class Patricia {
    var root:          PatriciaNode;
    var size:          int;
    var delete_found:  bool;

    function constructor() -> null {
        this.root         = PatriciaNode();
        this.size         = 0;
        this.delete_found = false;
    };

    // Single character at index i
    function char_at(s: str, i: int) -> str {
        return s.substring(i, i);
    };

    // Length of common prefix between two strings
    function common_prefix_len(a: str, b: str) -> int {
        var la: int      = a.length;
        var lb: int      = b.length;
        var min_len: int = la;
        if (lb < min_len) {
            min_len = lb;
        };
        var i: int = 0;
        while (i < min_len) {
            var ca: str = this.char_at(a, i);
            var cb: str = this.char_at(b, i);
            if (ca != cb) {
                break;
            };
            i++;
        };
        return i;
    };

    // Substring from begin to end of string
    function substr(s: str, begin: int) -> str {
        if (begin >= s.length) {
            return "";
        };
        return s.substring(begin, s.length - 1);
    };

    // Insert key-value pair
    function insert(key: str, value: DSValue) -> null {
        var inserted: bool = this.insert_node(this.root, key, value);
        if (inserted) {
            this.size = this.size + 1;
        };
    };

    // Returns true if a new key was inserted (false if existing key was updated)
    function insert_node(node: PatriciaNode, key: str, value: DSValue) -> bool {
        if (key.length == 0) {
            var was_new: bool = node.is_terminal == false;
            node.is_terminal  = true;
            node.value        = value;
            return was_new;
        };
        var i: int = 0;
        while (i < node.edge_labels.length) {
            var label: str = node.edge_labels[i];
            var cp: int    = this.common_prefix_len(label, key);
            if (cp == 0) {
                i++;
            } else {
                if (cp == label.length) {
                    // Full edge consumed — recurse into child with remaining key
                    var rest: str = this.substr(key, cp);
                    return this.insert_node(node.edge_children[i], rest, value);
                } else {
                    // Partial match — split the edge
                    var common_str: str = label.substring(0, cp - 1);
                    var old_rest: str    = this.substr(label, cp);
                    var new_rest: str    = this.substr(key, cp);

                    // Create intermediate node
                    var mid: PatriciaNode = PatriciaNode();
                    mid.edge_labels.push(old_rest);
                    mid.edge_children.push(node.edge_children[i]);

                    if (new_rest.length == 0) {
                        mid.is_terminal = true;
                        mid.value       = value;
                    } else {
                        var new_node: PatriciaNode = PatriciaNode();
                        new_node.is_terminal        = true;
                        new_node.value              = value;
                        mid.edge_labels.push(new_rest);
                        mid.edge_children.push(new_node);
                    };

                    node.edge_labels[i]   = common_str;
                    node.edge_children[i] = mid;
                    return true;
                };
            };
        };
        // No matching edge — create new edge with full remaining key
        var leaf: PatriciaNode = PatriciaNode();
        leaf.is_terminal       = true;
        leaf.value             = value;
        node.edge_labels.push(key);
        node.edge_children.push(leaf);
        return true;
    };

    // Find node for exact key, or null
    function find_node(key: str) -> PatriciaNode {
        var node: PatriciaNode = this.root;
        var remaining: str     = key;
        while (remaining.length > 0) {
            var found: bool = false;
            var i: int       = 0;
            while (i < node.edge_labels.length) {
                var label: str = node.edge_labels[i];
                var cp: int    = this.common_prefix_len(label, remaining);
                if (cp == label.length && cp > 0) {
                    remaining = this.substr(remaining, cp);
                    node      = node.edge_children[i];
                    found     = true;
                    break;
                };
                i++;
            };
            if (found == false) {
                return null;
            };
        };
        if (node.is_terminal) {
            return node;
        };
        return null;
    };

    function contains(key: str) -> bool {
        var node: PatriciaNode = this.find_node(key);
        return node != null;
    };

    function get(key: str) -> DSValue {
        var node: PatriciaNode = this.find_node(key);
        if (node == null) {
            c_print_err("MochaDSError (mocha-ds): key not found in Patricia.");
            c_exit(2);
            return ds_int(0);
        };
        return node.value;
    };

    // Returns true if any key starts with prefix
    function starts_with(prefix: str) -> bool {
        var node: PatriciaNode = this.root;
        var remaining: str     = prefix;
        while (remaining.length > 0) {
            var found: bool = false;
            var i: int       = 0;
            while (i < node.edge_labels.length) {
                var label: str = node.edge_labels[i];
                var cp: int    = this.common_prefix_len(label, remaining);
                if (cp == 0) {
                    i++;
                } else {
                    if (cp == remaining.length) {
                        return true;
                    };
                    if (cp == label.length) {
                        remaining = this.substr(remaining, cp);
                        node      = node.edge_children[i];
                        found     = true;
                        break;
                    } else {
                        return false;
                    };
                };
            };
            if (found == false) {
                return false;
            };
        };
        return true;
    };

    // Collect all words under a node with accumulated prefix
    function collect_words(node: PatriciaNode, prefix: str, out: DSValue[]) -> null {
        if (node.is_terminal) {
            out.push(ds_str(prefix));
        };
        var i: int = 0;
        while (i < node.edge_labels.length) {
            this.collect_words(node.edge_children[i], prefix + node.edge_labels[i], out);
            i++;
        };
    };

    // Return all words starting with prefix
    function all_with_prefix(prefix: str) -> DSValue[] {
        var out: DSValue[]    = [];
        var node: PatriciaNode = this.root;
        var remaining: str     = prefix;
        var matched: str       = "";
        while (remaining.length > 0) {
            var found: bool = false;
            var i: int       = 0;
            while (i < node.edge_labels.length) {
                var label: str = node.edge_labels[i];
                var cp: int    = this.common_prefix_len(label, remaining);
                if (cp == 0) {
                    i++;
                } else {
                    if (cp == remaining.length) {
                        if (cp == label.length) {
                            matched = matched + label;
                            this.collect_words(node.edge_children[i], matched, out);
                        } else {
                            matched = matched + label;
                            this.collect_words(node.edge_children[i], matched, out);
                        };
                        return out;
                    };
                    if (cp == label.length) {
                        matched   = matched + label;
                        remaining = this.substr(remaining, cp);
                        node      = node.edge_children[i];
                        found     = true;
                        break;
                    } else {
                        return out;
                    };
                };
            };
            if (found == false) {
                return out;
            };
        };
        this.collect_words(node, matched, out);
        return out;
    };

    // Rebuild edge arrays excluding index idx
    function remove_edge_at(node: PatriciaNode, idx: int) -> null {
        var new_labels: str[]            = [];
        var new_children: PatriciaNode[] = [];
        var i: int = 0;
        while (i < node.edge_labels.length) {
            if (i != idx) {
                new_labels.push(node.edge_labels[i]);
                new_children.push(node.edge_children[i]);
            };
            i++;
        };
        node.edge_labels   = new_labels;
        node.edge_children = new_children;
    };

    // Recursive delete with edge merging — mutates node in place, returns node
    function delete_rec(node: PatriciaNode, key: str) -> PatriciaNode {
        if (key.length == 0) {
            if (node.is_terminal) {
                node.is_terminal  = false;
                node.value        = null;
                this.delete_found = true;
            };
            return node;
        };
        var i: int = 0;
        while (i < node.edge_labels.length) {
            var label: str = node.edge_labels[i];
            var cp: int    = this.common_prefix_len(label, key);
            if (cp == label.length && cp == key.length) {
                // Exact match — this edge's child is the target
                var child: PatriciaNode = node.edge_children[i];
                if (child.is_terminal) {
                    child.is_terminal  = false;
                    child.value        = null;
                    this.delete_found  = true;
                    if (child.edge_labels.length == 0) {
                        this.remove_edge_at(node, i);
                    } else {
                        if (child.edge_labels.length == 1) {
                            var merged_label: str = label + child.edge_labels[0];
                            node.edge_labels[i]   = merged_label;
                            node.edge_children[i] = child.edge_children[0];
                        };
                    };
                };
                return node;
            } else {
                if (cp == label.length && cp < key.length) {
                    var rest: str               = this.substr(key, cp);
                    var new_child: PatriciaNode = this.delete_rec(node.edge_children[i], rest);
                    if (new_child.edge_labels.length == 0 && new_child.is_terminal == false) {
                        this.remove_edge_at(node, i);
                    } else {
                        if (new_child.edge_labels.length == 1 && new_child.is_terminal == false) {
                            var merged_label2: str = label + new_child.edge_labels[0];
                            node.edge_labels[i]    = merged_label2;
                            node.edge_children[i]  = new_child.edge_children[0];
                        };
                    };
                    return node;
                } else {
                    i++;
                };
            };
        };
        return node;
    };

    // Delete a key — returns true if key existed and was removed
    function delete(key: str) -> bool {
        this.delete_found = false;
        this.root         = this.delete_rec(this.root, key);
        if (this.delete_found) {
            this.size = this.size - 1;
        };
        return this.delete_found;
    };

    function is_empty() -> bool {
        return this.size == 0;
    };
};

"""  ========================
     GRAPH
     ========================  """

class GraphEdge {
    var to:     str;
    var weight: float;

    function constructor(to: str, weight: float) -> null {
        this.to     = to;
        this.weight = weight;
    };
};

class GraphNode {
    var label: str;
    var edges: GraphEdge[];

    function constructor(label: str) -> null {
        this.label = label;
        this.edges = [];
    };
};

class Graph {
    var nodes:       GraphNode[];
    var is_directed: bool;
    var size:        int;

    function constructor(is_directed: bool) -> null {
        this.nodes       = [];
        this.is_directed = is_directed;
        this.size        = 0;
    };

    function index_of(label: str) -> int {
        var i: int = 0;
        while (i < this.nodes.length) {
            if (this.nodes[i].label == label) {
                return i;
            };
            i++;
        };
        return -1;
    };

    function contains(label: str) -> bool {
        return this.index_of(label) != -1;
    };

    function add_node(label: str) -> null {
        if (this.index_of(label) == -1) {
            this.nodes.push(GraphNode(label));
            this.size = this.size + 1;
        };
    };

    function add_edge(src: str, to: str, weight: float) -> null {
        this.add_node(src);
        this.add_node(to);
        var fi: int = this.index_of(src);
        this.nodes[fi].edges.push(GraphEdge(to, weight));
        if (this.is_directed == false) {
            var ti: int = this.index_of(to);
            this.nodes[ti].edges.push(GraphEdge(src, weight));
        };
    };

    function is_empty() -> bool {
        return this.size == 0;
    };

    function bfs(begin_node: str) -> DSValue[] {
        var out: DSValue[] = [];
        if (this.contains(begin_node) == false) {
            return out;
        };
        var visited: str[] = [];
        var queue: str[]   = [];
        queue.push(begin_node);
        visited.push(begin_node);
        while (queue.length > 0) {
            var current: str = queue[0];
            var new_queue: str[] = [];
            var i: int = 1;
            while (i < queue.length) {
                new_queue.push(queue[i]);
                i++;
            };
            queue = new_queue;

            out.push(ds_str(current));

            var ci: int = this.index_of(current);
            var j: int = 0;
            while (j < this.nodes[ci].edges.length) {
                var nbr: str = this.nodes[ci].edges[j].to;
                var seen: bool = false;
                var k: int = 0;
                while (k < visited.length) {
                    if (visited[k] == nbr) {
                        seen = true;
                        break;
                    };
                    k = k + 1;
                };
                if (seen == false) {
                    visited.push(nbr);
                    queue.push(nbr);
                };
                j = j + 1;
            };
        };
        return out;
    };

    function dfs(begin_node: str) -> DSValue[] {
        var out: DSValue[] = [];
        if (this.contains(begin_node) == false) {
            return out;
        };
        var visited: str[] = [];
        this.dfs_visit(begin_node, visited, out);
        return out;
    };

    function dfs_visit(label: str, visited: str[], out: DSValue[]) -> null {
        visited.push(label);
        out.push(ds_str(label));
        var ci: int = this.index_of(label);
        var j: int = 0;
        while (j < this.nodes[ci].edges.length) {
            var nbr: str = this.nodes[ci].edges[j].to;
            var seen: bool = false;
            var k: int = 0;
            while (k < visited.length) {
                if (visited[k] == nbr) {
                    seen = true;
                    break;
                };
                k = k + 1;
            };
            if (seen == false) {
                this.dfs_visit(nbr, visited, out);
            };
            j = j + 1;
        };
    };

    function dijkstra(begin_node: str, end: str) -> float {
        if (this.contains(begin_node) == false || this.contains(end) == false) {
            return -1.0;
        };
        var n: int = this.nodes.length;
        var dist: float[]   = [];
        var visited: bool[] = [];
        var i: int = 0;
        while (i < n) {
            dist.push(1000000000.0);
            visited.push(false);
            i++;
        };
        var si: int = this.index_of(begin_node);
        dist[si] = 0.0;

        var count: int = 0;
        while (count < n) {
            var u: int = -1;
            var best: float = 1000000001.0;
            var v: int = 0;
            while (v < n) {
                if (visited[v] == false && dist[v] < best) {
                    best = dist[v];
                    u    = v;
                };
                v = v + 1;
            };
            if (u == -1) {
                break;
            };
            visited[u] = true;

            var j: int = 0;
            while (j < this.nodes[u].edges.length) {
                var edge: GraphEdge = this.nodes[u].edges[j];
                var vi: int = this.index_of(edge.to);
                if (visited[vi] == false) {
                    var alt: float = dist[u] + edge.weight;
                    if (alt < dist[vi]) {
                        dist[vi] = alt;
                    };
                };
                j = j + 1;
            };
            count = count + 1;
        };

        var ei: int = this.index_of(end);
        if (dist[ei] >= 1000000000.0) {
            return -1.0;
        };
        return dist[ei];
    };

    function bellman_ford(begin_node: str, end: str) -> float {
        if (this.contains(begin_node) == false || this.contains(end) == false) {
            return -1.0;
        };
        var n: int = this.nodes.length;
        var dist: float[] = [];
        var i: int = 0;
        while (i < n) {
            dist.push(1000000000.0);
            i++;
        };
        var si: int = this.index_of(begin_node);
        dist[si] = 0.0;

        var iter: int = 0;
        while (iter < n - 1) {
            var u: int = 0;
            while (u < n) {
                if (dist[u] < 1000000000.0) {
                    var j: int = 0;
                    while (j < this.nodes[u].edges.length) {
                        var edge: GraphEdge = this.nodes[u].edges[j];
                        var vi: int = this.index_of(edge.to);
                        var alt: float = dist[u] + edge.weight;
                        if (alt < dist[vi]) {
                            dist[vi] = alt;
                        };
                        j = j + 1;
                    };
                };
                u = u + 1;
            };
            iter = iter + 1;
        };

        var u2: int = 0;
        while (u2 < n) {
            if (dist[u2] < 1000000000.0) {
                var j2: int = 0;
                while (j2 < this.nodes[u2].edges.length) {
                    var edge2: GraphEdge = this.nodes[u2].edges[j2];
                    var vi2: int = this.index_of(edge2.to);
                    var alt2: float = dist[u2] + edge2.weight;
                    if (alt2 < dist[vi2]) {
                        return -2.0;
                    };
                    j2 = j2 + 1;
                };
            };
            u2 = u2 + 1;
        };

        var ei: int = this.index_of(end);
        if (dist[ei] >= 1000000000.0) {
            return -1.0;
        };
        return dist[ei];
    };

    """  ========================
         MST: PRIM, KRUSKAL, BORUVKA
         ======================== """

    // Prim's algorithm — returns total weight of MST (assumes connected graph)
    // Returns -1.0 if graph is empty
    function prim() -> float {
        var n: int = this.nodes.length;
        if (n == 0) {
            return -1.0;
        };
        var in_mst: bool[]  = [];
        var key: float[]    = [];
        var i: int = 0;
        while (i < n) {
            in_mst.push(false);
            key.push(1000000000.0);
            i++;
        };
        key[0] = 0.0;
        var total: float = 0.0;

        var count: int = 0;
        while (count < n) {
            var u: int = -1;
            var best: float = 1000000001.0;
            var v: int = 0;
            while (v < n) {
                if (in_mst[v] == false && key[v] < best) {
                    best = key[v];
                    u    = v;
                };
                v = v + 1;
            };
            if (u == -1) {
                break;
            };
            in_mst[u] = true;
            total     = total + key[u];

            var j: int = 0;
            while (j < this.nodes[u].edges.length) {
                var edge: GraphEdge = this.nodes[u].edges[j];
                var vi: int = this.index_of(edge.to);
                if (in_mst[vi] == false && edge.weight < key[vi]) {
                    key[vi] = edge.weight;
                };
                j = j + 1;
            };
            count = count + 1;
        };
        return total;
    };

    // Find root of set containing x (with path compression)
    function find_set(parent: int[], x: int) -> int {
        if (parent[x] != x) {
            parent[x] = this.find_set(parent, parent[x]);
        };
        return parent[x];
    };

    // Union two sets, returns true if they were different (i.e. union happened)
    function union_sets(parent: int[], rank: int[], a: int, b: int) -> bool {
        var ra: int = this.find_set(parent, a);
        var rb: int = this.find_set(parent, b);
        if (ra == rb) {
            return false;
        };
        if (rank[ra] < rank[rb]) {
            parent[ra] = rb;
        } else {
            if (rank[ra] > rank[rb]) {
                parent[rb] = ra;
            } else {
                parent[rb] = ra;
                rank[ra]   = rank[ra] + 1;
            };
        };
        return true;
    };

    // Kruskal's algorithm — returns total weight of MST (assumes connected graph)
    // Returns -1.0 if graph is empty
    function kruskal() -> float {
        var n: int = this.nodes.length;
        if (n == 0) {
            return -1.0;
        };

        // Collect all edges as (u, v, weight) — for undirected, avoid duplicates by only taking u < v
        var edge_u: int[]   = [];
        var edge_v: int[]   = [];
        var edge_w: float[] = [];

        var u: int = 0;
        while (u < n) {
            var j: int = 0;
            while (j < this.nodes[u].edges.length) {
                var edge: GraphEdge = this.nodes[u].edges[j];
                var v: int = this.index_of(edge.to);
                if (this.is_directed || u < v) {
                    edge_u.push(u);
                    edge_v.push(v);
                    edge_w.push(edge.weight);
                };
                j = j + 1;
            };
            u = u + 1;
        };

        // Sort edges by weight (simple insertion sort)
        var m: int = edge_w.length;
        var i: int = 1;
        // Iterative quicksort on edge_u/edge_v/edge_w by weight, ascending
        if (m > 1) {
            var stack_lo: int[] = [0];
            var stack_hi: int[] = [m - 1];
            while (stack_lo.length > 0) {
                var low: int  = stack_lo[stack_lo.length - 1];
                var high: int = stack_hi[stack_hi.length - 1];
                stack_lo.pop();
                stack_hi.pop();

                if (low < high) {
                    var pivot: float = edge_w[high];
                    var pi: int = low - 1;
                    var j: int = low;
                    while (j < high) {
                        if (edge_w[j] < pivot) {
                            pi = pi + 1;
                            var tu: int = edge_u[pi]; edge_u[pi] = edge_u[j]; edge_u[j] = tu;
                            var tv: int = edge_v[pi]; edge_v[pi] = edge_v[j]; edge_v[j] = tv;
                            var tw: float = edge_w[pi]; edge_w[pi] = edge_w[j]; edge_w[j] = tw;
                        };
                        j = j + 1;
                    };
                    pi = pi + 1;
                    var tu2: int = edge_u[pi]; edge_u[pi] = edge_u[high]; edge_u[high] = tu2;
                    var tv2: int = edge_v[pi]; edge_v[pi] = edge_v[high]; edge_v[high] = tv2;
                    var tw2: float = edge_w[pi]; edge_w[pi] = edge_w[high]; edge_w[high] = tw2;

                    stack_lo.push(low);
                    stack_hi.push(pi - 1);
                    stack_lo.push(pi + 1);
                    stack_hi.push(high);
                };
            };
        };

        // Union-Find
        var parent: int[] = [];
        var rank: int[]   = [];
        var p: int = 0;
        while (p < n) {
            parent.push(p);
            rank.push(0);
            p = p + 1;
        };

        var total: float = 0.0;
        var edges_used: int = 0;
        var e: int = 0;
        while (e < m && edges_used < n - 1) {
            if (this.union_sets(parent, rank, edge_u[e], edge_v[e])) {
                total       = total + edge_w[e];
                edges_used  = edges_used + 1;
            };
            e = e + 1;
        };
        return total;
    };

    // Boruvka's algorithm — returns total weight of MST (assumes connected graph)
    // Returns -1.0 if graph is empty
    function boruvka() -> float {
        var n: int = this.nodes.length;
        if (n == 0) {
            return -1.0;
        };

        var parent: int[] = [];
        var rank: int[]   = [];
        var p: int = 0;
        while (p < n) {
            parent.push(p);
            rank.push(0);
            p = p + 1;
        };

        var total: float    = 0.0;
        var num_trees: int  = n;

        while (num_trees > 1) {
            // cheapest[component_root] = (weight, u, v) — track best edge per component
            var cheap_w: float[] = [];
            var cheap_u: int[]   = [];
            var cheap_v: int[]   = [];
            var has_cheap: bool[] = [];
            var i: int = 0;
            while (i < n) {
                cheap_w.push(1000000000.0);
                cheap_u.push(-1);
                cheap_v.push(-1);
                has_cheap.push(false);
                i++;
            };

            var u: int = 0;
            while (u < n) {
                var j: int = 0;
                while (j < this.nodes[u].edges.length) {
                    var edge: GraphEdge = this.nodes[u].edges[j];
                    var v: int = this.index_of(edge.to);
                    var ru: int = this.find_set(parent, u);
                    var rv: int = this.find_set(parent, v);
                    if (ru != rv) {
                        if (edge.weight < cheap_w[ru]) {
                            cheap_w[ru]   = edge.weight;
                            cheap_u[ru]   = u;
                            cheap_v[ru]   = v;
                            has_cheap[ru] = true;
                        };
                        if (edge.weight < cheap_w[rv]) {
                            cheap_w[rv]   = edge.weight;
                            cheap_u[rv]   = u;
                            cheap_v[rv]   = v;
                            has_cheap[rv] = true;
                        };
                    };
                    j = j + 1;
                };
                u = u + 1;
            };

            var merged: bool = false;
            var r: int = 0;
            while (r < n) {
                if (has_cheap[r]) {
                    var did_union: bool = this.union_sets(parent, rank, cheap_u[r], cheap_v[r]);
                    if (did_union) {
                        total      = total + cheap_w[r];
                        num_trees  = num_trees - 1;
                        merged     = true;
                    };
                };
                r = r + 1;
            };

            if (merged == false) {
                break;
            };
        };

        return total;
    };

    // My Own Algorithm
    // GravityMerge — multi-seed traversal with collision-triggered merging.
    // Not a minimum spanning tree — produces a spanning tree via cluster
    // expansion and merging. Returns node labels in absorption order.
    function gravity_merge() -> DSValue[] {
        var out: DSValue[] = [];
        var n: int = this.nodes.length;
        if (n == 0) {
            return out;
        };
        if (n == 1) {
            out.push(ds_str(this.nodes[0].label));
            return out;
        };

        // owner[i] = cluster id that owns node i, or -1 if unclaimed
        var owner: int[] = [];
        var i: int = 0;
        while (i < n) {
            owner.push(-1);
            i++;
        };

        // ---- Collect undirected/deduped edges ----
        var edge_u: int[]   = [];
        var edge_v: int[]   = [];
        var edge_w: float[] = [];
        var u: int = 0;
        while (u < n) {
            var j: int = 0;
            while (j < this.nodes[u].edges.length) {
                var edge: GraphEdge = this.nodes[u].edges[j];
                var v: int = this.index_of(edge.to);
                if (this.is_directed || u < v) {
                    edge_u.push(u);
                    edge_v.push(v);
                    edge_w.push(edge.weight);
                };
                j++;
            };
            u++;
        };

        // sort edges by weight (iterative quicksort, ascending)
        var m: int = edge_w.length;
        if (m > 1) {
            var stack_lo: int[] = [0];
            var stack_hi: int[] = [m - 1];
            while (stack_lo.length > 0) {
                var low: int  = stack_lo[stack_lo.length - 1];
                var high: int = stack_hi[stack_hi.length - 1];
                stack_lo.pop();
                stack_hi.pop();
                if (low < high) {
                    var pivot: float = edge_w[high];
                    var pi: int = low - 1;
                    var jj: int = low;
                    while (jj < high) {
                        if (edge_w[jj] < pivot) {
                            pi++;
                            var tu: int = edge_u[pi]; edge_u[pi] = edge_u[jj]; edge_u[jj] = tu;
                            var tv: int = edge_v[pi]; edge_v[pi] = edge_v[jj]; edge_v[jj] = tv;
                            var tw: float = edge_w[pi]; edge_w[pi] = edge_w[jj]; edge_w[jj] = tw;
                        };
                        jj++;
                    };
                    pi++;
                    var tu2: int = edge_u[pi]; edge_u[pi] = edge_u[high]; edge_u[high] = tu2;
                    var tv2: int = edge_v[pi]; edge_v[pi] = edge_v[high]; edge_v[high] = tv2;
                    var tw2: float = edge_w[pi]; edge_w[pi] = edge_w[high]; edge_w[high] = tw2;
                    stack_lo.push(low);
                    stack_hi.push(pi - 1);
                    stack_lo.push(pi + 1);
                    stack_hi.push(high);
                };
            };
        };

        // ---- Seeding: greedy non-overlapping cheapest edges, capped at 5 ----
        var num_clusters: int = 0;
        var max_seeds: int = 5;
        var e: int = 0;
        while (e < m && num_clusters < max_seeds) {
            var su: int = edge_u[e];
            var sv: int = edge_v[e];
            if (owner[su] == -1 && owner[sv] == -1) {
                owner[su] = num_clusters;
                owner[sv] = num_clusters;
                out.push(ds_str(this.nodes[su].label));
                out.push(ds_str(this.nodes[sv].label));
                num_clusters = num_clusters + 1;
            };
            e++;
        };

        // Fallback: if no seed could be placed (e.g. no edges), seed node 0 alone
        if (num_clusters == 0) {
            owner[0] = 0;
            out.push(ds_str(this.nodes[0].label));
            num_clusters = 1;
        };

        var active: bool[] = [];
        var ac: int = 0;
        while (ac < num_clusters) {
            active.push(true);
            ac++;
        };

        // ---- Expansion rounds ----
        var claimed_total: int = out.length;
        while (claimed_total < n) {
            var pick_target: int[]   = [];
            var pick_weight: float[] = [];
            var c: int = 0;
            while (c < num_clusters) {
                var best_w: float = 1000000000.0;
                var best_target: int = -1;
                if (active[c]) {
                    var node_idx: int = 0;
                    while (node_idx < n) {
                        if (owner[node_idx] == c) {
                            var jj2: int = 0;
                            while (jj2 < this.nodes[node_idx].edges.length) {
                                var edge2: GraphEdge = this.nodes[node_idx].edges[jj2];
                                var tgt: int = this.index_of(edge2.to);
                                if (owner[tgt] != c) {
                                    if (edge2.weight < best_w) {
                                        best_w      = edge2.weight;
                                        best_target = tgt;
                                    };
                                };
                                jj2++;
                            };
                        };
                        node_idx++;
                    };
                };
                pick_target.push(best_target);
                pick_weight.push(best_w);
                c++;
            };

            // Apply all picks simultaneously; detect collisions/merges
            var any_progress: bool = false;
            var c2: int = 0;
            while (c2 < num_clusters) {
                if (active[c2] && pick_target[c2] != -1) {
                    var tgt2: int = pick_target[c2];
                    var existing_owner: int = owner[tgt2];

                    if (existing_owner == -1) {
                        // claim unclaimed node
                        owner[tgt2] = c2;
                        out.push(ds_str(this.nodes[tgt2].label));
                        claimed_total = claimed_total + 1;
                        any_progress = true;
                    } else {
                        if (existing_owner != c2 && active[existing_owner]) {
                            // collision — merge existing_owner into c2
                            var k2: int = 0;
                            while (k2 < n) {
                                if (owner[k2] == existing_owner) {
                                    owner[k2] = c2;
                                };
                                k2++;
                            };
                            active[existing_owner] = false;
                            any_progress = true;
                        };
                    };
                };
                c2++;
            };

            if (any_progress == false) {
                // No cluster could expand (disconnected graph) — stop
                break;
            };
        };

        return out;
    };
};

"""  ========================
     BLOOM FILTER
     ========================  """

class BloomFilter {
    var bits:  bool[];
    var m:     int;
    var k:     int;
    var count: int;

    function constructor(expected_items: int, false_positive_rate: float) -> null {
        var n: float = float(expected_items);
        var p: float = false_positive_rate;
        var ln2: float = 0.6931471805599453;
        var ln_p: float = p.log().real;
        var m_calc: float = (-1.0 * n * ln_p) / (ln2 * ln2);
        this.m = int(m_calc) + 1;
        if (this.m < 1) {
            this.m = 1;
        };

        var k_calc: float = (float(this.m) / n) * ln2;
        this.k = int(k_calc + 0.5);
        if (this.k < 1) {
            this.k = 1;
        };

        this.bits = [];
        var i: int = 0;
        while (i < this.m) {
            this.bits.push(false);
            i++;
        };
        this.count = 0;
    };

    // Kirsch-Mitzenmacher double hashing: h_i(x) = (h1 + i*h2) mod m
    function index_for(item: str, i: int) -> int {
        var h1: int = mocha_fnv1a(item);
        var h2: int = mocha_djb2(item);
        if (h1 < 0) {
            h1 = h1 * -1;
        };
        if (h2 < 0) {
            h2 = h2 * -1;
        };
        var combined: int = h1 + i * h2;
        if (combined < 0) {
            combined = combined * -1;
        };
        return combined % this.m;
    };

    function add(item: str) -> null {
        var i: int = 0;
        while (i < this.k) {
            var idx: int = this.index_for(item, i);
            this.bits[idx] = true;
            i++;
        };
        this.count = this.count + 1;
    };

    // Returns false = definitely not present, true = probably present
    function contains(item: str) -> bool {
        var i: int = 0;
        while (i < this.k) {
            var idx: int = this.index_for(item, i);
            if (this.bits[idx] == false) {
                return false;
            };
            i++;
        };
        return true;
    };

    function is_empty() -> bool {
        return this.count == 0;
    };
};


"""  ========================
     COUNTING BLOOM FILTER
     ========================  """

class CountingBloomFilter {
    var counters: int[];
    var m:        int;
    var k:        int;
    var count:    int;

    function constructor(expected_items: int, false_positive_rate: float) -> null {
        var n: float = float(expected_items);
        var p: float = false_positive_rate;
        var ln2: float = 0.6931471805599453;
        var ln_p: float = p.log().real;
        var m_calc: float = (-1.0 * n * ln_p) / (ln2 * ln2);
        this.m = int(m_calc) + 1;
        if (this.m < 1) {
            this.m = 1;
        };

        var k_calc: float = (float(this.m) / n) * ln2;
        this.k = int(k_calc + 0.5);
        if (this.k < 1) {
            this.k = 1;
        };

        this.counters = [];
        var i: int = 0;
        while (i < this.m) {
            this.counters.push(0);
            i++;
        };
        this.count = 0;
    };

    function index_for(item: str, i: int) -> int {
        var h1: int = mocha_fnv1a(item);
        var h2: int = mocha_djb2(item);
        if (h1 < 0) {
            h1 = h1 * -1;
        };
        if (h2 < 0) {
            h2 = h2 * -1;
        };
        var combined: int = h1 + i * h2;
        if (combined < 0) {
            combined = combined * -1;
        };
        return combined % this.m;
    };

    function add(item: str) -> null {
        var i: int = 0;
        while (i < this.k) {
            var idx: int = this.index_for(item, i);
            this.counters[idx] = this.counters[idx] + 1;
            i++;
        };
        this.count = this.count + 1;
    };

    function contains(item: str) -> bool {
        var i: int = 0;
        while (i < this.k) {
            var idx: int = this.index_for(item, i);
            if (this.counters[idx] == 0) {
                return false;
            };
            i++;
        };
        return true;
    };

    // Only call if item was definitely added before — removing an item
    // never added can corrupt the filter for others
    function remove(item: str) -> null {
        var i: int = 0;
        while (i < this.k) {
            var idx: int = this.index_for(item, i);
            if (this.counters[idx] > 0) {
                this.counters[idx] = this.counters[idx] - 1;
            };
            i++;
        };
        this.count = this.count - 1;
    };

    function is_empty() -> bool {
        return this.count == 0;
    };
};