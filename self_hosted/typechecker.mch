// ============================================================
// typechecker.mch — Mocha Self-Hosted Type Checker
// ============================================================

//Imports
from "mocha-string" import *; 
from "./parser.mch" import *;
from "./ScopeManager.mch" import *;

class MochaTypeError {
    var message: str;
    var line:    int;
    var col:     int;

    function constructor(msg: str, l: int, c: int) -> null {
        this.message = msg;
        this.line    = l;
        this.col     = c;
    };
};

class TypeChecker {
    var symbols:        ScopeManager;
    var current_class:  str;
    var current_return: str;
    var loop_depth:     int;
    var try_depth:      int;
    var rescue_depth:   int;
    var inheritance:    HashTable;
    var errors:         MochaTypeError[];
    var tag_types:      str[];
    var class_names:    str[];
    var current_shared: bool;

    function constructor() -> null {
        this.symbols        = ScopeManager();
        this.current_class  = "";
        this.current_return = "";
        this.loop_depth     = 0;
        this.try_depth      = 0;
        this.rescue_depth   = 0;
        this.inheritance    = HashTable();
        this.errors         = [];
        this.tag_types      = [];
        this.class_names    = [];
        this.current_shared = false;

        // Built-in functions
        this.symbols.declareFunction("print", "null");
        this.symbols.declareFunction("sort",  "null");
        this.symbols.declareFunction("tell",  "str");
        this.symbols.declareFunction("open",  "File");
        this.symbols.declareFunction("exists","bool");
        this.symbols.declareFunction("puts",  "int");
        this.symbols.declareFunction("str",   "str");
        this.symbols.declareFunction("int",   "int");
        this.symbols.declareFunction("float", "float");
        this.symbols.declareFunction("bool",  "bool");

        // Built-in classes
        this.symbols.declareClass("StringBuilder");
        this.symbols.declareClass("Complex");
        this.symbols.declareClass("File");
        this.symbols.declareClass("HashTable");
    };

    // true for classes declared with 'class' in the program (not tags, interfaces or built-ins)
    function isUserClass(name: str) -> bool {
        var i: int = 0;
        while (i < this.class_names.length) {
            if (this.class_names[i] == name) { return true; };
            i += 1;
        };
        return false;
    };

    // true for classes and for the C-backed handle types: these are move-only
    function isMoveOnly(type_name: str) -> bool {
        if (this.isUserClass(type_name)) { return true; };
        return type_name == "File" || type_name == "StringBuilder" || type_name == "HashTable";
    };

    // -------------------------------------------------------
    // Error helpers
    // -------------------------------------------------------

    function addError(msg: str, line: int, col: int) -> null {
        var e: MochaTypeError = MochaTypeError(msg, line, col);
        this.errors.push(e);
    };

    function addErrorAt(msg: str, node: ASTNode) -> null {
        this.addError(msg, node.line, node.col);
    };

    // -------------------------------------------------------
    // Type helpers
    // -------------------------------------------------------

    function isNumeric(t: str) -> bool {
        return t == "int" || t == "float" || t == "vast" || t == "Complex";
    };

    function isComparable(t: str) -> bool {
        return t == "int" || t == "float" || t == "str" || t == "vast";
    };

    function isPrimitive(t: str) -> bool {
        return t == "int" || t == "float" || t == "str" ||
               t == "bool" || t == "null" || t == "vast";
    };

    function isTagType(t: str) -> bool {
        var i: int = 0;
        while (i < this.tag_types.length) {
            if (this.tag_types[i] == t) { return true; };
            i += 1;
        };
        return false;
    };

    // Extract element type from array type
    // "int[]" -> "int", "int[][]" -> "int[]", "int" -> ""
    function extractElementType(arr_type: str) -> str {
        if (arr_type.length < 3) { return ""; };
        var last: str = arr_type.charAt(arr_type.length - 1);
        if (last != "]") { return ""; };
        // find last [
        var i: int = arr_type.length - 2;
        while (i >= 0) {
            var ch: str = arr_type.charAt(i);
            if (ch == "[") {
                if (i == 0) { return ""; };
                return arr_type.substring(0, i - 1);
            };
            i -= 1;
        };
        return "";
    };

        // int < vast < float < Complex, or -1 if not numeric
    function numericRank(t: str) -> int {
        if (t == "int")     { return 0; };
        if (t == "vast")    { return 1; };
        if (t == "float")   { return 2; };
        if (t == "Complex") { return 3; };
        return -1;
    };

    function typesCompatible(expected: str, actual: str) -> bool {
        if (expected == actual) { return true; };

        // unknown/any is compatible with everything
        if (actual == "unknown" || actual == "any") { return true; };
        if (expected == "unknown" || expected == "any") { return true; };

        // numeric types only convert upward: int -> vast -> float -> Complex
        var exp_rank: int = this.numericRank(expected);
        var act_rank: int = this.numericRank(actual);
        if (exp_rank >= 0 && act_rank >= 0) {
            return act_rank <= exp_rank;
        };

        // null compatible with non-primitives
        if (actual == "null" && this.isPrimitive(expected) == false) { return true; };
        if (expected == "null" && this.isPrimitive(actual) == false) { return true; };

        // array compatibility — recurse on element types
        var exp_elem: str = this.extractElementType(expected);
        var act_elem: str = this.extractElementType(actual);
        if (exp_elem != "" && act_elem != "") {
            return this.typesCompatible(exp_elem, act_elem);
        };

        // tuple compatibility — "(int, 3)" style
        if (expected.charAt(0) == "(" && actual.charAt(0) == "(") {
            var exp_inner: str = expected.substring(1, expected.length - 2);
            var act_inner: str = actual.substring(1, actual.length - 2);
            var exp_type: str  = this.tupleElemType(exp_inner);
            var act_type: str  = this.tupleElemType(act_inner);
            var exp_count: str = this.tupleCount(exp_inner);
            var act_count: str = this.tupleCount(act_inner);
            if (this.typesCompatible(exp_type, act_type) == false) { return false; };
            if (exp_count != "" && act_count != "") {
                return exp_count == act_count;
            };
            return true;
        };

        // set compatibility: element types must match; set<unknown> and set<object> fit any set
        if (expected.length >= 5 && actual.length >= 5) {
            if (expected.substring(0, 3) == "set<" && actual.substring(0, 3) == "set<") {
                var exp_set_elem: str = expected.substring(4, expected.length - 2);
                var act_set_elem: str = actual.substring(4, actual.length - 2);
                if (act_set_elem == "unknown" || act_set_elem == "object") { return true; };
                if (exp_set_elem == "unknown" || exp_set_elem == "object") { return true; };
                return this.typesCompatible(exp_set_elem, act_set_elem);
            };
        };

        // dict
        if (expected == "dict" && actual == "dict") { return true; };

        return false;
    };

    // Helper: from "int, 3" get "int"
    function tupleElemType(inner: str) -> str {
        var i: int = 0;
        while (i < inner.length) {
            if (inner.charAt(i) == ",") {
                if (i == 0) { return ""; };
                return inner.substring(0, i - 1);
            };
            i += 1;
        };
        return inner;
    };

    // Helper: from "int, 3" get "3"
    function tupleCount(inner: str) -> str {
        var i: int = 0;
        while (i < inner.length) {
            if (inner.charAt(i) == ",") {
                if (i >= inner.length - 2) { return ""; };
                return inner.substring(i + 2, inner.length - 1);
            };
            i += 1;
        };
        return "";
    };

    function resultTypeOfOp(op: str, left: str, right: str, node: ASTNode) -> str {
        // Complex promotion
        if (left == "Complex" || right == "Complex") {
            if (op == "+" || op == "-" || op == "*" || op == "/") {
                return "Complex";
            };
            this.addErrorAt("Operator '" + op + "' not supported for Complex", node);
            return "Complex";
        };

        // Arithmetic: + - * / %
        if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%") {
            // Tags are not integers
            if (this.isTagType(left) || this.isTagType(right)) {
                this.addErrorAt("Arithmetic on tag types is not allowed. Tags are not integers. Use match() for tag logic.", node);
                return "int";
            };

            // String concat
            if (op == "+" && left == "str" && right == "str") { return "str"; };

            if (this.isNumeric(left) == false) {
                this.addErrorAt("Cannot use '" + op + "' on type '" + left + "'. Arithmetic requires int or float", node);
                return "int";
            };
            if (this.isNumeric(right) == false) {
                this.addErrorAt("Cannot use '" + op + "' on type '" + right + "'. Arithmetic requires int or float", node);
                return "int";
            };

            // Precedence: float > vast > int
            if (left == "float" || right == "float") { return "float"; };
            if (left == "vast"  || right == "vast")  { return "vast"; };
            return "int";
        };

        // Ordered comparison: < > <= >=
        if (op == "<" || op == ">" || op == "<=" || op == ">=") {
            if (this.isTagType(left) || this.isTagType(right)) {
                this.addErrorAt("Tag types cannot be ordered. Use '==' or '!=' for tag comparison.", node);
                return "bool";
            };
            if (this.isComparable(left) == false) {
                this.addErrorAt("Cannot compare type '" + left + "' with '" + op + "'", node);
            };
            if (left != right) {
                if (this.isNumeric(left) == false || this.isNumeric(right) == false) {
                    this.addErrorAt("Cannot compare '" + left + "' with '" + right + "'. Types must match for comparison", node);
                };
            };
            return "bool";
        };

        // Equality: == !=
        if (op == "==" || op == "!=") {
            if (left != right) {
                if (this.isNumeric(left) == false || this.isNumeric(right) == false) {
                    if (left != "null" && right != "null") {
                        this.addErrorAt("Cannot compare '" + left + "' with '" + right + "'. Type coercion is prohibited in Mocha", node);
                    };
                };
            };
            return "bool";
        };

        // Logical: && ||
        if (op == "&&" || op == "||") {
            if (left != "bool") {
                this.addErrorAt("Left side of '" + op + "' must be bool, got '" + left + "'", node);
            };
            if (right != "bool") {
                this.addErrorAt("Right side of '" + op + "' must be bool, got '" + right + "'", node);
            };
            return "bool";
        };

        // Bitwise: & | ^ << >>
        if (op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>") {
            if (left != "int" && left != "vast") {
                this.addErrorAt("Bitwise operator '" + op + "' requires int or vast, got '" + left + "'", node);
            };
            if (right != "int" && right != "vast") {
                this.addErrorAt("Bitwise operator '" + op + "' requires int or vast, got '" + right + "'", node);
            };
            if (left == "vast" || right == "vast") { return "vast"; };
            return "int";
        };

