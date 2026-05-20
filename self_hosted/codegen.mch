// mocha-lib-deps: mocha-string
// ============================================================
// codegen.mch — Main CodeGen entry point
// ============================================================

from "./typechecker.mch" import *;
from "./codegen_utils.mch" import *;
from "./codegen_expr.mch" import *;
from "./codegen_calls.mch" import *;
from "./codegen_stmt.mch" import *;
from "./codegen_decl.mch" import *;

extend CodeGen {

    // --------------------------------------------------------
    // get_ir — assemble final IR string
    // --------------------------------------------------------

    function getIR() -> str {
        var result: str = "";
        var i: int = 0;
        while (i < this.output.length) {
            result = result + this.output[i] + "\n";
            i = i + 1;
        };
        return result;
    };

    // --------------------------------------------------------
    // generate — main entry point
    // --------------------------------------------------------

    function generate(program: ASTNode) -> str {
        var entry_func_name:   str      = "";
        var entry_func_params: ASTNode[] = [];

        print(program.children.length, newLine=true);

        // ====================================================
        // PRE-PASS: register tag types
        // ====================================================
        var ti: int = 0;
        while (ti < program.children.length) {
            var node: ASTNode = program.children[ti];
            if (node.kind == "TagDecl") {
                this.tag_types.push(node.value);
            };
            ti = ti + 1;
        };

        // Collect class nodes for inheritance lookup
        var ci: int = 0;
        while (ci < program.children.length) {
            var node: ASTNode = program.children[ci];
            if (node.kind == "ClassDecl") {
                this.class_node_list.push(node);
                this.class_node_index.put(node.value, str(this.class_node_list.length - 1));
            };
            ci = ci + 1;
        };

        // Register all native functions first
        var ni: int = 0;
        while (ni < program.children.length) {
            var node: ASTNode = program.children[ni];
            if (node.kind == "FunctionDecl") {
                if (node.flag2) {
                    var ret_llvm: str = this.toLLVMType(node.type_str);
                    var param_str: str = "";
                    var pi: int = 0;
                    while (pi < node.params.length) {
                        var p: ASTNode = node.params[pi];
                        if (p.value == "didLoad") { pi = pi + 1; continue; };
                        if (param_str != "") { param_str = param_str + ", "; };
                        param_str = param_str + this.toLLVMParamType(p.type_str);
                        pi = pi + 1;
                    };
                    var decl: str = "declare " + ret_llvm + " @" + node.extra + "(" + param_str + ")";
                    var already: bool = false;
                    var di: int = 0;
                    while (di < this.extra_declares.length) {
                        if (this.extra_declares[di] == decl) { already = true; };
                        di = di + 1;
                    };
                    if (already == false) {
                        this.extra_declares.push(decl);
                    };
                    this.lib_functions.put(node.value, node.extra + "|" + ret_llvm);
                    this.method_return_types.put(node.value, ret_llvm);
                    this.method_return_types.put(node.extra, ret_llvm);
                };
            };
            ni = ni + 1;
        };

        // ====================================================
        // PASS 0: Top-level globals
        // ====================================================
        var top_level_vars: ASTNode[] = [];
        var vi: int = 0;
        while (vi < program.children.length) {
            var node: ASTNode = program.children[vi];
            if (node.kind == "VarDecl" || node.kind == "ConstDecl") {
                top_level_vars.push(node);
            };
            vi = vi + 1;
        };

        if (top_level_vars.length > 0) {
            var gvi: int = 0;
            while (gvi < top_level_vars.length) {
                var gnode: ASTNode = top_level_vars[gvi];
                var mocha_t: str = gnode.type_str;
                var llvm_t:  str = this.toLLVMType(mocha_t);
                if (mocha_t.contains("[]")) {
                    this.emit("@__global_" + gnode.value + " = global %MochaArray* null");
                } else if (mocha_t == "dict") {
                    this.emit("@__global_" + gnode.value + " = global %MochaDict* null");
                } else if (llvm_t == "double") {
                    this.emit("@__global_" + gnode.value + " = global double 0.0");
                } else if (llvm_t.charAt(llvm_t.length - 1) == "*") {
                    this.emit("@__global_" + gnode.value + " = global " + llvm_t + " null");
                } else {
                    this.emit("@__global_" + gnode.value + " = global " + llvm_t + " 0");
                };
                gvi = gvi + 1;
            };
            this.emitBlank();

            // Emit globals init function
            this.emit("define void @__mocha_globals_init() {");
            this.emit("entry:");
            this.in_function = true;
            var gii: int = 0;
            while (gii < top_level_vars.length) {
                var gnode2: ASTNode = top_level_vars[gii];
                this.genVarDecl(gnode2);
                if (this.hasLocal(gnode2.value)) {
                    var lptr:  str = this.getLocalPtr(gnode2.value);
                    var ltype: str = this.getLocalType(gnode2.value);
                    var ltmp:  str = this.freshTemp();
                    this.emit("  " + ltmp + " = load " + ltype + ", " + ltype + "* " + lptr);
                    this.emit("  store " + ltype + " " + ltmp + ", " + ltype + "* @__global_" + gnode2.value);
                    this.global_ptrs.put(gnode2.value, "@__global_" + gnode2.value);
                    this.global_mocha_types.put(gnode2.value, gnode2.type_str);
                };
                gii = gii + 1;
            };
            this.emit("  ret void");
            this.emit("}");
            this.emitBlank();
            this.in_function = false;
        };

        // ====================================================
        // PASS 1: Register all function signatures
        // ====================================================
        var p1i: int = 0;
        while (p1i < program.children.length) {
            var node: ASTNode = program.children[p1i];

            if (node.kind == "FunctionDecl" || node.kind == "MethodDecl") {
                var ret_llvm: str = this.toLLVMType(node.type_str);
                this.method_return_types.put(node.value, ret_llvm);
                // check for didLoad
                var dli: int = 0;
                while (dli < node.params.length) {
                    if (node.params[dli].value == "didLoad") {
                        entry_func_name   = node.value;
                        entry_func_params = node.params;
                        this.method_return_types.put("mocha_entry_" + node.value, ret_llvm);
                    };
                    dli = dli + 1;
                };

            } else if (node.kind == "ClassDecl") {
                var cmi: int = 0;
                while (cmi < node.body.length) {
                    var member: ASTNode = node.body[cmi];
                    if (member.kind == "MethodDecl") {
                        var mret: str = this.toLLVMType(member.type_str);
                        this.method_return_types.put(node.value + "_" + member.value, mret);
                        var mdli: int = 0;
                        while (mdli < member.params.length) {
                            if (member.params[mdli].value == "didLoad") {
                                entry_func_name   = node.value + "_" + member.value;
                                entry_func_params = member.params;
                            };
                            mdli = mdli + 1;
                        };
                    };
                    cmi = cmi + 1;
                };

            } else if (node.kind == "ExtendDecl") {
                var efi: int = 0;
                while (efi < node.body.length) {
                    var efunc: ASTNode = node.body[efi];
                    var eret:  str = this.toLLVMType(efunc.type_str);
                    var ename: str = "mocha_ext_" + this.sanitizeTypeName(node.value) + "_" + efunc.value;
                    this.method_return_types.put(ename, eret);
                    efi = efi + 1;
                };
            };

            p1i = p1i + 1;
        };

        // ====================================================
        // PASS 1.5: Emit struct type definitions
        // ====================================================
        var s15i: int = 0;
        while (s15i < program.children.length) {
            var node: ASTNode = program.children[s15i];
            if (node.kind == "ClassDecl") {
                this.registerClassFields(node.value, node.body);
                var fields_enc: str = "";
                if (this.class_fields.has(node.value)) {
                    fields_enc = this.class_fields.get(node.value);
                };
                if (fields_enc == "") {
                    this.type_declarations.push("%struct." + node.value + " = type { i32 }");
                } else {
                    var flist: str[] = splitComma(fields_enc);
                    var tlist: str = "";
                    var fli: int = 0;
                    while (fli < flist.length) {
                        if (fli > 0) { tlist = tlist + ", "; };
                        tlist = tlist + this.fieldType(flist[fli]);
                        fli = fli + 1;
                    };
                    this.type_declarations.push("%struct." + node.value + " = type { " + tlist + " }");
                };
                this.type_declarations.push("");
            };
            s15i = s15i + 1;
        };

        // ====================================================
        // PASS 2: Generate function bodies
        // ====================================================
        var p2i: int = 0;
        while (p2i < program.children.length) {
            var node: ASTNode = program.children[p2i];

            if (node.kind == "FunctionDecl") {
                if (node.flag2 == false) {
                    // Check for didLoad
                    var is_entry: bool = false;
                    var edli: int = 0;
                    while (edli < node.params.length) {
                        if (node.params[edli].value == "didLoad") { is_entry = true; };
                        edli = edli + 1;
                    };
                    if (is_entry) {
                        var orig_name: str = node.value;
                        node.value = "mocha_entry_" + orig_name;
                        this.genFunction(node);
                        node.value = orig_name;
                    } else {
                        this.genFunction(node);
                    };
                };

            } else if (node.kind == "MethodDecl") {
                var is_entry2: bool = false;
                var edli2: int = 0;
                while (edli2 < node.params.length) {
                    if (node.params[edli2].value == "didLoad") { is_entry2 = true; };
                    edli2 = edli2 + 1;
                };
                if (is_entry2) {
                    var orig_name2: str = node.value;
                    node.value = "mocha_entry_" + orig_name2;
                    this.genFunction(node);
                    node.value = orig_name2;
                } else {
                    this.genFunction(node);
                };

            } else if (node.kind == "ClassDecl") {
                this.genClass(node);

            } else if (node.kind == "ExtendDecl") {
                this.genExtend(node);

            } else if (node.kind == "ConstDecl") {
                this.genConstDecl(node);

            } else if (node.kind == "TagDecl") {
                this.genTagDecl(node);
            };

            p2i = p2i + 1;
        };

        // ====================================================
        // Top-level statements
        // ====================================================
        var top_stmts: ASTNode[] = [];
        var tsi: int = 0;
        while (tsi < program.children.length) {
            var node: ASTNode = program.children[tsi];
            if (node.kind != "FunctionDecl" && node.kind != "MethodDecl" &&
                node.kind != "ClassDecl"    && node.kind != "ImportStmt"  &&
                node.kind != "InterfaceDecl"&& node.kind != "ExtendDecl"  &&
                node.kind != "VarDecl"      && node.kind != "ConstDecl"   &&
                node.kind != "TagDecl") {
                top_stmts.push(node);
            };
            tsi = tsi + 1;
        };

        if (top_stmts.length > 0) {
            this.emit("define void @mocha_main() {");
            this.emit("entry:");
            this.in_function = true;
            var tmi: int = 0;
            while (tmi < top_stmts.length) {
                this.genStmt(top_stmts[tmi]);
                tmi = tmi + 1;
            };
            if (this.lastIsTerminator() == false) {
                this.emit("  ret void");
            };
            this.emit("}");
            this.emitBlank();
            this.in_function = false;
        };

        // ====================================================
        // Emit main() entry point
        // ====================================================
        if (this.is_lib == false) {
            this.emit("define i32 @main(i32 %argc, i8** %argv) {");
            this.emit("entry:");
            this.emit("  call void @mocha_gc_init()");

            var lii: int = 0;
            while (lii < this.lib_init_calls.length) {
                this.emit("  call void @" + this.lib_init_calls[lii] + "()");
                lii = lii + 1;
            };

            if (top_level_vars.length > 0) {
                this.emit("  call void @__mocha_globals_init()");
            };

            if (entry_func_name != "") {
                var ir_func_name: str = "mocha_entry_" + entry_func_name;
                var args_str: str = "";
                var epi: int = 0;
                var arg_idx: int = 1;
                while (epi < entry_func_params.length) {
                    var ep: ASTNode = entry_func_params[epi];
                    if (ep.value == "didLoad") { epi = epi + 1; continue; };
                    var ep_llvm: str = this.toLLVMType(ep.type_str);
                    var gep:     str = this.freshTemp();
                    var raw:     str = this.freshTemp();
                    this.emit("  " + gep + " = getelementptr i8*, i8** %argv, i32 " + str(arg_idx));
                    this.emit("  " + raw + " = load i8*, i8** " + gep);
                    if (ep_llvm == "i32") {
                        var conv: str = this.freshTemp();
                        this.emit("  " + conv + " = call i32 @atoi(i8* " + raw + ")");
                        if (args_str != "") { args_str = args_str + ", "; };
                        args_str = args_str + "i32 " + conv;
                    } else if (ep_llvm == "double") {
                        var convf: str = this.freshTemp();
                        this.emit("  " + convf + " = call double @atof(i8* " + raw + ")");
                        if (args_str != "") { args_str = args_str + ", "; };
                        args_str = args_str + "double " + convf;
                    } else {
                        if (args_str != "") { args_str = args_str + ", "; };
                        args_str = args_str + "i8* " + raw;
                    };
                    arg_idx = arg_idx + 1;
                    epi = epi + 1;
                };

                var entry_ret: str = "void";
                if (this.method_return_types.has(ir_func_name)) {
                    entry_ret = this.method_return_types.get(ir_func_name);
                };
                if (entry_ret == "void") {
                    this.emit("  call void @" + ir_func_name + "(" + args_str + ")");
                } else {
                    var etmp: str = this.freshTemp();
                    this.emit("  " + etmp + " = call " + entry_ret + " @" + ir_func_name + "(" + args_str + ")");
                };
            } else if (top_stmts.length > 0) {
                this.emit("  call void @mocha_main()");
            };

            this.emit("  call void @mocha_gc_shutdown()");
            this.emit("  ret i32 0");
            this.emit("}");
        };

        // ====================================================
        // Assemble final output
        // ====================================================
        var final_output: str[] = [];

        // 1. Preamble
        var preamble_saved: str[] = this.output;
        this.output = [];
        this.emitPreamble();
        var preamble_lines: str[] = this.output;
        this.output = preamble_saved;

        // 2. String globals
        var str_saved: str[] = this.output;
        this.output = [];
        this.emitStringGlobals();
        var str_lines: str[] = this.output;
        this.output = str_saved;

        // 3. Type declarations
        // 4. Extra declares
        // 5. Main output

        var result: str = "";

        var pri: int = 0;
        while (pri < preamble_lines.length) {
            result = result + preamble_lines[pri] + "\n";
            pri = pri + 1;
        };

        var stri: int = 0;
        while (stri < str_lines.length) {
            result = result + str_lines[stri] + "\n";
            stri = stri + 1;
        };

        var tdeci: int = 0;
        while (tdeci < this.type_declarations.length) {
            result = result + this.type_declarations[tdeci] + "\n";
            tdeci = tdeci + 1;
        };

        var edeci: int = 0;
        while (edeci < this.extra_declares.length) {
            result = result + this.extra_declares[edeci] + "\n";
            edeci = edeci + 1;
        };

        result = result + "\n";

        var oi: int = 0;
        while (oi < this.output.length) {
            result = result + this.output[oi] + "\n";
            oi = oi + 1;
        };

        return result;
    };
};

// ============================================================
// compiler.mch entry point
// ============================================================

function main(didLoad, source_file: str) -> null {
    // Step 1: Read source
    var f: File = open(source_file, "read");
    var source: str = f.read();
    f.close();

    // Step 2: Lex
    var lex: Lexer = Lexer(source);
    var tokens: Token[] = lex.tokenise();

    // Step 3: Parse
    var parser: Parser = Parser(tokens);
    var ast: ASTNode = parser.parse();

    // Step 4: Type check
    var tc: TypeChecker = TypeChecker();
    tc.check(ast);

    // Step 5: Codegen
    var cg: CodeGen = CodeGen();
    var ir: str = cg.generate(ast);

    // Step 6: Write output
    var out_file: str = source_file + ".ll";
    var out: File = open(out_file, "write");
    out.write(ir);
    out.close();

    puts("Done! IR written to: " + out_file);
};