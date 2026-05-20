// ============================================================
// symtable.mch — Symbol Table for Mocha Self-Hosted Type Checker
// ============================================================

// ============================================================
// SYMBOL INFO
// Stores all metadata about a declared name
// ============================================================
class SymbolInfo {
    var type:        str;
    var is_const:    bool;
    var is_function: bool;
    var is_class:    bool;
    var visibility:  str;

    function constructor() -> null {
        this.type        = "";
        this.is_const    = false;
        this.is_function = false;
        this.is_class    = false;
        this.visibility  = "public";
    };
};

// ============================================================
// SCOPE
// One hashtable per scope level
// ============================================================
class Scope {
    var table: HashTable;

    function constructor() -> null {
        this.table = HashTable();
    };

    function declare(name: str, info: SymbolInfo) -> null {
        this.table.put(name, info);
    };

    function lookup(name: str) -> SymbolInfo {
        if (this.table.has(name)) {
            return this.table.get(name);
        };
        return null;
    };

    function has(name: str) -> bool {
        return this.table.has(name);
    };
};

// ============================================================
// SYMBOL TABLE
// Stack of scopes — innermost to outermost
// ============================================================
class SymbolTable {
    var scopes: Scope[];

    function constructor() -> null {
        this.scopes = [];
        // push global scope
        var global: Scope = Scope();
        this.scopes.push(global);
    };

    function push_scope() -> null {
        var s: Scope = Scope();
        this.scopes.push(s);
    };

    function pop_scope() -> null {
        this.scopes.pop();
    };

    function declare(name: str, info: SymbolInfo) -> null {
        // declare in current (innermost) scope
        var top: Scope = this.scopes[this.scopes.length - 1];
        top.declare(name, info);
    };

    function lookup(name: str) -> SymbolInfo {
        // search from innermost to outermost
        var i: int = this.scopes.length - 1;
        while (i >= 0) {
            var found: SymbolInfo = this.scopes[i].lookup(name);
            if (found != null) {
                return found;
            };
            i = i - 1;
        };
        return null;
    };

    function declared_in_current(name: str) -> bool {
        var top: Scope = this.scopes[this.scopes.length - 1];
        return top.has(name);
    };
};