import sys, os, subprocess, shutil, io
from typing import Optional, Set
from mocha_lexer import Lexer
from mocha_parser import Parser
from mocha_typeChecker import TypeChecker
from mocha_codegen import CodeGen, MochaCodeGenError, mangle_function_name, C_STDLIB_NAMES, LLVM_TYPES, to_llvm_type
from mocha_ast import (
    FieldDecl, ImportStmt, FunctionDecl, MethodDecl, ConstDecl, 
    ExtendDecl, ReturnStmt, ClassDecl, ArrayLiteral,
    IntLiteral, FloatLiteral, BoolLiteral, StrLiteral,
    Identifier, UnaryOp
)

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

import functools
print = functools.partial(print, flush=True)

# ============================================================
# AUTO-DETECT COMPILER TOOLS
# ============================================================

def find_tool(name: str, common_paths: list) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for path in common_paths:
        if os.path.exists(path):
            return path
    return None

CLANG_PATH = find_tool("clang", [
    r"C:\Program Files\LLVM\bin\clang.exe",
    r"C:\LLVM\bin\clang.exe",
    "/usr/bin/clang",
    "/usr/local/bin/clang",
])

MINGW_GCC = find_tool("gcc", [
    r"C:\mingw64\mingw64\bin\gcc.exe",
    r"C:\mingw64\bin\gcc.exe",
    r"C:\MinGW\bin\gcc.exe",
    "/usr/bin/gcc",
    "/usr/local/bin/gcc",
])

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
RUNTIME_C   = os.path.join(SCRIPT_DIR, "mocha_runtime.c")
RUNTIME_OBJ = os.path.join(SCRIPT_DIR, "mocha_runtime.o")
LIB_DIR     = os.path.join(SCRIPT_DIR, "lib")
SQLITE3_C   = os.path.join(SCRIPT_DIR, "sqlite-amalgamation-3510300", "sqlite3.c")
SQLITE3_OBJ = os.path.join(SCRIPT_DIR, "sqlite-amalgamation-3510300", "sqlite3.o")
CPP_FILE    = os.path.join(SCRIPT_DIR, "hello_cpp.cpp")
CPP_OBJ     = os.path.join(SCRIPT_DIR, "hello_cpp.o")
LUA_DIR     = os.path.join(SCRIPT_DIR, "lua-5.5.0_Win64_dllw6_lib")
LUA_LIB     = os.path.join(LUA_DIR, "liblua55.a")
LUA_INCLUDE = os.path.join(LUA_DIR, "include")
RUST_LIB    = os.path.join(SCRIPT_DIR, "rust_ffi.a")
ZIG_LIB  = os.path.join(SCRIPT_DIR, "zig_ffi.lib")
ZIG_PATH = os.path.join(SCRIPT_DIR, "zig-x86_64-windows-0.17.0-dev.313+27be3b069", "zig.exe")
WREN_DIR     = os.path.join(SCRIPT_DIR, "wren")
WREN_C       = os.path.join(SCRIPT_DIR, "build", "wren.c")
WREN_OBJ     = os.path.join(SCRIPT_DIR, "build", "wren.o")
WREN_INCLUDE = os.path.join(WREN_DIR, "include")

if not CLANG_PATH:
    print("❌ clang not found! Please install LLVM from https://llvm.org/releases/")
    sys.exit(1)

if not MINGW_GCC:
    print("❌ gcc not found! Please install MinGW from https://www.mingw-w64.org/")
    sys.exit(1)

assert CLANG_PATH is not None
assert MINGW_GCC is not None

# ============================================================
# CODE SIGNING
# ============================================================

def sign_executable(exe_path: str) -> str:
    sign_cmd = [
        "powershell", "-Command",
        f'$cert = Get-ChildItem Cert:\\LocalMachine\\My | Where-Object Subject -eq "CN=MochaLang" | Select-Object -First 1; '
        f'if (!$cert) {{ Write-Output "no_cert" }} '
        f'elseif ($cert.NotAfter -lt (Get-Date)) {{ Write-Output "expired" }} '
        f'else {{ Set-AuthenticodeSignature -FilePath "{exe_path}" -Certificate $cert | Out-Null; Write-Output "signed" }}'
    ]
    result = subprocess.run(sign_cmd, capture_output=True, text=True, encoding='utf-8')
    return result.stdout.strip()

# ============================================================
# MANIFEST HELPERS
# ============================================================