        return "unknown";
    };

    function checkExpr(node: ASTNode) -> str {
        var kind: str = node.kind;
        match (kind) {
            case "IntLiteral":     return "int";
            case "FloatLiteral":   return "float";
            case "ComplexLiteral": return "Complex";
            case "StrLiteral":     return "str";
            case "BoolLiteral":    return "bool";
            case "NullLiteral":    return "null";

            case "This":
                if (this.current_class == "") {
                    this.addErrorAt("'this' used outside of a class", node);
                    return "unknown";
                };
                if (this.current_shared) {
                    this.addErrorAt("'this' cannot be used in a shared method", node);
                    return "unknown";
                };
                return this.current_class;

            case "Identifier":
                return this.checkIdentifier(node);

            case "BinaryOp":
                return this.checkBinaryOp(node);

            case "UnaryOp":
                return this.checkUnaryOp(node);

            case "PreIncrement":
                return this.checkIncrement(node, node.right);
            case "PreDecrement":
                return this.checkIncrement(node, node.right);
            case "PostIncrement":
                return this.checkIncrement(node, node.left);

            case "TypeCast":
                return this.checkTypeCast(node);

            case "MemberAccess":
                return this.checkMemberAccess(node);

            case "TagAccess":
                var tag_key: str = node.value + "." + node.extra;
                var tag_sym: str = this.symbols.lookupEncoded(tag_key);
                if (tag_sym == "") {
                    this.addErrorAt("'" + node.extra + "' is not a member of tag '" + node.value + "'", node);
                    return "unknown";
                };
                return this.symbols.decodeField(tag_sym, 0);

            case "IndexAccess":
                return this.checkIndexAccess(node);

            case "Index2DAccess":
                return this.checkIndex2DAccess(node);

            case "RowSlice":
                var rs_type: str = this.checkExpr(node.left);
                var rs_elem: str = this.extractElementType(rs_type);
                if (rs_elem == "") { return "unknown"; };
                return rs_elem;

            case "ColSlice":
                var cs_type: str = this.checkExpr(node.left);
                var cs_elem: str = this.extractElementType(cs_type);
                if (cs_elem == "") { return "unknown"; };
                return cs_elem;

            case "TupleAccess":
                return this.checkTupleAccess(node);

            case "TupleLiteral":
                return this.checkTupleLiteral(node);

            case "ArrayLiteral":
                return this.checkArrayLiteral(node);

            case "ListComprehension":
                return this.checkListComprehension(node);

            case "FunctionCall":
                return this.checkFunctionCall(node);

            case "LambdaExpr":
                return this.checkLambda(node);

            case "AllocArray":
                return this.checkAllocArray(node);

            case "AwaitExpr":
                return this.checkExpr(node.left);
            
            case "LibQualifiedCall":
                var lq: int = 0;
                while (lq < node.args.length) {
                    if (node.args[lq].kind != "NamedArg") {
                        this.checkExpr(node.args[lq]);
                    };
                    lq += 1;
                };
                var lib_enc: str = this.symbols.lookupEncoded(node.extra + "." + node.value);
                if (lib_enc != "") {
                    return this.symbols.decodeField(lib_enc, 0);
                };
                return "unknown";

            case "SetLiteral":
                if (node.children.length == 0) { return "set<unknown>"; };
                var set_first: str = this.checkExpr(node.children[0]);
                var sk: int = 1;
                while (sk < node.children.length) {
                    var set_elem: str = this.checkExpr(node.children[sk]);
                    if (this.typesCompatible(set_first, set_elem) == false) {
                        this.addErrorAt("Set elements must all be the same type (first element is '" + set_first + "'), but got '" + set_elem + "'", node);
                    };
                    sk += 1;
                };
                if (set_first != "int" && set_first != "float" && set_first != "str" && set_first != "bool") {
                    return "set<object>";
                };
                return "set<" + set_first + ">";

            case "DictLiteral":
                var dk: int = 0;
                while (dk < node.children.length) {
                    var dkey_type: str = this.checkExpr(node.children[dk]);
                    if (dkey_type != "str" && dkey_type != "unknown") {
                        this.addErrorAt("Dict keys must be str, got '" + dkey_type + "'", node);
                    };
                    if (dk + 1 < node.children.length) {
                        this.checkExpr(node.children[dk + 1]);
                    };
                    dk += 2;
                };
                return "dict";

            case "RangeNode":
                var rl: str = this.checkExpr(node.left);
                var rr: str = this.checkExpr(node.right);
                var range_ok: bool = true;
                if (rl != "int" && rl != "str" && rl != "unknown") {
                    this.addErrorAt("Range start must be int or str, got '" + rl + "'", node);
                    range_ok = false;
                };
                if (rr != "int" && rr != "str" && rr != "unknown") {
                    this.addErrorAt("Range end must be int or str, got '" + rr + "'", node);
                    range_ok = false;
                };
                if (range_ok && rl != "unknown" && rr != "unknown" && rl != rr) {
                    this.addErrorAt("Range start and end must be the same type, got '" + rl + "' and '" + rr + "'", node);
                };
                if (rl == "str") { return "str[]"; };
                return "int[]";

            default:
                return "unknown";
        };
    };

    function checkIdentifier(node: ASTNode) -> str {
        if (node.value == "this") {
            if (this.current_class == "") {
                this.addErrorAt("'this' used outside of a class", node);
                return "unknown";
            };
            return this.current_class;
        };
        var t: str = this.symbols.lookupType(node.value);
        if (t == "") {
            this.addErrorAt("'" + node.value + "' is not declared. Did you forget 'var " + node.value + ": type = value;'?", node);
            return "unknown";
        };
        return t;
    };

    function checkBinaryOp(node: ASTNode) -> str {
        var left_type:  str = this.checkExpr(node.left);
        var right_type: str = this.checkExpr(node.right);

        // Compile-time division by zero
        if (node.value == "/" || node.value == "%") {
            if (node.right.kind == "IntLiteral" || node.right.kind == "FloatLiteral") {
                if (node.right.int_val == 0 && node.right.real_val == 0.0) {
                    this.addErrorAt("Dividing by zero emits undefined result.", node);
                };
            };
        };

        var result_type: str = this.resultTypeOfOp(node.value, left_type, right_type, node);

        // inferred type for codegen
        node.type_str = result_type;

        // Set op_kind in node.extra for codegen
        var op: str = node.value;

        // Complex
        if (left_type == "Complex" || right_type == "Complex") {
            if (op == "+") { node.extra = "complex_add"; };
            if (op == "-") { node.extra = "complex_sub"; };
            if (op == "*") { node.extra = "complex_mul"; };
            if (op == "/") { node.extra = "complex_div"; };
            return result_type;
        };

        // Arithmetic
        if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%") {
            if (op == "+" && left_type == "str" && right_type == "str") {
                node.extra = "string_concat";
            } else if (result_type == "float") {
                if (op == "+") { node.extra = "float_add"; };
                if (op == "-") { node.extra = "float_sub"; };
                if (op == "*") { node.extra = "float_mul"; };
                if (op == "/") { node.extra = "float_div"; };
                if (op == "%") { node.extra = "float_mod"; };
            } else if (result_type == "vast") {
                if (op == "+") { node.extra = "vast_add"; };
                if (op == "-") { node.extra = "vast_sub"; };
                if (op == "*") { node.extra = "vast_mul"; };
                if (op == "/") { node.extra = "vast_div"; };
                if (op == "%") { node.extra = "vast_mod"; };
            } else {
                if (op == "+") { node.extra = "int_add"; };
                if (op == "-") { node.extra = "int_sub"; };
                if (op == "*") { node.extra = "int_mul"; };
                if (op == "/") { node.extra = "int_div"; };
                if (op == "%") { node.extra = "int_mod"; };
            };
            return result_type;
        };

        // Equality
        if (op == "==" || op == "!=") {
            var eq_sfx: str = "eq";
            if (op == "!=") { eq_sfx = "ne"; };
            if (left_type == "str" && right_type == "str") {
                node.extra = "str_" + eq_sfx;
            } else if (left_type == "float" || right_type == "float") {
                node.extra = "float_" + eq_sfx;
            } else if (left_type == "vast" || right_type == "vast") {
                node.extra = "vast_" + eq_sfx;
            } else if (left_type == "bool" || right_type == "bool") {
                node.extra = "bool_" + eq_sfx;
            } else {
                node.extra = "int_" + eq_sfx;
            };
            return result_type;
        };

        // Ordered comparison
        if (op == "<" || op == ">" || op == "<=" || op == ">=") {
            if (left_type == "str" || right_type == "str") {
                node.extra = "str_" + op;
            } else if (left_type == "float" || right_type == "float") {
                node.extra = "float_" + op;
            } else if (left_type == "vast" || right_type == "vast") {
                node.extra = "vast_" + op;
            } else {
                node.extra = "int_" + op;
            };
            return result_type;
        };

        // Bitwise: vast_bit_* if either side is vast, otherwise int_bit_*
        if (op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>") {
            var bit_pfx: str = "int_";
            if (left_type == "vast" || right_type == "vast") { bit_pfx = "vast_"; };
            if (op == "&")  { node.extra = bit_pfx + "bit_and"; };
            if (op == "|")  { node.extra = bit_pfx + "bit_or"; };
            if (op == "^")  { node.extra = bit_pfx + "bit_xor"; };
            if (op == "<<") { node.extra = bit_pfx + "bit_shl"; };
            if (op == ">>") { node.extra = bit_pfx + "bit_shr"; };
            return result_type;
        };

        // Logical
        if (op == "&&") { node.extra = "bool_and"; };
        if (op == "||") { node.extra = "bool_or"; };

        return result_type;
    };

    function checkUnaryOp(node: ASTNode) -> str {
        var right_type: str = this.checkExpr(node.right);
        if (node.value == "!") {
            if (right_type != "bool") {
                this.addErrorAt("'!' requires bool, got '" + right_type + "'", node);
            };
            return "bool";
        };
        if (node.value == "-") {
            if (this.isNumeric(right_type) == false) {
                this.addErrorAt("Unary '-' requires int or float, got '" + right_type + "'", node);
            };
            return right_type;
        };
        if (node.value == "~") {
            if (right_type != "int" && right_type != "vast") {
                this.addErrorAt("'~' requires int or vast, got '" + right_type + "'", node);
            };
            return right_type;
        };
        return "unknown";
    };

    function checkIncrement(node: ASTNode, operand: ASTNode) -> str {
        var t: str = this.checkExpr(operand);
        if (t != "int" && t != "vast") {
            this.addErrorAt("'" + node.value + "' requires int or vast, got '" + t + "'", node);
        };
        return t;
    };

    function checkTypeCast(node: ASTNode) -> str {
        var value_type: str = this.checkExpr(node.left);
        if (value_type == "bool" && this.isNumeric(node.value)) {
            this.addErrorAt("Cannot cast bool to " + node.value + ". Boolean arithmetic is prohibited in Mocha!!", node);
        };
        if (value_type == "str" && this.isNumeric(node.value)) {
            this.addErrorAt("Cannot cast str to " + node.value + " directly. Use toInt() or toFloat() from mocha-string.", node);
        };
        return node.value;
    };

    function checkArrayLiteral(node: ASTNode) -> str {
        if (node.children.length == 0) { return "unknown[]"; };
        var first_type: str = this.checkExpr(node.children[0]);
        var i: int = 1;
        while (i < node.children.length) {
            var elem_type: str = this.checkExpr(node.children[i]);
            if (this.typesCompatible(first_type, elem_type) == false) {
                this.addErrorAt("Array element " + str(i) + " has type '" + elem_type + "' but expected '" + first_type + "'. Arrays cannot mix types in Mocha", node);
            };
            i += 1;
        };
        return first_type + "[]";
    };

    function checkTupleLiteral(node: ASTNode) -> str {
        if (node.children.length == 0) {
            this.addErrorAt("Tuple cannot be empty.", node);
            return "unknown";
        };
        var first_type: str = this.checkExpr(node.children[0]);
        var i: int = 1;
        while (i < node.children.length) {
            var elem_type: str = this.checkExpr(node.children[i]);
            if (this.typesCompatible(first_type, elem_type) == false) {
                this.addErrorAt("Mocha tuples are homogeneous — all elements must be the same type. For mixed types, use a dict.", node);
                return "unknown";
            };
            i += 1;
        };
        return "(" + first_type + ", " + str(node.children.length) + ")";
    };

    function checkTupleAccess(node: ASTNode) -> str {
        var tuple_type: str = this.checkExpr(node.left);
        if (tuple_type.charAt(0) != "(") {
            this.addErrorAt("'#' access used on non-tuple type '" + tuple_type + "'", node);
            return "unknown";
        };
        var inner: str = tuple_type.substring(1, tuple_type.length - 2);
        var elem_type: str = this.tupleElemType(inner);
        var count_str: str = this.tupleCount(inner);
        if (count_str != "") {
            var count: int = count_str.toInt();
            if (node.int_val >= count) {
                this.addErrorAt("Tuple index " + str(node.int_val) + " out of range. Tuple has " + count_str + " elements.", node);
                return "unknown";
            };
        };
        return elem_type;
    };

    function checkAllocArray(node: ASTNode) -> str {
        var size_type: str = this.checkExpr(node.left);
        if (size_type != "int") {
            this.addErrorAt("alloc size must be int, got '" + size_type + "'", node);
        };
        if (node.right != null) {
            var size2_type: str = this.checkExpr(node.right);
            if (size2_type != "int") {
                this.addErrorAt("alloc size must be int, got '" + size2_type + "'", node);
            };
            return node.value + "[][]";
        };
        return node.value + "[]";
    };

    function checkListComprehension(node: ASTNode) -> str {
        var iter_type: str = this.checkExpr(node.right);
        var elem_type: str = this.extractElementType(iter_type);
        if (elem_type == "") {
            if (iter_type == "str") {
                elem_type = "str";
            } else {
                this.addErrorAt("List comprehension source must be an array, got '" + iter_type + "'", node);
                elem_type = "unknown";
            };
        };

        // source element type for codegen
        node.extra = elem_type;

        this.symbols.pushScope();
        this.symbols.declareSimple(node.value, elem_type);
        var expr_type: str = this.checkExpr(node.left);

        // result element type for codegen
        node.type_str = expr_type;

        if (node.condition != null) {
            var cond_type: str = this.checkExpr(node.condition);
            if (cond_type != "bool") {
                this.addErrorAt("List comprehension condition must be bool, got '" + cond_type + "'", node);
            };
            // check else branch if present
            if (node.else_body.length > 0) {
                var else_type: str = this.checkExpr(node.else_body[0]);
                if (else_type != expr_type) {
                    this.addErrorAt("List comprehension else branch type '" + else_type + "' must match then branch type '" + expr_type + "'", node);
                };
            };
        };
        this.symbols.popScope();
        return expr_type + "[]";
    };

    function checkLambda(node: ASTNode) -> str {
        this.symbols.pushScope();
        var i: int = 0;
        while (i < node.params.length) {
            this.declareChecked(node.params[i].value, node.params[i].type_str, false, node.params[i]);
            i += 1;
        };
        if (node.type_str != "" && node.type_str != "null") {
            var body_type: str = this.checkExpr(node.left);
            if (body_type != "unknown" && this.typesCompatible(node.type_str, body_type) == false) {
                this.addErrorAt("Lambda return type mismatch: declared '" + node.type_str + "' but body evaluates to '" + body_type + "'", node);
            };
        };
        this.symbols.popScope();
        return "lambda";
    };

    function checkIndexAccess(node: ASTNode) -> str {
        var obj_type:   str = this.checkExpr(node.left);
        var index_type: str = this.checkExpr(node.right);

        if (obj_type == "dict") {
            if (index_type != "str") {
                this.addErrorAt("Dict key must be str, got '" + index_type + "'", node);
            };
            return "any";
        };

        if (index_type != "int") {
            this.addErrorAt("Array index must be int, got '" + index_type + "'", node);
        };

        var elem_type: str = this.extractElementType(obj_type);
        if (elem_type == "") {
            this.addErrorAt("Cannot index into non-array type '" + obj_type + "'", node);
            return "unknown";
        };
        return elem_type;
    };

    function checkIndex2DAccess(node: ASTNode) -> str {
        var obj_type: str = this.checkExpr(node.left);

        if (obj_type == "dict") {
            var rk: str = this.checkExpr(node.condition);
            var ck: str = this.checkExpr(node.right);
            if (rk != "str") { this.addErrorAt("Dict key must be str, got '" + rk + "'", node); };
            if (ck != "str") { this.addErrorAt("Dict key must be str, got '" + ck + "'", node); };
            return "any";
        };

        var row_type: str = this.checkExpr(node.condition);
        var col_type: str = this.checkExpr(node.right);
        if (row_type != "int") { this.addErrorAt("2D array row index must be int, got '" + row_type + "'", node); };
        if (col_type != "int") { this.addErrorAt("2D array col index must be int, got '" + col_type + "'", node); };

        var elem: str = this.extractElementType(obj_type);
        if (elem != "") { elem = this.extractElementType(elem); };
        if (elem == "") {
            this.addErrorAt("Cannot 2D-index into non-2D-array type '" + obj_type + "'", node);
            return "unknown";
        };
        return elem;
    };

    function checkMemberAccess(node: ASTNode) -> str {
        var obj_type: str = this.checkExpr(node.left);
        var member:   str = node.value;

        // If the inner chain already failed, that error is already reported: stay quiet
        if (obj_type == "unknown") {
            return "unknown";
        };

        // Dict built-ins
        if (obj_type == "dict") {
            if (member == "length")    { return "int"; };
            if (member == "has")       { return "bool"; };
            if (member == "allKeys")   { return "str[]"; };
            if (member == "allValues") { return "str[]"; };
            if (member == "jsonify")   { return "str"; };
            if (member == "merge")     { return "dict"; };
            if (member == "copy")      { return "dict"; };
            if (member == "remove")    { return "null"; };
            if (member == "clean")     { return "null"; };
            this.addErrorAt("'." + member + "' is not a method on dict. Available: .length, .has, .allKeys, .allValues, .jsonify, .remove, .clean, .merge, .copy", node);
            return "unknown";
        };

        // length: arrays and str
        if (member == "length") {
            if (obj_type == "str") { return "int"; };
            var le: str = this.extractElementType(obj_type);
            if (le == "") {
                this.addErrorAt("'.length' used on non-array type '" + obj_type + "'", node);
            };
            return "int";
        };

        // rows / cols: 2D arrays
        if (member == "rows" || member == "cols") {
            var re: str = this.extractElementType(obj_type);
            if (re != "") { re = this.extractElementType(re); };
            if (re == "") {
                this.addErrorAt("'." + member + "' used on non-2D-array type '" + obj_type + "'", node);
            };
            return "int";
        };

        // push / pop
        if (member == "push" || member == "pop") {
            var pe: str = this.extractElementType(obj_type);
            if (pe == "") {
                this.addErrorAt("'." + member + "()' used on non-array type '" + obj_type + "'", node);
            };
            return "null";
        };

        // resize / drop
        if (member == "resize" || member == "drop") { return "null"; };

        // occs
        if (member == "occs") { return "int"; };

        // Set built-ins
        if (obj_type.length >= 4) {
            if (obj_type.substring(0, 3) == "set<") {
                if (member == "size")                        { return "int"; };
                if (member == "has")                         { return "bool"; };
                if (member == "subset" || member == "superset") { return "bool"; };
                if (member == "insert" || member == "delete" ||
                    member == "clean"  || member == "negate" ||
                    member == "retype")                      { return "null"; };
                if (member == "union"   || member == "intersect" ||
                    member == "xor"     || member == "rel_diff")  { return obj_type; };
                if (member == "min" || member == "max") {
                    // element type of set<T> (substring is inclusive at both ends)
                    var set_inner: str = obj_type.substring(4, obj_type.length - 2);
                    if (set_inner == "bool") {
                        this.addErrorAt("min()/max() not defined for set<bool> - bools are unordered", node);
                    } else if (set_inner != "int" && set_inner != "float" && set_inner != "vast" && set_inner != "str") {
                        this.addErrorAt("min()/max() not supported for set<" + set_inner + ">", node);
                    };
                    return set_inner;
                };
                if (member == "jaccard" || member == "dice" || member == "overlap") { return "float"; };
                this.addErrorAt("'." + member + "' is not a method on set. Available: .size, .has, .insert, .delete, .clean, .negate, .retype, .union, .intersect, .xor, .rel_diff, .subset, .superset, .min, .max, .jaccard, .dice, and .overlap", node);
                return "unknown";
            };
        };

        // String built-ins
        if (obj_type == "str") {
            if (member == "length")    { return "int"; };
            if (member == "charAt")    { return "str"; };
            if (member == "toInt")     { return "int"; };
            if (member == "toFloat")   { return "float"; };
            if (member == "substring") { return "str"; };
        };

        // Complex properties
        if (member == "real" || member == "imag") {
            if (obj_type == "Complex") { return "float"; };
            this.addErrorAt("Property '." + member + "' does not exist on type '" + obj_type + "'. '.real' and '.imag' are properties of Complex only.", node);
            return "unknown";
        };

        // HashTable built-ins
        if (obj_type == "HashTable") {
            if (member == "put"    || member == "remove" ||
                member == "clear"  || member == "free")   { return "null"; };
            if (member == "get")                           { return "unknown"; };
            if (member == "has")                           { return "bool"; };
            if (member == "size")                          { return "int"; };
            if (member == "keys"   || member == "values")  { return "str[]"; };
            return "unknown";
        };

        // Tag values (not Tag.MEMBER on the type itself, which falls through to lookup)
        var is_tag: bool = false;
        var ti: int = 0;
        while (ti < this.tag_types.length) {
            if (this.tag_types[ti] == obj_type) { is_tag = true; };
            ti += 1;
        };
        var tag_type_access: bool = false;
        if (node.left.kind == "Identifier") {
            if (node.left.value == obj_type) { tag_type_access = true; };
        };
        if (is_tag && tag_type_access == false) {
            if (member == "name") { return "str"; };
            this.addErrorAt("'." + member + "' is not a method on tag type '" + obj_type + "'. Available: .name()", node);
            return "unknown";
        };

        // Class member lookup: walk ALL parents
        if (this.findOwner(obj_type, member) == "") {
            this.addErrorAt("'." + member + "' is not a method or property on '" + obj_type + "'", node);
            return "unknown";
        };
        return this.lookupMember(obj_type, member, node);
    };

     // the idx-th parent of a class ("" when there is none); parents are stored as "Class#0", "Class#1", ...
    function parentAt(cls: str, idx: int) -> str {
        var key: str = cls + "#" + str(idx);
        if (this.inheritance.has(key)) {
            return this.inheritance.get(key);
        };
        return "";
    };

    // the class (cls itself or any ancestor, through ALL parents) that declares this member, or ""
    function findOwner(cls: str, member: str) -> str {
        if (this.symbols.lookupEncoded(cls + "." + member) != "") { return cls; };
        var idx: int = 0;
        var parent: str = this.parentAt(cls, idx);
        while (parent != "") {
            if (parent != cls) {
                var found: str = this.findOwner(parent, member);
                if (found != "") { return found; };
            };
            idx += 1;
            parent = this.parentAt(cls, idx);
        };
        return "";
    };

    function lookupMember(obj_type: str, member: str, node: ASTNode) -> str {
        var current: str = this.findOwner(obj_type, member);
        if (current == "") { return "unknown"; };

        var key:     str = current + "." + member;
        var encoded: str = this.symbols.lookupEncoded(key);
        var visibility: str = this.symbols.decodeField(encoded, 4);
        if (visibility == "private") {
            if (this.current_class != current) {
                this.addErrorAt("'" + member + "' is private to '" + current + "' and cannot be accessed from outside", node);
            };
        } else if (visibility == "protected") {
            if (this.current_class == "") {
                this.addErrorAt("'" + member + "' is protected in '" + current + "' and cannot be accessed from global scope", node);
            } else if (this.current_class != current) {
                if (this.isSubclassOf(this.current_class, current) == false) {
                    this.addErrorAt("'" + member + "' is protected in '" + current + "' and cannot be accessed from '" + this.current_class + "'", node);
                };
            };
        };
        return this.symbols.decodeField(encoded, 0);
    };

    // true if cls descends from parent through ANY of its parents
    function isSubclassOf(cls: str, parent: str) -> bool {
        var idx: int = 0;
        var p: str = this.parentAt(cls, idx);
        while (p != "") {
            if (p == parent) { return true; };
            if (p != cls) {
                if (this.isSubclassOf(p, parent)) { return true; };
            };
            idx += 1;
            p = this.parentAt(cls, idx);
        };
        return false;
    };

    // number of real parameters (didLoad not counted); -1 for variadic functions
    function countParams(fn: ASTNode) -> int {
        if (fn.is_variadic) { return -1; };
        var cnt: int = 0;
        var ck: int = 0;
        while (ck < fn.params.length) {
            var cp: ASTNode = fn.params[ck];
            if (cp.value != "didLoad") { cnt += 1; };
            ck += 1;
        };
        return cnt;
    };

    // remember the parameter count of every top-level function and every class method/constructor.
    // The count lives in the KEY ("params:fn:g:1") and the value is the literal "1", so no
    // computed string is ever stored as a table value
    function registerParamCounts(program: ASTNode) -> null {
        var ri: int = 0;
        while (ri < program.children.length) {
            var rnode: ASTNode = program.children[ri];
            if (rnode.kind == "FunctionDecl") {
                var fcount: int = this.countParams(rnode);
                if (fcount >= 0) {
                    var fkey: str = "params:fn:" + rnode.value + ":" + str(fcount);
                    this.inheritance.put(fkey, "1");
                };
            } else if (rnode.kind == "ClassDecl") {
                var rj: int = 0;
                while (rj < rnode.body.length) {
                    var rmember: ASTNode = rnode.body[rj];
                    if (rmember.kind == "MethodDecl" || rmember.kind == "FunctionDecl") {
                        var mcount: int = this.countParams(rmember);
                        if (mcount >= 0) {
                            var mkey: str = "params:" + rnode.value + "." + rmember.value + ":" + str(mcount);
                            this.inheritance.put(mkey, "1");
                        };
                    };
                    rj += 1;
                };
            };
            ri += 1;
        };
    };

    // max argument count stored for a key like "fn:g" or "Dog.bark"; -1 when unknown or variadic
    function storedCount(k: str) -> int {
        var n: int = 0;
        while (n <= 32) {
            var pk: str = "params:" + k + ":" + str(n);
            if (this.inheritance.has(pk)) { return n; };
            n += 1;
        };
        return -1;
    };

    // max argument count of cls.member, walking ALL parents; -1 when not found
    function memberParamCount(cls: str, member: str) -> int {
        var own: int = this.storedCount(cls + "." + member);
        if (own >= 0) { return own; };
        var pidx: int = 0;
        var par: str = this.parentAt(cls, pidx);
        while (par != "") {
            if (par != cls) {
                var up: int = this.memberParamCount(par, member);
                if (up >= 0) { return up; };
            };
            pidx += 1;
            par = this.parentAt(cls, pidx);
        };
        return -1;
    };

    function checkFunctionCall(node: ASTNode) -> str {
        // Determine func name and obj type
        var func_name: str = "";
        var obj_type:  str = "";

        if (node.left.kind == "MemberAccess") {
            func_name = node.left.value;
            obj_type  = this.checkExpr(node.left.left);

            // Const mutation check
            if (func_name == "push"    || func_name == "pop"     ||
                func_name == "insert"  || func_name == "delete"  ||
                func_name == "remove"  || func_name == "clean"   ||
                func_name == "retype"  || func_name == "reverse" ||
                func_name == "sort"    || func_name == "drop"    ||
                func_name == "resize"  || func_name == "occs") {
                if (node.left.left.kind == "Identifier") {
                    if (this.symbols.isConst(node.left.left.value)) {
                        this.addErrorAt("Cannot call '" + func_name + "()' on constant '" + node.left.left.value + "'. Constants are immutable in Mocha", node);
                    };
                };
            };
        } else if (node.left.kind == "Identifier") {
            func_name = node.left.value;
            obj_type  = "";
        } else {
            // e.g. chained call result: check callee expr and return unknown
            this.checkExpr(node.left);
            var i0: int = 0;
            while (i0 < node.args.length) {
                if (node.args[i0].kind != "NamedArg") {
                    this.checkExpr(node.args[i0]);
                };
                i0 += 1;
            };
            return "unknown";
        };

        // Check all args (Complex(a, b) arguments must be numbers); remember the type of the
        // first positional argument. retype's argument is a type name, not a variable: skip it
        var is_complex_ctor: bool = false;
        if (obj_type == "" && func_name == "Complex") { is_complex_ctor = true; };

        var have_first: bool = false;
        var first_arg_type: str = "";

        var i: int = 0;
        while (i < node.args.length) {
            if (node.args[i].kind != "NamedArg" && func_name != "retype") {
                var arg_t: str = this.checkExpr(node.args[i]);
                if (have_first == false) {
                    first_arg_type = arg_t;
                    have_first = true;
                };
                if (is_complex_ctor) {
                    if (arg_t != "int" && arg_t != "vast" && arg_t != "float" && arg_t != "unknown") {
                        this.addErrorAt("Complex() arguments must be int, vast or float, not '" + arg_t + "'", node);
                    };
                };
            };
            i += 1;
        };

        // Complex(a, b) takes at most 2 arguments (real, imag)
        if (is_complex_ctor) {
            if (node.args.length > 2) {
                this.addErrorAt("Complex() takes at most 2 arguments (real, imag), got " + str(node.args.length), node);
            };
        };

        // Lambda invocation
        if (obj_type == "") {
            var lam_encoded: str = this.symbols.lookupEncoded(func_name);
            if (lam_encoded != "") {
                if (this.symbols.decodeField(lam_encoded, 0) == "lambda") {
                    return "unknown";
                };
            };
        };

        // Too many arguments would be silently dropped (named arguments are not counted)
        var given: int = 0;
        var gi: int = 0;
        while (gi < node.args.length) {
            if (node.args[gi].kind != "NamedArg") { given += 1; };
            gi += 1;
        };
        if (obj_type == "") {
            var max_fn: int = this.storedCount("fn:" + func_name);
            if (max_fn >= 0) {
                if (given > max_fn) {
                    this.addErrorAt("Function '" + func_name + "' takes at most " + str(max_fn) + " argument(s), got " + str(given), node);
                };
            } else {
                var max_ctor: int = this.memberParamCount(func_name, "constructor");
                if (max_ctor >= 0) {
                    if (given > max_ctor) {
                        this.addErrorAt("Constructor of '" + func_name + "' takes at most " + str(max_ctor) + " argument(s), got " + str(given), node);
                    };
                };
            };
        } else if (obj_type != "unknown") {
            var max_method: int = this.memberParamCount(obj_type, func_name);
            if (max_method >= 0) {
                if (given > max_method) {
                    this.addErrorAt("Method '" + obj_type + "." + func_name + "' takes at most " + str(max_method) + " argument(s), got " + str(given), node);
                };
            };
        };

        // Tag values: the only method is .name()
        var call_is_tag: bool = false;
        var cti: int = 0;
        while (cti < this.tag_types.length) {
            if (this.tag_types[cti] == obj_type) { call_is_tag = true; };
            cti += 1;
        };
        if (call_is_tag && obj_type != "") {
            if (func_name == "name") { return "str"; };
            this.addErrorAt("'." + func_name + "()' is not a method on tag type '" + obj_type + "'. Available: .name()", node);
            return "unknown";
        };

        // Dict methods
        if (obj_type == "dict") {
            if (func_name == "has")                          { return "bool"; };
            if (func_name == "allKeys" || func_name == "allValues") { return "str[]"; };
            if (func_name == "jsonify")                      { return "str"; };
            if (func_name == "remove"  || func_name == "clean")     { return "null"; };
            if (func_name == "length")                       { return "int"; };
            if (func_name == "copy")                         { return "dict"; };
            if (func_name == "merge") {
                // the positional argument must be a dict
                if (have_first == false) {
                    this.addErrorAt("merge() requires a dict argument", node);
                } else if (first_arg_type != "dict") {
                    this.addErrorAt("merge() argument must be dict, got '" + first_arg_type + "'", node);
                };
                // override= must be bool; any other keyword is an error
                var mi: int = 0;
                while (mi < node.args.length) {
                    var marg: ASTNode = node.args[mi];
                    if (marg.kind == "NamedArg") {
                        if (marg.value == "override") {
                            var kw_type: str = this.checkExpr(marg.left);
                            if (kw_type != "bool") {
                                this.addErrorAt("merge() override= must be bool, got '" + kw_type + "'", node);
                            };
                        } else {
                            this.addErrorAt("merge() unknown keyword argument '" + marg.value + "'", node);
                        };
                    };
                    mi += 1;
                };
                return "dict";
            };
            this.addErrorAt("'." + func_name + "()' is not a method on dict. Available: .length, .has, .allKeys, .allValues, .jsonify, .remove, .clean, .merge, .copy", node);
            return "unknown";
        };

        // HashTable methods
        if (obj_type == "HashTable") {
            if (func_name == "put"   || func_name == "remove" ||
                func_name == "clear" || func_name == "free")   { return "null"; };
            if (func_name == "get")                            { return "unknown"; };
            if (func_name == "has")                            { return "bool"; };
            if (func_name == "size")                           { return "int"; };
            if (func_name == "keys"  || func_name == "values") { return "str[]"; };
            return "unknown";
        };

        // File methods
        if (obj_type == "File") {
            if (func_name == "read" || func_name == "readLine")                           { return "str"; };
            if (func_name == "eof")                                                       { return "bool"; };
            if (func_name == "write" || func_name == "close" || func_name == "free")      { return "null"; };
        };

        // 2D arrays: occs needs row= or col=, push needs exactly one data argument
        var is_2d: bool = false;
        if (obj_type.length >= 4) {
            if (obj_type.substring(obj_type.length - 4, obj_type.length - 1) == "[][]") { is_2d = true; };
        };
        if (is_2d) {
            if (func_name == "occs") {
                var has_row_col: bool = false;
                var oi: int = 0;
                while (oi < node.args.length) {
                    var oarg: ASTNode = node.args[oi];
                    if (oarg.kind == "NamedArg") {
                        if (oarg.value == "row" || oarg.value == "col") { has_row_col = true; };
                    };
                    oi += 1;
                };
                if (has_row_col == false) {
                    this.addErrorAt("occs() on a 2D array requires a 'row=' or 'col=' argument. Example: arr.occs(val, row=0) or arr.occs(val, col=2)", node);
                };
                return "int";
            };
            if (func_name == "push") {
                if (given != 1) {
                    this.addErrorAt("push() on a 2D array requires exactly one data argument. Example: matrix.push(row) or matrix.push(col, col=true)", node);
                };
                return "null";
            };
        };

        // Set methods
        if (obj_type.length >= 4) {
            if (obj_type.substring(0, 3) == "set<") {
                if (func_name == "has")                           { return "bool"; };
                if (func_name == "insert" || func_name == "delete" ||
                    func_name == "clean"  || func_name == "negate") { return "null"; };
                if (func_name == "retype") {
                    // the argument is a type name, not a variable
                    if (node.args.length > 0) {
                        if (node.args[0].kind == "Identifier") {
                            var rt: str = node.args[0].value;
                            if (rt != "int" && rt != "float" && rt != "str" && rt != "bool" && rt != "vast") {
                                this.addErrorAt("Invalid type '" + rt + "' for retype(). Valid types are: int, float, str, bool, vast", node);
                            };
                        };
                    };
                    return "null";
                };
                if (func_name == "union"    || func_name == "intersect" ||
                    func_name == "xor"      || func_name == "rel_diff") {
                    if (have_first) {
                        if (first_arg_type != obj_type) {
                            this.addErrorAt("Cannot call '" + func_name + "' on '" + obj_type + "' with '" + first_arg_type + "'. Both sets must be the same type. Use .retype() to convert first.", node);
                        };
                    };
                    return obj_type;
                };
                if (func_name == "subset" || func_name == "superset") {
                    if (have_first) {
                        if (first_arg_type != obj_type) {
                            this.addErrorAt("Cannot call '" + func_name + "' on '" + obj_type + "' with '" + first_arg_type + "'. Both sets must be the same type.", node);
                        };
                    };
                    return "bool";
                };
                if (func_name == "size") { return "int"; };
                if (func_name == "min" || func_name == "max") {
                    var set_inner: str = obj_type.substring(4, obj_type.length - 2);
                    if (set_inner == "bool") {
                        this.addErrorAt("min()/max() not defined for set<bool> - bools are unordered", node);
                    } else if (set_inner != "int" && set_inner != "float" && set_inner != "vast" && set_inner != "str") {
                        this.addErrorAt("min()/max() not supported for set<" + set_inner + ">", node);
                    };
                    return set_inner;
                };
                if (func_name == "jaccard" || func_name == "dice" || func_name == "overlap") {
                    if (have_first) {
                        if (first_arg_type != obj_type) {
                            this.addErrorAt("Cannot call '" + func_name + "' on '" + obj_type + "' with '" + first_arg_type + "'. Both sets must be the same type.", node);
                        };
                    };
                    return "float";
                };
                return "unknown";
            };
        };

        // String methods
        if (obj_type == "str") {
            if (func_name == "charAt")    { return "str"; };
            if (func_name == "toInt")     { return "int"; };
            if (func_name == "toFloat")   { return "float"; };
            if (func_name == "dictify")   { return "dict"; };
            if (func_name == "substring") { return "str"; };
        };

        // Array copy: a new array of the same type (a 2D .copy() does not exist)
        if (func_name == "copy") {
            if (this.endsWithBrackets(obj_type) && this.countBrackets(obj_type) == 1) {
                return obj_type;
            };
        };

        // occs
        if (func_name == "occs") { return "int"; };

        // Module alias call: obj_type == "module"
        if (obj_type == "module") {
            if (node.left.left.kind == "Identifier") {
                var alias:      str = node.left.left.value;
                var mod_sym:    str = this.symbols.lookupEncoded(alias + "." + func_name);
                if (mod_sym != "") {
                    return this.symbols.decodeField(mod_sym, 0);
                };
            };
            return "unknown";
        };

        // Diamond conflict: the same method inherited from two parents
        if (obj_type != "" && obj_type != "unknown") {
            var diamond_enc: str = this.symbols.lookupEncoded("diamond:" + obj_type + "." + func_name);
            if (diamond_enc != "") {
                var dparents: str[] = this.splitComma(this.symbols.decodeField(diamond_enc, 0));
                var obj_label: str = "obj";
                if (node.left.kind == "MemberAccess") {
                    if (node.left.left.kind == "Identifier") {
                        obj_label = node.left.left.value;
                    };
                };
                this.addErrorAt("Method '" + func_name + "()' is inherited from both " + dparents[0] + " and " + dparents[1] + ". Please specify parent class to prevent the Diamond Problem. Use " + dparents[0] + "." + obj_label + "." + func_name + "() or " + dparents[1] + "." + obj_label + "." + func_name + "()", node);
            };
        };

        // Class method lookup (private/protected are checked by lookupMember)
        if (obj_type != "" && obj_type != "unknown") {
            if (this.findOwner(obj_type, func_name) != "") {
                return this.lookupMember(obj_type, func_name, node);
            };
        };

        // Global function lookup
        if (obj_type == "") {
            var global_sym: str = this.symbols.lookupEncoded(func_name);
            if (global_sym != "") {
                return this.symbols.decodeField(global_sym, 0);
            };
        };

        return "unknown";
    };

    function checkStmt(node: ASTNode) -> null {
        match (node.kind) {
            case "VarDecl":
                this.checkVarDecl(node);
            case "ConstDecl":
                this.checkConstDecl(node);
            case "Assignment":
                this.checkAssignment(node);
            case "CompoundAssignment":
                this.checkCompoundAssignment(node);
            case "ReturnStmt":
                this.checkReturn(node);
            case "IfStmt":
                this.checkIf(node);
            case "WhileLoop":
                this.checkWhile(node);
            case "DoWhileLoop":
                this.checkDoWhile(node);
            case "ForLoop":
                this.checkFor(node);
            case "ForEachLoop":
                this.checkForeach(node);
            case "MatchStmt":
                this.checkMatch(node);
            case "TryRescue":
                this.checkTryRescue(node);
            case "FailStmt":
                this.checkFail(node);
            case "RethrowStmt":
                if (this.rescue_depth == 0) {
                    this.addErrorAt("'rethrow' used outside of a rescue block", node);
                };
            case "BreakStmt":
                if (this.loop_depth == 0) {
                    this.addErrorAt("'break' used outside of a loop", node);
                };
            case "ContinueStmt":
                if (this.loop_depth == 0) {
                    this.addErrorAt("'continue' used outside of a loop", node);
                };
            case "ExprStmt":
                if (node.left.kind == "Assignment") {
                    this.checkAssignment(node.left);
                } else if (node.left.kind == "CompoundAssignment") {
                    this.checkCompoundAssignment(node.left);
                } else {
                    this.checkExpr(node.left);
                };
            case "FunctionCall":
                this.checkFunctionCall(node);
            case "PostIncrement":
                this.checkIncrement(node, node.left);
            case "PreIncrement":
                this.checkIncrement(node, node.right);
            case "PreDecrement":
                this.checkIncrement(node, node.right);
            default:
                this.checkExpr(node);
        };
    };

    function checkStmtList(stmts: ASTNode[]) -> null {
        var left_block: bool = false;
        var reported:   bool = false;
        var i: int = 0;
        while (i < stmts.length) {
            var stmt: ASTNode = stmts[i];
            if (left_block && reported == false) {
                this.addErrorAt("Unreachable code: this statement can never run, because an earlier statement always leaves the block.", stmt);
                reported = true;
            };
            this.checkStmt(stmt);
            if (left_block == false) {
                var one: ASTNode[] = [];
                one.push(stmt);
                if (this.hasReturn(one) || stmt.kind == "BreakStmt" || stmt.kind == "ContinueStmt") {
                    left_block = true;
                };
            };
            i += 1;
        };
    };

    function checkBlock(stmts: ASTNode[]) -> null {
        this.symbols.pushScope();
        this.checkStmtList(stmts);
        this.symbols.popScope();
    };

    // "int[][]" -> 2
    function countBrackets(t: str) -> int {
        var n: int = 0;
        var i: int = 0;
        while (i < t.length) {
            if (t.charAt(i) == "[") { n += 1; };
            i += 1;
        };
        return n;
    };

    // true if the type ends with "[]"
    function endsWithBrackets(t: str) -> bool {
        if (t.length < 2) { return false; };
        return t.charAt(t.length - 2) == "[" && t.charAt(t.length - 1) == "]";
    };

    // "File[][]" -> "File", "int" -> "int"
    function baseTypeName(t: str) -> str {
        var i: int = 0;
        while (i < t.length) {
            if (t.charAt(i) == "[") {
                if (i == 0) { return ""; };
                return t.substring(0, i - 1);
            };
            i += 1;
        };
        return t;
    };

    // declare a variable/constant in the current scope, rejecting a second declaration
    function declareChecked(name: str, type_str: str, is_const: bool, node: ASTNode) -> null {
        if (this.symbols.isDeclaredLocally(name)) {
            this.addErrorAt("'" + name + "' is already declared in this scope. Mocha prohibits variable redeclaration.", node);
        };
        this.symbols.declare(name, type_str, is_const, false, false, "public");
    };

    function checkVarDecl(node: ASTNode) -> null {
        var dims: int = this.countBrackets(node.type_str);

        // 3D arrays not supported
        if (dims > 2) {
            this.addErrorAt(str(dims) + "D arrays are not supported in Mocha. Use a class or 2D array instead.", node);
        };

        // Arrays of C-backed handle types are not supported
        if (this.endsWithBrackets(node.type_str)) {
            var handle_type: str = this.baseTypeName(node.type_str);
            if (handle_type == "File" || handle_type == "StringBuilder" || handle_type == "HashTable") {
                this.addErrorAt("Arrays of " + handle_type + " are not supported. Keep each " + handle_type + " in its own variable.", node);
            };
        };

        var value_type: str = "unknown";
        if (node.left != null) {
            value_type = this.checkExpr(node.left);
        };

        // Empty array literal [] fits any 1D array type; a 2D type needs [[]] or alloc T[0][0]
        if (value_type == "unknown[]" && this.endsWithBrackets(node.type_str)) {
            if (dims == 2) {
                var base_type: str = this.baseTypeName(node.type_str);
                this.addErrorAt("'" + node.value + "' is a 2D array ('" + node.type_str + "') and cannot be initialised with an empty '[]'. Write an empty 2D array as [[]] (one empty row) or alloc " + base_type + "[0][0].", node);
            };
        } else if (this.typesCompatible(node.type_str, value_type) == false) {
            this.addErrorAt("Type mismatch in declaration of '" + node.value + "': declared as '" + node.type_str + "' but value is '" + value_type + "'", node);
        };

        if (node.type_str == "str") {
            if (node.left != null && node.left.kind == "NullLiteral") {
                this.addErrorAt("'" + node.value + "' is type 'str' which cannot be null. Use empty string \"\" instead", node);
            };
        };

        this.declareChecked(node.value, node.type_str, false, node);

        // Class instances and C-backed handles are move-only, not aliasable
        if (this.isMoveOnly(node.type_str) && node.left != null) {
            if (node.left.kind == "Identifier") {
                this.reportAlias(node.type_str, node.left.value, node.value, node);
            };
        };
    };

    function checkConstDecl(node: ASTNode) -> null {
        var dims: int = this.countBrackets(node.type_str);

        // 3D arrays not supported
        if (dims > 2) {
            this.addErrorAt(str(dims) + "D arrays are not supported in Mocha. Use a class or 2D array instead.", node);
        };

        var value_type: str = this.checkExpr(node.left);

        // Empty array literal [] fits any 1D array type; a 2D type needs [[]] or alloc T[0][0]
        if (value_type == "unknown[]" && this.endsWithBrackets(node.type_str)) {
            if (dims == 2) {
                var base_type: str = this.baseTypeName(node.type_str);
                this.addErrorAt("'" + node.value + "' is a 2D array ('" + node.type_str + "') and cannot be initialised with an empty '[]'. Write an empty 2D array as [[]] (one empty row) or alloc " + base_type + "[0][0].", node);
            };
        } else if (this.typesCompatible(node.type_str, value_type) == false) {
            this.addErrorAt("Type mismatch in constant '" + node.value + "': declared as '" + node.type_str + "' but value is '" + value_type + "'", node);
        };

        // Class instances and C-backed handles are move-only, not aliasable
        if (this.isMoveOnly(node.type_str)) {
            if (node.left.kind == "Identifier") {
                this.reportAlias(node.type_str, node.left.value, node.value, node);
            };
        };

        this.declareChecked(node.value, node.type_str, true, node);
    };

    // shared error for var / const / assignment aliasing
    function reportAlias(type_name: str, from_name: str, into_name: str, node: ASTNode) -> null {
        var kind: str = "class instance";
        if (this.isUserClass(type_name) == false) { kind = type_name + " handle"; };
        this.addErrorAt("Cannot alias " + kind + " '" + from_name + "' into '" + into_name + "': " + kind + "s in Mocha are move-only, not copyable. This prevents security issues and accidental mutations. Construct a new one instead.", node);
    };

    function checkAssignment(node: ASTNode) -> null {
        if (node.left.kind == "TupleAccess") {
            this.addErrorAt("Cannot assign to tuple element. Tuples are immutable in Mocha.", node);
            return;
        };

        var value_type: str = this.checkExpr(node.right);

        // C-backed handles have no RC: storing a variable of one into a field or an
        // array/dict slot would leave two owners of one object
        if (node.left.kind != "Identifier" && node.right.kind == "Identifier") {
            if (value_type == "File" || value_type == "StringBuilder" || value_type == "HashTable") {
                this.addErrorAt("Cannot store " + value_type + " handle '" + node.right.value + "' into a field or element: " + value_type + " handles in Mocha are move-only, not copyable. Construct a new one in place instead.", node);
            };
        };

        if (node.left.kind == "Identifier") {
            var encoded: str = this.symbols.lookupEncoded(node.left.value);
            if (encoded != "") {
                if (this.symbols.isConst(node.left.value)) {
                    this.addErrorAt("Cannot reassign constant '" + node.left.value + "'. Constants are immutable in Mocha", node);
                };
                var target_type: str = this.symbols.decodeField(encoded, 0);
                if (this.typesCompatible(target_type, value_type) == false) {
                    this.addErrorAt("Type mismatch: cannot assign '" + value_type + "' to '" + node.left.value + "' which is '" + target_type + "'", node);
                };

                // Class instances and C-backed handles are move-only, not aliasable (x = x is fine)
                if (this.isMoveOnly(target_type)) {
                    if (node.right.kind == "Identifier") {
                        if (node.right.value != node.left.value) {
                            this.reportAlias(target_type, node.right.value, node.left.value, node);
                        };
                    };
                };
            };

        } else if (node.left.kind == "MemberAccess") {
            // Complex is immutable: c.real = 9 would be silently ignored by codegen
            var target_obj_type: str = this.checkExpr(node.left.left);
            if (target_obj_type == "Complex") {
                this.addErrorAt("Cannot assign to '" + node.left.value + "': Complex is immutable in Mocha. Create a new one instead, e.g. c = Complex(9, c.imag)", node);
                return;
            };

            var field_type: str = this.checkExpr(node.left);
            var field_is_prim: bool = field_type == "int" || field_type == "vast" || field_type == "float" || field_type == "bool" || field_type == "str";
            var value_is_prim: bool = value_type == "int" || value_type == "vast" || value_type == "float" || value_type == "bool" || value_type == "str";

            // null is not a number: it can't clear an int/vast/float/bool field
            if (node.right.kind == "NullLiteral" && field_is_prim && field_type != "str") {
                this.addErrorAt("Cannot assign null to '" + node.left.value + "' which is '" + field_type + "'. null is only valid for str, class, array and other pointer types; use 0 to reset a number.", node);
            } else if (field_is_prim && value_is_prim) {
                // primitive field: the value's primitive type must be compatible (same rule as variables)
                if (this.typesCompatible(field_type, value_type) == false) {
                    this.addErrorAt("Type mismatch: cannot assign '" + value_type + "' to field '" + node.left.value + "' which is '" + field_type + "'", node);
                };
            };

        } else if (node.left.kind == "IndexAccess") {
            if (node.left.left.kind == "Identifier") {
                if (this.symbols.isConst(node.left.left.value)) {
                    this.addErrorAt("Cannot mutate constant '" + node.left.left.value + "'. Constants are immutable in Mocha", node);
                };
            };
            var obj_type: str = this.checkExpr(node.left.left);
            this.checkExpr(node.left.right);

            // Dict assignment: values are dynamic, but a dict cannot hold itself
            if (obj_type == "dict") {
                if (node.left.left.kind == "Identifier" && node.right.kind == "Identifier") {
                    if (node.left.left.value == node.right.value) {
                        this.addErrorAt("Cannot store dict '" + node.right.value + "' inside itself. That creates a cycle, and printing or releasing it would never end", node);
                    };
                };
                return;
            };

            var elem_type: str = this.extractElementType(obj_type);
            if (elem_type == "") {
                this.addErrorAt("Cannot index into non-array type '" + obj_type + "'", node);
            } else if (this.typesCompatible(elem_type, value_type) == false) {
                this.addErrorAt("Cannot assign '" + value_type + "' to array of '" + elem_type + "'", node);
            };

        } else if (node.left.kind == "Index2DAccess") {
            if (node.left.left.kind == "Identifier") {
                if (this.symbols.isConst(node.left.left.value)) {
                    this.addErrorAt("Cannot mutate constant '" + node.left.left.value + "'. Constants are immutable in Mocha", node);
                };
            };
            var obj_type2: str = this.checkExpr(node.left.left);
            // Nested dict write, e.g. d["a"]["b"] = v: values are dynamic, always valid
            if (obj_type2 == "dict") { return; };
            var elem2: str = this.extractElementType(obj_type2);
            if (elem2 != "") { elem2 = this.extractElementType(elem2); };
            if (elem2 == "") {
                this.addErrorAt("Cannot index into non-2D-array type '" + obj_type2 + "'", node);
            } else if (this.typesCompatible(elem2, value_type) == false) {
                this.addErrorAt("Cannot assign '" + value_type + "' to 2D array of '" + elem2 + "'", node);
            };
        };
    };

    function checkCompoundAssignment(node: ASTNode) -> null {
        var target_type: str = this.checkExpr(node.left);
        var value_type:  str = this.checkExpr(node.right);

        if (node.left.kind == "Identifier") {
            if (this.symbols.isConst(node.left.value)) {
                this.addErrorAt("Cannot use '" + node.value + "' on constant '" + node.left.value + "'", node);
            };
        } else if (node.left.kind == "MemberAccess") {
            // Complex is immutable: c.real += 5 must not reach codegen
            var target_obj_type: str = this.checkExpr(node.left.left);
            if (target_obj_type == "Complex") {
                this.addErrorAt("Cannot use '" + node.value + "' on '" + node.left.value + "': Complex is immutable in Mocha. Create a new one instead, e.g. c = Complex(c.real + 5, c.imag)", node);
                return;
            };
        } else if (node.left.kind == "IndexAccess") {
            if (node.left.left.kind == "Identifier") {
                if (this.symbols.isConst(node.left.left.value)) {
                    this.addErrorAt("Cannot mutate constant '" + node.left.left.value + "'. Constants are immutable in Mocha", node);
                };
            };
        } else if (node.left.kind == "Index2DAccess") {
            if (node.left.left.kind == "Identifier") {
                if (this.symbols.isConst(node.left.left.value)) {
                    this.addErrorAt("Cannot mutate constant '" + node.left.left.value + "'. Constants are immutable in Mocha", node);
                };
            };
        };

        if (this.isNumeric(target_type) == false) {
            this.addErrorAt("'" + node.value + "' requires a numeric type, got '" + target_type + "'", node);
        };
        if (this.isNumeric(value_type) == false) {
            this.addErrorAt("'" + node.value + "' requires a numeric value, got '" + value_type + "'", node);
        };
    };

    function checkReturn(node: ASTNode) -> null {
        if (this.current_return == "") {
            this.addErrorAt("'return' used outside of a function", node);
            return;
        };
        if (node.left == null) {
            if (this.current_return != "null") {
                this.addErrorAt("Empty return in function that should return '" + this.current_return + "'", node);
            };
            return;
        };
        var value_type: str = this.checkExpr(node.left);
        if (this.typesCompatible(this.current_return, value_type) == false) {
            this.addErrorAt("Return type mismatch: function declared to return '" + this.current_return + "' but returning '" + value_type + "'", node);
        };
    };

    function checkIf(node: ASTNode) -> null {
        var cond_type: str = this.checkExpr(node.condition);
        if (cond_type != "bool" && cond_type != "unknown") {
            this.addErrorAt("If condition must be bool, got '" + cond_type + "'. Mocha does not allow truthy/falsy coercion", node);
        };
        this.checkBlock(node.body);

        var ei: int = 0;
        while (ei < node.else_ifs.length) {
            var elif_node: ASTNode = node.else_ifs[ei];
            var ec_type: str = this.checkExpr(elif_node.condition);
            if (ec_type != "bool" && ec_type != "unknown") {
                this.addErrorAt("else if condition must be bool, got '" + ec_type + "'", elif_node);
            };
            this.checkBlock(elif_node.body);
            ei += 1;
        };

        if (node.else_body.length > 0) {
            this.checkBlock(node.else_body);
        };
    };

    function checkWhile(node: ASTNode) -> null {
        this.loop_depth += 1;
        var cond_type: str = this.checkExpr(node.condition);
        if (cond_type != "bool") {
            this.addErrorAt("While condition must be bool, got '" + cond_type + "'", node);
        };
        this.checkBlock(node.body);
        this.loop_depth -= 1;
    };

    function checkDoWhile(node: ASTNode) -> null {
        this.loop_depth += 1;
        this.checkBlock(node.body);
        var cond_type: str = this.checkExpr(node.condition);
        if (cond_type != "bool") {
            this.addErrorAt("Do-while condition must be bool, got '" + cond_type + "'", node);
        };
        this.loop_depth -= 1;
    };

    function checkTryRescue(node: ASTNode) -> null {
        // try body in its own scope
        this.try_depth += 1;
        this.symbols.pushScope();
        this.checkStmtList(node.body);
        this.symbols.popScope();
        this.try_depth -= 1;

        // rescue body in its own scope (node.value is the optional binding name)
        this.rescue_depth += 1;
        this.symbols.pushScope();
        if (node.value != "") {
            this.symbols.declareSimple(node.value, "str");
        };
        this.checkStmtList(node.else_body);
        this.symbols.popScope();
        this.rescue_depth -= 1;
    };

    function checkFail(node: ASTNode) -> null {
        var msg_type: str = this.checkExpr(node.left);
        if (msg_type != "str") {
            this.addErrorAt("'fail' expects a str message, got '" + msg_type + "'", node);
        };
    };

    function checkFor(node: ASTNode) -> null {
        this.loop_depth += 1;
        this.symbols.pushScope();

        this.checkStmt(node.left);
        var cond_type: str = this.checkExpr(node.condition);
        if (cond_type != "bool") {
            this.addErrorAt("For loop condition must be bool, got '" + cond_type + "'", node);
        };
        this.checkExpr(node.right);

        this.checkStmtList(node.body);

        this.symbols.popScope();
        this.loop_depth -= 1;
    };

    function checkForeach(node: ASTNode) -> null {
        this.loop_depth += 1;

        var iterable_type: str = this.checkExpr(node.left);
        var elem_type: str = "";

        if (node.flag1 && iterable_type.length >= 5) {
            if (iterable_type.substring(0, 3) != "set<") {
                this.addErrorAt("Expected a set in 'for each ... in <...>', got '" + iterable_type + "'", node);
            };
        };
        if (iterable_type.length >= 5) {
            if (iterable_type.substring(0, 3) == "set<") {
                elem_type = iterable_type.substring(4, iterable_type.length - 2);
                node.type_str = elem_type;
                this.symbols.pushScope();
                this.symbols.declareSimple(node.value, elem_type);
                this.checkStmtList(node.body);
                this.symbols.popScope();
                this.loop_depth -= 1;
                return;
            };
        };

        if (iterable_type.length >= 2) {
            elem_type = this.extractElementType(iterable_type);
        };

        if (elem_type == "") {
            if (iterable_type != "unknown" && iterable_type != "dict") {
                this.addErrorAt("'for each' requires an array or set, got '" + iterable_type + "'", node);
            };
            elem_type = "unknown";
        };

        var var_type: str = node.type_str;
        if (var_type == "") { var_type = elem_type; };
        node.type_str = var_type;

        this.symbols.pushScope();
        this.symbols.declareSimple(node.value, var_type);
        this.checkStmtList(node.body);
        this.symbols.popScope();
        this.loop_depth -= 1;
    };

    function checkMatch(node: ASTNode) -> null {
        var val_type:    str  = this.checkExpr(node.left);
        var has_default: bool = false;

        var ci: int = 0;
        while (ci < node.cases.length) {
            var case_node: ASTNode = node.cases[ci];

            if (case_node.flag1) {
                has_default = true;
            } else {
                if (case_node.left != null) {
                    // pattern with when guard — declare binding
                    if (case_node.left.kind == "Identifier" && case_node.condition != null) {
                        this.symbols.pushScope();
                        this.symbols.declareSimple(case_node.left.value, val_type);
                        var wt: str = this.checkExpr(case_node.condition);
                        if (wt != "bool") {
                            this.addErrorAt("'when' condition must be bool, got '" + wt + "'", case_node);
                        };
                        this.checkBlock(case_node.body);
                        this.symbols.popScope();
                        ci += 1;
                        continue;
                    };
                    this.checkExpr(case_node.left);
                };
                if (case_node.condition != null) {
                    var ct: str = this.checkExpr(case_node.condition);
                    if (ct != "bool") {
                        this.addErrorAt("'when' condition must be bool, got '" + ct + "'", case_node);
                    };
                };
            };

            this.checkBlock(case_node.body);
            ci += 1;
        };

        if (has_default == false) {
            this.addErrorAt("Match statement must have a 'default' case.", node);
        };
    };

    function checkFunction(node: ASTNode) -> null {
        // Register if not already declared
        if (this.symbols.isDeclared(node.value) == false) {
            this.symbols.declareFunction(node.value, node.type_str);
        };

        var prev_return: str  = this.current_return;
        var prev_shared: bool = this.current_shared;

        this.current_return = node.type_str;
        this.current_shared = node.flag1;

        this.symbols.pushScope();

        var i: int = 0;
        while (i < node.params.length) {
            var param: ASTNode = node.params[i];
            if (param.value != "didLoad") {
                this.declareChecked(param.value, param.type_str, false, param);
            };
            i += 1;
        };

        // native functions have no body (the parser stores the native name in extra;
        // flag2 can't be used here because it also means "local")
        if (node.extra == "" || node.kind == "MethodDecl") {
            this.checkStmtList(node.body);

            if (node.type_str != "null") {
                if (this.hasReturn(node.body) == false) {
                    this.addErrorAt("Function '" + node.value + "' declared as '" + node.type_str + "' but has no return statement. Clang will throw fatal error without it.", node);
                };
            };
        };

        this.symbols.popScope();
        this.current_return = prev_return;
        this.current_shared = prev_shared;
    };

    function isLiteralTrue(node: ASTNode) -> bool {
        if (node == null) { return false; };
        if (node.kind == "BoolLiteral") { return node.bool_val; };
        return false;
    };

    // True if a 'break' in these statements could leave the CURRENT loop.
    // Nested loops are skipped: their breaks only leave themselves.
    function hasLoopBreak(stmts: ASTNode[]) -> bool {
        var i: int = 0;
        while (i < stmts.length) {
            var stmt: ASTNode = stmts[i];
            if (stmt.kind == "BreakStmt") { return true; };
            if (stmt.kind == "IfStmt") {
                if (this.hasLoopBreak(stmt.body)) { return true; };
                var ei: int = 0;
                while (ei < stmt.else_ifs.length) {
                    if (this.hasLoopBreak(stmt.else_ifs[ei].body)) { return true; };
                    ei += 1;
                };
                if (this.hasLoopBreak(stmt.else_body)) { return true; };
            };
            if (stmt.kind == "MatchStmt") {
                var ci: int = 0;
                while (ci < stmt.cases.length) {
                    if (this.hasLoopBreak(stmt.cases[ci].body)) { return true; };
                    ci += 1;
                };
            };
            i += 1;
        };
        return false;
    };

    function hasReturn(stmts: ASTNode[]) -> bool {
        var i: int = 0;
        while (i < stmts.length) {
            var stmt: ASTNode = stmts[i];
            if (stmt.kind == "ReturnStmt") { return true; };

            // every path must return: then, each else-if, and a final else
            if (stmt.kind == "IfStmt") {
                if (stmt.else_body.length > 0) {
                    var all_paths: bool = this.hasReturn(stmt.body) && this.hasReturn(stmt.else_body);
                    var ei: int = 0;
                    while (ei < stmt.else_ifs.length) {
                        if (this.hasReturn(stmt.else_ifs[ei].body) == false) {
                            all_paths = false;
                        };
                        ei += 1;
                    };
                    if (all_paths) { return true; };
                };
            };

            // a loop on literal 'true' with no break that can leave it never completes
            if (stmt.kind == "WhileLoop" || stmt.kind == "DoWhileLoop" || stmt.kind == "ForLoop") {
                if (this.isLiteralTrue(stmt.condition)) {
                    if (this.hasLoopBreak(stmt.body) == false) { return true; };
                };
            };

            // needs a default, and every case must really return (a break is not a return)
            if (stmt.kind == "MatchStmt") {
                var has_default: bool = false;
                var ci: int = 0;
                while (ci < stmt.cases.length) {
                    if (stmt.cases[ci].flag1) { has_default = true; };
                    ci += 1;
                };
                if (has_default) {
                    var all_return: bool = true;
                    var ci2: int = 0;
                    while (ci2 < stmt.cases.length) {
                        if (this.hasReturn(stmt.cases[ci2].body) == false) {
                            all_return = false;
                        };
                        ci2 += 1;
                    };
                    if (all_return) { return true; };
                };
            };
            i += 1;
        };
        return false;
    };

        // true if the list holds s
    function listHas(list: str[], s: str) -> bool {
        var k: int = 0;
        while (k < list.length) {
            if (list[k] == s) { return true; };
            k += 1;
        };
        return false;
    };

    // remember the method names and field names a class declares
    function registerMembers(node: ASTNode) -> null {
        var mstr: str = "";
        var fstr: str = "";
        var k: int = 0;
        while (k < node.body.length) {
            var mem: ASTNode = node.body[k];
            if (mem.kind == "MethodDecl") {
                if (mem.value != "constructor") {
                    if (mstr != "") { mstr = mstr + ","; };
                    mstr = mstr + mem.value;
                };
            } else if (mem.kind == "FieldDecl") {
                if (fstr != "") { fstr = fstr + ","; };
                fstr = fstr + mem.value;
            };
            k += 1;
        };
        this.symbols.declareGlobal("members:" + node.value, mstr, false, false, false, "public");
        this.symbols.declareGlobal("fields:" + node.value, fstr, false, false, false, "public");
    };

    // all names (own + inherited through every parent) for prefix "members:" or "fields:"
    function allNames(cls: str, prefix: str) -> str[] {
        var result: str[] = [];
        var enc: str = this.symbols.lookupEncoded(prefix + cls);
        if (enc != "") {
            var joined: str = this.symbols.decodeField(enc, 0);
            if (joined != "") {
                var own: str[] = this.splitComma(joined);
                var a: int = 0;
                while (a < own.length) {
                    if (this.listHas(result, own[a]) == false) { result.push(own[a]); };
                    a += 1;
                };
            };
        };
        var idx: int = 0;
        var parent: str = this.parentAt(cls, idx);
        while (parent != "") {
            if (parent != cls) {
                var inherited: str[] = this.allNames(parent, prefix);
                var b: int = 0;
                while (b < inherited.length) {
                    if (this.listHas(result, inherited[b]) == false) { result.push(inherited[b]); };
                    b += 1;
                };
            };
            idx += 1;
            parent = this.parentAt(cls, idx);
        };
        return result;
    };

    // two parents giving the same member: fields are an error, methods are recorded
    function checkDiamond(node: ASTNode) -> null {
        if (node.children.length < 2) { return; };
        var pass: int = 0;
        while (pass < 2) {
            var prefix: str = "members:";
            if (pass == 1) { prefix = "fields:"; };
            var names:  str[] = [];
            var owners: str[] = [];
            var pi: int = 0;
            while (pi < node.children.length) {
                var pname: str = node.children[pi].value;
                var plist: str[] = this.allNames(pname, prefix);
                var q: int = 0;
                while (q < plist.length) {
                    var at: int = -1;
                    var w: int = 0;
                    while (w < names.length) {
                        if (names[w] == plist[q]) { at = w; };
                        w += 1;
                    };
                    if (at < 0) {
                        names.push(plist[q]);
                        owners.push(pname);
                    } else {
                        owners[at] = owners[at] + "," + pname;
                    };
                    q += 1;
                };
                pi += 1;
            };
            var r: int = 0;
            while (r < names.length) {
                var who: str[] = this.splitComma(owners[r]);
                if (who.length > 1) {
                    if (pass == 0) {
                        this.symbols.declareGlobal("diamond:" + node.value + "." + names[r], owners[r], false, false, false, "public");
                    } else {
                        this.addErrorAt("Diamond conflict: field '" + names[r] + "' is inherited from both " + who[0] + " and " + who[1] + " in class '" + node.value + "'. Mocha does not support diamond inheritance of fields - rename one of the conflicting fields to resolve this.", node);
                    };
                };
                r += 1;
            };
            pass += 1;
        };
    };

    function checkClass(node: ASTNode) -> null {
        if (this.symbols.isDeclared(node.value) == false) {
            this.symbols.declareClass(node.value);
        };

        // Track inheritance — node.children has Parent nodes
        if (node.children.length > 0) {
            this.inheritance.put(node.value, node.children[0].value);
            // store EVERY parent as "Class#0", "Class#1", ... for multiple inheritance
            var inh_i: int = 0;
            while (inh_i < node.children.length) {
                this.inheritance.put(node.value + "#" + str(inh_i), node.children[inh_i].value);
                inh_i += 1;
            };
        };

        this.registerMembers(node);
        this.checkDiamond(node);

        var prev_class: str = this.current_class;
        this.current_class = node.value;

        this.symbols.pushScope();

        // First pass — declare all fields and methods so they can reference each other
        var i: int = 0;
        while (i < node.body.length) {
            var member: ASTNode = node.body[i];
            if (member.kind == "FieldDecl") {
                if (member.flag2) {
                    var weak_prims: str[] = ["int", "float", "str", "bool", "vast", "dict", "null"];
                    if (this.countBrackets(member.type_str) > 0 || this.listHas(weak_prims, member.type_str) || this.symbols.isDeclared(member.type_str) == false) {
                        this.addErrorAt("'weak' only applies to a field whose type is a single class, not '" + member.type_str + "'", member);
                    };
                };
                if (member.flag1) {
                    this.addErrorAt("'shared' is not allowed on fields - use a module-level variable instead", member);
                };
                this.symbols.declare(member.value, member.type_str,
                                    false, false, false, member.extra);
                this.symbols.declareGlobal(node.value + "." + member.value,
                                        member.type_str,
                                        false, false, false, member.extra);
            } else if (member.kind == "MethodDecl") {
                this.symbols.declare(member.value, member.type_str,
                                    false, true, false, member.extra);
                this.symbols.declareGlobal(node.value + "." + member.value,
                                        member.type_str,
                                        false, true, false, member.extra);
            };
            i += 1;
        };

        // Second pass — check method bodies and field initialisers
        var j: int = 0;
        while (j < node.body.length) {
            var member2: ASTNode = node.body[j];
            if (member2.kind == "MethodDecl") {
                this.checkFunction(member2);
            } else if (member2.kind == "FieldDecl") {
                if (member2.left != null) {
                    this.checkExpr(member2.left);
                };
            };
            j += 1;
        };

        this.symbols.popScope();
        this.current_class = prev_class;

        // Interface compliance — node.else_ifs has Interface nodes
        var ii: int = 0;
        while (ii < node.else_ifs.length) {
            var iface_name: str = node.else_ifs[ii].value;
            var iface_encoded: str = this.symbols.lookupEncoded("interface." + iface_name);
            if (iface_encoded == "") {
                this.addErrorAt("Unknown interface '" + iface_name + "'", node);
            } else {
                this.checkInterfaceCompliance(node, iface_name);
            };
            ii += 1;
        };
    };

    function checkInterfaceCompliance(class_node: ASTNode, iface_name: str) -> null {
        var methods_encoded: str = this.symbols.lookupEncoded("interface." + iface_name + ".methods");
        if (methods_encoded == "") { return; };
        var names_joined: str = this.symbols.decodeField(methods_encoded, 0);
        if (names_joined == "") { return; };
        var method_names: str[] = this.splitComma(names_joined);

        var mi: int = 0;
        while (mi < method_names.length) {
            var mname: str = method_names[mi];

            // interface signature: "returnType@paramType;paramType"
            var sig_encoded: str = this.symbols.lookupEncoded("interface." + iface_name + "." + mname);
            var sig: str = this.symbols.decodeField(sig_encoded, 0);
            var sig_parts: str[] = this.splitBy(sig, "@");
            var want_ret: str = sig_parts[0];
            var want_params: str[] = [];
            if (sig_parts.length > 1) {
                if (sig_parts[1] != "") {
                    want_params = this.splitBy(sig_parts[1], ";");
                };
            };

            // find the class method
            var found_idx: int = -1;
            var ci: int = 0;
            while (ci < class_node.body.length) {
                if (class_node.body[ci].kind == "MethodDecl") {
                    if (class_node.body[ci].value == mname) {
                        if (found_idx < 0) { found_idx = ci; };
                    };
                };
                ci += 1;
            };

            if (found_idx < 0) {
                this.addErrorAt("Class '" + class_node.value + "' implements '" + iface_name + "' but is missing method '" + mname + "'", class_node);
            } else {
                // return type
                if (class_node.body[found_idx].type_str != want_ret) {
                    this.addErrorAt("'" + class_node.value + "." + mname + "' return type '" + class_node.body[found_idx].type_str + "' doesn't match interface '" + want_ret + "'", class_node);
                };
                // parameters (didLoad is not counted)
                var have_types: str[] = [];
                var pi: int = 0;
                while (pi < class_node.body[found_idx].params.length) {
                    if (class_node.body[found_idx].params[pi].value != "didLoad") {
                        have_types.push(class_node.body[found_idx].params[pi].type_str);
                    };
                    pi += 1;
                };
                if (have_types.length != want_params.length) {
                    this.addErrorAt("'" + class_node.value + "." + mname + "' wrong number of parameters for interface '" + iface_name + "'", class_node);
                } else {
                    var qi: int = 0;
                    while (qi < have_types.length) {
                        if (have_types[qi] != want_params[qi]) {
                            this.addErrorAt("'" + class_node.value + "." + mname + "' parameter type '" + have_types[qi] + "' doesn't match interface type '" + want_params[qi] + "'", class_node);
                        };
                        qi += 1;
                    };
                };
            };
            mi += 1;
        };
    };

    // split a string on a single-character separator
    function splitBy(s: str, sep: str) -> str[] {
        var result: str[] = [];
        var current: str = "";
        var i: int = 0;
        while (i < s.length) {
            var ch: str = s.charAt(i);
            if (ch == sep) {
                result.push(current);
                current = "";
            } else {
                current = current + ch;
            };
            i += 1;
        };
        result.push(current);
        return result;
    };

    // Helper: split a comma-separated string into str[]
    function splitComma(s: str) -> str[] {
        return this.splitBy(s, ",");
    };

    function checkInterface(node: ASTNode) -> null {
        if (this.symbols.isDeclared(node.value) == false) {
            this.symbols.declareClass(node.value);
        };

        // Register the interface itself so checkClass can find "interface.Name"
        this.symbols.declareGlobal(
            "interface." + node.value,
            node.value,
            false, false, false, "public"
        );

        var names_str: str = "";
        var i: int = 0;
        while (i < node.body.length) {
            var method: ASTNode = node.body[i];
            if (i > 0) { names_str = names_str + ","; };
            names_str = names_str + method.value;

            // signature "returnType@paramType;paramType"
            var ptypes: str = "";
            var pk: int = 0;
            while (pk < method.params.length) {
                if (method.params[pk].value != "didLoad") {
                    if (ptypes != "") { ptypes = ptypes + ";"; };
                    ptypes = ptypes + method.params[pk].type_str;
                };
                pk += 1;
            };
            this.symbols.declareGlobal(
                "interface." + node.value + "." + method.value,
                method.type_str + "@" + ptypes,
                false, false, false, "public"
            );
            i += 1;
        };

        this.symbols.declareGlobal(
            "interface." + node.value + ".methods",
            names_str,
            false, false, false, "public"
        );
    };

    function checkTag(node: ASTNode) -> null {
        // Register tag type itself
        if (this.symbols.isDeclared(node.value) == false) {
            this.symbols.declareClass(node.value);
        };
        this.tag_types.push(node.value);

        // Register each member as a constant of the tag's type
        var i: int = 0;
        while (i < node.children.length) {
            var key: str = node.value + "." + node.children[i].value;
            if (this.symbols.isDeclared(key) == false) {
                this.symbols.declare(key, node.value, true, false, false, "public");
            };
            i += 1;
        };
    };

    function checkExtend(node: ASTNode) -> null {
        var prev_class: str = this.current_class;
        this.current_class = node.value;

        var i: int = 0;
        while (i < node.body.length) {
            var func: ASTNode = node.body[i];
            this.symbols.pushScope();
            this.symbols.declareSimple("this", node.value);
            this.checkFunction(func);
            this.symbols.popScope();
            i += 1;
        };

        this.current_class = prev_class;
    };

    function check(program: ASTNode) -> null {
        // --------------------------------------------------------
        // PRE-PASS — register all top-level signatures first
        // so functions/classes can reference each other regardless
        // of declaration order
        // --------------------------------------------------------
        this.registerParamCounts(program);
        var i: int = 0;
        while (i < program.children.length) {
            var node: ASTNode = program.children[i];

            if (node.kind == "FunctionDecl") {
                if (this.symbols.isDeclared(node.value)) {
                    // find the first earlier top-level function with the same name
                    var dup_first: int = -1;
                    var dup_scan: int = 0;
                    while (dup_scan < i) {
                        var dup_cand: ASTNode = program.children[dup_scan];
                        if (dup_cand.kind == "FunctionDecl" && dup_cand.value == node.value) {
                            if (dup_first == -1) { dup_first = dup_scan; };
                        };
                        dup_scan += 1;
                    };

                    if (dup_first == -1) {
                        this.addErrorAt("Illegal redefinition of function '" + node.value + "'. Mocha prohibits Function OverLoading", node);
                    } else {
                        // build "function name(a: int, b: str) -> ret" for the earlier and the current function
                        var dup_sig_first: str = "";
                        var dup_sig_second: str = "";
                        var dup_pass: int = 0;
                        while (dup_pass < 2) {
                            var dup_idx: int = dup_first;
                            if (dup_pass == 1) { dup_idx = i; };
                            var dup_fnode: ASTNode = program.children[dup_idx];
                            var dup_params: str = "";
                            var dup_k: int = 0;
                            while (dup_k < dup_fnode.params.length) {
                                var dup_p: ASTNode = dup_fnode.params[dup_k];
                                if (dup_p.value != "didLoad") {
                                    if (dup_params != "") { dup_params = dup_params + ", "; };
                                    dup_params = dup_params + dup_p.value + ": " + dup_p.type_str;
                                };
                                dup_k += 1;
                            };
                            var dup_sig: str = "function " + dup_fnode.value + "(" + dup_params + ") -> " + dup_fnode.type_str;
                            if (dup_pass == 0) { dup_sig_first = dup_sig; } else { dup_sig_second = dup_sig; };
                            dup_pass += 1;
                        };

                        this.addErrorAt("Illegal redefinition of function " + node.value + " in scope. Its versions are:\n  " + dup_sig_first + " {...};\n  and " + dup_sig_second + " {...};\nPlease resolve this ambiguity by renaming one of the functions. Mocha prohibits Function OverLoading", node);
                    };
                } else {
                    this.symbols.declareFunction(node.value, node.type_str);
                };

            } else if (node.kind == "ClassDecl") {
                if (this.symbols.isDeclared(node.value) == false) {
                    this.symbols.declareClass(node.value);
                };
                // remember real classes (not tags/interfaces) for the move-only rule
                this.class_names.push(node.value);
                // Pre-register all fields so cross-class references work
                var fi: int = 0;
                while (fi < node.body.length) {
                    var member: ASTNode = node.body[fi];
                    if (member.kind == "FieldDecl") {
                        var fkey: str = node.value + "." + member.value;
                        if (this.symbols.isDeclared(fkey) == false) {
                            this.symbols.declare(fkey, member.type_str,
                                                false, false, false, member.extra);
                        };
                    } else if (member.kind == "MethodDecl") {
                        var mkey: str = node.value + "." + member.value;
                        if (this.symbols.isDeclared(mkey) == false) {
                            this.symbols.declare(mkey, member.type_str,
                                                false, true, false, member.extra);
                        };
                    };
                    fi += 1;
                };

            } else if (node.kind == "ExtendDecl") {
                var ei: int = 0;
                while (ei < node.body.length) {
                    var efunc: ASTNode = node.body[ei];
                    var ekey: str = node.value + "." + efunc.value;
                    if (this.symbols.isDeclared(ekey) == false) {
                        this.symbols.declareFunction(ekey, efunc.type_str);
                    };
                    ei += 1;
                };

            } else if (node.kind == "TagDecl") {
                if (this.symbols.isDeclared(node.value) == false) {
                    this.symbols.declareClass(node.value);
                };
                this.tag_types.push(node.value);
                var ti: int = 0;
                while (ti < node.children.length) {
                    var tkey: str = node.value + "." + node.children[ti].value;
                    if (this.symbols.isDeclared(tkey) == false) {
                        this.symbols.declare(tkey, node.value,
                                            true, false, false, "public");
                    };
                    ti += 1;
                };
            };

            i += 1;
        };

        // --------------------------------------------------------
        // MAIN PASS — full type checking
        // --------------------------------------------------------
        var entry_points: str[] = [];

        var j: int = 0;
        while (j < program.children.length) {
            var node2: ASTNode = program.children[j];

            if (node2.kind == "ImportStmt") {
                var import_name: str = node2.extra;
                if (import_name == "") { import_name = node2.value; };
                if (import_name != "" && import_name != "*") {
                    if (this.symbols.isDeclared(import_name) == false) {
                        this.symbols.declareSimple(import_name, "module");
                    };
                };

            } else if (node2.kind == "ClassDecl") {
                this.checkClass(node2);
                // the entry point must be a plain top-level function
                var cmi: int = 0;
                while (cmi < node2.body.length) {
                    if (node2.body[cmi].kind == "MethodDecl") {
                        var cmp: int = 0;
                        while (cmp < node2.body[cmi].params.length) {
                            if (node2.body[cmi].params[cmp].value == "didLoad") {
                                this.addErrorAt("'didLoad' is only allowed on a top-level function, not on method '" + node2.value + "." + node2.body[cmi].value + "'", node2.body[cmi]);
                            };
                            cmp += 1;
                        };
                    };
                    cmi += 1;
                };

            } else if (node2.kind == "InterfaceDecl") {
                this.checkInterface(node2);

            } else if (node2.kind == "TagDecl") {
                // already handled in pre-pass

            } else if (node2.kind == "FunctionDecl") {
                this.checkFunction(node2);
                // Check for didLoad entry point
                var pi: int = 0;
                while (pi < node2.params.length) {
                    if (node2.params[pi].value == "didLoad") {
                        entry_points.push(node2.value);
                    };
                    pi += 1;
                };

            } else if (node2.kind == "MethodDecl") {
                this.checkFunction(node2);

            } else if (node2.kind == "ExtendDecl") {
                this.checkExtend(node2);

            } else {
                this.checkStmt(node2);
            };

            j += 1;
        };

        // --------------------------------------------------------
        // Entry point validation
        // --------------------------------------------------------
        if (entry_points.length == 0) {
            this.addError(
                "No entry point found. Mark one function with 'didLoad' as its first parameter. Example: function main(didLoad, name: str) -> null { ... };",
                0, 0
            );
        } else if (entry_points.length > 1) {
            var ep_str: str = "";
            var epi: int = 0;
            while (epi < entry_points.length) {
                if (epi > 0) { ep_str = ep_str + ", "; };
                ep_str = ep_str + entry_points[epi];
                epi += 1;
            };
            this.addError("Multiple entry points found: " + ep_str + ". Only one function can have 'didLoad'.", 0, 0);
        };

        // --------------------------------------------------------
        // Report errors
        // --------------------------------------------------------
        if (this.errors.length > 0) {
            var ei2: int = 0;
            while (ei2 < this.errors.length) {
                var e: MochaTypeError = this.errors[ei2];
                puts("MochaTypeError at line " + str(e.line) + ", col " + str(e.col) + ": " + e.message);
                ei2 += 1;
            };
            //exit_program(1);
        };
    };
};