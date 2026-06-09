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
            i = i + 1;
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