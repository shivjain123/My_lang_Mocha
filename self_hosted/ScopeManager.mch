class ScopeManager {
    var scopes: HashTable[];

    function constructor() -> null {
        this.scopes = [];
        this.scopes.push(HashTable());
    };

    function encodeSymbol(type_str: str, is_const: bool,
                          is_function: bool, is_class: bool,
                          visibility: str) -> str {
        var c: str = "false";
        var f: str = "false";
        var k: str = "false";
        if (is_const)    { c = "true"; };
        if (is_function) { f = "true"; };
        if (is_class)    { k = "true"; };
        return type_str + "|" + c + "|" + f + "|" + k + "|" + visibility;
    };

    function decodeField(encoded: str, idx: int) -> str {
        var current: str = "";
        var count: int = 0;
        var i: int = 0;
        while (i < encoded.length) {
            var ch: str = encoded.charAt(i);
            if (ch == "|") {
                if (count == idx) { return current; };
                current = "";
                count += 1;
            } else {
                current = current + ch;
            };
            i += 1;
        };
        if (count == idx) { return current; };
        return "";
    };

    function pushScope() -> null {
        this.scopes.push(HashTable());
    };

    function popScope() -> null {
        if (this.scopes.length > 1) {
            this.scopes.pop();
        };
    };

    function declare(name: str, type_str: str, is_const: bool,
                     is_function: bool, is_class: bool,
                     visibility: str) -> null {
        var top: HashTable = this.scopes[this.scopes.length - 1];
        var encoded: str = this.encodeSymbol(type_str, is_const,
                                             is_function, is_class, visibility);
        top.put(name, encoded);
    };

    function declareSimple(name: str, type_str: str) -> null {
        this.declare(name, type_str, false, false, false, "public");
    };

    function declareFunction(name: str, return_type: str) -> null {
        this.declare(name, return_type, false, true, false, "public");
    };

    function declareClass(name: str) -> null {
        this.declare(name, name, false, false, true, "public");
    };

    function lookupEncoded(name: str) -> str {
        var i: int = this.scopes.length - 1;
        while (i >= 0) {
            var scope: HashTable = this.scopes[i];
            if (scope.has(name)) { return scope.get(name); };
            i -= 1;
        };
        return "";
    };

    function lookupType(name: str) -> str {
        var encoded: str = this.lookupEncoded(name);
        if (encoded == "") { return ""; };
        return this.decodeField(encoded, 0);
    };

    function isDeclared(name: str) -> bool {
        return this.lookupEncoded(name) != "";
    };

    function isDeclaredLocally(name: str) -> bool {
        var top: HashTable = this.scopes[this.scopes.length - 1];
        return top.has(name);
    };

    function isConst(name: str) -> bool {
        var encoded: str = this.lookupEncoded(name);
        if (encoded == "") { return false; };
        return this.decodeField(encoded, 1) == "true";
    };

    function isFunction(name: str) -> bool {
        var encoded: str = this.lookupEncoded(name);
        if (encoded == "") { return false; };
        return this.decodeField(encoded, 2) == "true";
    };

    function isClass(name: str) -> bool {
        var encoded: str = this.lookupEncoded(name);
        if (encoded == "") { return false; };
        return this.decodeField(encoded, 3) == "true";
    };

    function getVisibility(name: str) -> str {
        var encoded: str = this.lookupEncoded(name);
        if (encoded == "") { return "public"; };
        return this.decodeField(encoded, 4);
    };

    function declareGlobal(name: str, type_str: str, is_const: bool,
                           is_function: bool, is_class: bool,
                           visibility: str) -> null {
        var encoded: str = this.encodeSymbol(type_str, is_const,
                                             is_function, is_class, visibility);
        this.scopes[0].put(name, encoded);
    };
};