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
    var inheritance:    HashTable;
    var errors:         MochaTypeError[];
    var tag_types:      str[];
    var current_shared: bool;

    function constructor() -> null {
        this.symbols        = ScopeManager();
        this.current_class  = "";
        this.current_return = "";
        this.loop_depth     = 0;
        this.inheritance    = HashTable();
        this.errors         = [];
        this.tag_types      = [];
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

    function typesCompatible(expected: str, actual: str) -> bool {
        if (expected == actual) { return true; };

        // unknown/any is compatible with everything
        if (actual == "unknown" || actual == "any") { return true; };
        if (expected == "unknown" || expected == "any") { return true; };

        // numeric types are mutually compatible
        if (this.isNumeric(expected) && this.isNumeric(actual)) { return true; };

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

        // set compatibility
        if (expected.length >= 4 && actual.length >= 4) {
            if (expected.substring(0, 3) == "set<" && actual.substring(0, 3) == "set<") {
                return true;
            };
            if (expected.substring(0, 3) == "set<" && actual == "set<unknown>") {
                return true;
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

            case "OkExpr":
                this.checkExpr(node.left);
                return "Result";

            case "ErrorExpr":
                this.checkExpr(node.left);
                return "Result";

            case "AwaitExpr":
                return this.checkExpr(node.left);

            case "RangeNode":
                var rl: str = this.checkExpr(node.left);
                var rr: str = this.checkExpr(node.right);
                if (rl != "int") {
                    this.addErrorAt("Range start must be int, got '" + rl + "'", node);
                };
                if (rr != "int") {
                    this.addErrorAt("Range end must be int, got '" + rr + "'", node);
                };
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
        this.symbols.pushScope();
        this.symbols.declareSimple(node.value, elem_type);
        var expr_type: str = this.checkExpr(node.left);
        if (node.condition != null) {
            var cond_type: str = this.checkExpr(node.condition);
            if (cond_type != "bool") {
                this.addErrorAt("List comprehension condition must be bool, got '" + cond_type + "'", node);
            };
            // NEW — check else branch if present
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
            this.symbols.declareSimple(node.params[i].value, node.params[i].type_str);
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
            return "dict";
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

        if (obj_type == "unknown") {
            this.addErrorAt("Cannot access '." + member + "' on unresolved type. Check the preceding expression for errors.", node);
            return "unknown";
        };

        // Dict built-ins
        if (obj_type == "dict") {
            if (member == "length")    { return "int"; };
            if (member == "has")       { return "bool"; };
            if (member == "allKeys")   { return "str[]"; };
            if (member == "allValues") { return "str[]"; };
            if (member == "merge")     { return "dict"; };
            if (member == "remove")    { return "null"; };
            if (member == "clean")     { return "null"; };
            this.addErrorAt("Unknown dict method '." + member + "'", node);
            return "unknown";
        };

        // length — arrays and str
        if (member == "length") {
            if (obj_type == "str") { return "int"; };
            var le: str = this.extractElementType(obj_type);
            if (le == "") {
                this.addErrorAt("'.length' used on non-array type '" + obj_type + "'", node);
            };
            return "int";
        };

        // rows / cols — 2D arrays
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
                if (member == "insert" || member == "delete" ||
                    member == "clean"  || member == "negate" ||
                    member == "retype")                      { return "null"; };
                if (member == "union"   || member == "intersect" ||
                    member == "xor"     || member == "rel_diff")  { return obj_type; };
                this.addErrorAt("Unknown set method '." + member + "'", node);
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

        // Class member lookup — walk inheritance chain
        return this.lookupMember(obj_type, member, node);
    };

    function lookupMember(obj_type: str, member: str, node: ASTNode) -> str {
        var current: str = obj_type;
        while (current != "") {
            var key:     str = current + "." + member;
            var encoded: str = this.symbols.lookupEncoded(key);
            if (encoded != "") {
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
            // Walk up inheritance chain
            if (this.inheritance.has(current)) {
                current = this.inheritance.get(current);
            } else {
                current = "";
            };
        };
        return "unknown";
    };

    function isSubclassOf(cls: str, parent: str) -> bool {
        var current: str = cls;
        while (current != "") {
            if (this.inheritance.has(current)) {
                current = this.inheritance.get(current);
                if (current == parent) { return true; };
            } else {
                current = "";
            };
        };
        return false;
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
            // e.g. chained call result — check callee expr and return unknown
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

        // Check all args
        var i: int = 0;
        while (i < node.args.length) {
            if (node.args[i].kind != "NamedArg") {
                this.checkExpr(node.args[i]);
            };
            i += 1;
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

        // Dict methods
        if (obj_type == "dict") {
            if (func_name == "has")                          { return "bool"; };
            if (func_name == "allKeys" || func_name == "allValues") { return "str[]"; };
            if (func_name == "remove"  || func_name == "clean")     { return "null"; };
            if (func_name == "length")                       { return "int"; };
            if (func_name == "merge")                        { return "dict"; };
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

        // Set methods
        if (obj_type.length >= 4) {
            if (obj_type.substring(0, 3) == "set<") {
                if (func_name == "has")                           { return "bool"; };
                if (func_name == "insert" || func_name == "delete" ||
                    func_name == "clean"  || func_name == "negate" ||
                    func_name == "retype")                        { return "null"; };
                if (func_name == "union"    || func_name == "intersect" ||
                    func_name == "xor"      || func_name == "rel_diff") {
                    if (node.args.length > 0) {
                        var arg_type: str = this.checkExpr(node.args[0]);
                        if (arg_type != obj_type) {
                            this.addErrorAt("Cannot call '" + func_name + "' on '" + obj_type + "' with '" + arg_type + "'. Both sets must be the same type.", node);
                        };
                    };
                    return obj_type;
                };
                if (func_name == "size") { return "int"; };
                return "unknown";
            };
        };

        // String methods
        if (obj_type == "str") {
            if (func_name == "charAt")    { return "str"; };
            if (func_name == "toInt")     { return "int"; };
            if (func_name == "toFloat")   { return "float"; };
            if (func_name == "substring") { return "str"; };
        };

        // occs
        if (func_name == "occs") { return "int"; };

        // Module alias call — obj_type == "module"
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

        // Class method lookup
        if (obj_type != "" && obj_type != "unknown") {
            var class_sym: str = this.symbols.lookupEncoded(obj_type + "." + func_name);
            if (class_sym != "") {
                return this.symbols.decodeField(class_sym, 0);
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
            case "ForLoop":
                this.checkFor(node);
            case "ForEachLoop":
                this.checkForeach(node);
            case "MatchStmt":
                this.checkMatch(node);
            case "BreakStmt":
                if (this.loop_depth == 0) {
                    this.addErrorAt("'break' used outside of a loop", node);
                };
            case "ContinueStmt":
                if (this.loop_depth == 0) {
                    this.addErrorAt("'continue' used outside of a loop", node);
                };
            case "PrintStmt":
                var pi: int = 0;
                while (pi < node.args.length) {
                    if (node.args[pi].kind != "NamedArg") {
                        this.checkExpr(node.args[pi]);
                    };
                    pi += 1;
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

    function checkBlock(stmts: ASTNode[]) -> null {
        this.symbols.pushScope();
        var i: int = 0;
        while (i < stmts.length) {
            this.checkStmt(stmts[i]);
            i += 1;
        };
        this.symbols.popScope();
    };

    function checkVarDecl(node: ASTNode) -> null {
        var value_type: str = "unknown";
        if (node.left != null) {
            value_type = this.checkExpr(node.left);
        };

        if (value_type == "unknown[]" && node.type_str.length >= 2) {
            // empty array literal — trust declared type
        } else if (this.typesCompatible(node.type_str, value_type) == false) {
            this.addErrorAt("Type mismatch in declaration of '" + node.value + "': declared as '" + node.type_str + "' but value is '" + value_type + "'", node);
        };

        if (node.type_str == "str") {
            if (node.left != null && node.left.kind == "NullLiteral") {
                this.addErrorAt("'" + node.value + "' is type 'str' which cannot be null. Use empty string \"\" instead", node);
            };
        };

        this.symbols.declareSimple(node.value, node.type_str);
    };

    function checkConstDecl(node: ASTNode) -> null {
        var value_type: str = this.checkExpr(node.left);

        if (value_type == "unknown[]" && node.type_str.length >= 2) {
            // empty array literal — trust declared type
        } else if (this.typesCompatible(node.type_str, value_type) == false) {
            this.addErrorAt("Type mismatch in constant '" + node.value + "': declared as '" + node.type_str + "' but value is '" + value_type + "'", node);
        };

        this.symbols.declare(node.value, node.type_str, true, false, false, "public");
    };

    function checkAssignment(node: ASTNode) -> null {
        if (node.left.kind == "TupleAccess") {
            this.addErrorAt("Cannot assign to tuple element. Tuples are immutable in Mocha.", node);
            return;
        };

        var value_type: str = this.checkExpr(node.right);

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
            };

        } else if (node.left.kind == "MemberAccess") {
            this.checkExpr(node.left);

        } else if (node.left.kind == "IndexAccess") {
            if (node.left.left.kind == "Identifier") {
                if (this.symbols.isConst(node.left.left.value)) {
                    this.addErrorAt("Cannot mutate constant '" + node.left.left.value + "'. Constants are immutable in Mocha", node);
                };
            };
            var obj_type: str = this.checkExpr(node.left.left);
            this.checkExpr(node.left.right);
            if (obj_type == "dict") { return; };
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

    function checkFor(node: ASTNode) -> null {
        this.loop_depth += 1;
        this.symbols.pushScope();

        this.checkStmt(node.left);
        var cond_type: str = this.checkExpr(node.condition);
        if (cond_type != "bool") {
            this.addErrorAt("For loop condition must be bool, got '" + cond_type + "'", node);
        };
        this.checkExpr(node.right);

        var i: int = 0;
        while (i < node.body.length) {
            this.checkStmt(node.body[i]);
            i += 1;
        };

        this.symbols.popScope();
        this.loop_depth -= 1;
    };

    function checkForeach(node: ASTNode) -> null {
        this.loop_depth += 1;

        var iterable_type: str = this.checkExpr(node.left);
        var elem_type: str = "";

        if (iterable_type.length >= 4) {
            if (iterable_type.substring(0, 3) == "set<") {
                elem_type = iterable_type.substring(4, iterable_type.length - 1);
                this.symbols.pushScope();
                this.symbols.declareSimple(node.value, elem_type);
                var si: int = 0;
                while (si < node.body.length) {
                    this.checkStmt(node.body[si]);
                    si += 1;
                };
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

        this.symbols.pushScope();
        this.symbols.declareSimple(node.value, var_type);
        var i: int = 0;
        while (i < node.body.length) {
            this.checkStmt(node.body[i]);
            i += 1;
        };
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
                this.symbols.declareSimple(param.value, param.type_str);
            };
            i += 1;
        };

        // native functions have no body
        if (node.flag2 == false) {
            var bi: int = 0;
            while (bi < node.body.length) {
                this.checkStmt(node.body[bi]);
                bi += 1;
            };

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

    function hasReturn(stmts: ASTNode[]) -> bool {
        var i: int = 0;
        while (i < stmts.length) {
            var stmt: ASTNode = stmts[i];
            if (stmt.kind == "ReturnStmt") { return true; };
            if (stmt.kind == "IfStmt") {
                if (stmt.else_body.length > 0) {
                    if (this.hasReturn(stmt.body) && this.hasReturn(stmt.else_body)) {
                        return true;
                    };
                };
            };
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
                            if (this.hasBreak(stmt.cases[ci2].body) == false) {
                                all_return = false;
                            };
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

    function hasBreak(stmts: ASTNode[]) -> bool {
        var i: int = 0;
        while (i < stmts.length) {
            if (stmts[i].kind == "BreakStmt") { return true; };
            i += 1;
        };
        return false;
    };

    function checkClass(node: ASTNode) -> null {
        if (this.symbols.isDeclared(node.value) == false) {
            this.symbols.declareClass(node.value);
        };

        // Track inheritance — node.children has Parent nodes
        if (node.children.length > 0) {
            this.inheritance.put(node.value, node.children[0].value);
        };

        var prev_class: str = this.current_class;
        this.current_class = node.value;

        this.symbols.pushScope();

        // First pass — declare all fields and methods so they can reference each other
        var i: int = 0;
        while (i < node.body.length) {
            var member: ASTNode = node.body[i];
            if (member.kind == "FieldDecl") {
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
        // Interface methods stored as "interface.IfaceName.methodName" -> "retType|params"
        // We'll iterate by checking each method node registered under this interface
        // Interface method list stored as "interface.IfaceName.methods" -> comma joined names
        var methods_encoded: str = this.symbols.lookupEncoded("interface." + iface_name + ".methods");
        if (methods_encoded == "") { return; };

        // methods_encoded is comma-separated method names
        var method_names: str[] = this.splitComma(methods_encoded);
        var mi: int = 0;
        while (mi < method_names.length) {
            var mname: str = method_names[mi];
            var sig_key: str = "interface." + iface_name + "." + mname;
            var sig: str = this.symbols.lookupEncoded(sig_key);
            // sig = "returnType" (params checking deferred — complex to encode)

            // Check class has this method
            var found: bool = false;
            var ci: int = 0;
            while (ci < class_node.body.length) {
                if (class_node.body[ci].kind == "MethodDecl") {
                    if (class_node.body[ci].value == mname) {
                        found = true;
                    };
                };
                ci += 1;
            };
            if (found == false) {
                this.addErrorAt("Class '" + class_node.value + "' implements '" + iface_name + "' but is missing method '" + mname + "'", class_node);
            };
            mi += 1;
        };
    };

    // Helper: split a comma-separated string into str[]
    function splitComma(s: str) -> str[] {
        var result: str[] = [];
        var current: str = "";
        var i: int = 0;
        while (i < s.length) {
            var ch: str = s.charAt(i);
            if (ch == ",") {
                if (current.length > 0) {
                    result.push(current);
                    current = "";
                };
            } else {
                current = current + ch;
            };
            i += 1;
        };
        if (current.length > 0) {
            result.push(current);
        };
        return result;
    };

    function checkInterface(node: ASTNode) -> null {
        if (this.symbols.isDeclared(node.value) == false) {
            this.symbols.declareClass(node.value);
        };

        // Collect method names for compliance checking
        var method_names: str[] = [];
        var i: int = 0;
        while (i < node.body.length) {
            var method: ASTNode = node.body[i];
            method_names.push(method.value);
            // Store return type under "interface.IfaceName.methodName"
            this.symbols.declareGlobal(
                "interface." + node.value + "." + method.value,
                method.type_str,
                false, false, false, "public"
            );
            i += 1;
        };

        // Store method name list as comma-joined string
        var names_str: str = "";
        var j: int = 0;
        while (j < method_names.length) {
            if (j > 0) { names_str = names_str + ","; };
            names_str = names_str + method_names[j];
            j += 1;
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
        var i: int = 0;
        while (i < program.children.length) {
            var node: ASTNode = program.children[i];

            if (node.kind == "FunctionDecl") {
                if (this.symbols.isDeclared(node.value)) {
                    this.addErrorAt("Illegal redefinition of function '" + node.value + "'. Mocha prohibits Function OverLoading", node);
                } else {
                    this.symbols.declareFunction(node.value, node.type_str);
                };

            } else if (node.kind == "ClassDecl") {
                if (this.symbols.isDeclared(node.value) == false) {
                    this.symbols.declareClass(node.value);
                };
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