# ============================================================
# load_lib_manifest
#
# Twin of register_lib_in_codegen but for the TYPE CHECKER
# instead of CodeGen. Reads a .mchi and declares everything
# into the TC's symbol table so type checking passes before
# codegen even runs.
#
# PARAMS:
#   alias  — import alias, registers as alias.fn if set
#   seen   — circular dep guard, always pass None from outside
#
# HANDLES FOUR LINE TYPES:
#   // mocha-lib-deps: → recursively load deps first
#   function           → declare return type in TC symbols
#   const              → declare as const in TC symbols  
#   extend type_name   → declare as "type_name.func" in TC symbols
#                        so e.g. float[].mean() type-checks correctly
#   class              → declare class name as a type in TC symbols
#
# NOTE: All declares are wrapped in try/except — if a symbol
#   is already declared (e.g. dep loaded twice via different
#   paths), silently skip rather than throw a redeclaration error
# ============================================================
def load_lib_manifest(lib_name: str, lib_dir: str, type_checker: TypeChecker, alias, seen: Optional[Set] = None):
    if seen is None:
        seen = set() #Set because only one value allowed
    if lib_name in seen:
        return  # ← circular dependency protection
    seen.add(lib_name)
    
    mchi_path = os.path.join(lib_dir, f"{lib_name}.mchi")
    if not os.path.exists(mchi_path):
        print(f"  ⚠️  No manifest (.mchi) found for '{lib_name}' at {mchi_path}")
        return

    with open(mchi_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()

        # Check deps before skipping comments
        if line.startswith("// mocha-lib-deps:"):
            deps_str = line.replace("// mocha-lib-deps:", "").strip()
            dep_libs = [d.strip() for d in deps_str.split(",")]
            for dep in dep_libs:
                load_lib_manifest(dep, lib_dir, type_checker, None, seen)
            continue

        if not line or line.startswith("//"):
            continue

        if line.startswith("function "):
            after_func = line[len("function "):]
            func_name  = after_func[:after_func.index("(")].strip()
            ret_part   = after_func.split("->")[1].strip().rstrip(";").strip()
            if " native " in ret_part:
                ret_type = ret_part.split(" native ")[0].strip()
            else:
                ret_type = ret_part
            key = f"{alias}.{func_name}" if alias else func_name
            try:
                type_checker.symbols.declare(key, ret_type, is_function=True)
            except Exception:
                pass

        elif line.startswith("const "):
            after_const = line[len("const "):]
            const_name  = after_const[:after_const.index(":")].strip()
            type_part   = after_const.split(":")[1].strip()
            const_type  = type_part.split("=")[0].strip().rstrip(";").strip()
            key = f"{alias}.{const_name}" if alias else const_name
            try:
                type_checker.symbols.declare(key, const_type, is_const=True)
            except Exception:
                pass

        elif line.startswith("extend "):
            parts = line.split()
            type_name  = parts[1]
            after_func = line[line.index("function ") + len("function "):]
            func_name  = after_func[:after_func.index("(")].strip()
            ret_part   = after_func.split("->")[1].strip().rstrip(";").strip()
            if " native " in ret_part:
                ret_type = ret_part.split(" native ")[0].strip()
            else:
                ret_type = ret_part
            key = f"{type_name}.{func_name}"
            try:
                type_checker.symbols.declare(key, ret_type, is_function=True)
            except Exception:
                pass

        elif line.startswith("class ") and line.endswith(";") and " field " not in line and " function " not in line:
            class_name = line[6:-1].strip()
            try:
                type_checker.symbols.declare(class_name, class_name, is_class=True)
            except Exception:
                pass
            
        elif line.startswith("class ") and " field " in line and " function " not in line:
            parts = line.split(" field ")
            class_name = parts[0][6:].strip()
            field_parts = parts[1].rstrip(";").split(":")
            field_name = field_parts[0].strip()
            field_type = field_parts[1].strip()
            key = f"{class_name}.{field_name}"
            try:
                type_checker.symbols.declare(key, field_type)
            except Exception:
                pass

# ============================================================
# register_lib_in_codegen
#
# Reads a .mchi (Mocha lib interface file, like a C header)
# and registers its contents into the CodeGen object so the
# compiler knows about the lib when generating LLVM IR.
#
# Has a type map and parse_llvm nested function 
#
# PARAMS:
#   lib_name  — e.g. "mocha-stats"
#   alias     — import alias, registers under both alias.fn AND fn
#   is_native — skips global init registration if True
#   seen      — circular dep guard, always pass None from outside
#
# HANDLES FOUR LINE TYPES IN .mchi:
#   // mocha-lib-deps:  → recursively register deps first
#   function            → register in lib_functions + emit declare
#   const               → register in lib_constants
#   extend              → register extension method + emit declare
#   class ... function  → register class method + emit declare
#                         (added for clang — without it, calls to
#                          lib class methods produce unknown symbol errors)
#
# FINALLY: if lib has top-level globals, registers its
#   __mocha_globals_init_* so main() calls it at startup
# ============================================================
def register_lib_in_codegen(lib_name: str, lib_dir: str, codegen: CodeGen, alias, is_native: bool = False, seen: Optional[Set]=None):
    if seen is None:
        seen = set()
    if lib_name in seen:
        return
    seen.add(lib_name)
    mchi_path = os.path.join(lib_dir, f"{lib_name}.mchi")
    if not os.path.exists(mchi_path):
        return

    with open(mchi_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    type_map = {
        "int":   "i32",
        "vast":  "i64",
        "float": "double",
        "str":   "i8*",
        "bool":  "i8",
        "null":  "void",
        "Complex":       "%struct.MochaComplex*",
        "StringBuilder": "%struct.MochaStringBuilder*",
        "File": "%struct.MochaFile*",
        "HashTable": "%struct.MochaHashTable*",
    }

    def parse_llvm_type(ptype, is_param=False):
        if is_param and ptype == "null":
            return "i8*"
        if ptype.startswith("("):
            return "%MochaTuple*"
        if "[][]" in ptype:
            return "%MochaArray2D*"
        if "[]" in ptype or ("[" in ptype and "]" in ptype):
            return "%MochaArray*"
        if ptype == "dict":
            return "%MochaDict*"
        if ptype.startswith("set<"):
            return "%MochaSet*"
        if ptype == "lambda":
            return "i8*"
        return type_map.get(ptype, "i8*")

    for line in lines:
        line = line.strip()

        # MUST check deps before skipping comments
        if line.startswith("// mocha-lib-deps:"):
            deps_str = line.replace("// mocha-lib-deps:", "").strip()
            dep_libs = [d.strip() for d in deps_str.split(",")]
            for dep in dep_libs:
                register_lib_in_codegen(dep, lib_dir, codegen, None, False, seen)
            continue

        if not line or line.startswith("//"): continue

        if line.startswith("function "):
            after_func = line[len("function "):]
            func_name  = after_func[:after_func.index("(")].strip()

            if " native " in line:
                c_name      = line.split(" native ")[1].strip().rstrip(";")
                actual_name = c_name
            else:
                actual_name = mangle_function_name(func_name)

            ret_part = after_func.split("->")[1].strip().rstrip(";").strip()
            if " native " in ret_part:
                ret_type = ret_part.split(" native ")[0].strip()
            else:
                ret_type = ret_part

            llvm_ret    = parse_llvm_type(ret_type)
            params_str  = after_func[after_func.index("(")+1:after_func.index(")")].strip()
            llvm_params = []
            param_names = []
            if params_str:
                for param in params_str.split(","):
                    param = param.strip()
                    if ":" in param:
                        pname = param.split(":")[0].strip()
                        ptype = param.split(":")[1].strip()
                        llvm_params.append(parse_llvm_type(ptype, is_param=True))
                        param_names.append(pname)

            if alias:
                codegen.lib_functions[f"{alias}.{func_name}"] = (actual_name, llvm_ret, llvm_params, param_names)
                codegen.lib_functions[func_name] = (actual_name, llvm_ret, llvm_params, param_names)
            else:
                codegen.lib_functions[func_name] = (actual_name, llvm_ret, llvm_params, param_names)
                codegen.lib_functions[f"{lib_name}.{func_name}"] = (actual_name, llvm_ret, llvm_params, param_names)

            # Name mangling: eclare the function so codegen uses it instead of C stdlib
            param_str = ", ".join(llvm_params)
            declare_str = f"declare {llvm_ret} @{actual_name}({param_str})"
            if declare_str not in codegen.extra_declares:
                codegen.extra_declares.append(declare_str)

            codegen.method_return_types[func_name]   = llvm_ret
            codegen.method_return_types[actual_name] = llvm_ret

        elif line.startswith("const "):
            after      = line[len("const "):]
            const_name = after[:after.index(":")].strip()
            rest       = after.split("=")
            const_val  = rest[1].strip().rstrip(";") if len(rest) > 1 else "0.0"
            const_type = after.split(":")[1].split("=")[0].strip()
            llvm_type  = type_map.get(const_type, "double")

            if alias:
                codegen.lib_constants[f"{alias}.{const_name}"] = (const_val, llvm_type)
            else:
                codegen.lib_constants[const_name] = (const_val, llvm_type)
                codegen.lib_constants[f"{lib_name}.{const_name}"] = (const_val, llvm_type)

        elif line.startswith("extend "):
            parts      = line.split()
            type_name  = parts[1]
            after_func = line[line.index("function ") + len("function "):]
            func_name  = after_func[:after_func.index("(")].strip()
            ret_part   = after_func.split("->")[1].strip().rstrip(";").strip()

            # sanitize type_name for LLVM — [] is invalid in identifiers
            sanitized_type = type_name.replace("[]", "_arr").replace("[", "_").replace("]", "")

            if " native " in ret_part:
                c_func_name = ret_part.split(" native ")[1].strip()   # native name unchanged!
                ret_type    = ret_part.split(" native ")[0].strip()
            else:
                c_func_name = f"mocha_ext_{sanitized_type}_{func_name}"  # sanitized
                ret_type    = ret_part

            llvm_ret = parse_llvm_type(ret_type)

            # register under BOTH raw and sanitized keys so lookups work
            codegen.method_return_types[c_func_name] = llvm_ret
            codegen.method_return_types[f"mocha_ext_{sanitized_type}_{func_name}"] = llvm_ret
            codegen.method_return_types[f"mocha_ext_{type_name}_{func_name}"] = llvm_ret
            codegen.ext_native_names[f"mocha_ext_{type_name}_{func_name}"]    = c_func_name
            codegen.ext_native_names[f"mocha_ext_{sanitized_type}_{func_name}"] = c_func_name

            params_str  = after_func[after_func.index("(")+1:after_func.index(")")].strip()

            # this param uses the actual LLVM struct type based on dimensions
            if "[][]" in type_name:
                this_llvm = "%MochaArray2D*"
            elif "[]" in type_name:
                this_llvm = "%MochaArray*"
            else:
                this_llvm = parse_llvm_type(type_name)

            llvm_params = [this_llvm]
            if params_str:
                for param in params_str.split(","):
                    param = param.strip()
                    if ":" in param:
                        ptype = param.split(":")[1].strip()
                        llvm_params.append(parse_llvm_type(ptype))
            param_str = ", ".join(llvm_params)

            declare_str = f"declare {llvm_ret} @{c_func_name}({param_str})"
            if declare_str not in codegen.extra_declares:
                codegen.extra_declares.append(declare_str)

        elif line.startswith("class ") and " field " in line and " function " not in line:
            parts = line.split(" field ")
            class_name = parts[0][6:].strip()
            field_parts = parts[1].rstrip(";").split(":")
            field_name = field_parts[0].strip()
            field_type = field_parts[1].strip()
            if class_name not in codegen.class_fields:
                codegen.class_fields[class_name] = []
            # avoid duplicates
            existing = [f[0] for f in codegen.class_fields[class_name]]
            if field_name not in existing:
                codegen.class_fields[class_name].append((field_name, field_type))
        
        elif line.startswith("class ") and " function " in line and " field " not in line:
            parts = line.split(" function ")
            class_name = parts[0][6:].strip()
            # Ensure type definition exists before any declares reference it
            type_def = f"%struct.{class_name} = type opaque"
            if type_def not in codegen.type_declarations:
                codegen.type_declarations.append(type_def)
                
            after_func = parts[1]
            func_name = after_func[:after_func.index("(")].strip()
            ret_type = after_func.split("->")[1].strip().rstrip(";").strip()
            llvm_ret = parse_llvm_type(ret_type)
            method_key = f"{class_name}_{func_name}"
            codegen.method_return_types[method_key] = llvm_ret

            # Emit declare so the function is known to the IR
            params_str = after_func[after_func.index("(")+1:after_func.index(")")].strip()
            this_llvm = f"%struct.{class_name}*"
            llvm_params = [this_llvm]
            if params_str:
                for param in params_str.split(","):
                    param = param.strip()
                    if ":" in param:
                        ptype = param.split(":")[1].strip()
                        llvm_params.append(parse_llvm_type(ptype))
            param_str = ", ".join(llvm_params)
            declare_str = f"declare {llvm_ret} @{method_key}({param_str})"
            if declare_str not in codegen.extra_declares:
                codegen.extra_declares.append(declare_str)


    lib_c_name = lib_name.replace('-', '_')
    if not is_native:
        has_globals = any(
            l.strip().startswith("const ") or l.strip().startswith("var ")
            for l in lines
        )
        if has_globals:
            init_func = f"__mocha_globals_init_{lib_c_name}"
            if init_func not in codegen.lib_init_calls:
                codegen.extra_declares.append(f"declare void @{init_func}()")
                codegen.lib_init_calls.append(init_func)

# ============================================================
# collect_dep_objects
#
# Recursively collects all .o files needed for a lib and its
# transitive dependencies into link_objects.
#
# e.g. mocha-processing depends on mocha-stats which depends
# on mocha-math — this ensures all three .o files get linked
# even if only mocha-processing was explicitly imported.
#
# seen set prevents double-adding and infinite loops.
# ============================================================
def collect_dep_objects(lib_name: str, lib_dir: str, link_objects: list, seen: Optional[Set] = None):
    if seen is None:
        seen = set()
    if lib_name in seen:
        return
    seen.add(lib_name)
    dep_obj = os.path.join(lib_dir, f"{lib_name}.o")
    if dep_obj not in link_objects and os.path.exists(dep_obj):
        link_objects.append(dep_obj)
        print(f"  📦 Auto-linking dep: {lib_name}")
    mchi_path = os.path.join(lib_dir, f"{lib_name}.mchi")
    if not os.path.exists(mchi_path):
        return
    with open(mchi_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith("// mocha-lib-deps:"):
                for dep in line.replace("// mocha-lib-deps:", "").strip().split(","):
                    collect_dep_objects(dep.strip(), lib_dir, link_objects, seen)

# ============================================================
# resolve_imports
#
# Processes all ImportStmt nodes in the AST and prepares
# everything needed for compilation and linking.
# Returns: (link_objects, native_libs, class_decls, injected_stmts)
#
# PARAMS:
#   ast          — the parsed AST of the current file
#   lib_dir      — directory where .mchi/.o/.ll lib files live
#   current_file — path of file being compiled (for relative imports)
#   seen_files   — circular import guard, always pass None from outside
#
# HANDLES TWO IMPORT TYPES:
#
#   1. .mch FILE IMPORTS  e.g. from "utils.mch" import *
#      Lexes + parses the imported file, recursively resolves
#      its own imports, then injects all its statements into
#      the current AST so they compile together as one unit.
#      Circular imports detected via seen_files set.
#
#   2. LIBRARY IMPORTS  e.g. from "mocha-stats" import *
#      Two-pass approach:
#
#      PASS 1 — needs linking?
#        Scans .mchi for non-native functions or extend blocks.
#        Native-only libs (all `native` declarations) need no .o
#        Pure Mocha libs need their .o linked into the executable.
#
#      PASS 2 — collect classes + deps
#        Scans .mchi for class declarations → added to class_decls
#        so codegen knows struct layouts exist.
#        Scans for // mocha-lib-deps: → calls collect_dep_objects
#        to pull in transitive dependency .o files too.
#
#      LINKING:
#        .o exists  → add to link_objects directly
#        .ll exists → compile to .o first then add (JIT lib compile)
#        neither    → warn user to run mocha --lib on the lib file
#
# RETURNS:
#   link_objects   — list of .o paths to pass to clang linker
#   native_libs    — set of native-only lib names (no .o needed)
#   class_decls    — class names from libs for codegen struct awareness
#   injected_stmts — AST statements from .mch imports to compile inline
# ============================================================

def resolve_imports(ast, lib_dir: str, current_file: str = "", seen_files: Optional[Set] = None) -> tuple:
    if seen_files is None:
        seen_files = set()

    link_objects   = []
    native_libs    = set()
    class_decls    = []
    injected_stmts = []

    for node in ast.statements:
        if not isinstance(node, ImportStmt):
            continue

        # ── .mch file import ──
        if node.source.endswith(".mch"):
            base_dir = os.path.dirname(os.path.abspath(current_file)) if current_file else os.getcwd()
            mch_path = os.path.normpath(os.path.join(base_dir, node.source))

            if not os.path.exists(mch_path):
                print(f"  ❌ Cannot find imported file: {mch_path}")
                continue

            if mch_path in seen_files:
                print(f"  ⚠️  Circular import detected, skipping: {node.source}")
                continue

            seen_files.add(mch_path)

            with open(mch_path, encoding='utf-8') as f:
                src = f.read()

            tokens     = Lexer(src).tokenise()
            import_ast = Parser(tokens).parse()

            # Recursively resolve imports in the imported file
            """_, _, sub_classes, sub_stmts = resolve_imports(
                import_ast, lib_dir,
                current_file=mch_path,
                seen_files=seen_files
            )"""

            sub_objects, _, sub_classes, sub_stmts = resolve_imports(
                import_ast, lib_dir,
                current_file=mch_path,
                seen_files=seen_files
            )
            for obj in sub_objects:
                if obj not in link_objects:
                    link_objects.append(obj)
            class_decls.extend(sub_classes)
            injected_stmts.extend(sub_stmts)
            injected_stmts.extend(import_ast.statements)
            print(f"  ✅ Imported: {node.source}")
            continue

        # ── existing library logic, completely unchanged ──
        mchi_path = os.path.join(lib_dir, f"{node.source}.mchi")
        obj_path  = os.path.join(lib_dir, f"{node.source}.o")
        ll_path   = os.path.join(lib_dir, f"{node.source}.ll")

        # Pass 1 — check if lib needs linking
        has_non_native = False
        if os.path.exists(mchi_path):
            with open(mchi_path, encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line == "// mocha-lib-type: compiled":
                        has_non_native = True
                        break
                    if line.startswith("function ") and " native " not in line:
                        has_non_native = True
                        break
                    if line.startswith("extend "):
                        has_non_native = True
                        break
        else:
            has_non_native = True

        # Pass 2 — collect class declarations and dependencies
        if os.path.exists(mchi_path):
            with open(mchi_path, encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("class ") and line.endswith(";") and " function " not in line:
                        class_name = line[6:-1].strip()
                        if class_name not in class_decls:
                            class_decls.append(class_name)
                    if line.startswith("// mocha-lib-deps:"):
                        deps_str = line.replace("// mocha-lib-deps:", "").strip()
                        dep_libs = [d.strip() for d in deps_str.split(",")]
                        for dep in dep_libs:
                            collect_dep_objects(dep, lib_dir, link_objects)

        # Link the .o if needed
        if has_non_native:
            if obj_path not in link_objects:
                if os.path.exists(obj_path):
                    link_objects.append(obj_path)
                    print(f"  📦 Linking lib: {node.source}")
                elif os.path.exists(ll_path):
                    print(f"  🔧 Compiling lib from .ll: {node.source}...")
                    result = subprocess.run(
                        [str(CLANG_PATH), "-c", ll_path, "-o", obj_path, 
                         "-target", "x86_64-w64-mingw32"],
                        capture_output=True, text=True, encoding='utf-8'
                    )
                    if result.returncode != 0:
                        print(f"  ❌ Failed to compile lib {node.source}:\n{result.stderr}")
                    else:
                        link_objects.append(obj_path)
                        print(f"  ✅ Compiled and linking: {node.source}")
                else:
                    print(f"  ⚠️  Library '{node.source}' not found in {lib_dir}/")
                    print(f"      Run: mocha --lib lib/{node.source}.mch")
        else:
            native_libs.add(node.source)
            print(f"  📦 Native lib (no .o needed): {node.source}")

    return link_objects, native_libs, class_decls, injected_stmts


# ============================================================
# LIBRARY PRE-COMPILATION
# ============================================================

# ============================================================
# compile_lib
#
# Compiles a .mch library file into a linkable .o + .mchi manifest.
# Called when user runs: mocha --lib lib/mocha-stats.mch
#
# OUTPUT FILES:
#   .ll   — LLVM IR of the library
#   .o    — compiled object file for linking
#   .mchi — interface manifest (like a C header) for TC + codegen
#
# PIPELINE:
#   1. Lex + Parse the lib source file
#   2. resolve_imports — find deps, inject imported statements
#   3. Load dep manifests into TC (both ImportStmt AND
#      // mocha-lib-deps: lines — checked separately because
#      mocha-lib-deps bypasses the ImportStmt AST node)
#   4. Type check — entry point error filtered out since
#      libs deliberately have no didLoad function
#   5. Register dep functions into CodeGen (same dual-source
#      as step 3 — ImportStmt + mocha-lib-deps both handled)
#   6. Register dep global inits so lib's own globals
#      initialise after its dependencies are ready
#   7. Codegen → .ll
#   8. clang -c → .o
#   9. generate_manifest → .mchi
#
# SPECIAL CASE:
#   mocha-SymCha gets an extra forward declare for pow()
#   because it uses symbolic calculus which calls pow directly.
#   Only lib that needs this — hardcoded by name.
# ============================================================
def compile_lib(source_file: str) -> bool:
    print(f"🔧 Compiling Mocha library: {source_file}")

    if not os.path.exists(source_file):
        print(f"❌ File not found: {source_file}")
        return False

    lib_name = os.path.splitext(os.path.basename(source_file))[0]

    with open(source_file, 'r', encoding='utf-8') as f:
        source = f.read()

    tokens = Lexer(source).tokenise()
    ast    = Parser(tokens).parse()

    # Resolve imports so dependencies are known during lib compilation
    link_objects, native_libs, class_decls, injected_stmts = resolve_imports(ast, LIB_DIR, current_file=source_file)
    ast.statements = injected_stmts + ast.statements

    type_checker = TypeChecker()
    # Load dep manifests into type checker
    for node in ast.statements:
        if isinstance(node, ImportStmt):
            if not node.source.startswith("./") and not node.source.startswith("../"):
                load_lib_manifest(node.source, LIB_DIR, type_checker, None)
    
    # ALSO load deps declared via // mocha-lib-deps: in the source file
    # These are parsed by resolve_imports but not visible as ImportStmt nodes
    for line in source.splitlines():
        line = line.strip()
        if line.startswith("// mocha-lib-deps:"):
            deps_str = line.replace("// mocha-lib-deps:", "").strip()
            for dep in [d.strip() for d in deps_str.split(",")]:
                if dep:
                    load_lib_manifest(dep, LIB_DIR, type_checker, None)
            break  # only one deps line ever

    errors = type_checker.check(ast)
    errors = [e for e in errors if "entry point" not in str(e).lower()]
    if errors:
        print("❌ Type errors in library:")
        for e in errors:
            print(f"   {e}")
        return False

    codegen = CodeGen(is_lib=True, lib_name=lib_name)

    # Register dep functions in codegen
    for node in ast.statements:
        if isinstance(node, ImportStmt):
            register_lib_in_codegen(node.source, LIB_DIR, codegen, None,
                                    is_native=(node.source in native_libs))
    
    # Register deps declared via // mocha-lib-deps:
    for line in source.splitlines():
        line = line.strip()
        if line.startswith("// mocha-lib-deps:"):
            deps_str = line.replace("// mocha-lib-deps:", "").strip()
            for dep in [d.strip() for d in deps_str.split(",")]:
                if dep:
                    register_lib_in_codegen(dep, LIB_DIR, codegen, None, is_native=False)
            break

    # Register lib init calls for dependencies
    for obj in link_objects:
        dep_name = os.path.splitext(os.path.basename(obj))[0]
        init_fn  = f"__mocha_globals_init_{dep_name.replace('-','_')}"
        if init_fn not in codegen.lib_init_calls:
            codegen.lib_init_calls.append(init_fn)

    # Forward declare pow so IR can verify it — only needed for mocha-SymCha (uses symbolic calculus)
    if lib_name == "mocha-SymCha":
        codegen.extra_declares.append("declare double @pow(double, i32)")

    llvm_ir = codegen.generate(ast)

    base      = os.path.splitext(source_file)[0]
    ll_file   = f"{base}.ll"
    obj_file  = f"{base}.o"
    mchi_file = f"{base}.mchi"

    with open(ll_file, 'w', encoding='utf-8') as f:
        f.write(llvm_ir)

    generate_manifest(ast, mchi_file, source_file)

    result = subprocess.run(
        [str(CLANG_PATH), "-c", ll_file, "-o", obj_file,
         "-target", "x86_64-w64-mingw32"],
        capture_output=True, text=True, encoding='utf-8'
    )
    if result.returncode != 0:
        print(f"❌ clang failed:\n{result.stderr}")
        return False

    print(f"✅ Library compiled: {obj_file}")
    print(f"✅ Manifest generated: {mchi_file}")
    print(f"   Import with: import {lib_name} from \"{lib_name}\" as alias;")
    print(f"            OR: from \"{lib_name}\" import *;")
    return True

# ============================================================
# generate_manifest
#
# Generates the .mchi interface file for a compiled lib.
# The .mchi is Mocha's equivalent of a C header — it describes
# what a lib exports without the implementation details.
# Auto-called at end of compile_lib, never called manually.
#
# OUTPUT FORMAT (written to .mchi):
#   // Auto-generated manifest for mocha-stats.mch
#   // mocha-lib-type: compiled
#   // mocha-lib-deps: mocha-math
#   function mean(...) -> float native mocha_stats_mean;
#   const PI: float = 3.14159;
#   extend float[] function mean() -> float;
#   class StandardScaler;
#   class StandardScaler function transform(...) -> float[];
#
# HANDLES FOUR NODE TYPES:
#
#   FunctionDecl — three sub-cases:
#     is_native     → emit as-is with native c_name
#     is_dummy_body → single-literal-return body signals C-backed
#                     function (pre-FFI design), emit with
#                     c_prefix_funcname as native name
#     normal        → mangle the name, emit as native if mangled
#                     (mangling = name differs from original),
#                     plain emit if no mangling needed
#
#   ConstDecl — only primitive literals supported
#               (int, float, bool, str). Array consts skipped.
#
#   ExtendDecl — emits one line per method in the extend block
#                native extends keep their c_name,
#                pure Mocha extends just declare signature
#
#   ClassDecl — emits "class Name;" for struct awareness
#               then one line per non-constructor method as
#               "class Name function method(...) -> type;"
#               constructor skipped — never called by name externally
#
# DEP PRESERVATION:
#   Copies // mocha-lib-deps: line from source file verbatim
#   so transitive dep resolution works when this lib is imported.
#   Also collects ImportStmt nodes as additional deps.
#
# ============================================================

def generate_manifest(ast, mchi_path: str, source_file: str):

    lib_base = os.path.splitext(os.path.basename(source_file))[0]
    c_prefix = lib_base.replace("-", "_")

    lines = [f"// Auto-generated manifest for {os.path.basename(source_file)}"]
    lines.append("// Warning: Do not edit manually; regenerate with --lib\n")
    lines.append("// mocha-lib-type: compiled\n")

    # Preserve mocha-lib-deps from source
    with open(source_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip().startswith("// mocha-lib-deps:"):
                lines.append(line.strip() + "\n")
                break

    # Collect dependencies from imports
    deps = []
    for node in ast.statements:
        if isinstance(node, ImportStmt):
            deps.append(node.source)
    if deps:
        lines.append(f"// mocha-lib-deps: {','.join(deps)}\n")

    # ← ADD THIS: preserve mocha-extern-class directives
    with open(source_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith("// mocha-extern-class "):
                extern_decl = line[len("// mocha-extern-class "):]
                lines.append(f"class {extern_decl}")

    def is_dummy_body(func_node):
        if len(func_node.body) != 1:
            return False
        stmt = func_node.body[0]
        if not isinstance(stmt, ReturnStmt):
            return False
        return isinstance(stmt.value, (IntLiteral, FloatLiteral, StrLiteral, Identifier))

    for node in ast.statements:
        if isinstance(node, FunctionDecl):
            params = ", ".join(
                f"{p.name}: {p.type}" for p in node.params
                if not getattr(p, 'has_didLoad', False)
            )
            if node.is_native:
                lines.append(f"function {node.name}({params}) -> {node.return_type} native {node.native_name};")
            elif is_dummy_body(node):
                lines.append(f"function {node.name}({params}) -> {node.return_type} native {c_prefix}_{node.name};")
            else:
                mangled = mangle_function_name(node.name)
                if mangled != node.name:
                    # store mangled name as native so dependents call the right symbol
                    lines.append(f"function {node.name}({params}) -> {node.return_type} native {mangled};")
                else:
                    lines.append(f"function {node.name}({params}) -> {node.return_type};")

        elif isinstance(node, ConstDecl):
            if isinstance(node.value, (IntLiteral, FloatLiteral, BoolLiteral, StrLiteral)):
                lines.append(f"const {node.name}: {node.type} = {node.value.value};")
            elif isinstance(node.value, UnaryOp):
                if node.value.op == '-':
                    if isinstance(node.value.right, IntLiteral):
                        lines.append(f"const {node.name}: {node.type} = -{node.value.right.value};")
                    elif isinstance(node.value.right, FloatLiteral):
                        lines.append(f"const {node.name}: {node.type} = -{node.value.right.value};")
                    else:
                        raise Exception(f"Unsupported const value type: {type(node.value)}")
            elif isinstance(node.value, ArrayLiteral):
                pass
            else:
                raise Exception(f"Unsupported const value type: {type(node.value)}")

        elif isinstance(node, ExtendDecl):
            for func in node.body:
                params = ", ".join(f"{p.name}: {p.type}" for p in func.params)
                if getattr(func, 'is_native', False) and func.native_name:
                    lines.append(f"extend {node.type_name} function {func.name}({params}) -> {func.return_type} native {func.native_name};")
                else:
                    lines.append(f"extend {node.type_name} function {func.name}({params}) -> {func.return_type};")

        elif isinstance(node, ClassDecl):
            lines.append(f"class {node.name};")
            
            # emit field declarations
            for member in node.body:
                if isinstance(member, FieldDecl):
                    lines.append(f"class {node.name} field {member.name}: {member.type};")
            
            for member in node.body:
                if isinstance(member, MethodDecl):
                    if member.name == "constructor":
                        continue
                    params = ", ".join(f"{p.name}: {p.type}" for p in member.params
                                    if not getattr(p, 'has_didLoad', False))
                    lines.append(f"class {node.name} function {member.name}({params}) -> {member.return_type};")
    with open(mchi_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

# ============================================================
# MAIN COMPILER
# ============================================================

def needs_recompile(src, obj): #Incremental Compilation
    if not os.path.exists(obj):
        return True
    return os.path.getmtime(src) > os.path.getmtime(obj)

def compile_mocha(source_file: str, output_name: str = "a.out", debug=False) -> bool:
    import time
    start = time.time()

    print(f"🔥 Mocha Compiler v0.8")
    print(f"📄 Compiling: {source_file}\n")

    if not source_file.endswith('.mch'):
        print("⚠️  Warning: Mocha files should use the .mch extension\n")

    with open(source_file, 'r', encoding='utf-8') as f:
        source = f.read()

    print("Step 1: Lexing...")
    tokens = Lexer(source).tokenise()
    print(f"  ✅ {len(tokens)} tokens\n")

    print("Step 2: Parsing...")
    ast = Parser(tokens).parse()
    print(f"  ✅ AST generated\n")

    # Debug mode — dump tokens and AST
    if debug:
        from mocha_debug import print_tokens, print_ast
        print("\n=== DEBUG: TOKEN STREAM ===", file=sys.stderr)
        print_tokens(tokens, stream=sys.stderr)
        print("\n=== DEBUG: AST ===", file=sys.stderr)
        print_ast(ast, stream=sys.stderr)
        print("=== END DEBUG ===\n", file=sys.stderr)

    print("Step 2.5: Resolving imports...")
    link_objects, native_libs, class_decls, injected_stmts = resolve_imports(ast, LIB_DIR, current_file=source_file)
    ast.statements = injected_stmts + ast.statements

    if link_objects or injected_stmts:
        if link_objects:
            print(f"  ✅ {len(link_objects)} lib(s) resolved\n")
        # sibling imports already printed individually inside resolve_imports
    else:
        print(f"  ✅ No imports\n")

    print()

    print("Step 3: Type Checking...")
    type_checker = TypeChecker()

    for node in ast.statements:
        if isinstance(node, ImportStmt):
            if node.source.startswith("./") or node.source.startswith("../"):
                continue  # sibling file, already merged into AST
            alias = node.alias if node.alias else node.module
            load_lib_manifest(node.source, LIB_DIR, type_checker, alias)
            if node.imports is not None:
                load_lib_manifest(node.source, LIB_DIR, type_checker, None)
                # from "x" import * — also register under bare names (no alias)
                # so sin() works directly without MochaMath.sin() prefix

    errors = type_checker.check(ast)
    if errors:
        print(f"  ❌ Type errors found:\n")
        for e in errors:
            print(f"     {e}")
        return False
    print(f"  ✅ Type check passed\n")

    print("Step 4: Code Generation...")
    codegen = CodeGen()

    for node in ast.statements:
        if isinstance(node, ImportStmt):
            alias = node.alias if node.alias else node.module
            register_lib_in_codegen(node.source, LIB_DIR, codegen, alias,
                                    is_native=(node.source in native_libs))
            if node.imports is not None:
                # from "x" import * — also register under bare names (no alias)
                # so sin() works directly without MochaMath.sin() prefix
                register_lib_in_codegen(node.source, LIB_DIR, codegen, None,
                                        is_native=(node.source in native_libs))

    for class_name in class_decls:
        if " " in class_name:
            continue
        # remove any existing opaque definition first
        existing = [d for d in codegen.type_declarations if f"%struct.{class_name}" in d]
        for e in existing:
            codegen.type_declarations.remove(e)
        
        if class_name in codegen.class_fields and codegen.class_fields[class_name]:
            fields = codegen.class_fields[class_name]
            llvm_fields = ", ".join(to_llvm_type(f[1]) for f in fields)
            struct_decl = f"%struct.{class_name} = type {{ {llvm_fields} }}"
        else:
            struct_decl = f"%struct.{class_name} = type opaque"
        
        codegen.type_declarations.append(struct_decl)

    try:
        llvm_ir = codegen.generate(ast)
    except MochaCodeGenError as e:
        print(f"  ❌ {e}")
        sys.exit(1)

    ll_file = f"{output_name}.ll"
    with open(ll_file, 'w', encoding='utf-8') as f:
        f.write(llvm_ir)
    print(f"  ✅ Generated {ll_file}\n")

    print("Step 5: Compiling to executable...")

    if not os.path.exists(RUNTIME_C):
        print(f"  ❌ Runtime not found: {RUNTIME_C}")
        return False

    assert CLANG_PATH is not None
    assert MINGW_GCC is not None
    
    MINGW_SYSROOT = os.path.dirname(os.path.dirname(MINGW_GCC))
    CLANG_TARGET  = "x86_64-w64-mingw32"

    # Compile runtime C
    result = subprocess.run(
        [CLANG_PATH, "-O3", "-march=native", "-flto", "-c", RUNTIME_C, "-o", RUNTIME_OBJ,
         "-target", CLANG_TARGET,
         "--sysroot", MINGW_SYSROOT,
         f"-I{LUA_INCLUDE}",
         f"-I{WREN_INCLUDE}"],
        capture_output=True, text=True, encoding='utf-8' # type: ignore
    )
    if result.returncode != 0:
        print(f"  ❌ runtime compile failed:\n{result.stderr}")
        return False
    
    # Compile C++ file
    if os.path.exists(CPP_FILE):
        if needs_recompile(CPP_FILE, CPP_OBJ):
            result = subprocess.run(
                [CLANG_PATH.replace("clang.exe", "clang++.exe"),
                "-O3", "-march=native", "-flto", "-c", CPP_FILE, "-o", CPP_OBJ,
                "-target", CLANG_TARGET,
                "--sysroot", MINGW_SYSROOT],
                capture_output=True, text=True, encoding='utf-8'
            )
            if result.returncode != 0:
                print(f"  ❌ C++ compile failed:\n{result.stderr}")
                return False
        else:
            print("  ⚡ C++ cached", flush=True)

    # Compile sqlite3
    if needs_recompile(SQLITE3_C, SQLITE3_OBJ):
        result = subprocess.run(
            [CLANG_PATH, "-O3", "-march=native", "-flto", "-c", SQLITE3_C, "-o", SQLITE3_OBJ,
            "-target", CLANG_TARGET,
            "--sysroot", MINGW_SYSROOT],
            capture_output=True, text=True, encoding='utf-8'
        )
        if result.returncode != 0:
            print(f"  ❌ sqlite3 compile failed:\n{result.stderr}")
            return False
    else:
        print("  ⚡ sqlite3 cached", flush=True)
    
    # Compile Wren
    if needs_recompile(WREN_C, WREN_OBJ):
        result = subprocess.run(
            [CLANG_PATH, "-O3", "-march=native", "-flto", "-c", WREN_C, "-o", WREN_OBJ,
            "-target", CLANG_TARGET,
            "--sysroot", MINGW_SYSROOT,
            f"-I{WREN_INCLUDE}"],
            capture_output=True, text=True, encoding='utf-8'
        )
        if result.returncode != 0:
            print(f"  ❌ wren compile failed:\n{result.stderr}")
            return False
    else:
        print("  ⚡ wren cached", flush=True)

    # Compile Zig
    if needs_recompile("zig_ffi.zig", "zig_ffi.lib"):
        result = subprocess.run(
            [ZIG_PATH, "build-lib", "zig_ffi.zig",
            "-target", "x86_64-windows-gnu",
            "-O", "ReleaseFast"],
            capture_output=True, text=True, encoding='utf-8'
        )
        if result.returncode != 0:
            print(f"  ❌ zig compile failed:\n{result.stderr}")
            return False
    else:
        print("  ⚡ zig cached", flush=True)

    # Compile IR to object file
    obj_file = f"{output_name}.o"
    result = subprocess.run(
        [CLANG_PATH, "-O3", "-march=native", "-flto", "-c", ll_file, "-o", obj_file,
         "-target", CLANG_TARGET,
         "--sysroot", MINGW_SYSROOT],
        capture_output=True, text=True, encoding='utf-8'
    )
    if result.returncode != 0:
        print(f"  ❌ clang failed:\n{result.stderr}")
        return False

    # Detect which FFI libs are actually needed
    with open(ll_file, 'r', encoding='utf-8') as f:
        ir_content = f.read()

    needs_rust = 'mocha_rust_' in ir_content
    needs_cpp  = 'mocha_cpp_'  in ir_content
    needs_zig = 'mocha_zig_' in ir_content

    # Link everything
    exe_file = f"{output_name}.exe"
    link_cmd = [
        CLANG_PATH, "-O3", "-march=native", "-flto",
        obj_file, RUNTIME_OBJ, SQLITE3_OBJ,
    ]

    if needs_cpp:
        link_cmd.append(CPP_OBJ)

    link_cmd += link_objects + [
        "-o", exe_file,
        "-target", CLANG_TARGET,
        "--sysroot", MINGW_SYSROOT,
        "-fuse-ld=lld",
        "-lm",
        "-lbcrypt",
        LUA_LIB,
        WREN_OBJ
    ]

    if needs_rust:
        link_cmd.append(RUST_LIB)
    if needs_zig:
        link_cmd.append(ZIG_LIB)

    link_cmd += ["-lgcc_eh", "-lgcc"]

    result = subprocess.run(link_cmd, capture_output=True, text=True, encoding='utf-8')
    if result.returncode != 0:
        print(f"  ❌ linking failed:\n{result.stderr}\n{result.stdout}")
        return False

    # Sign the executable
    print("  🔏 Signing executable...")
    sign_result = sign_executable(exe_file)
    if sign_result == "signed":
        print(f"  ✅ Signed with MochaLang certificate")
    elif sign_result == "no_cert":
        print(f"  ⚠️  MochaLang cert not found — run setup_cert.ps1 to create it")
    elif sign_result == "expired":
        print(f"  ⚠️  MochaLang cert expired — run setup_cert.ps1 to renew it")
    else:
        print(f"  ⚠️  Signing skipped")

    print(f"  ✅ Generated {exe_file}\n")
    print(f"🎉 Compilation successful!")
    print(f"▶  Run with: {exe_file}")

    elapsed = time.time() - start
    print(f"⏱  Compiled in {elapsed:.2f}s")

    return True

# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    # Remove --debug from argv for cleaner processing
    debug_mode = "--debug" in sys.argv
    args = [a for a in sys.argv if a != "--debug"]
    
    if len(args) < 2:
        print("Usage: mocha <file.mch>")
        print("       mocha --lib <libfile.mch>")
        sys.exit(1)

    if args[1] == "--lib":
        if len(args) < 3:
            print("Usage: mocha --lib <libfile.mch>")
            sys.exit(1)
        success = compile_lib(args[2])
        sys.exit(0 if success else 1)

    source_file = args[1]
    output_name = args[2] if len(args) > 2 else os.path.splitext(source_file)[0]
    success = compile_mocha(source_file, output_name, debug=debug_mode)
    sys.exit(0 if success else 1)