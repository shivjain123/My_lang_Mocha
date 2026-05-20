// mocha-lib-deps: mocha-string
// ============================================================
// codegen_calls.mch — Function and method call code generation
// ============================================================

extend CodeGen {

    // --------------------------------------------------------
    // Box a value to i8* for array/HashTable storage
    // --------------------------------------------------------

    function boxValue(val_reg: str, val_type: str) -> str {
        if (val_type == "i8*") { return val_reg; };
        var slot: str = this.freshTemp();
        var cast: str = this.freshTemp();
        this.emit("  " + slot + " = alloca " + val_type);
        this.emit("  store " + val_type + " " + val_reg + ", " + val_type + "* " + slot);
        this.emit("  " + cast + " = bitcast " + val_type + "* " + slot + " to i8*");
        return cast;
    };

    // --------------------------------------------------------
    // Collect positional args — returns encoded "reg|type" list
    // --------------------------------------------------------

    function collectArgs(node: ASTNode) -> str[] {
        var result: str[] = [];
        var i: int = 0;
        while (i < node.args.length) {
            var arg: ASTNode = node.args[i];
            if (arg.kind != "NamedArg") {
                result.push(this.genExpr(arg));
            };
            i = i + 1;
        };
        return result;
    };

    // Check if NamedArg with name exists, return its value node or null
    function findNamedArg(node: ASTNode, name: str) -> ASTNode {
        var i: int = 0;
        while (i < node.args.length) {
            var arg: ASTNode = node.args[i];
            if (arg.kind == "NamedArg") {
                if (arg.value == name) {
                    return arg.left;
                };
            };
            i = i + 1;
        };
        return null;
    };

    // --------------------------------------------------------
    // emitCall — generic call emitter
    // --------------------------------------------------------

    function emitCall(ret_type: str, func_name: str, args: str[]) -> str {
        var arg_str: str = "";
        var i: int = 0;
        while (i < args.length) {
            if (i > 0) { arg_str = arg_str + ", "; };
            var r: str = this.exprReg(args[i]);
            var t: str = this.exprType(args[i]);
            arg_str = arg_str + t + " " + r;
            i = i + 1;
        };
        var tmp: str = this.freshTemp();
        if (ret_type == "void") {
            this.emit("  call void @" + func_name + "(" + arg_str + ")");
            return this.exprResult("void", "void");
        };
        this.emit("  " + tmp + " = call " + ret_type + " @" + func_name + "(" + arg_str + ")");
        return this.exprResult(tmp, ret_type);
    };

    // --------------------------------------------------------
    // String method calls
    // --------------------------------------------------------

    function genStrMethodCall(s_reg: str, member: str, node: ASTNode) -> str {
        var tmp: str = this.freshTemp();

        if (member == "charAt") {
            var idx_result: str = this.genExpr(node.args[0]);
            var idx_reg:    str = this.exprReg(idx_result);
            this.emit("  " + tmp + " = call i8* @mocha_str_charat(i8* " + s_reg + ", i32 " + idx_reg + ")");
            return this.exprResult(tmp, "i8*");
        };

        if (member == "toInt") {
            this.emit("  " + tmp + " = call i32 @mocha_str_to_int(i8* " + s_reg + ")");
            return this.exprResult(tmp, "i32");
        };

        if (member == "toFloat") {
            this.emit("  " + tmp + " = call double @mocha_str_to_float(i8* " + s_reg + ")");
            return this.exprResult(tmp, "double");
        };

        if (member == "toVast") {
            this.emit("  " + tmp + " = call i64 @mocha_str_to_vast(i8* " + s_reg + ")");
            return this.exprResult(tmp, "i64");
        };

        if (member == "length") {
            this.emit("  " + tmp + " = call i32 @mocha_str_length(i8* " + s_reg + ")");
            return this.exprResult(tmp, "i32");
        };

        // Extension method fallback (mocha-string library)
        var ext_key: str = "mocha_ext_str_" + member;
        if (this.method_return_types.has(ext_key)) {
            var ret_type: str = this.method_return_types.get(ext_key);
            var arg_str:  str = "i8* " + s_reg;
            var i: int = 0;
            while (i < node.args.length) {
                var arg: ASTNode = node.args[i];
                if (arg.kind != "NamedArg") {
                    var ar: str = this.genExpr(arg);
                    arg_str = arg_str + ", " + this.exprType(ar) + " " + this.exprReg(ar);
                };
                i = i + 1;
            };
            if (ret_type == "void") {
                this.emit("  call void @" + ext_key + "(" + arg_str + ")");
                return this.exprResult("void", "void");
            };
            this.emit("  " + tmp + " = call " + ret_type + " @" + ext_key + "(" + arg_str + ")");
            return this.exprResult(tmp, ret_type);
        };

        mocha_error("MochaCodeGenError", "Unknown str method '" + member + "'");
        return this.exprResult(tmp, "i8*");
    };

    // --------------------------------------------------------
    // Array method calls
    // --------------------------------------------------------

    function genArrayMethodCall(arr_reg: str, member: str, node: ASTNode, obj_name: str) -> str {
        var tmp: str = this.freshTemp();

        if (member == "push") {
            var start_node: ASTNode = this.findNamedArg(node, "start");
            var use_start: bool = false;
            if (start_node != null) {
                if (start_node.kind == "BoolLiteral") {
                    use_start = start_node.bool_val;
                };
            };
            // find positional arg
            var val_arg: ASTNode = null;
            var i: int = 0;
            while (i < node.args.length) {
                if (node.args[i].kind != "NamedArg") {
                    val_arg = node.args[i];
                };
                i = i + 1;
            };
            if (val_arg == null) {
                mocha_error("MochaCodeGenError", "push() requires a value argument");
                return this.exprResult("void", "void");
            };
            var val_result: str = this.genExpr(val_arg);
            var val_reg:    str = this.exprReg(val_result);
            var val_type:   str = this.exprType(val_result);
            var cast:       str = this.boxValue(val_reg, val_type);
            var fn: str = "mocha_array_push";
            if (use_start) { fn = "mocha_array_push_front"; };
            this.emit("  call void @" + fn + "(%MochaArray* " + arr_reg + ", i8* " + cast + ")");
            return this.exprResult("void", "void");
        };

        if (member == "pop") {
            this.emit("  call void @mocha_array_pop(%MochaArray* " + arr_reg + ", i8* null)");
            return this.exprResult("void", "void");
        };

        if (member == "copy") {
            this.emit("  " + tmp + " = call %MochaArray* @mocha_array_copy(%MochaArray* " + arr_reg + ")");
            return this.exprResult(tmp, "%MochaArray*");
        };

        if (member == "occs") {
            var oval_result: str = this.genExpr(node.args[0]);
            var oval_reg:    str = this.exprReg(oval_result);
            var oval_type:   str = this.exprType(oval_result);
            var ocast:       str = this.boxValue(oval_reg, oval_type);
            this.emit("  " + tmp + " = call i32 @mocha_array_occs(%MochaArray* " + arr_reg + ", i8* " + ocast + ")");
            return this.exprResult(tmp, "i32");
        };

        // Extension method
        var obj_type: str = "int[]";
        if (obj_name != "") {
            if (this.local_mocha_types.has(obj_name)) {
                obj_type = this.local_mocha_types.get(obj_name);
            };
        };
        var san_key: str = "mocha_ext_" + this.sanitizeTypeName(obj_type) + "_" + member;
        if (this.method_return_types.has(san_key)) {
            var ret_type: str = this.method_return_types.get(san_key);
            var arg_str:  str = "%MochaArray* " + arr_reg;
            var j: int = 0;
            while (j < node.args.length) {
                if (node.args[j].kind != "NamedArg") {
                    var ar: str = this.genExpr(node.args[j]);
                    arg_str = arg_str + ", " + this.exprType(ar) + " " + this.exprReg(ar);
                };
                j = j + 1;
            };
            if (ret_type == "void") {
                this.emit("  call void @" + san_key + "(" + arg_str + ")");
                return this.exprResult("void", "void");
            };
            this.emit("  " + tmp + " = call " + ret_type + " @" + san_key + "(" + arg_str + ")");
            return this.exprResult(tmp, ret_type);
        };

        mocha_error("MochaCodeGenError", "Unknown array method '" + member + "' on '" + obj_type + "'");
        return this.exprResult("void", "void");
    };

    // --------------------------------------------------------
    // HashTable method calls
    // --------------------------------------------------------

    function genHashTableMethodCall(ht_reg: str, member: str, node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        var args: str[] = this.collectArgs(node);

        if (member == "put") {
            var key_reg: str = this.exprReg(args[0]);
            var val_reg: str = this.exprReg(args[1]);
            var val_type: str = this.exprType(args[1]);
            var cast: str = this.boxValue(val_reg, val_type);
            this.emit("  call void @mocha_ht_put(%struct.MochaHashTable* " + ht_reg + ", i8* " + key_reg + ", i8* " + cast + ")");
            return this.exprResult("void", "void");
        };
        if (member == "get") {
            var gkey: str = this.exprReg(args[0]);
            this.emit("  " + tmp + " = call i8* @mocha_ht_get(%struct.MochaHashTable* " + ht_reg + ", i8* " + gkey + ")");
            return this.exprResult(tmp, "i8*");
        };
        if (member == "has") {
            var hkey: str = this.exprReg(args[0]);
            this.emit("  " + tmp + " = call i8 @mocha_ht_has(%struct.MochaHashTable* " + ht_reg + ", i8* " + hkey + ")");
            return this.exprResult(tmp, "i8");
        };
        if (member == "remove") {
            var rkey: str = this.exprReg(args[0]);
            this.emit("  call void @mocha_ht_remove(%struct.MochaHashTable* " + ht_reg + ", i8* " + rkey + ")");
            return this.exprResult("void", "void");
        };
        if (member == "size") {
            this.emit("  " + tmp + " = call i32 @mocha_ht_size(%struct.MochaHashTable* " + ht_reg + ")");
            return this.exprResult(tmp, "i32");
        };
        if (member == "clear") {
            this.emit("  call void @mocha_ht_clear(%struct.MochaHashTable* " + ht_reg + ")");
            return this.exprResult("void", "void");
        };
        if (member == "keys") {
            this.emit("  " + tmp + " = call %MochaArray* @mocha_ht_keys(%struct.MochaHashTable* " + ht_reg + ")");
            return this.exprResult(tmp, "%MochaArray*");
        };
        if (member == "values") {
            this.emit("  " + tmp + " = call %MochaArray* @mocha_ht_values(%struct.MochaHashTable* " + ht_reg + ")");
            return this.exprResult(tmp, "%MochaArray*");
        };
        if (member == "free") {
            this.emit("  call void @mocha_ht_free(%struct.MochaHashTable* " + ht_reg + ")");
            return this.exprResult("void", "void");
        };

        mocha_error("MochaCodeGenError", "Unknown HashTable method '" + member + "'");
        return this.exprResult("void", "void");
    };

    // --------------------------------------------------------
    // Struct method dispatch (user classes)
    // --------------------------------------------------------

    function genStructMethodCall(obj_reg: str, obj_type: str, member: str, node: ASTNode) -> str {
        var class_name: str = this.inferClassName(obj_type);
        var mangled:    str = class_name + "_" + member;
        var ret_type:   str = "i32";
        if (this.method_return_types.has(mangled)) {
            ret_type = this.method_return_types.get(mangled);
        };
        var args: str[] = this.collectArgs(node);
        var arg_str: str = obj_type + " " + obj_reg;
        var i: int = 0;
        while (i < args.length) {
            arg_str = arg_str + ", " + this.exprType(args[i]) + " " + this.exprReg(args[i]);
            i = i + 1;
        };
        var tmp: str = this.freshTemp();
        if (ret_type == "void") {
            this.emit("  call void @" + mangled + "(" + arg_str + ")");
            return this.exprResult("void", "void");
        };
        this.emit("  " + tmp + " = call " + ret_type + " @" + mangled + "(" + arg_str + ")");
        return this.exprResult(tmp, ret_type);
    };

    // --------------------------------------------------------
    // sanitizeTypeName — "int[]" -> "int_arr" etc.
    // --------------------------------------------------------

    function sanitizeTypeName(t: str) -> str {
        var result: str = "";
        var i: int = 0;
        while (i < t.length) {
            var ch: str = t.charAt(i);
            if (ch == "[" || ch == "]" || ch == "<" || ch == ">") {
                result = result + "_";
            } else if (ch == ",") {
                result = result + "_";
            } else if (ch == " ") {
                // skip
            } else {
                result = result + ch;
            };
            i = i + 1;
        };
        return result;
    };

    // --------------------------------------------------------
    // genMemberCall — dispatch method calls on objects
    // --------------------------------------------------------

    function genMemberCall(node: ASTNode) -> str {
        var obj:    ASTNode = node.left.left;
        var member: str     = node.left.value;

        // Evaluate object
        var obj_result: str = this.genExpr(obj);
        var obj_reg:    str = this.exprReg(obj_result);
        var obj_type:   str = this.exprType(obj_result);

        // Array methods
        if (obj_type == "%MochaArray*") {
            var obj_name: str = "";
            if (obj.kind == "Identifier") { obj_name = obj.value; };
            return this.genArrayMethodCall(obj_reg, member, node, obj_name);
        };

        // String methods
        if (obj_type == "i8*") {
            return this.genStrMethodCall(obj_reg, member, node);
        };

        // HashTable methods
        if (obj_type == "%struct.MochaHashTable*") {
            return this.genHashTableMethodCall(obj_reg, member, node);
        };

        // StringBuilder methods
        if (obj_type == "%struct.MochaStringBuilder*") {
            var sb_mangled: str = "StringBuilder_" + member;
            var sb_ret: str = "void";
            if (this.method_return_types.has(sb_mangled)) {
                sb_ret = this.method_return_types.get(sb_mangled);
            };
            var sb_args: str[] = this.collectArgs(node);
            var sb_arg_str: str = "%struct.MochaStringBuilder* " + obj_reg;
            var si: int = 0;
            while (si < sb_args.length) {
                sb_arg_str = sb_arg_str + ", " + this.exprType(sb_args[si]) + " " + this.exprReg(sb_args[si]);
                si = si + 1;
            };
            var sb_tmp: str = this.freshTemp();
            var sb_cfunc: str = "mocha_sb_" + member;
            if (sb_ret == "void") {
                this.emit("  call void @" + sb_cfunc + "(" + sb_arg_str + ")");
                return this.exprResult("void", "void");
            };
            this.emit("  " + sb_tmp + " = call " + sb_ret + " @" + sb_cfunc + "(" + sb_arg_str + ")");
            return this.exprResult(sb_tmp, sb_ret);
        };

        // File methods
        if (obj_type == "%struct.MochaFile*") {
            var f_tmp: str = this.freshTemp();
            var f_args: str[] = this.collectArgs(node);
            var f_arg_str: str = "%struct.MochaFile* " + obj_reg;
            var fi: int = 0;
            while (fi < f_args.length) {
                f_arg_str = f_arg_str + ", " + this.exprType(f_args[fi]) + " " + this.exprReg(f_args[fi]);
                fi = fi + 1;
            };
            var f_cfunc: str = "";
            if (member == "read")     { f_cfunc = "mocha_file_read"; };
            if (member == "readLine") { f_cfunc = "mocha_file_readline"; };
            if (member == "write")    { f_cfunc = "mocha_file_write"; };
            if (member == "close")    { f_cfunc = "mocha_file_close"; };
            if (f_cfunc == "") {
                mocha_error("MochaCodeGenError", "Unknown File method '" + member + "'");
                return this.exprResult("void", "void");
            };
            var f_ret: str = "void";
            if (member == "read" || member == "readLine") { f_ret = "i8*"; };
            if (f_ret == "void") {
                this.emit("  call void @" + f_cfunc + "(" + f_arg_str + ")");
                return this.exprResult("void", "void");
            };
            this.emit("  " + f_tmp + " = call " + f_ret + " @" + f_cfunc + "(" + f_arg_str + ")");
            return this.exprResult(f_tmp, f_ret);
        };

        // Complex methods
        if (obj_type == "%struct.MochaComplex*") {
            return this.genStructMethodCall(obj_reg, obj_type, member, node);
        };

        // User class methods
        if (obj_type.length >= 8) {
            if (obj_type.substring(0, 7) == "%struct") {
                return this.genStructMethodCall(obj_reg, obj_type, member, node);
            };
        };

        mocha_error("MochaCodeGenError", "Cannot call method '" + member + "' on type '" + obj_type + "'");
        return this.exprResult("void", "void");
    };

    // --------------------------------------------------------
    // genPrint
    // --------------------------------------------------------

    function genPrint(node: ASTNode) -> str {
        var new_line: int = 0;
        var nl_node: ASTNode = this.findNamedArg(node, "newLine");
        if (nl_node != null) {
            if (nl_node.kind == "BoolLiteral") {
                if (nl_node.bool_val) { new_line = 1; };
            };
        };

        var positional: ASTNode[] = [];
        var i: int = 0;
        while (i < node.args.length) {
            if (node.args[i].kind != "NamedArg") {
                positional.push(node.args[i]);
            };
            i = i + 1;
        };

        if (positional.length == 0) {
            return this.exprResult("void", "void");
        };

        var j: int = 0;
        while (j < positional.length) {
            var is_last: bool = j == positional.length - 1;
            var nl: int = 0;
            if (is_last) { nl = new_line; };

            var val_result: str = this.genExpr(positional[j]);
            var val_reg:    str = this.exprReg(val_result);
            var val_type:   str = this.exprType(val_result);

            if (val_type == "i8*") {
                this.emit("  call void @mocha_print_str(i8* " + val_reg + ", i8 " + str(nl) + ")");
            } else if (val_type == "double") {
                this.emit("  call void @mocha_print_float(double " + val_reg + ", i8 " + str(nl) + ")");
            } else if (val_type == "i8") {
                this.emit("  call void @mocha_print_bool(i8 " + val_reg + ", i8 " + str(nl) + ")");
            } else if (val_type == "i1") {
                var w: str = this.freshTemp();
                this.emit("  " + w + " = zext i1 " + val_reg + " to i8");
                this.emit("  call void @mocha_print_bool(i8 " + w + ", i8 " + str(nl) + ")");
            } else if (val_type == "i64") {
                this.emit("  call void @mocha_print_vast(i64 " + val_reg + ", i8 " + str(nl) + ")");
            } else {
                this.emit("  call void @mocha_print_int(i32 " + val_reg + ", i8 " + str(nl) + ")");
            };

            j = j + 1;
        };
        return this.exprResult("void", "void");
    };

    // --------------------------------------------------------
    // genDirectCall — plain function calls
    // --------------------------------------------------------

    function genDirectCall(node: ASTNode) -> str {
        var func_name: str = node.left.value;
        var tmp:       str = this.freshTemp();

        // Built-in: print
        if (func_name == "print") {
            return this.genPrint(node);
        };

        // Built-in: puts
        if (func_name == "puts") {
            var args: str[] = this.collectArgs(node);
            if (args.length > 0) {
                var s: str = this.exprReg(args[0]);
                this.emit("  call i32 @puts(i8* " + s + ")");
            };
            return this.exprResult("void", "void");
        };

        // Built-in: str()
        if (func_name == "str") {
            var sargs: str[] = this.collectArgs(node);
            var sreg:  str = this.exprReg(sargs[0]);
            var styp:  str = this.exprType(sargs[0]);
            if (styp == "i32") {
                this.emit("  " + tmp + " = call i8* @mocha_int_to_str(i32 " + sreg + ")");
            } else if (styp == "double") {
                this.emit("  " + tmp + " = call i8* @mocha_float_to_str(double " + sreg + ")");
            } else if (styp == "i64") {
                this.emit("  " + tmp + " = call i8* @mocha_vast_to_str(i64 " + sreg + ")");
            } else if (styp == "i8") {
                this.emit("  " + tmp + " = call i8* @mocha_int_to_str(i32 " + sreg + ")");
            } else {
                tmp = sreg; // already a string
            };
            return this.exprResult(tmp, "i8*");
        };

        // Built-in: int()
        if (func_name == "int") {
            var iargs: str[] = this.collectArgs(node);
            var ireg:  str = this.exprReg(iargs[0]);
            var ityp:  str = this.exprType(iargs[0]);
            if (ityp == "double") {
                this.emit("  " + tmp + " = fptosi double " + ireg + " to i32");
            } else if (ityp == "i8*") {
                this.emit("  " + tmp + " = call i32 @mocha_str_to_int(i8* " + ireg + ")");
            } else {
                this.emit("  " + tmp + " = add i32 0, " + ireg);
            };
            return this.exprResult(tmp, "i32");
        };

        // Built-in: float()
        if (func_name == "float") {
            var fargs: str[] = this.collectArgs(node);
            var freg:  str = this.exprReg(fargs[0]);
            var ftyp:  str = this.exprType(fargs[0]);
            if (ftyp == "i32") {
                this.emit("  " + tmp + " = sitofp i32 " + freg + " to double");
            } else if (ftyp == "i8*") {
                this.emit("  " + tmp + " = call double @mocha_str_to_float(i8* " + freg + ")");
            } else {
                this.emit("  " + tmp + " = fadd double 0.0, " + freg);
            };
            return this.exprResult(tmp, "double");
        };

        // Built-in: tell
        if (func_name == "tell") {
            var targs: str[] = this.collectArgs(node);
            if (targs.length > 0) {
                this.emit("  " + tmp + " = call i8* @mocha_tell(i8* " + this.exprReg(targs[0]) + ")");
            } else {
                this.emit("  " + tmp + " = call i8* @mocha_tell(i8* null)");
            };
            return this.exprResult(tmp, "i8*");
        };

        // Built-in: open
        if (func_name == "open") {
            var oargs: str[] = this.collectArgs(node);
            var path_reg: str = this.exprReg(oargs[0]);
            var mode_reg: str = this.exprReg(oargs[1]);
            this.emit("  " + tmp + " = call %struct.MochaFile* @mocha_file_open(i8* " + path_reg + ", i8* " + mode_reg + ")");
            return this.exprResult(tmp, "%struct.MochaFile*");
        };

        // Built-in: exists
        if (func_name == "exists") {
            var eargs: str[] = this.collectArgs(node);
            this.emit("  " + tmp + " = call i8 @mocha_file_exists(i8* " + this.exprReg(eargs[0]) + ")");
            return this.exprResult(tmp, "i8");
        };

        // Built-in: exit_program
        if (func_name == "exit_program") {
            var xargs: str[] = this.collectArgs(node);
            var xreg: str = this.exprReg(xargs[0]);
            this.emit("  call void @mocha_exit(i32 " + xreg + ")");
            this.emit("  unreachable");
            return this.exprResult("void", "void");
        };

        // Built-in constructors
        if (func_name == "HashTable") {
            this.emit("  " + tmp + " = call %struct.MochaHashTable* @mocha_ht_new()");
            return this.exprResult(tmp, "%struct.MochaHashTable*");
        };
        if (func_name == "StringBuilder") {
            this.emit("  " + tmp + " = call %struct.MochaStringBuilder* @mocha_sb_new()");
            return this.exprResult(tmp, "%struct.MochaStringBuilder*");
        };
        if (func_name == "Complex") {
            var cargs: str[] = this.collectArgs(node);
            var creal: str = this.exprReg(cargs[0]);
            var cimag: str = this.exprReg(cargs[1]);
            var crtype: str = this.exprType(cargs[0]);
            var citype: str = this.exprType(cargs[1]);
            if (crtype == "i32") {
                var cp1: str = this.freshTemp();
                this.emit("  " + cp1 + " = sitofp i32 " + creal + " to double");
                creal = cp1;
            };
            if (citype == "i32") {
                var cp2: str = this.freshTemp();
                this.emit("  " + cp2 + " = sitofp i32 " + cimag + " to double");
                cimag = cp2;
            };
            this.emit("  " + tmp + " = call %struct.MochaComplex* @mocha_complex_new(double " + creal + ", double " + cimag + ")");
            return this.exprResult(tmp, "%struct.MochaComplex*");
        };

        // User constructor — func_name starts with uppercase
        if (func_name.charAt(0) != func_name.toLower().charAt(0)) {
            var struct_ptr_type: str = "%struct." + func_name + "*";
            var raw:  str = this.freshTemp();
            var obj:  str = this.freshTemp();
            var size: str = this.freshTemp();
            this.emit("  " + size + " = add i64 0, 1024");
            this.emit("  " + raw + " = call i8* @malloc(i64 " + size + ")");
            this.emit("  call void @llvm.memset.p0i8.i64(i8* " + raw + ", i8 0, i64 1024, i1 false)");
            this.emit("  " + obj + " = bitcast i8* " + raw + " to " + struct_ptr_type);

            var has_ctor: bool = false;
            var ci: int = 0;
            while (ci < this.classes_with_ctors.length) {
                if (this.classes_with_ctors[ci] == func_name) { has_ctor = true; };
                ci = ci + 1;
            };

            if (has_ctor) {
                var ctor_args: str[] = this.collectArgs(node);
                var ctor_arg_str: str = struct_ptr_type + " " + obj;
                var ai: int = 0;
                while (ai < ctor_args.length) {
                    ctor_arg_str = ctor_arg_str + ", " + this.exprType(ctor_args[ai]) + " " + this.exprReg(ctor_args[ai]);
                    ai = ai + 1;
                };
                this.emit("  call void @" + func_name + "_constructor(" + ctor_arg_str + ")");
            };

            return this.exprResult(obj, struct_ptr_type);
        };

        // Lib function
        if (this.lib_functions.has(func_name)) {
            var lf_encoded: str = this.lib_functions.get(func_name);
            // encoded as "c_name|ret_type"
            var lf_cname: str = this.fieldName(lf_encoded);
            var lf_ret:   str = this.fieldType(lf_encoded);
            var lf_args:  str[] = this.collectArgs(node);
            var lf_arg_str: str = "";
            var lfi: int = 0;
            while (lfi < lf_args.length) {
                if (lfi > 0) { lf_arg_str = lf_arg_str + ", "; };
                lf_arg_str = lf_arg_str + this.exprType(lf_args[lfi]) + " " + this.exprReg(lf_args[lfi]);
                lfi = lfi + 1;
            };
            if (lf_ret == "void") {
                this.emit("  call void @" + lf_cname + "(" + lf_arg_str + ")");
                return this.exprResult("void", "void");
            };
            this.emit("  " + tmp + " = call " + lf_ret + " @" + lf_cname + "(" + lf_arg_str + ")");
            return this.exprResult(tmp, lf_ret);
        };

        // Normal function call
        var nargs: str[] = this.collectArgs(node);
        var narg_str: str = "";
        var ni: int = 0;
        while (ni < nargs.length) {
            if (ni > 0) { narg_str = narg_str + ", "; };
            narg_str = narg_str + this.exprType(nargs[ni]) + " " + this.exprReg(nargs[ni]);
            ni = ni + 1;
        };

        var ret_type: str = "i32";
        if (this.method_return_types.has(func_name)) {
            ret_type = this.method_return_types.get(func_name);
        } else if (this.current_class != "") {
            var mangled: str = this.current_class + "_" + func_name;
            if (this.method_return_types.has(mangled)) {
                ret_type  = this.method_return_types.get(mangled);
                func_name = mangled;
            };
        };

        if (ret_type == "void") {
            this.emit("  call void @" + func_name + "(" + narg_str + ")");
            return this.exprResult("void", "void");
        };
        this.emit("  " + tmp + " = call " + ret_type + " @" + func_name + "(" + narg_str + ")");
        return this.exprResult(tmp, ret_type);
    };
};