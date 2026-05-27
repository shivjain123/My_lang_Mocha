# ============================================================
# Mocha Code Generator
# ============================================================

from mocha_ast import *
from typing import Optional, cast
import os

class MochaCodeGenError(Exception):
    def __init__(self, message, line=0, col=0):
        loc = f" at line {line}, col {col}" if line else ""
        super().__init__(f"MochaCodeGenError{loc}: {message}")


LLVM_TYPES = {
    "int":     "i32",
    "vast":    "i64",
    "float":   "double",
    "bool":    "i8",
    "str":     "i8*",
    "null":    "void",
    "Result":  "i32",
    "StringBuilder": "%struct.MochaStringBuilder*",
    "Complex": "%struct.MochaComplex*",
    "File": "%struct.MochaFile*",
    "HashTable": "%struct.MochaHashTable*",
    "unknown": "i32",
}

_tag_types_registry: set = set()

def to_llvm_type(mocha_type: str) -> str:
    if mocha_type.startswith("("):
        return "%MochaTuple*"
    if "[][]" in mocha_type:
        return "%MochaArray2D*"
    if "[" in mocha_type:
        return "%MochaArray*"
    if mocha_type == "dict": 
        return "%MochaDict*"
    if mocha_type.startswith("set<"):
        return "%MochaSet*"
    if mocha_type == "lambda":
        return "i8*"
    if mocha_type in LLVM_TYPES:
        return LLVM_TYPES[mocha_type]
    if mocha_type in _tag_types_registry:
        return "i32"
    return "%struct." + mocha_type + "*"

def to_llvm_param_type(mocha_type: str) -> str:
    """Like to_llvm_type but null → i8* for use as parameter"""
    if mocha_type == "null":
        return "i8*"
    return to_llvm_type(mocha_type)

C_STDLIB_NAMES = {
    "abs", "pow", "sqrt", "sin", "cos", "tan", "log", "exp",
    "ceil", "floor", "round", "rand", "exit", "printf", "puts"
}

def mangle_function_name(name: str) -> str:
    if name in C_STDLIB_NAMES:
        return f"mocha_user_{name}"
    return name

# ── Module-level method maps ──────────────────────────────────────────────────

COMPLEX_METHOD_MAP = {
    "toString":  ("i8*",                   "mocha_complex_tostring"),
    "abs":       ("double",                "mocha_complex_abs"),
    "add":       ("%struct.MochaComplex*", "mocha_complex_add"),
    "sub":       ("%struct.MochaComplex*", "mocha_complex_sub"),
    "mul":       ("%struct.MochaComplex*", "mocha_complex_mul"),
    "div":       ("%struct.MochaComplex*", "mocha_complex_div"),
    "conjugate": ("%struct.MochaComplex*", "mocha_complex_conjugate"),
}

STRINGBUILDER_METHOD_MAP = {
    "append":   ("void", "mocha_sb_append"),
    "toString": ("i8*",  "mocha_sb_tostring"),
    "reverse":  ("i8*",  "mocha_sb_reverse"),
    "clear":    ("void", "mocha_sb_clear"),
    "length":   ("i32",  "mocha_sb_length"),
    "free":     ("void", "mocha_sb_free"),
}

FILE_METHOD_MAP = {
    "read":     ("i8*",  "mocha_file_read"),
    "readLine": ("i8*",  "mocha_file_readline"),
    "write":    ("void", "mocha_file_write"),
    "close":    ("void", "mocha_file_close"),
}

HASHTABLE_METHOD_MAP = {
    "put":    ("void",         "mocha_ht_put"),
    "get":    ("i8*",          "mocha_ht_get"),
    "has":    ("i8",           "mocha_ht_has"),
    "remove": ("void",         "mocha_ht_remove"),
    "size":   ("i32",          "mocha_ht_size"),
    "clear":  ("void",         "mocha_ht_clear"),
    "keys":   ("%MochaArray*", "mocha_ht_keys"),
    "values": ("%MochaArray*", "mocha_ht_values"),
    "free":   ("void",         "mocha_ht_free"),
}

STDLIB_NAMES = {
    "malloc",
    "fopen",
    "fclose",
    "fputs",
    "mocha_print_stderr",
    "mocha_exit"
}

class CodeGen:
    def __init__(self, is_lib=False, lib_name="", source_file="unknown.mch"):
        self.source_file           = os.path.basename(source_file)
        self.current_emitted_line  = -1
        self.output        = []
        self.temp_count    = 0
        self.str_count     = 0
        self.string_consts = {}
        self.locals        = {}
        self.current_return_type = "void"
        self.in_function   = False
        self.current_class = None
        self.classes_with_constructors = set()
        self.class_fields = {}
        self.class_parents = {}
        self.method_return_types = {}
        self.local_mocha_types = {}
        self.lib_functions = {}
        self.lib_constants = {}
        self.class_all_parents = {}
        self.globals = {}
        self.global_mocha_types = {}
        self.is_lib=is_lib
        self.lib_name=lib_name
        self.extra_declares = []
        self.lib_init_calls = []
        self.globals_init_emitted = False
        self.type_declarations = []
        self.ext_native_names = {}  # mocha_ext_key -> actual C name
        self.expected_assign_type = None
        self.class_nodes = {}  # class_name -> ClassDecl node
        self.entry_allocas = []
        self.class_mocha_fields = {}  # class_name -> [(field_name, mocha_type_str)]
        self.local_name_counts = {}  # tracks how many times a name has been used

        # Built-in StringBuilder type
        self.class_fields["StringBuilder"] = [
            ("data",     "i8*"),
            ("length",   "i32"),
            ("capacity", "i32"),
        ]
        self.method_return_types["StringBuilder_toString"] = "i8*"
        self.method_return_types["StringBuilder_reverse"]  = "i8*"
        self.method_return_types["StringBuilder_clear"]    = "void"
        self.method_return_types["StringBuilder_append"]   = "void"
        self.method_return_types["StringBuilder_length"]   = "i32"

        # Built-in Complex Number type
        self.class_fields["Complex"] = [
            ("real", "double"),
            ("imag", "double"),
        ]
        self.method_return_types["Complex_toString"] = "i8*"
        self.method_return_types["Complex_abs"]      = "double"
        self.method_return_types["Complex_add"]      = "%struct.MochaComplex*"
        self.method_return_types["Complex_sub"]      = "%struct.MochaComplex*"
        self.method_return_types["Complex_mul"]      = "%struct.MochaComplex*"
        self.method_return_types["Complex_div"]      = "%struct.MochaComplex*"
        self.method_return_types["Complex_conjugate"] = "%struct.MochaComplex*"

        # Built-in File object for I/O
        self.class_fields["File"] = [
            ("handle", "i8*"),
            ("path",   "i8*"),
            ("mode",   "i8*"),
            ("is_open", "i8"),
        ]
        self.method_return_types["File_read"]     = "i8*"
        self.method_return_types["File_readLine"] = "i8*"
        self.method_return_types["File_write"]    = "void"
        self.method_return_types["File_close"]    = "void"

        # Built-in HashTable type
        self.class_fields["HashTable"] = [
            ("entries",  "i8*"),
            ("capacity", "i32"),
            ("count",    "i32"),
            ("used",     "i32"),
        ]
        self.method_return_types["HashTable_put"]    = "void"
        self.method_return_types["HashTable_get"]    = "i8*"
        self.method_return_types["HashTable_has"]    = "i8"
        self.method_return_types["HashTable_remove"] = "void"
        self.method_return_types["HashTable_size"]   = "i32"
        self.method_return_types["HashTable_clear"]  = "void"
        self.method_return_types["HashTable_keys"]   = "%MochaArray*"
        self.method_return_types["HashTable_values"] = "%MochaArray*"
        self.method_return_types["HashTable_free"]   = "void"

        #Built-in Format for strings
        self.method_return_types["mocha_ext_str_format"] = "i8*"

    # -------------------------------------------------------
    # Helpers
    # -------------------------------------------------------

    def emit(self, line: str):
        self.output.append(line)

    def emit_blank(self):
        self.output.append("")

    def fresh_temp(self) -> str:
        name = f"%t{self.temp_count}"
        self.temp_count += 1
        return name

    def fresh_label(self, hint: str = "lbl") -> str:
        name = f"{hint}_{self.temp_count}"
        self.temp_count += 1
        return name

    def escape_string(self, value: str) -> str:
        escaped = ""
        for ch in value:
            if ch == '\\': escaped += '\\5C'
            elif ch == '"': escaped += '\\22'
            elif ch == '\n': escaped += '\\0A'
            elif ch == '\t': escaped += '\\09'
            elif ord(ch) < 128: escaped += ch
            else:
                for byte in ch.encode('utf-8'):
                    escaped += f"\\{byte:02X}"
        return escaped

    def fresh_str_global(self, value: str) -> str:
        name = f"@.str{self.str_count}"
        self.str_count += 1
        escaped = self.escape_string(value)
        # Count actual LLVM bytes: \XX is 1 byte, regular char is 1 byte
        byte_count = 0
        i = 0
        while i < len(escaped):
            if escaped[i] == '\\':
                i += 3  # skip \XX
            else:
                i += 1
            byte_count += 1
        length = byte_count + 1  # +1 for \00
        self.string_consts[name] = (escaped, length)
        return name

    def last_is_terminator(self) -> bool:
        """Returns True if the last non-empty emitted line is a ret or br."""
        for line in reversed(self.output):
            s = line.strip()
            if s:
                return s.startswith("ret ") or s.startswith("br ") or s == "ret void"
        return False

    def emit_br_if_needed(self, label: str):
        """Only emit a branch if the block doesn't already end with a terminator."""
        if not self.last_is_terminator():
            self.emit(f"  br label %{label}")
    
    def build_header(self):
        sections = {
            "Mocha compiled output": [],
            
            "GC Runtime": [
                "declare void @mocha_gc_init()",
                "declare void @mocha_gc_collect()",
                "declare void @mocha_gc_shutdown()",
            ],

            "String Runtime": [
                "declare i8* @mocha_str_literal(i8*)",
                "declare i8* @mocha_str_concat(i8*, i8*)",
                "declare i8* @mocha_int_to_str(i32)",
                "declare i8* @mocha_float_to_str(double)",
                "declare i8* @mocha_bool_to_str(i8)",
                "declare i32 @mocha_str_eq(i8*, i8*)",
                "declare i32 @mocha_str_length(i8*)",
                "declare i8* @mocha_str_charat(i8*, i32)",
                "declare void @llvm.memset.p0i8.i64(i8*, i8, i64, i1)",
                "declare i32 @SetConsoleOutputCP(i32)",
                "declare i32 @mocha_str_to_int(i8*)",
                "declare double @mocha_str_to_float(i8*)",
                "declare i8* @mocha_vast_to_str(i64)",
                "declare i8* @mocha_str_format(i8*, i8**, i32)",
                "declare i8* @mocha_str_format_named(i8*, i8**, i8**, i32)",
            ],

            "Print Runtime": [
                "declare void @mocha_print_str(i8*, i8)",
                "declare void @mocha_print_int(i32, i8)",
                "declare void @mocha_print_float(double, i8)",
                "declare void @mocha_print_bool(i8, i8)",
                "declare void @mocha_print_vast(i64, i8)",
            ],

            "Fixed-Point Float Arithmetic": [
                "declare double @mocha_float_add(double, double)",
                "declare double @mocha_float_sub(double, double)",
                "declare double @mocha_float_mul(double, double)",
                "declare double @mocha_float_div(double, double)",
                "declare double @mocha_float_mod(double, double)",
            ],

            "C Standard Library": [
                "declare i8* @malloc(i64)",
                "declare i32 @atoi(i8*)",
                "declare double @atof(i8*)",
                "declare i32 @strcmp(i8*, i8*)",
                "declare void @mocha_exit(i32)",
                "declare void @mocha_print_stderr(i8*)",
            ],

            "Array Runtime": [
                "%MochaArray = type { i8*, i32, i32, i32, i32 }",
                "declare %MochaArray* @mocha_array_new(i32, i32, i32)",
                "declare %MochaArray* @mocha_array_alloc_filled(i32, i32)",
                "declare void @mocha_array_set(%MochaArray*, i32, i8*)",
                "declare void @mocha_array_get(%MochaArray*, i32, i8*)",
                "declare void @mocha_array_push(%MochaArray*, i8*)",
                "declare void @mocha_array_pop(%MochaArray*, i8*)",
                "declare void @mocha_array_push_front(%MochaArray*, i8*)",
                "declare void @mocha_array_init_set(%MochaArray*, i32, i8*)",
                "declare i32 @mocha_array_length(%MochaArray*)",
                "declare i32 @mocha_array_occs(%MochaArray*, i8*)",
                "declare i32 @mocha_array2d_occs(%MochaArray2D*, i8*)",
                "declare i32 @mocha_array2d_occs_row(%MochaArray2D*, i8*, i32)",
                "declare i32 @mocha_array2d_occs_col(%MochaArray2D*, i8*, i32)",
                "declare i32 @mocha_array2d_occs_rowrange(%MochaArray2D*, i8*, i32, i32)",
                "declare i32 @mocha_array2d_occs_colrange(%MochaArray2D*, i8*, i32, i32)",
                "declare %MochaArray* @mocha_array_copy(%MochaArray*)",
                "declare i32    @mocha_array_min_int(%MochaArray*)",
                "declare double @mocha_array_min_float(%MochaArray*)",
                "declare i64    @mocha_array_min_vast(%MochaArray*)",
                "declare i8*    @mocha_array_min_str(%MochaArray*)",
                "declare i32    @mocha_array_max_int(%MochaArray*)",
                "declare double @mocha_array_max_float(%MochaArray*)",
                "declare i64    @mocha_array_max_vast(%MochaArray*)",
                "declare i8*    @mocha_array_max_str(%MochaArray*)",
            ],

            "2D Array Runtime": [
                "%MochaArray2D = type { %MochaArray**, i32, i32, i32, i32, i32 }",
                "declare %MochaArray2D* @mocha_array2d_new(i32, i32, i32, i32, i32)",
                "declare void @mocha_array2d_set(%MochaArray2D*, i32, i32, i8*)",
                "declare void @mocha_array2d_get(%MochaArray2D*, i32, i32, i8*)",
                "declare void @mocha_array2d_resize(%MochaArray2D*, i32, i32, i32)",
                "declare void @mocha_array2d_drop_row(%MochaArray2D*, i32)",
                "declare void @mocha_array2d_drop_col(%MochaArray2D*, i32)",
                "declare i32 @mocha_array2d_rows(%MochaArray2D*)",
                "declare i32 @mocha_array2d_cols(%MochaArray2D*)",
                "declare %MochaArray* @mocha_array2d_get_row(%MochaArray2D*, i32)",
                    "declare %MochaArray* @mocha_array2d_get_col(%MochaArray2D*, i32)",
            ],

            "Tuple Runtime": [
                "%MochaTuple = type { i8**, i32 }",
                "declare %MochaTuple* @mocha_tuple_new(i32)",
                "declare void @mocha_tuple_set(%MochaTuple*, i32, i8*)",
                "declare i8* @mocha_tuple_get(%MochaTuple*, i32)",
            ],

            "Sorting": [
                "declare void @mocha_sort_int(%MochaArray*)",
                "declare void @mocha_sort_float(%MochaArray*)",
                "declare void @mocha_sort_str(%MochaArray*)",
                "declare void @mocha_sort_int_cmp(%MochaArray*, i8 (i8*, i8*)*)",
                "declare void @mocha_sort_float_cmp(%MochaArray*, i8 (i8*, i8*)*)",
                "declare void @mocha_sort_str_cmp(%MochaArray*, i8 (i8*, i8*)*)",
                "%MochaClosureBundle = type { i8*, i8*, i32 }",
                "declare i32 @mocha_call_lambda_int(%MochaClosureBundle*, i8*, i8*)",
                "declare double @mocha_call_lambda_float(%MochaClosureBundle*, i8*, i8*)",
                "declare i8* @mocha_call_lambda_str(%MochaClosureBundle*, i8*, i8*)",
                "declare i8 @mocha_call_lambda_bool(%MochaClosureBundle*, i8*)",
                "declare void @mocha_sort_int_cmp_env(%MochaArray*, %MochaClosureBundle*)",
                "declare void @mocha_sort_float_cmp_env(%MochaArray*, %MochaClosureBundle*)",
                "declare void @mocha_sort_str_cmp_env(%MochaArray*, %MochaClosureBundle*)"
            ],

            "Dict Runtime": [
                "%MochaDict = type { i8*, i32, i32 }",
                "declare %MochaDict* @mocha_dict_new()",
                "declare void @mocha_dict_set_int(%MochaDict*, i8*, i32)",
                "declare void @mocha_dict_set_float(%MochaDict*, i8*, double)",
                "declare void @mocha_dict_set_str(%MochaDict*, i8*, i8*)",
                "declare void @mocha_dict_set_bool(%MochaDict*, i8*, i8)",
                "declare void @mocha_dict_set_dict(%MochaDict*, i8*, %MochaDict*)",
                "declare void @mocha_dict_set_vast(%MochaDict*, i8*, i64)",
                "declare void @mocha_dict_set_object(%MochaDict*, i8*, i8*)",
                "declare i8* @mocha_dict_get(%MochaDict*, i8*)",
                "declare i8* @mocha_dict_get_typed(%MochaDict*, i8*, i32)",
                "declare i32 @mocha_dict_get_type(%MochaDict*, i8*)",
                "declare i8 @mocha_dict_has(%MochaDict*, i8*)",
                "declare void @mocha_dict_remove(%MochaDict*, i8*)",
                "declare void @mocha_dict_clean(%MochaDict*)",
                "declare i32 @mocha_dict_length(%MochaDict*)",
                "declare %MochaArray* @mocha_dict_allkeys(%MochaDict*)",
                "declare %MochaArray* @mocha_dict_allvalues(%MochaDict*)",
                "declare %MochaDict* @mocha_dict_get_dict(%MochaDict*, i8*)",
                "declare void @mocha_dict_print_value(%MochaDict*, i8*, i8)",
                "declare i64 @mocha_str_to_vast(i8*)",
                "declare %MochaDict* @mocha_dict_merge(%MochaDict*, %MochaDict*, i8)",
            ],

            "Set Runtime": [
                "%MochaSet = type { i8*, i32, i32, i32, i32 }",
                "declare %MochaSet* @mocha_set_new(i32)",
                "declare void @mocha_set_insert(%MochaSet*, i8*)",
                "declare void @mocha_set_delete(%MochaSet*, i8*)",
                "declare i8 @mocha_set_has(%MochaSet*, i8*)",
                "declare i32 @mocha_set_size(%MochaSet*)",
                "declare void @mocha_set_clean(%MochaSet*)",
                "declare void @mocha_set_retype(%MochaSet*, i32)",
                "declare void @mocha_set_negate(%MochaSet*)",
                "declare i8 @mocha_set_complement_has(%MochaSet*, i32)",
                "declare void @mocha_set_get(%MochaSet*, i32, i8*)",
                "declare %MochaSet* @mocha_set_union(%MochaSet*, %MochaSet*)",
                "declare %MochaSet* @mocha_set_intersect(%MochaSet*, %MochaSet*)",
                "declare %MochaSet* @mocha_set_xor(%MochaSet*, %MochaSet*)",
                "declare %MochaSet* @mocha_set_rel_diff(%MochaSet*, %MochaSet*)",
                "declare i32    @mocha_set_min_int(%MochaSet*)",
                "declare double @mocha_set_min_float(%MochaSet*)",
                "declare i64    @mocha_set_min_vast(%MochaSet*)",
                "declare i8*    @mocha_set_min_str(%MochaSet*)",
                "declare i32    @mocha_set_max_int(%MochaSet*)",
                "declare double @mocha_set_max_float(%MochaSet*)",
                "declare i64    @mocha_set_max_vast(%MochaSet*)",
                "declare i8*    @mocha_set_max_str(%MochaSet*)",
            ],

            "StringBuilder Runtime": [
                "%struct.MochaStringBuilder = type { i8*, i32, i32 }",
                "declare %struct.MochaStringBuilder* @mocha_sb_new()",
                "declare void @mocha_sb_append(%struct.MochaStringBuilder*, i8*)",
                "declare i8* @mocha_sb_tostring(%struct.MochaStringBuilder*)",
                "declare i8* @mocha_sb_reverse(%struct.MochaStringBuilder*)",
                "declare void @mocha_sb_clear(%struct.MochaStringBuilder*)",
                "declare i32 @mocha_sb_length(%struct.MochaStringBuilder*)",
                "declare void @mocha_sb_free(%struct.MochaStringBuilder*)",
            ],

            "Complex Runtime": [
                "%struct.MochaComplex = type { double, double }",
                "declare %struct.MochaComplex* @mocha_complex_new(double, double)",
                "declare %struct.MochaComplex* @mocha_complex_add(%struct.MochaComplex*, %struct.MochaComplex*)",
                "declare %struct.MochaComplex* @mocha_complex_sub(%struct.MochaComplex*, %struct.MochaComplex*)",
                "declare %struct.MochaComplex* @mocha_complex_mul(%struct.MochaComplex*, %struct.MochaComplex*)",
                "declare %struct.MochaComplex* @mocha_complex_div(%struct.MochaComplex*, %struct.MochaComplex*)",
                "declare double @mocha_complex_abs(%struct.MochaComplex*)",
                "declare i8* @mocha_complex_tostring(%struct.MochaComplex*)",
                "declare %struct.MochaComplex* @mocha_complex_conjugate(%struct.MochaComplex*)",
            ],
            "I/O": [
                "declare i8* @mocha_tell(i8*)",
            ],
            "File I/O": [
                "%struct.MochaFile = type { i8*, i8*, i8*, i8 }",
                "declare %struct.MochaFile* @mocha_file_open(i8*, i8*)",
                "declare i8*  @mocha_file_read(%struct.MochaFile*)",
                "declare i8*  @mocha_file_readline(%struct.MochaFile*)",
                "declare void @mocha_file_write(%struct.MochaFile*, i8*)",
                "declare void @mocha_file_close(%struct.MochaFile*)",
                "declare i8   @mocha_file_exists(i8*)",
            ],

            "HashTable Runtime": [
                "%struct.MochaHashTable = type { i8*, i32, i32, i32 }",
                "declare %struct.MochaHashTable* @mocha_ht_new()",
                "declare void @mocha_ht_put(%struct.MochaHashTable*, i8*, i8*)",
                "declare i8*  @mocha_ht_get(%struct.MochaHashTable*, i8*)",
                "declare i8   @mocha_ht_has(%struct.MochaHashTable*, i8*)",
                "declare void @mocha_ht_remove(%struct.MochaHashTable*, i8*)",
                "declare i32  @mocha_ht_size(%struct.MochaHashTable*)",
                "declare void @mocha_ht_clear(%struct.MochaHashTable*)",
                "declare %MochaArray* @mocha_ht_keys(%struct.MochaHashTable*)",
                "declare %MochaArray* @mocha_ht_values(%struct.MochaHashTable*)",
                "declare void @mocha_ht_free(%struct.MochaHashTable*)",
            ],

            "Exception-Handling Runtime": [
                "%MochaExFrame = type opaque",
                "declare %MochaExFrame* @mocha_ex_push() nounwind",
                "declare void @mocha_ex_enter(%MochaExFrame*)",
                "declare i32 @mocha_ex_did_land() nounwind",
                "declare void @mocha_ex_throw(i8*) noreturn",
                "declare i8* @mocha_ex_pop() nounwind",
                "declare void @mocha_ex_rethrow() noreturn",
            ],

            "Runtime Stack Tracking": [
                "declare void @mocha_stack_push(i8*, i8*, i32) nounwind",
                "declare void @mocha_stack_pop() nounwind",
                "declare void @mocha_stack_update_line(i32) nounwind",
                "declare void @mocha_stack_print() nounwind",
            ],
        }

        header = [
            "; Mocha compiled output",
            "; Generated by Mocha Compiler",
            "",
        ]

        # Extra declares from imported libs
        for decl in self.extra_declares:
            # Extract function name from declare string
            # e.g. "declare double @mocha_wrap_hypot(double, double)"
            decl_name = decl.split("@")[1].split("(")[0] if "@" in decl else ""
            if decl_name not in STDLIB_NAMES:
                header.append(decl)

        for section, decls in sections.items():
            header.append(f"; {'='*50}")
            header.append(f"; {section}")
            header.append(f"; {'='*50}")
            for decl in decls:
                header.append(decl)
            header.append("")

        return header

    def get_ir(self) -> str:
        header = self.build_header()

        # Type declarations go right after header, before everything else
        type_decls = []
        if self.type_declarations:
            type_decls = self.type_declarations + ['']

        if self.lib_functions:
            header.append('; External library functions')
            seen_decls = set()
            
            # collect what extra_declares already emitted
            for decl in self.extra_declares:
                if "@" in decl:
                    seen_decls.add(decl.split("@")[1].split("(")[0])
            
            for _, info in self.lib_functions.items():
                func_name, ret_llvm, llvm_params = info[0], info[1], info[2]
                if func_name in seen_decls or func_name in STDLIB_NAMES:
                    continue
                seen_decls.add(func_name)
                param_str = ", ".join(llvm_params)
                header.append(f'declare {ret_llvm} @{func_name}({param_str})')

        if self.string_consts:
            header.append('; String constants')
            for name, (escaped, length) in self.string_consts.items():
                header.append(
                    f'{name} = private unnamed_addr constant '
                    f'[{length} x i8] c"{escaped}\\00"'
                )

            header.append('')

        lambda_funcs = getattr(self, 'lambda_functions', [])
        return '\n'.join(header + type_decls + lambda_funcs + self.output)
    # -------------------------------------------------------
    # Expressions
    # -------------------------------------------------------

    def gen_expr(self, node: Node) -> tuple:
        if isinstance(node, IntLiteral):    return self.gen_int_literal(node)
        if isinstance(node, FloatLiteral):  return self.gen_float_literal(node)
        if isinstance(node, ComplexLiteral):
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %struct.MochaComplex* @mocha_complex_new(double {node.real}, double {node.imag})")
            return (tmp, "%struct.MochaComplex*")
        if isinstance(node, BoolLiteral):   return self.gen_bool_literal(node)
        if isinstance(node, StrLiteral):    return self.gen_str_literal(node)
        if isinstance(node, NullLiteral):   return ("null", "i8*")
        if isinstance(node, DictLiteral): return self.gen_dict_literal(node)
        if isinstance(node, Identifier):    return self.gen_identifier(node)
        if isinstance(node, BinaryOp):      return self.gen_binary_op(node)
        if isinstance(node, UnaryOp):       return self.gen_unary_op(node)
        if isinstance(node, PostIncrement): return self.gen_post_increment(node) # type: ignore
        if isinstance(node, PreIncrement):  return self.gen_pre_increment(node) # type: ignore
        if isinstance(node, PreDecrement):  return self.gen_pre_increment(node) # type: ignore
        if isinstance(node, TypeCast):      return self.gen_type_cast(node)
        if isinstance(node, FunctionCall):  return self.gen_function_call(node)
        if isinstance(node, QualifiedMethodCall): return self.gen_qualified_method_call(node)
        if isinstance(node, OkExpr):        return self.gen_expr(node.value)
        if isinstance(node, MemberAccess):  return self.gen_member_access(node)
        if isinstance(node, ArrayLiteral):  return self.gen_array_literal(node)
        if isinstance(node, IndexAccess):   return self.gen_index_access(node)
        if isinstance(node, Index2DAccess): return self.gen_index2d_access(node)
        if isinstance(node, RowSlice):      return self.gen_row_slice(node)
        if isinstance(node, ColSlice):      return self.gen_col_slice(node)
        if isinstance(node, TupleLiteral): return self.gen_tuple_literal(node)
        if isinstance(node, TupleAccess):  return self.gen_tuple_access(node)
        if isinstance(node, SetLiteral): return self.gen_set_literal(node)
        if isinstance(node, LambdaExpr): return self.gen_lambda(node)
        if isinstance(node, LibQualifiedCall): return self.gen_lib_qualified_call(node)
        if isinstance(node, AllocArray): return self.gen_alloc_array(node)
        if isinstance(node, ListComprehension): return self.gen_list_comprehension(node)
        if isinstance(node, TagAccess):
            key = f"{node.tag_name}.{node.member_name}"
            if key in self.globals:
                global_name, _ = self.globals[key]
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = load i32, i32* {global_name}")
                return (tmp, "i32")
            return ("0", "i32")
        if isinstance(node, ErrorExpr):
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = add i32 0, -1")
            return (tmp, "i32")
        raise MochaCodeGenError(f"Cannot generate code for: {type(node).__name__}", node.line, node.col)
    
    def box_value(self, val_reg: str, val_type: str) -> str:
        """Box a value into i8* for runtime calls (alloca → store → bitcast)."""
        slot = self.fresh_temp()
        cast = self.fresh_temp()
        self.emit(f"  {slot} = alloca {val_type}")
        self.emit(f"  store {val_type} {val_reg}, {val_type}* {slot}")
        self.emit(f"  {cast} = bitcast {val_type}* {slot} to i8*")
        return cast

    def gen_int_literal(self, node):
        tmp = self.fresh_temp()
        # If value exceeds i32 range, emit as i64 directly
        if node.value > 2147483647 or node.value < -2147483648:
            self.emit(f"  {tmp} = add i64 0, {node.value}")
            return (tmp, "i64")
        self.emit(f"  {tmp} = add i32 0, {node.value}")
        return (tmp, "i32")

    def gen_float_literal(self, node):
        tmp = self.fresh_temp()
        value = float(node.value)
        llvm_val = f"{value:.20f}"
        # strip trailing zeros but keep at least one decimal place
        llvm_val = llvm_val.rstrip('0').rstrip('.')
        if '.' not in llvm_val:
            llvm_val += '.0'
        self.emit(f"  {tmp} = fadd double 0.0, {llvm_val}")
        return (tmp, "double")

    def gen_bool_literal(self, node):
        tmp = self.fresh_temp()
        self.emit(f"  {tmp} = add i8 0, {1 if node.value else 0}")
        return (tmp, "i8")

    def gen_str_literal(self, node):
        gname  = self.fresh_str_global(node.value)
        length = len(node.value.encode('utf-8')) + 1  # byte length, not char length
        tptr   = self.fresh_temp()
        tstr   = self.fresh_temp()
        self.emit(f"  {tptr} = getelementptr [{length} x i8], [{length} x i8]* {gname}, i32 0, i32 0")
        self.emit(f"  {tstr} = call i8* @mocha_str_literal(i8* {tptr})")
        return (tstr, "i8*")

    def gen_identifier(self, node):
        # Check global lib constants (syntax 2/3 imports)
        if node.name in self.lib_constants:
            val, llvm_type = self.lib_constants[node.name]
            tmp = self.fresh_temp()
            if llvm_type == "double":
                self.emit(f"  {tmp} = fadd double 0.0, {val}")
            elif llvm_type == "i32":
                self.emit(f"  {tmp} = add i32 0, {val}")
            else:
                self.emit(f"  {tmp} = add i32 0, {val}")
            return (tmp, llvm_type)

        # FIX: check locals FIRST
        if node.name in self.locals:
            ptr, llvm_type = self.locals[node.name]
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = load {llvm_type}, {llvm_type}* {ptr}")
            return (tmp, llvm_type)

        # THEN globals
        if node.name in self.globals:
            ptr, llvm_type = self.globals[node.name]
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = load {llvm_type}, {llvm_type}* {ptr}")
            return (tmp, llvm_type)

        raise MochaCodeGenError(f"Undeclared variable: '{node.name}'", node.line, node.col)

    def infer_mocha_type(self, node):
        if isinstance(node, Identifier):
            if node.name == "this" and self.current_class:
                return self.current_class
            return self.local_mocha_types.get(node.name, "")
        if isinstance(node, MemberAccess):
            obj_mocha = self.infer_mocha_type(node.obj)
            base = obj_mocha.replace("[]", "").strip()
            for fname, ftype in self.class_mocha_fields.get(base, []):
                if fname == node.member:
                    return ftype
        if isinstance(node, IndexAccess):
            arr_mocha = self.infer_mocha_type(node.obj)
            return arr_mocha.replace("[]", "").strip()
        return ""
    
    def gen_member_access(self, node):
        if isinstance(node.obj, Identifier):
            lib_key = f"{node.obj.name}.{node.member}"
            if lib_key in self.lib_constants:
                const_val, const_llvm = self.lib_constants[lib_key]
                tmp = self.fresh_temp()
                if const_llvm == "double":
                    self.emit(f"  {tmp} = fadd double 0.0, {const_val}")
                else:
                    self.emit(f"  {tmp} = add i32 0, {const_val}")
                return (tmp, const_llvm)
            
            # Tag access: Color.GREEN, TokenType.PLUS etc.
            if node.obj.name in _tag_types_registry:
                key = f"{node.obj.name}.{node.member}"
                if key in self.globals:
                    global_name, _ = self.globals[key]
                    tmp = self.fresh_temp()
                    self.emit(f"  {tmp} = load i32, i32* {global_name}")
                    return (tmp, "i32")
                return ("0", "i32")
            
        obj_reg, obj_type = self.gen_expr(node.obj)

        # String length
        if obj_type == "i8*" and node.member == "length":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i32 @mocha_str_length(i8* {obj_reg})")
            return (tmp, "i32")
        
        # String charAt
        if obj_type == "i8*" and node.member == "charAt":
            return (obj_reg, "i8*")  # partial — args handled in gen_function_call

        # Array built-ins
        if obj_type == "%MochaArray*":
            if node.member == "length":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i32 @mocha_array_length(%MochaArray* {obj_reg})")
                return (tmp, "i32")
            # push and pop handled in gen_function_call, not here

        if obj_type == "%MochaArray2D*":
            if node.member == "rows" or node.member == "length":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i32 @mocha_array2d_rows(%MochaArray2D* {obj_reg})")
                return (tmp, "i32")
            if node.member == "cols":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i32 @mocha_array2d_cols(%MochaArray2D* {obj_reg})")
                return (tmp, "i32")
            
        # Dict built-ins
        if obj_type == "%MochaDict*":
            if node.member == "length":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i32 @mocha_dict_length(%MochaDict* {obj_reg})")
                return (tmp, "i32")
            if node.member == "allKeys":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call %MochaArray* @mocha_dict_allkeys(%MochaDict* {obj_reg})")
                return (tmp, "%MochaArray*")
            if node.member == "allValues":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call %MochaArray* @mocha_dict_allvalues(%MochaDict* {obj_reg})")
                return (tmp, "%MochaArray*")
            
        # Set built-ins
        if obj_type == "%MochaSet*":
            if node.member == "size":
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i32 @mocha_set_size(%MochaSet* {obj_reg})")
                return (tmp, "i32")
        
        if obj_type == "%struct.MochaComplex*" and node.member in ("real", "imag"):
            idx = 0 if node.member == "real" else 1
            tmp_ptr = self.fresh_temp()
            tmp_val = self.fresh_temp()
            self.emit(f"  {tmp_ptr} = getelementptr %struct.MochaComplex, %struct.MochaComplex* {obj_reg}, i32 0, i32 {idx}")
            self.emit(f"  {tmp_val} = load double, double* {tmp_ptr}")
            return (tmp_val, "double")

        # Extract class name from "%struct.BankAccount*"
        if obj_type.startswith("%struct.") and obj_type.endswith("*"):
            class_name = obj_type[len("%struct."):-1]
            fields     = self.class_fields.get(class_name, [])

            for idx, (fname, ftype) in enumerate(fields):
                if fname == node.member:
                    ptr = self.fresh_temp()
                    tmp = self.fresh_temp()
                    llvm_ftype = ftype if ftype.startswith("%") or ftype in ("i32", "i64", "double", "i8", "i8*", "void") else to_llvm_type(ftype)  # ← convert here
                    self.emit(
                        f"  {ptr} = getelementptr %struct.{class_name}, "
                        f"%struct.{class_name}* {obj_reg}, i32 0, i32 {idx}"
                    )
                    self.emit(f"  {tmp} = load {llvm_ftype}, {llvm_ftype}* {ptr}")
                    return (tmp, llvm_ftype)  # ← return llvm type too
        
        # Tag .name on any i32 result
        if obj_type == "i32" and node.member == "name":
            tag_type = self.infer_mocha_type(node.obj)
            if tag_type in _tag_types_registry:
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i8* @{tag_type}__name(i32 {obj_reg})")
                return (tmp, "i8*")

        # Fallback for unknown members
        tmp = self.fresh_temp()
        self.emit(f"  {tmp} = add i32 0, 0  ; unknown member '{node.member}'")
        return (tmp, "i32")

    def gen_binary_op(self, node):
        left_reg,  left_type  = self.gen_expr(node.left)
        tmp      = self.fresh_temp()
        op_kind = getattr(node, "op_kind", None)
        # SHORT CIRCUIT — must happen before right is evaluated
        if op_kind == "bool_and":
            result_ptr = self.fresh_temp()
            self.emit(f"  {result_ptr} = alloca i8")
            self.emit(f"  store i8 0, i8* {result_ptr}")
            left_i1 = self.fresh_temp()
            if left_type == "i8":
                self.emit(f"  {left_i1} = trunc i8 {left_reg} to i1")
            else:
                left_i1 = left_reg
            lbl_right = self.fresh_label("and_right")
            lbl_done = self.fresh_label("and_done")
            self.emit(f"  br i1 {left_i1}, label %{lbl_right}, label %{lbl_done}")
            self.emit(f"{lbl_right}:")
            right_reg, right_type = self.gen_expr(node.right)
            if right_type == "i1":
                p = self.fresh_temp()
                self.emit(f"  {p} = zext i1 {right_reg} to i8")
                right_reg = p
            self.emit(f"  store i8 {right_reg}, i8* {result_ptr}")
            self.emit(f"  br label %{lbl_done}")
            self.emit(f"{lbl_done}:")
            self.emit(f"  {tmp} = load i8, i8* {result_ptr}")
            return (tmp, "i8")

        if op_kind == "bool_or":
            result_ptr = self.fresh_temp()
            self.emit(f"  {result_ptr} = alloca i8")
            self.emit(f"  store i8 1, i8* {result_ptr}")
            left_i1 = self.fresh_temp()
            if left_type == "i8":
                self.emit(f"  {left_i1} = trunc i8 {left_reg} to i1")
            else:
                left_i1 = left_reg
            lbl_right = self.fresh_label("or_right")
            lbl_done = self.fresh_label("or_done")
            self.emit(f"  br i1 {left_i1}, label %{lbl_done}, label %{lbl_right}")
            self.emit(f"{lbl_right}:")
            right_reg, right_type = self.gen_expr(node.right)
            if right_type == "i1":
                p = self.fresh_temp()
                self.emit(f"  {p} = zext i1 {right_reg} to i8")
                right_reg = p
            self.emit(f"  store i8 {right_reg}, i8* {result_ptr}")
            self.emit(f"  br label %{lbl_done}")
            self.emit(f"{lbl_done}:")
            self.emit(f"  {tmp} = load i8, i8* {result_ptr}")
            return (tmp, "i8")
        right_reg, right_type = self.gen_expr(node.right)
        
        # ===== DISPATCH BASED ON op_kind =====
        #Complex ops
        if op_kind in ("complex_add", "complex_sub", "complex_mul", "complex_div"):
            op_map = {
                "complex_add": "mocha_complex_add",
                "complex_sub": "mocha_complex_sub",
                "complex_mul": "mocha_complex_mul",
                "complex_div": "mocha_complex_div",
            }
            # Promote int/float operand to Complex if needed
            def to_complex(reg, typ):
                if typ == "%struct.MochaComplex*":
                    return reg
                # wrap scalar as Complex(x, 0.0)
                if typ == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sitofp i32 {reg} to double")
                    reg = p
                c = self.fresh_temp()
                self.emit(f"  {c} = call %struct.MochaComplex* @mocha_complex_new(double {reg}, double 0.0)")
                return c

            l = to_complex(left_reg, left_type)
            r = to_complex(right_reg, right_type)
            c_func = op_map[op_kind]
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %struct.MochaComplex* @{c_func}(%struct.MochaComplex* {l}, %struct.MochaComplex* {r})")
            return (tmp, "%struct.MochaComplex*")
        
        # FLOAT OPS
        if op_kind in ("float_add", "float_sub", "float_mul", "float_div", "float_mod"):
            # --- PROMOTION: int → double if needed ---
            if left_type != right_type:
                if left_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sitofp i32 {left_reg} to double")
                    left_reg = p
                    left_type = "double"
                if right_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sitofp i32 {right_reg} to double")
                    right_reg = p
                    right_type = "double"

            fn_map = {
                "float_add": "mocha_float_add",
                "float_sub": "mocha_float_sub",
                "float_mul": "mocha_float_mul",
                "float_div": "mocha_float_div",
                "float_mod": "mocha_float_mod",
            }

            fn = fn_map[op_kind]
            self.emit(f"  {tmp} = call double @{fn}(double {left_reg}, double {right_reg})")
            return (tmp, "double")

        # VAST (i64)
        if op_kind in ("vast_add", "vast_sub", "vast_mul", "vast_div", "vast_mod"):
            # --- PROMOTION: i32 → i64 if needed ---
            if left_type != right_type:
                if left_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sext i32 {left_reg} to i64")
                    left_reg = p
                    left_type = "i64"
                if right_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sext i32 {right_reg} to i64")
                    right_reg = p
                    right_type = "i64"

            ops = {
                "vast_add": "add",
                "vast_sub": "sub",
                "vast_mul": "mul",
                "vast_div": "sdiv",
                "vast_mod": "srem",
            }

            instr = ops[op_kind]
            self.emit(f"  {tmp} = {instr} i64 {left_reg}, {right_reg}")
            return (tmp, "i64")


        # INT (i32) or mixed with vast
        if op_kind in ("int_add", "int_sub", "int_mul", "int_div", "int_mod"):
            # --- Promote to i64 if one operand is vast ---
            if left_type == "i64" or right_type == "i64":
                # promote i32 → i64
                if left_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sext i32 {left_reg} to i64")
                    left_reg = p
                    left_type = "i64"
                if right_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sext i32 {right_reg} to i64")
                    right_reg = p
                    right_type = "i64"

                instr = {
                    "int_add": "add",
                    "int_sub": "sub",
                    "int_mul": "mul",
                    "int_div": "sdiv",
                    "int_mod": "srem",
                }[op_kind]
                self.emit(f"  {tmp} = {instr} i64 {left_reg}, {right_reg}")
                return (tmp, "i64")

            # --- Normal i32 add/sub/mul/div/mod ---
            instr = {
                "int_add": "add",
                "int_sub": "sub",
                "int_mul": "mul",
                "int_div": "sdiv",
                "int_mod": "srem",
            }[op_kind]
            self.emit(f"  {tmp} = {instr} i32 {left_reg}, {right_reg}")
            return (tmp, "i32")

        #------------- ARITHEMETIC OVER -------------#

        # --- STRING OPERATIONS ---
        if op_kind == "string_concat":
            self.emit(f"  {tmp} = call i8* @mocha_str_concat(i8* {left_reg}, i8* {right_reg})")
            return (tmp, "i8*")
        
        # STRING EQUALITY / INEQUALITY
        if op_kind in ("str_eq", "str_ne"):
            cmp = self.fresh_temp()
            self.emit(f"  {cmp} = call i32 @mocha_str_eq(i8* {left_reg}, i8* {right_reg})")
            result = self.fresh_temp()
            if op_kind == "str_eq":
                self.emit(f"  {result} = icmp ne i32 {cmp}, 0")
            else:
                self.emit(f"  {result} = icmp eq i32 {cmp}, 0")
            ext = self.fresh_temp()
            self.emit(f"  {ext} = zext i1 {result} to i8")
            return (ext, "i8")

        if op_kind in ("str_<", "str_>", "str_<=", "str_>="):
            cmp = self.fresh_temp()
            self.emit(f"  {cmp} = call i32 @strcmp(i8* {left_reg}, i8* {right_reg})")
            result = self.fresh_temp()
            cmp_map_str = {
                "str_<":  "icmp slt",
                "str_>":  "icmp sgt",
                "str_<=": "icmp sle",
                "str_>=": "icmp sge",
            }
            self.emit(f"  {result} = {cmp_map_str[op_kind]} i32 {cmp}, 0")
            return (result, "i1")

        # --- NUMERIC & BOOL COMPARISONS ---
        cmp_map = {
            # INT
            "int_eq": "icmp eq", "int_ne": "icmp ne", "int_<": "icmp slt",
            "int_>": "icmp sgt", "int_<=": "icmp sle", "int_>=": "icmp sge",

            # FLOAT
            "float_eq": "fcmp oeq", "float_ne": "fcmp one", "float_<": "fcmp olt",
            "float_>": "fcmp ogt", "float_<=": "fcmp ole", "float_>=": "fcmp oge",

            # VAST
            "vast_eq": "icmp eq", "vast_ne": "icmp ne", "vast_<": "icmp slt",
            "vast_>": "icmp sgt", "vast_<=": "icmp sle", "vast_>=": "icmp sge",

            # BOOL
            "bool_eq": "icmp eq", "bool_ne": "icmp ne",
            "bool_<": "icmp slt", "bool_>": "icmp sgt",
            "bool_<=": "icmp sle", "bool_>=": "icmp sge",
        }

        if op_kind in cmp_map:
            instr = cmp_map[op_kind]

            # PROMOTE i32 → double for floats (centralized block)
            if op_kind.startswith("float_"):
                if left_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sitofp i32 {left_reg} to double")
                    left_reg = p
                if right_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sitofp i32 {right_reg} to double")
                    right_reg = p
                self.emit(f"  {tmp} = {instr} double {left_reg}, {right_reg}")
            else:
                # Promote i32 → i64 for vast comparisons
                if left_type == "i64" and right_type == "i32":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sext i32 {right_reg} to i64")
                    right_reg = p
                    right_type = "i64"
                elif left_type == "i32" and right_type == "i64":
                    p = self.fresh_temp()
                    self.emit(f"  {p} = sext i32 {left_reg} to i64")
                    left_reg = p
                    left_type = "i64"

                ltype = left_type if left_type != "i1" else "i8"
                self.emit(f"  {tmp} = {instr} {ltype} {left_reg}, {right_reg}")
            
            return (tmp, "i1")

        # --- FALLBACK ---
        raise MochaCodeGenError(f"Unknown binary operator: '{op_kind}'", node.line, node.col)

    def gen_unary_op(self, node):
        right_reg, right_type = self.gen_expr(node.right)
        tmp = self.fresh_temp()
        if node.op == "!":
            self.emit(f"  {tmp} = xor i8 {right_reg}, 1")
            return (tmp, "i8")
        if node.op == "-":
            if right_type == "double":
                self.emit(f"  {tmp} = fneg double {right_reg}")
            elif right_type == "i64":
                self.emit(f"  {tmp} = sub i64 0, {right_reg}")
            else:
                self.emit(f"  {tmp} = sub i32 0, {right_reg}")
            return (tmp, right_type)
        raise MochaCodeGenError(f"Unknown unary operator: '{node.op}'", node.line, node.col)

    def resolve_lvalue_ptr(self, node):
        """
        Returns one of:
        ("local", ptr, llvm_type)          — simple variable
        ("field", ptr, llvm_type)          — struct field via GEP
        ("array", arr_reg, idx_reg, elem_llvm)  — runtime-managed array element
        """
        if isinstance(node, Identifier):
            ptr, llvm_type = self.locals[node.name]
            return ("local", ptr, llvm_type)

        if isinstance(node, MemberAccess):
            obj_val, obj_llvm = self.gen_expr(node.obj)
            class_name = obj_llvm.replace("%struct.", "").replace("*", "").strip()
            fields = self.class_fields.get(class_name, [])
            idx = next((i for i, (n, _) in enumerate(fields) if n == node.member), None)
            if idx is None:
                raise MochaCodeGenError(
                    f"Internal compiler error: field '{node.member}' not found on '{class_name}'",
                    node.line, node.col
                )
            field_type = to_llvm_type(fields[idx][1])
            ptr = self.fresh_temp()
            self.emit(f"  {ptr} = getelementptr %struct.{class_name}, %struct.{class_name}* {obj_val}, i32 0, i32 {idx}")
            return ("field", ptr, field_type)

        if isinstance(node, IndexAccess):
            arr_reg, _ = self.gen_expr(node.obj)
            idx_reg, _ = self.gen_expr(node.index)
            # Resolve element llvm type same way gen_index_access does
            mocha_type = self.infer_mocha_type(node.obj)
            if not mocha_type and isinstance(node.obj, Identifier):
                mocha_type = self.local_mocha_types.get(node.obj.name, "") or \
                            self.global_mocha_types.get(node.obj.name, "")
            elem_llvm = "i32"
            if mocha_type:
                bracket = mocha_type.rfind("[")
                if bracket != -1:
                    elem_mocha = mocha_type[:bracket]
                    elem_llvm = to_llvm_type(elem_mocha)
            return ("array", arr_reg, idx_reg, elem_llvm)

        raise MochaCodeGenError(
            "Internal compiler error: invalid increment/decrement target",
            node.line, node.col
        )


    def _emit_increment(self, node, return_old: bool):
        lval = self.resolve_lvalue_ptr(node.operand)
        op = "add" if node.op == "++" else "sub"

        if lval[0] in ("local", "field"):
            ptr, llvm_type = lval[1], lval[2]
            old = self.fresh_temp()
            self.emit(f"  {old} = load {llvm_type}, {llvm_type}* {ptr}")
            new = self.fresh_temp()
            self.emit(f"  {new} = {op} {llvm_type} {old}, 1")
            self.emit(f"  store {llvm_type} {new}, {llvm_type}* {ptr}")
            return (old if return_old else new, llvm_type)

        if lval[0] == "array":
            arr_reg, idx_reg, elem_llvm = lval[1], lval[2], lval[3]
            slot = self.alloca_at_entry(elem_llvm)
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {elem_llvm}* {slot} to i8*")
            self.emit(f"  call void @mocha_array_get(%MochaArray* {arr_reg}, i32 {idx_reg}, i8* {cast})")
            old = self.fresh_temp()
            self.emit(f"  {old} = load {elem_llvm}, {elem_llvm}* {slot}")
            new = self.fresh_temp()
            self.emit(f"  {new} = {op} {elem_llvm} {old}, 1")
            self.emit(f"  store {elem_llvm} {new}, {elem_llvm}* {slot}")
            cast2 = self.fresh_temp()
            self.emit(f"  {cast2} = bitcast {elem_llvm}* {slot} to i8*")
            self.emit(f"  call void @mocha_array_set(%MochaArray* {arr_reg}, i32 {idx_reg}, i8* {cast2})")
            return (old if return_old else new, elem_llvm)

    def gen_post_increment(self, node):
        return self._emit_increment(node, return_old=True)

    def gen_pre_increment(self, node):
        return self._emit_increment(node, return_old=False)

    def gen_type_cast(self, node):
        val_reg, val_type = self.gen_expr(node.value)
        target = to_llvm_type(node.to_type)
        tmp    = self.fresh_temp()

        # int → float
        if val_type == "i32" and target == "double":
            self.emit(f"  {tmp} = sitofp i32 {val_reg} to double")
        # float → int (truncate)
        elif val_type == "double" and target == "i32":
            self.emit(f"  {tmp} = fptosi double {val_reg} to i32")
        # int → bool (0 = false, anything else = true)
        elif val_type == "i32" and target == "i8":
            cmp = self.fresh_temp()
            self.emit(f"  {cmp} = icmp ne i32 {val_reg}, 0")
            self.emit(f"  {tmp} = zext i1 {cmp} to i8")
        # bool → int (zero-extend)
        elif val_type == "i8" and target == "i32":
            self.emit(f"  {tmp} = zext i8 {val_reg} to i32")
        # bool → float
        elif val_type == "i8" and target == "double":
            self.emit(f"  {tmp} = uitofp i8 {val_reg} to double")
        # bool → str ("true" / "false")
        elif val_type == "i8" and target == "i8*":
            self.emit(f"  {tmp} = call i8* @mocha_bool_to_str(i8 {val_reg})")
        # i1 → str (comparison result, zext to i8 first)
        elif val_type == "i1" and target == "i8*":
            zext = self.fresh_temp()
            self.emit(f"  {zext} = zext i1 {val_reg} to i8")
            self.emit(f"  {tmp} = call i8* @mocha_bool_to_str(i8 {zext})")
        # int → int (no-op, just copy)
        elif val_type == "i32" and target == "i32":
            self.emit(f"  {tmp} = add i32 {val_reg}, 0")
        # int → vast (sign-extend to 64-bit)
        elif val_type == "i32" and target == "i64":
            self.emit(f"  {tmp} = sext i32 {val_reg} to i64")
        # float → str (via runtime)
        elif val_type == "double" and target == "i8*":
            self.emit(f"  {tmp} = call i8* @mocha_float_to_str(double {val_reg})")
        # str → str (already a pointer, no-op)
        elif val_type == "i8*" and target == "i8*":
            self.emit(f"  {tmp} = bitcast i8* {val_reg} to i8*")
        # str → vast (parse string as 64-bit int via runtime)
        elif val_type == "i8*" and target == "i64":
            self.emit(f"  {tmp} = call i64 @mocha_str_to_vast(i8* {val_reg})")
        # vast → float (numeric conversion, may lose precision for very large values)
        elif val_type == "i64" and target == "double":
            self.emit(f"  {tmp} = sitofp i64 {val_reg} to double")
        # vast → int (truncate upper 32 bits — may lose data!)
        elif val_type == "i64" and target == "i32":
            self.emit(f"  {tmp} = trunc i64 {val_reg} to i32")
        # vast → bool (truncate to 1 byte)
        elif val_type == "i64" and target == "i8":
            self.emit(f"  {tmp} = trunc i64 {val_reg} to i8")
        # vast → str (via runtime)
        elif val_type == "i64" and target == "i8*":
            self.emit(f"  {tmp} = call i8* @mocha_vast_to_str(i64 {val_reg})")
        # int → str (via runtime)
        elif val_type == "i32" and target == "i8*":
            self.emit(f"  {tmp} = call i8* @mocha_int_to_str(i32 {val_reg})")
        # any remaining → str (assume int, convert via runtime)
        elif target == "i8*":
            self.emit(f"  {tmp} = call i8* @mocha_int_to_str(i32 {val_reg})")
        # fallback — raw bitcast (unsafe, last resort)
        else:
            self.emit(f"  {tmp} = bitcast {val_type} {val_reg} to {target}")

        return (tmp, target)
    
    
    def gen_array_method_call(self, arr_reg, member, node, obj_name=None):
        # ---------------- BUILT-INS ---------------- #

        if member == "push":
            start = False
            val_arg = None

            for arg in node.args:
                if isinstance(arg, Assignment) and isinstance(arg.target, Identifier):
                    if arg.target.name == "start" and isinstance(arg.value, BoolLiteral):
                        start = arg.value.value
                else:
                    val_arg = arg

            if val_arg is None:
                raise MochaCodeGenError(f"'{member}' requires a value argument", node.line, node.col)
            val_reg, val_type = self.gen_expr(val_arg)

            cast = self.box_value(val_reg, val_type)

            fn = "mocha_array_push_front" if start else "mocha_array_push"
            self.emit(f"  call void @{fn}(%MochaArray* {arr_reg}, i8* {cast})")

            return ("void", "void")

        elif member == "pop":
            self.emit(f"  call void @mocha_array_pop(%MochaArray* {arr_reg}, i8* null)")
            return ("void", "void")

        elif member == "occs":
            val_reg, val_type = self.gen_expr(node.args[0])

            cast = self.box_value(val_reg, val_type)

            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i32 @mocha_array_occs(%MochaArray* {arr_reg}, i8* {cast})")

            return (tmp, "i32")
        
        elif member == "copy":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaArray* @mocha_array_copy(%MochaArray* {arr_reg})")
            return (tmp, "%MochaArray*")

        elif member == "min" or member == "max":
            # determine element type from mocha type
            obj_type = self.local_mocha_types.get(obj_name, "int[]") if obj_name else "int[]"
            bracket = obj_type.rfind("[")
            elem_mocha = obj_type[:bracket] if bracket != -1 else "int"
            
            suffix_map = {
                "int":   ("int",   "i32"),
                "float": ("float", "double"),
                "vast":  ("vast",  "i64"),
                "str":   ("str",   "i8*"),
            }
            suffix, ret_llvm = suffix_map.get(elem_mocha, ("int", "i32"))
            
            fn = f"mocha_array_{member}_{suffix}"
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call {ret_llvm} @{fn}(%MochaArray* {arr_reg})")
            return (tmp, ret_llvm)

        # ---------------- EXTENSIONS ---------------- #

        obj_type = self.local_mocha_types.get(obj_name, "int[]") if obj_name else "int[]"

        # Build argument list ONCE
        args_ir = []
        this_type = "%MochaArray2D*" if "[][]" in obj_type else "%MochaArray*"
        args_ir.append(f"{this_type} {arr_reg}")

        for arg in node.args:
            if isinstance(arg, Assignment):
                continue
            reg, typ = self.gen_expr(arg)
            args_ir.append(f"{typ} {reg}")

        arg_str = ", ".join(args_ir)

        # 🔑 Try BOTH naming styles
        sanitized_key = f"mocha_ext_{self.sanitize_type_name(obj_type)}_{member}"
        raw_key       = f"mocha_ext_{obj_type}_{member}"

        key = None
        if sanitized_key in self.method_return_types:
            key = sanitized_key
        elif raw_key in self.method_return_types:
            key = raw_key

        if key:
            ret_type = self.method_return_types[key]

            if ret_type == "void":
                self.emit(f"  call void @{key}({arg_str})")
                return ("void", "void")
            else:
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call {ret_type} @{key}({arg_str})")
                return (tmp, ret_type)

        raise MochaCodeGenError(f"Unknown array method '{member}' on type '{obj_type}'", node.line, node.col)

    def gen_array2d_method_call(self, arr_reg, member, node, obj_name):
        # ---------------- BUILT-INS ---------------- #

        if member == "resize":
            rows_reg, _ = self.gen_expr(node.args[0])
            cols_reg, _ = self.gen_expr(node.args[1])

            mocha_type = self.local_mocha_types.get(obj_name, "")
            bracket = mocha_type.rfind("[")
            base = mocha_type[:bracket]
            bracket2 = base.rfind("[")
            elem_mocha = base[:bracket2] if "[" in base else base

            elem_size = {"int": 4, "vast": 8, "float": 8, "str": 8, "bool": 1}.get(elem_mocha, 4)

            self.emit(f"  call void @mocha_array2d_resize(%MochaArray2D* {arr_reg}, i32 {rows_reg}, i32 {cols_reg}, i32 {elem_size})")
            return ("void", "void")

        elif member == "drop":
            arg = node.args[0]

            if isinstance(arg, RowSlice):
                row_reg, _ = self.gen_expr(arg.row)
                self.emit(f"  call void @mocha_array2d_drop_row(%MochaArray2D* {arr_reg}, i32 {row_reg})")

            elif isinstance(arg, ColSlice):
                col_reg, _ = self.gen_expr(arg.col)
                self.emit(f"  call void @mocha_array2d_drop_col(%MochaArray2D* {arr_reg}, i32 {col_reg})")

            return ("void", "void")

        elif member == "occs":
            val_arg = None
            row_arg = None
            col_arg = None

            for arg in node.args:
                if isinstance(arg, Assignment) and isinstance(arg.target, Identifier):
                    if arg.target.name == "row":
                        row_arg = arg.value
                    elif arg.target.name == "col":
                        col_arg = arg.value
                else:
                    val_arg = arg

            if val_arg is None:
                raise MochaCodeGenError(f"'{member}' requires a value argument", node.line, node.col)
            val_reg, val_type = self.gen_expr(val_arg)

            slot = self.fresh_temp()
            self.emit(f"  {slot} = alloca {val_type}")
            self.emit(f"  store {val_type} {val_reg}, {val_type}* {slot}")

            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {val_type}* {slot} to i8*")

            tmp = self.fresh_temp()

            if isinstance(row_arg, ArrayLiteral):
                start_reg, _ = self.gen_expr(row_arg.elements[0])
                end_reg, _   = self.gen_expr(row_arg.elements[1])
                self.emit(f"  {tmp} = call i32 @mocha_array2d_occs_rowrange(%MochaArray2D* {arr_reg}, i8* {cast}, i32 {start_reg}, i32 {end_reg})")

            elif row_arg is not None:
                row_reg, _ = self.gen_expr(row_arg)
                self.emit(f"  {tmp} = call i32 @mocha_array2d_occs_row(%MochaArray2D* {arr_reg}, i8* {cast}, i32 {row_reg})")

            elif isinstance(col_arg, ArrayLiteral):
                start_reg, _ = self.gen_expr(col_arg.elements[0])
                end_reg, _   = self.gen_expr(col_arg.elements[1])
                self.emit(f"  {tmp} = call i32 @mocha_array2d_occs_colrange(%MochaArray2D* {arr_reg}, i8* {cast}, i32 {start_reg}, i32 {end_reg})")

            elif col_arg is not None:
                col_reg, _ = self.gen_expr(col_arg)
                self.emit(f"  {tmp} = call i32 @mocha_array2d_occs_col(%MochaArray2D* {arr_reg}, i8* {cast}, i32 {col_reg})")
            else:
                # No row/col specified — search entire 2D array
                self.emit(f"  {tmp} = call i32 @mocha_array2d_occs(%MochaArray2D* {arr_reg}, i8* {cast})")

            return (tmp, "i32")

        # ---------------- EXTENSIONS ---------------- #

        obj_type = self.local_mocha_types.get(obj_name, "int[][]") if obj_name else "int[][]"

        # Build args once
        args_ir = [f"%MochaArray2D* {arr_reg}"]
        for arg in node.args:
            if isinstance(arg, Assignment):
                continue
            reg, typ = self.gen_expr(arg)
            args_ir.append(f"{typ} {reg}")

        arg_str = ", ".join(args_ir)

        sanitized_key = f"mocha_ext_{self.sanitize_type_name(obj_type)}_{member}"
        raw_key       = f"mocha_ext_{obj_type}_{member}"

        key = None
        if sanitized_key in self.method_return_types:
            key = sanitized_key
        elif raw_key in self.method_return_types:
            key = raw_key

        if key:
            ret_type = self.method_return_types[key]

            if ret_type == "void":
                self.emit(f"  call void @{key}({arg_str})")
                return ("void", "void")
            else:
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call {ret_type} @{key}({arg_str})")
                return (tmp, ret_type)

        raise MochaCodeGenError(f"Unknown 2D array method '{member}' on type '{obj_type}'", node.line, node.col)

    def gen_dict_method_call(self, d_reg, member, node):
        if member == "has":
            key_reg, _ = self.gen_expr(node.args[0])
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i8 @mocha_dict_has(%MochaDict* {d_reg}, i8* {key_reg})")
            return (tmp, "i8")
        elif member == "remove":
            key_reg, _ = self.gen_expr(node.args[0])
            self.emit(f"  call void @mocha_dict_remove(%MochaDict* {d_reg}, i8* {key_reg})")
            return ("void", "void")
        elif member == "clean":
            self.emit(f"  call void @mocha_dict_clean(%MochaDict* {d_reg})")
            return ("void", "void")
        elif member == "allKeys":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaArray* @mocha_dict_allkeys(%MochaDict* {d_reg})")
            return (tmp, "%MochaArray*")
        elif member == "allValues":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaArray* @mocha_dict_allvalues(%MochaDict* {d_reg})")
            return (tmp, "%MochaArray*")
        elif member == "merge":
            # extract override flag
            override = 0
            for a in node.args:
                if isinstance(a, Assignment):
                    if isinstance(a.target, Identifier) and a.target.name == "override":
                        if isinstance(a.value, BoolLiteral):
                            override = 1 if a.value.value else 0

            # get dict2 (first positional arg)
            positional = [a for a in node.args if not isinstance(a, Assignment)]
            dict2_reg, _ = self.gen_expr(positional[0])

            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaDict* @mocha_dict_merge(%MochaDict* {d_reg}, %MochaDict* {dict2_reg}, i8 {override})")
            return (tmp, "%MochaDict*")
        return None

    def gen_set_method_call(self, s_reg, member, node):
        if member == "insert":
            val_reg, val_type = self.gen_expr(node.args[0])
            slot = self.fresh_temp()
            self.emit(f"  {slot} = alloca {val_type}")
            self.emit(f"  store {val_type} {val_reg}, {val_type}* {slot}")
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {val_type}* {slot} to i8*")
            self.emit(f"  call void @mocha_set_insert(%MochaSet* {s_reg}, i8* {cast})")
            return ("void", "void")
        elif member == "delete":
            val_reg, val_type = self.gen_expr(node.args[0])
            cast = self.box_value(val_reg, val_type)
            self.emit(f"  call void @mocha_set_delete(%MochaSet* {s_reg}, i8* {cast})")
            return ("void", "void")
        elif member == "has":
            val_reg, val_type = self.gen_expr(node.args[0])
            cast = self.box_value(val_reg, val_type)
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i8 @mocha_set_has(%MochaSet* {s_reg}, i8* {cast})")
            return (tmp, "i8")
        elif member == "clean":
            self.emit(f"  call void @mocha_set_clean(%MochaSet* {s_reg})")
            return ("void", "void")
        elif member == "negate":
            self.emit(f"  call void @mocha_set_negate(%MochaSet* {s_reg})")
            return ("void", "void")
        elif member == "retype":
            type_tags = {"int": 0, "float": 1, "str": 2, "bool": 3, "vast": 4, "object": 5}
            new_type = "int"
            for arg in node.args:
                if not isinstance(arg, NullLiteral):
                    if isinstance(arg, Identifier):
                        new_type = arg.name
            tag = type_tags.get(new_type, 0)
            self.emit(f"  call void @mocha_set_retype(%MochaSet* {s_reg}, i32 {tag})")
            
            # Update local mocha type so subsequent operations use correct type
            if isinstance(node.name, MemberAccess) and isinstance(node.name.obj, Identifier):
                self.local_mocha_types[node.name.obj.name] = f"set<{new_type}>"
            
            return ("void", "void")
        elif member == "union":
            s2_reg, _ = self.gen_expr(node.args[0])
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaSet* @mocha_set_union(%MochaSet* {s_reg}, %MochaSet* {s2_reg})")
            return (tmp, "%MochaSet*")
        elif member == "intersect":
            s2_reg, _ = self.gen_expr(node.args[0])
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaSet* @mocha_set_intersect(%MochaSet* {s_reg}, %MochaSet* {s2_reg})")
            return (tmp, "%MochaSet*")
        elif member == "xor":
            s2_reg, _ = self.gen_expr(node.args[0])
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaSet* @mocha_set_xor(%MochaSet* {s_reg}, %MochaSet* {s2_reg})")
            return (tmp, "%MochaSet*")
        elif member == "rel_diff":
            s2_reg, _ = self.gen_expr(node.args[0])
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaSet* @mocha_set_rel_diff(%MochaSet* {s_reg}, %MochaSet* {s2_reg})")
            return (tmp, "%MochaSet*")
        elif member == "min" or member == "max":
            mocha_type = self.local_mocha_types.get(
                node.name.obj.name if hasattr(node.name, 'obj') else "", "set<int>"
            )
            inner = mocha_type[4:-1] if mocha_type.startswith("set<") else "int"
            suffix_map = {
                "int":   ("int",   "i32"),
                "float": ("float", "double"),
                "vast":  ("vast",  "i64"),
                "str":   ("str",   "i8*"),
            }
            suffix, ret_llvm = suffix_map.get(inner, ("int", "i32"))
            fn = f"mocha_set_{member}_{suffix}"
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call {ret_llvm} @{fn}(%MochaSet* {s_reg})")
            return (tmp, ret_llvm)
        return None

    def gen_str_method_call(self, s_reg, member, node):
        if member == "charAt":
            idx_reg, _ = self.gen_expr(node.args[0])
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i8* @mocha_str_charat(i8* {s_reg}, i32 {idx_reg})")
            return (tmp, "i8*")
        elif member == "toInt":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i32 @mocha_str_to_int(i8* {s_reg})")
            return (tmp, "i32")
        elif member == "toFloat":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call double @mocha_str_to_float(i8* {s_reg})")
            return (tmp, "double")
        elif member == "format":
            # Separate positional and named args
            positional = [a for a in node.args if not isinstance(a, Assignment)]
            named      = [a for a in node.args if isinstance(a, Assignment)]

            # Compile-time mixing error
            if positional and named:
                raise MochaCodeGenError(
                    "format() does not allow mixing positional and named arguments",
                    node.line, node.col
                )

            if named:
                # ── Named mode ──
                to_str_fns = {
                    "i32":    ("mocha_int_to_str",   "i32"),
                    "i64":    ("mocha_vast_to_str",  "i64"),
                    "double": ("mocha_float_to_str", "double"),
                    "i8":     ("mocha_bool_to_str",  "i8"),
                    "i1":     ("mocha_bool_to_str",  "i8"),
                }

                key_regs = []
                val_regs = []

                for arg in named:
                    # key → i8*
                    key_str = cast(Identifier, arg.target).name
                    key_global = self.fresh_str_global(key_str)
                    key_len = len(key_str.encode('utf-8')) + 1
                    key_reg = self.fresh_temp()
                    self.emit(f"  {key_reg} = getelementptr [{key_len} x i8], [{key_len} x i8]* {key_global}, i32 0, i32 0")
                    # no mocha_str_literal call needed — just raw i8* pointer is fine for key comparison in C
                    key_regs.append(key_reg)

                    # value → i8*
                    r, t = self.gen_expr(arg.value)
                    if t == "i8*":
                        val_regs.append(r)
                    elif t == "i1":
                        w = self.fresh_temp()
                        self.emit(f"  {w} = zext i1 {r} to i8")
                        s = self.fresh_temp()
                        self.emit(f"  {s} = call i8* @mocha_bool_to_str(i8 {w})")
                        val_regs.append(s)
                    else:
                        fn, llvm_t = to_str_fns.get(t, ("mocha_int_to_str", "i32"))
                        s = self.fresh_temp()
                        self.emit(f"  {s} = call i8* @{fn}({llvm_t} {r})")
                        val_regs.append(s)

                argc = len(named)

                # build keys array on stack
                keys_ptr = self.fresh_temp()
                self.emit(f"  {keys_ptr} = alloca i8*, i32 {argc}")
                for i, kr in enumerate(key_regs):
                    ep = self.fresh_temp()
                    self.emit(f"  {ep} = getelementptr i8*, i8** {keys_ptr}, i32 {i}")
                    self.emit(f"  store i8* {kr}, i8** {ep}")

                # build values array on stack
                vals_ptr = self.fresh_temp()
                self.emit(f"  {vals_ptr} = alloca i8*, i32 {argc}")
                for i, vr in enumerate(val_regs):
                    ep = self.fresh_temp()
                    self.emit(f"  {ep} = getelementptr i8*, i8** {vals_ptr}, i32 {i}")
                    self.emit(f"  store i8* {vr}, i8** {ep}")

                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i8* @mocha_str_format_named(i8* {s_reg}, i8** {keys_ptr}, i8** {vals_ptr}, i32 {argc})")
                return (tmp, "i8*")

            else:
                # ── Positional mode (existing code) ──
                to_str_fns = {
                    "i32":    ("mocha_int_to_str",   "i32"),
                    "i64":    ("mocha_vast_to_str",  "i64"),
                    "double": ("mocha_float_to_str", "double"),
                    "i8":     ("mocha_bool_to_str",  "i8"),
                    "i1":     ("mocha_bool_to_str",  "i8"),
                }

                str_regs = []
                for arg in positional:
                    r, t = self.gen_expr(arg)
                    if t == "i8*":
                        str_regs.append(r)
                    elif t == "i1":
                        w = self.fresh_temp()
                        self.emit(f"  {w} = zext i1 {r} to i8")
                        s = self.fresh_temp()
                        self.emit(f"  {s} = call i8* @mocha_bool_to_str(i8 {w})")
                        str_regs.append(s)
                    else:
                        fn, llvm_t = to_str_fns.get(t, ("mocha_int_to_str", "i32"))
                        s = self.fresh_temp()
                        self.emit(f"  {s} = call i8* @{fn}({llvm_t} {r})")
                        str_regs.append(s)

                argc = len(str_regs)
                arr_ptr = self.fresh_temp()
                self.emit(f"  {arr_ptr} = alloca i8*, i32 {argc}")
                for i, sr in enumerate(str_regs):
                    ep = self.fresh_temp()
                    self.emit(f"  {ep} = getelementptr i8*, i8** {arr_ptr}, i32 {i}")
                    self.emit(f"  store i8* {sr}, i8** {ep}")
                
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call i8* @mocha_str_format(i8* {s_reg}, i8** {arr_ptr}, i32 {argc})")
                return (tmp, "i8*")
            
        # fallthrough — extended str method from mocha-string or other lib
        else:
            func_name = f"mocha_ext_str_{member}"
            # look up return type
            ret_type = self.method_return_types.get(func_name, "i8*")
            ret_llvm = ret_type
            # compile args
            args = [f"i8* {s_reg}"]  # this is always first arg
            for arg in node.args:
                arg_reg, arg_type = self.gen_expr(arg)
                args.append(f"{arg_type} {arg_reg}")
            arg_str = ", ".join(args)
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call {ret_llvm} @{func_name}({arg_str})")
            return (tmp, ret_llvm)

    def get_return_type(self, name, node=None):
        if name not in self.method_return_types:
            line = getattr(node, 'line', '?')
            col  = getattr(node, 'col', '?')
            raise MochaCodeGenError(
                f"Unknown function or method '{name}' — did you forget to import a library?",
                line, col # type: ignore
            )
        return self.method_return_types[name]

    def gen_struct_method_call(self, obj_ptr, obj_llvm_type, member, node):
        class_name = obj_llvm_type[len("%struct."):-1]
        found = False
        func_name = f"{class_name}_{member}"
        if func_name in self.method_return_types:
            found = True
        if not found:
            for p in self.class_all_parents.get(class_name, []):
                search_class = p
                while search_class:
                    candidate = f"{search_class}_{member}"
                    if candidate in self.method_return_types:
                        func_name = candidate
                        found = True
                        break
                    search_class = self.class_parents.get(search_class)
                if found:
                    break

        # ── extend method fallback ──
        if not found:
            ext_candidate = f"mocha_ext_{class_name}_{member}"
            if ext_candidate in self.method_return_types:
                func_name = ext_candidate
                found = True

        if not found:
            raise MochaCodeGenError(
                f"Unknown function or method '{func_name}' — did you forget to import a library?",
                node.line, node.col
            )

        ret_type = self.get_return_type(func_name, node)
        obj_reg = self.fresh_temp()
        self.emit(f"  {obj_reg} = load {obj_llvm_type}, {obj_llvm_type}* {obj_ptr}")
        args = self._collect_args(node)
        all_args = [(obj_reg, obj_llvm_type)] + args
        return self._emit_call(ret_type, func_name, all_args)
    
    def _collect_args(self, node):
        """Collect positional args, skipping named params (Assignment nodes)."""
        args = []
        for arg in node.args:
            if isinstance(arg, Assignment):
                continue
            reg, typ = self.gen_expr(arg)
            args.append((reg, typ))
        return args

    def _emit_call(self, ret_type, c_func, all_args):
        """Emit a call and return (reg, type). Handles void vs non-void."""
        # resolve native name if this is an extend method with a native mapping
        c_func = self.ext_native_names.get(c_func, c_func)
        
        arg_str = ", ".join(f"{t} {r}" for r, t in all_args)
        if ret_type == "void":
            self.emit(f"  call void @{c_func}({arg_str})")
            return ("void", "void")
        tmp = self.fresh_temp()
        self.emit(f"  {tmp} = call {ret_type} @{c_func}({arg_str})")
        return (tmp, ret_type)

    def _dispatch_struct_method(self, obj_reg, obj_llvm_type, method_map, type_name, member, node):
        """Generic struct method dispatcher. Assumes obj_reg is already loaded."""
        if member not in method_map:
            raise MochaCodeGenError(f"{type_name} has no method '{member}'", node.line, node.col)
        ret_type, c_func = method_map[member]
        args = self._collect_args(node)
        all_args = [(obj_reg, obj_llvm_type)] + args
        return self._emit_call(ret_type, c_func, all_args)

    def gen_member_call(self, node):
        obj    = node.name.obj
        member = node.name.member

        if isinstance(obj, Identifier):
            obj_name = obj.name

            if obj_name in self.locals:
                _, obj_llvm_type = self.locals[obj_name]
                if obj_llvm_type.startswith("%struct.") and obj_llvm_type.endswith("*"):
                    class_name = obj_llvm_type[len("%struct."):-1]
                    mangled = f"{class_name}_{member}"

            # Shared/static method call: ClassName.method()
            if obj_name in self.class_nodes:
                mangled  = f"{obj_name}_{member}"
                ret_type = self.get_return_type(mangled, node)
                args     = self._collect_args(node)
                arg_str  = ", ".join(f"{t} {r}" for r, t in args)
                tmp      = self.fresh_temp()
                if ret_type == "void":
                    self.emit(f"  call void @{mangled}({arg_str})")
                    return ("void", "void")
                self.emit(f"  {tmp} = call {ret_type} @{mangled}({arg_str})")
                return (tmp, ret_type)

            lib_key = f"{obj_name}.{member}"
            if lib_key in self.lib_functions:
                return None  # let gen_function_call handle via func_name

            if obj_name in self.locals:
                obj_ptr, obj_llvm_type = self.locals[obj_name]

                if obj_llvm_type == "%MochaArray*":
                    arr_reg = self.fresh_temp()
                    self.emit(f"  {arr_reg} = load %MochaArray*, %MochaArray** {obj_ptr}")
                    return self.gen_array_method_call(arr_reg, member, node, obj_name)

                elif obj_llvm_type == "%MochaArray2D*":
                    arr_reg = self.fresh_temp()
                    self.emit(f"  {arr_reg} = load %MochaArray2D*, %MochaArray2D** {obj_ptr}")
                    return self.gen_array2d_method_call(arr_reg, member, node, obj_name)

                elif obj_llvm_type == "%MochaDict*":
                    d_reg = self.fresh_temp()
                    self.emit(f"  {d_reg} = load %MochaDict*, %MochaDict** {obj_ptr}")
                    return self.gen_dict_method_call(d_reg, member, node)

                elif obj_llvm_type == "%MochaSet*":
                    s_reg = self.fresh_temp()
                    self.emit(f"  {s_reg} = load %MochaSet*, %MochaSet** {obj_ptr}")
                    return self.gen_set_method_call(s_reg, member, node)

                elif obj_llvm_type == "%struct.MochaStringBuilder*":
                    sb_reg = self.fresh_temp()
                    self.emit(f"  {sb_reg} = load %struct.MochaStringBuilder*, %struct.MochaStringBuilder** {obj_ptr}")
                    return self._dispatch_struct_method(sb_reg, "%struct.MochaStringBuilder*", STRINGBUILDER_METHOD_MAP, "StringBuilder", member, node)

                elif obj_llvm_type == "%struct.MochaComplex*":
                    c_reg = self.fresh_temp()
                    self.emit(f"  {c_reg} = load %struct.MochaComplex*, %struct.MochaComplex** {obj_ptr}")
                    return self._dispatch_struct_method(c_reg, "%struct.MochaComplex*", COMPLEX_METHOD_MAP, "Complex", member, node)

                elif obj_llvm_type == "%struct.MochaFile*":
                    f_reg = self.fresh_temp()
                    self.emit(f"  {f_reg} = load %struct.MochaFile*, %struct.MochaFile** {obj_ptr}")
                    return self._dispatch_struct_method(f_reg, "%struct.MochaFile*", FILE_METHOD_MAP, "File", member, node)

                elif obj_llvm_type == "%struct.MochaHashTable*":
                    ht_reg = self.fresh_temp()
                    self.emit(f"  {ht_reg} = load %struct.MochaHashTable*, %struct.MochaHashTable** {obj_ptr}")
                    
                    if member == "put":
                        key_reg, _ = self.gen_expr(node.args[0])
                        val_reg, val_type = self.gen_expr(node.args[1])
                        if val_type != "i8*":
                            boxed = self.box_value(val_reg, val_type)
                        else:
                            boxed = val_reg
                        self.emit(f"  call void @mocha_ht_put(%struct.MochaHashTable* {ht_reg}, i8* {key_reg}, i8* {boxed})")
                        return ("void", "void")
                    
                    elif member == "get":
                        key_reg, _ = self.gen_expr(node.args[0])
                        raw = self.fresh_temp()
                        self.emit(f"  {raw} = call i8* @mocha_ht_get(%struct.MochaHashTable* {ht_reg}, i8* {key_reg})")
                        expected = self.expected_assign_type or ""
                        if expected == "int":
                            ptr = self.fresh_temp()
                            val = self.fresh_temp()
                            self.emit(f"  {ptr} = bitcast i8* {raw} to i32*")
                            self.emit(f"  {val} = load i32, i32* {ptr}")
                            return (val, "i32")
                        elif expected == "float":
                            ptr = self.fresh_temp()
                            val = self.fresh_temp()
                            self.emit(f"  {ptr} = bitcast i8* {raw} to double*")
                            self.emit(f"  {val} = load double, double* {ptr}")
                            return (val, "double")
                        elif expected == "bool":
                            val = self.fresh_temp()
                            self.emit(f"  {val} = load i8, i8* {raw}")
                            return (val, "i8")
                        elif expected == "vast":
                            ptr = self.fresh_temp()
                            val = self.fresh_temp()
                            self.emit(f"  {ptr} = bitcast i8* {raw} to i64*")
                            self.emit(f"  {val} = load i64, i64* {ptr}")
                            return (val, "i64")
                        else:
                            return (raw, "i8*")  # str or unknown
                                    
                    return self._dispatch_struct_method(ht_reg, "%struct.MochaHashTable*", HASHTABLE_METHOD_MAP, "HashTable", member, node)
                
                elif obj_llvm_type == "i32":
                    if member == "name":
                        mocha_type = self.local_mocha_types.get(obj_name, "")
                        if mocha_type in _tag_types_registry:
                            obj_reg = self.fresh_temp()
                            self.emit(f"  {obj_reg} = load i32, i32* {obj_ptr}")
                            tmp = self.fresh_temp()
                            self.emit(f"  {tmp} = call i8* @{mocha_type}__name(i32 {obj_reg})")
                            return (tmp, "i8*")

                elif obj_llvm_type == "i8*":
                    s_reg = self.fresh_temp()
                    self.emit(f"  {s_reg} = load i8*, i8** {obj_ptr}")
                    return self.gen_str_method_call(s_reg, member, node)

                elif obj_llvm_type == "double":
                    obj_reg    = self.fresh_temp()
                    self.emit(f"  {obj_reg} = load double, double* {obj_ptr}")
                    method_key  = f"mocha_ext_float_{member}"
                    actual_name = self.ext_native_names.get(method_key, method_key)
                    args = []
                    for arg in node.args:
                        if isinstance(arg, Assignment):
                            if isinstance(arg.target, Identifier):
                                reg, typ = self.gen_expr(arg.value)
                                args.append((reg, typ))
                        else:
                            reg, typ = self.gen_expr(arg)
                            args.append((reg, typ))
                    if method_key in self.method_return_types:
                        ret_type = self.method_return_types[method_key]
                        all_args = [(obj_reg, "double")] + args
                        return self._emit_call(ret_type, actual_name, all_args)

                elif obj_llvm_type.startswith("%struct.") and obj_llvm_type.endswith("*"):
                    return self.gen_struct_method_call(obj_ptr, obj_llvm_type, member, node)


        elif isinstance(obj, FunctionCall):
            obj_reg, obj_type = self.gen_expr(obj)

            if obj_type == "i8*":
                return self.gen_str_method_call(obj_reg, member, node)

            elif obj_type == "%MochaArray*":
                tmp_ptr = self.fresh_temp()
                self.emit(f"  {tmp_ptr} = alloca %MochaArray*")
                self.emit(f"  store %MochaArray* {obj_reg}, %MochaArray** {tmp_ptr}")
                prev = self.locals.get("__chain_tmp")
                self.locals["__chain_tmp"] = (tmp_ptr, "%MochaArray*")
                result = self.gen_array_method_call(obj_reg, member, node, None)
                if prev:
                    self.locals["__chain_tmp"] = prev
                return result

            elif obj_type == "%MochaArray2D*":
                tmp_ptr = self.fresh_temp()
                self.emit(f"  {tmp_ptr} = alloca %MochaArray2D*")
                self.emit(f"  store %MochaArray2D* {obj_reg}, %MochaArray2D** {tmp_ptr}")
                self.locals["__chain2d_tmp"]      = (tmp_ptr, "%MochaArray2D*")
                self.local_mocha_types["__chain2d_tmp"] = "float[][]"
                return self.gen_array2d_method_call(obj_reg, member, node, "__chain2d_tmp")

            elif obj_type == "%struct.MochaComplex*":
                return self._dispatch_struct_method(obj_reg, "%struct.MochaComplex*", COMPLEX_METHOD_MAP, "Complex", member, node)

            elif obj_type.startswith("%struct.") and obj_type.endswith("*"):
                tmp_ptr = self.fresh_temp()
                self.emit(f"  {tmp_ptr} = alloca {obj_type}")
                self.emit(f"  store {obj_type} {obj_reg}, {obj_type}* {tmp_ptr}")
                return self.gen_struct_method_call(tmp_ptr, obj_type, member, node)

        elif isinstance(obj, (IndexAccess, Index2DAccess, MemberAccess)):
            obj_reg, obj_type = self.gen_expr(obj)

            if obj_type == "i8*":
                return self.gen_str_method_call(obj_reg, member, node)

            elif obj_type == "double":
                method_key  = f"mocha_ext_float_{member}"
                actual_name = self.ext_native_names.get(method_key, method_key)
                args = []
                for arg in node.args:
                    if isinstance(arg, Assignment):
                        if isinstance(arg.target, Identifier):
                            reg, typ = self.gen_expr(arg.value)
                            args.append((reg, typ))
                    else:
                        reg, typ = self.gen_expr(arg)
                        args.append((reg, typ))
                if method_key in self.method_return_types:
                    ret_type = self.method_return_types[method_key]
                    all_args = [(obj_reg, "double")] + args
                    return self._emit_call(ret_type, actual_name, all_args)

            elif obj_type == "%MochaArray*":
                return self.gen_array_method_call(obj_reg, member, node, None)

            elif obj_type == "%MochaArray2D*":
                return self.gen_array2d_method_call(obj_reg, member, node, None)

            elif obj_type == "%struct.MochaComplex*":
                return self._dispatch_struct_method(obj_reg, "%struct.MochaComplex*", COMPLEX_METHOD_MAP, "Complex", member, node)
            
            elif obj_type == "%struct.MochaHashTable*":
                return self._dispatch_struct_method(obj_reg, "%struct.MochaHashTable*", HASHTABLE_METHOD_MAP, "HashTable", member, node)

            elif obj_type.startswith("%struct.") and obj_type.endswith("*"):
                class_name = obj_type[len("%struct."):-1]
                if class_name in self.class_nodes:
                    mangled  = f"{class_name}_{member}"
                    ret_type = self.get_return_type(mangled, node)
                    args     = self._collect_args(node)
                    all_args = [(obj_reg, obj_type)] + args
                    return self._emit_call(ret_type, mangled, all_args)
                
        elif isinstance(obj, (FloatLiteral, IntLiteral, UnaryOp, BinaryOp)):
            obj_reg, obj_type = self.gen_expr(obj)

            if obj_type == "%struct.MochaComplex*":
                return self._dispatch_struct_method(obj_reg, "%struct.MochaComplex*", COMPLEX_METHOD_MAP, "Complex", member, node)

            method_key  = f"mocha_ext_{('float' if obj_type == 'double' else 'int')}_{member}"
            actual_name = self.ext_native_names.get(method_key, method_key)
            args = []
            for arg in node.args:
                if isinstance(arg, Assignment):
                    if isinstance(arg.target, Identifier):
                        reg, typ = self.gen_expr(arg.value)
                        args.append((reg, typ))
                else:
                    reg, typ = self.gen_expr(arg)
                    args.append((reg, typ))
            if method_key in self.method_return_types:
                ret_type = self.method_return_types[method_key]
                all_args = [(obj_reg, obj_type)] + args
                return self._emit_call(ret_type, actual_name, all_args)
        
        elif isinstance(obj, StrLiteral):
            obj_reg, obj_type = self.gen_expr(obj)
            return self.gen_str_method_call(obj_reg, member, node)

    def gen_function_call(self, node):
        # -------------------------------------------------------
        # Step 1: Determine function name and any implicit first arg
        # -------------------------------------------------------
        func_name = "unknown"
        is_constructor_candidate = False
        self.extra_first_arg = None

        if isinstance(node.name, Identifier):
            func_name = node.name.name
            is_constructor_candidate = bool(func_name) and func_name[0].isupper()

            # Lambda invocation — pred(x) where pred is a bundle pointer
            if func_name in self.locals:
                ptr, llvm_type = self.locals[func_name]
                if self.local_mocha_types.get(func_name) == "lambda":
                    # Load the bundle pointer
                    bundle = self.fresh_temp()
                    self.emit(f"  {bundle} = load i8*, i8** {ptr}")
                    
                    # Unpack fn and env from bundle
                    slot0 = self.fresh_temp()
                    fn_ptr = self.fresh_temp()
                    slot1 = self.fresh_temp()
                    env_ptr = self.fresh_temp()
                    self.emit(f"  {slot0} = bitcast i8* {bundle} to i8**")
                    self.emit(f"  {fn_ptr} = load i8*, i8** {slot0}")
                    self.emit(f"  {slot1} = getelementptr i8*, i8** {slot0}, i32 1")
                    self.emit(f"  {env_ptr} = load i8*, i8** {slot1}")

                    # Evaluate and box each argument
                    boxed_args = []
                    arg_types = []
                    for arg in node.args:
                        if isinstance(arg, Assignment):
                            continue
                        arg_reg, arg_type = self.gen_expr(arg)
                        arg_types.append(arg_type)          # collected here now
                        box = self.fresh_temp()
                        box_ptr = self.fresh_temp()
                        self.emit(f"  {box_ptr} = alloca {arg_type}")
                        self.emit(f"  store {arg_type} {arg_reg}, {arg_type}* {box_ptr}")
                        self.emit(f"  {box} = bitcast {arg_type}* {box_ptr} to i8*")
                        boxed_args.append(box)

                    # Build call: fn(arg0, arg1, ..., env)
                    boxed_str = ", ".join(f"i8* {a}" for a in boxed_args)

                    # Determine call_ret
                    pred_names = {"pred", "predicate", "condition", "filter", "test"}
                    transform_names = {"transform", "mapper", "fn", "func", "f"}

                    if self.expected_assign_type == "float":
                        call_ret = "double"
                    elif self.expected_assign_type == "str":
                        call_ret = "i8*"
                    elif self.expected_assign_type == "bool":
                        call_ret = "i8"
                    elif self.expected_assign_type in ("int", "vast"):
                        call_ret = "i32"
                    elif func_name in pred_names:
                        call_ret = "i8"  # predicates always return bool
                    elif func_name in transform_names:
                        call_ret = arg_types[0] if len(arg_types) == 1 else "i8"
                    else:
                        # fallback — infer from arg type
                        if len(arg_types) == 1:
                            if arg_types[0] == "double":
                                call_ret = "double"
                            elif arg_types[0] == "i8*":
                                call_ret = "i8*"
                            else:
                                call_ret = "i8"
                        elif len(arg_types) >= 2:
                            call_ret = arg_types[0]
                        else:
                            call_ret = "i8"

                    # Cast fn to correct signature and call
                    param_types = ", ".join(["i8*"] * (len(boxed_args) + 1))
                    fn_typed = self.fresh_temp()
                    result = self.fresh_temp()
                    self.emit(f"  {fn_typed} = bitcast i8* {fn_ptr} to {call_ret} ({param_types})*")
                    self.emit(f"  {result} = call {call_ret} {fn_typed}({boxed_str}, i8* {env_ptr})")
                    return (result, call_ret)
            
            # Native function mapping — c_sqrt → mocha_wrap_sqrt_f etc.
            if func_name in self.lib_functions:
                actual_name, ret_llvm, llvm_params, param_names = self.lib_functions[func_name]
                
                args_ir = []
                for i, arg in enumerate(node.args):
                    if isinstance(arg, Assignment):
                        continue
                    arg_reg, arg_type = self.gen_expr(arg)
                    if i < len(llvm_params):
                        declared_type = llvm_params[i]
                        if declared_type != arg_type:
                            cast_tmp = self.fresh_temp()
                            if declared_type == "double" and arg_type == "i32":
                                self.emit(f"  {cast_tmp} = sitofp i32 {arg_reg} to double")
                                arg_reg = cast_tmp
                                arg_type = "double"
                        args_ir.append(f"{declared_type} {arg_reg}")
                    else:
                        args_ir.append(f"{arg_type} {arg_reg}")
                args_str = ", ".join(args_ir)
                tmp = self.fresh_temp()
                if ret_llvm == "void":
                    self.emit(f"  call void @{actual_name}({args_str})")
                    return (tmp, "void")
                else:
                    self.emit(f"  {tmp} = call {ret_llvm} @{actual_name}({args_str})")
                return (tmp, ret_llvm)

        elif isinstance(node.name, MemberAccess):
            obj    = node.name.obj
            member = node.name.member

            # Try dispatching to helper — if it returns a result, we're done
            result = self.gen_member_call(node)
            if result is not None:
                return result

            # If gen_member_call returned None, func_name may have been set
            # (e.g. struct method, lib alias) — fall through to steps 2-5
            if isinstance(obj, Identifier):
                obj_name = obj.name
                lib_key  = f"{obj_name}.{member}"
                if lib_key in self.lib_functions:
                    func_name = self.lib_functions[lib_key][0]
                elif obj_name in self.locals:
                    obj_ptr, obj_llvm_type = self.locals[obj_name]
                    if obj_llvm_type.startswith("%struct.") and obj_llvm_type.endswith("*"):
                        func_name = self.gen_struct_method_call(obj_ptr, obj_llvm_type, member, node)
                    else:
                        func_name = member
                else:
                    func_name = member
            else:
                func_name = member

        # -------------------------------------------------------
        # Step 2: Collect arguments
        # -------------------------------------------------------

        args = []
        named_args = {}  # {param_name: (reg, type)}

        if self.extra_first_arg:
            args.append(self.extra_first_arg)
            self.extra_first_arg = None

        for arg in node.args:
            if isinstance(arg, Assignment):
                # Named arg — evaluate and store by name
                if isinstance(arg.target, Identifier):
                    reg, typ = self.gen_expr(arg.value)
                    named_args[arg.target.name] = (reg, typ)
            else:
                reg, typ = self.gen_expr(arg)
                args.append((reg, typ))

        # -------------------------------------------------------
        # Step 3: Built-in functions
        # -------------------------------------------------------
        if func_name == "print":
            return self.gen_print(args, node)
        if func_name == "sort":
            return self.gen_sort(args, node)
        if func_name == "tell":
            tmp = self.fresh_temp()
            if args:
                prompt_reg, prompt_type = args[0]
                # ensure it's a loaded i8*, not a double pointer
                self.emit(f"  {tmp} = call i8* @mocha_tell(i8* {prompt_reg})")
            else:
                self.emit(f"  {tmp} = call i8* @mocha_tell(i8* null)")
            return (tmp, "i8*")
        if func_name == "open":
            path_reg, _ = args[0]
            mode_reg, _ = args[1]
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %struct.MochaFile* @mocha_file_open(i8* {path_reg}, i8* {mode_reg})")
            return (tmp, "%struct.MochaFile*")

        if func_name == "exists":
            path_reg, _ = args[0]
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call i8 @mocha_file_exists(i8* {path_reg})")
            return (tmp, "i8")
        
        # -------------------------------------------------------
        # Step 3b: Built-in constructors
        # -------------------------------------------------------
        if func_name == "StringBuilder":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %struct.MochaStringBuilder* @mocha_sb_new()")
            return (tmp, "%struct.MochaStringBuilder*")
        
        if func_name == "Complex":
            tmp = self.fresh_temp()
            real_reg, real_type = args[0] if len(args) > 0 else ("0.0", "double")
            imag_reg, imag_type = args[1] if len(args) > 1 else ("0.0", "double")
            if real_type == "i32":
                p = self.fresh_temp()
                self.emit(f"  {p} = sitofp i32 {real_reg} to double")
                real_reg = p
            if imag_type == "i32":
                p = self.fresh_temp()
                self.emit(f"  {p} = sitofp i32 {imag_reg} to double")
                imag_reg = p
            self.emit(f"  {tmp} = call %struct.MochaComplex* @mocha_complex_new(double {real_reg}, double {imag_reg})")
            return (tmp, "%struct.MochaComplex*")
        
        if func_name == "HashTable":
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %struct.MochaHashTable* @mocha_ht_new()")
            return (tmp, "%struct.MochaHashTable*")

        # -------------------------------------------------------
        # Step 4: Constructor call
        # -------------------------------------------------------
        if is_constructor_candidate and func_name in self.classes_with_constructors:
            class_name      = func_name
            func_name       = f"{func_name}_constructor"
            struct_ptr_type = f"%struct.{class_name}*"
            raw  = self.fresh_temp()
            obj  = self.fresh_temp()
            size = self.fresh_temp()
            self.emit(f"  {size} = add i64 0, 1024  ; sizeof {class_name}")
            self.emit(f"  {raw} = call i8* @malloc(i64 {size})")
            self.emit(f"  call void @llvm.memset.p0i8.i64(i8* {raw}, i8 0, i64 64, i1 false)")  # ← ADD THIS
            self.emit(f"  {obj} = bitcast i8* {raw} to {struct_ptr_type}")
            args.insert(0, (obj, struct_ptr_type))
            arg_str = ", ".join(f"{t} {r}" for r, t in args)
            self.emit(f"  call void @{func_name}({arg_str})")
            return (obj, struct_ptr_type)

        elif is_constructor_candidate:
            struct_ptr_type = f"%struct.{func_name}*"
            raw  = self.fresh_temp()
            obj  = self.fresh_temp()
            size = self.fresh_temp()
            self.emit(f"  {size} = add i64 0, 64  ; sizeof {func_name}")
            self.emit(f"  {raw} = call i8* @malloc(i64 {size})")
            self.emit(f"  call void @llvm.memset.p0i8.i64(i8* {raw}, i8 0, i64 64, i1 false)")
            self.emit(f"  {obj} = bitcast i8* {raw} to {struct_ptr_type}")

            # ← always call constructor, args or not
            constructor_name = f"{func_name}_constructor"
            if node.args:
                arg_vals = []
                for arg in node.args:
                    val, typ = self.gen_expr(arg)
                    arg_vals.append((val, typ))
                param_types = ", ".join([struct_ptr_type] + [t for _, t in arg_vals])
                declare = f"declare void @{constructor_name}({param_types})"
                arg_str = ", ".join(f"{t} {v}" for v, t in [(obj, struct_ptr_type)] + arg_vals)
            else:
                declare = f"declare void @{constructor_name}({struct_ptr_type})"
                arg_str = f"{struct_ptr_type} {obj}"

            if declare not in self.extra_declares:
                self.extra_declares.append(declare)
            self.emit(f"  call void @{constructor_name}({arg_str})")

            return (obj, struct_ptr_type)

        # -------------------------------------------------------
        # Step 4b: Global lib functions (syntax 2/3 imports)
        # -------------------------------------------------------
        if func_name in self.lib_functions:
            entry = self.lib_functions[func_name]
            c_name, llvm_ret = entry[0], entry[1]
            param_names = entry[3] if len(entry) > 3 else []

            # Merge positional args with named args
            final_args = list(args)  # start with positional args
            if named_args and param_names:
                # Extend final_args to fit all params
                while len(final_args) < len(param_names):
                    final_args.append(None)
                # Slot named args into their correct positions
                for i, pname in enumerate(param_names):
                    if pname in named_args and i >= len(args):
                        final_args[i] = named_args[pname]

            # Filter out any None slots (unset optional params)
            final_args = [a for a in final_args if a is not None]

            arg_str = ", ".join(f"{t} {r}" for r, t in final_args)
            if llvm_ret == "void":
                self.emit(f"  call void @{c_name}({arg_str})")
                return ("void", "void")
            else:
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call {llvm_ret} @{c_name}({arg_str})")
                return (tmp, llvm_ret)

        # -------------------------------------------------------
        # Step 5: Normal function call
        # -------------------------------------------------------
        tmp      = self.fresh_temp()
        arg_str  = ", ".join(f"{t} {r}" for r, t in args)
        # Try bare name first
        ret_type = self.method_return_types.get(func_name)

        # If inside a class, try mangled name
        if ret_type is None and self.current_class:
            mangled = f"{self.current_class}_{func_name}"
            mangled_ret = self.method_return_types.get(mangled)
            if mangled_ret is not None:
                ret_type = mangled_ret
                func_name = mangled

        # Final fallback
        if ret_type is None:
            ret_type = "i32"
        if ret_type == "void":
            self.emit(f"  call void @{func_name}({arg_str})")
            return ("void", "void")
        else:
            self.emit(f"  {tmp} = call {ret_type} @{func_name}({arg_str})")
            return (tmp, ret_type)
        
    def gen_print(self, args: list, node) -> tuple:
        new_line = 0
        for arg in node.args:
            if isinstance(arg, Assignment):
                if isinstance(arg.target, Identifier) and arg.target.name == "newLine":
                    if isinstance(arg.value, BoolLiteral):
                        new_line = 1 if arg.value.value else 0

        if not args:
            return ("void", "void")

        # filter out keyword args from node.args to get positional count
        positional_nodes = [a for a in node.args if not isinstance(a, Assignment)]

        for i, (val_reg, val_type) in enumerate(args):
            is_last = (i == len(args) - 1)
            nl = new_line if is_last else 0

            # dict access special cases only for first arg
            if i == 0:
                print_arg = positional_nodes[0]
                if isinstance(print_arg, Index2DAccess):
                    if isinstance(print_arg.obj, Identifier):
                        mocha_type = self.local_mocha_types.get(print_arg.obj.name, "")
                        if mocha_type == "dict":
                            dict_reg, _ = self.gen_expr(print_arg.obj)
                            key1_reg, _ = self.gen_expr(print_arg.row)
                            inner = self.fresh_temp()
                            self.emit(f"  {inner} = call i8* @mocha_dict_get(%MochaDict* {dict_reg}, i8* {key1_reg})")
                            cast = self.fresh_temp()
                            self.emit(f"  {cast} = bitcast i8* {inner} to %MochaDict*")
                            key2_reg, _ = self.gen_expr(print_arg.col)
                            self.emit(f"  call void @mocha_dict_print_value(%MochaDict* {cast}, i8* {key2_reg}, i8 {nl})")
                            continue

                if isinstance(print_arg, IndexAccess):
                    if isinstance(print_arg.obj, Identifier):
                        mocha_type = self.local_mocha_types.get(print_arg.obj.name, "")
                        if mocha_type == "dict":
                            dict_reg, _ = self.gen_expr(print_arg.obj)
                            key_reg, _ = self.gen_expr(print_arg.index)
                            self.emit(f"  call void @mocha_dict_print_value(%MochaDict* {dict_reg}, i8* {key_reg}, i8 {nl})")
                            continue

            # normal print dispatch
            print_fns = {
                "i8*":    "mocha_print_str",
                "i32":    "mocha_print_int",
                "i64":    "mocha_print_vast",
                "double": "mocha_print_float",
                "i8":     "mocha_print_bool",
                "i1":     "mocha_print_bool",
            }
            fn = print_fns.get(val_type, "mocha_print_str")

            if val_type == "i8*":
                self.emit(f"  call void @{fn}(i8* {val_reg}, i8 {nl})")
            elif val_type == "double":
                self.emit(f"  call void @{fn}(double {val_reg}, i8 {nl})")
            elif val_type == "i8":
                self.emit(f"  call void @{fn}(i8 {val_reg}, i8 {nl})")
            elif val_type == "i1":
                w = self.fresh_temp()
                self.emit(f"  {w} = zext i1 {val_reg} to i8")
                self.emit(f"  call void @mocha_print_bool(i8 {w}, i8 {nl})")
            elif val_type == "i64":
                self.emit(f"  call void @{fn}(i64 {val_reg}, i8 {nl})")
            else:
                self.emit(f"  call void @{fn}(i32 {val_reg}, i8 {nl})")

        return ("void", "void")
    
    # -------------------------------------------------------
    # Sorting (Merge+Slct, N=16)!
    # -------------------------------------------------------

    def gen_sort(self, args: list, node) -> tuple:
        if not args:
            return ("void", "void")

        arr_reg, arr_type = args[0]

        # Check for lambda comparator
        has_lambda = len(node.args) > 1 and isinstance(node.args[1], LambdaExpr)

        sort_fn = "mocha_sort_int"
        sort_env_fn = "mocha_sort_int_cmp_env"
        elem_mocha = "int"
        if isinstance(node.args[0], Identifier):
            mocha_type = self.local_mocha_types.get(node.args[0].name, "")
            if mocha_type:
                bracket = mocha_type.rfind("[")
                elem_mocha = mocha_type[:bracket]
                sort_fn = {
                    "int":   "mocha_sort_int",
                    "float": "mocha_sort_float",
                    "str":   "mocha_sort_str",
                }.get(elem_mocha, "mocha_sort_int")
                sort_env_fn = {
                    "int":   "mocha_sort_int_cmp_env",
                    "float": "mocha_sort_float_cmp_env",
                    "str":   "mocha_sort_str_cmp_env",
                }.get(elem_mocha, "mocha_sort_int_cmp_env")

        if has_lambda:
            bundle_reg, _ = args[1]
            bundle_cast = self.fresh_temp()
            self.emit(f"  {bundle_cast} = bitcast i8* {bundle_reg} to %MochaClosureBundle*")
            self.emit(f"  call void @{sort_env_fn}(%MochaArray* {arr_reg}, %MochaClosureBundle* {bundle_cast})")
        else:
            self.emit(f"  call void @{sort_fn}(%MochaArray* {arr_reg})")

        return ("void", "void")
    
    def find_captured_vars(self, node, param_names: set) -> list:
        """Walk lambda body AST and find identifiers from outer scope."""
        captured = []
        seen = set()

        def walk(n):
            if isinstance(n, Identifier):
                name = n.name
                if (name not in param_names and 
                    name not in seen and
                    name in self.locals):
                    captured.append((name, self.locals[name]))
                    seen.add(name)
            # Walk children
            for field in vars(n).values():
                if isinstance(field, Node):
                    walk(field)
                elif isinstance(field, list):
                    for item in field:
                        if isinstance(item, Node):
                            walk(item)

        walk(node)
        return captured
    
    def _save_codegen_state(self):
        return (
            self.output,
            self.locals.copy(),
            self.local_mocha_types.copy()
        )

    def _restore_codegen_state(self, state):
        self.output, self.locals, self.local_mocha_types = state

    def _emit_bundle(self, fn_cast, env_ptr_or_null, ret_tag):
        """Emit a closure bundle {fn_ptr, env_ptr, ret_tag} and return bundle reg."""
        bundle  = self.fresh_temp()
        slot0   = self.fresh_temp()
        slot1   = self.fresh_temp()
        slot2   = self.fresh_temp()
        tag_ptr = self.fresh_temp()
        self.emit(f"  {bundle} = call i8* @malloc(i64 24)")
        self.emit(f"  {slot0} = bitcast i8* {bundle} to i8**")
        self.emit(f"  store i8* {fn_cast}, i8** {slot0}")
        self.emit(f"  {slot1} = getelementptr i8*, i8** {slot0}, i32 1")
        self.emit(f"  store i8* {env_ptr_or_null}, i8** {slot1}")
        self.emit(f"  {slot2} = getelementptr i8*, i8** {slot0}, i32 2")
        self.emit(f"  {tag_ptr} = bitcast i8** {slot2} to i32*")
        self.emit(f"  store i32 {ret_tag}, i32* {tag_ptr}")
        return bundle

    def gen_lambda(self, node: LambdaExpr) -> tuple:
        lambda_name = f"mocha_lambda_{self.temp_count}"
        self.temp_count += 1

        # --- 1. Find captured variables ---
        param_names = {p.name for p in node.params}
        captured    = self.find_captured_vars(node.body, param_names)
        has_capture = len(captured) > 0

        # --- 2. Build env struct and allocate if needed ---
        env_type    = f"%env_{lambda_name}"
        env_ptr_reg = None

        if has_capture:
            field_types = ", ".join(llvm_t for (_, (_, llvm_t)) in captured)
            self.type_declarations.append(f"{env_type} = type {{ {field_types} }}")

            env_alloc = self.fresh_temp()
            env_cast  = self.fresh_temp()
            struct_size = len(captured) * 8
            self.emit(f"  {env_alloc} = call i8* @malloc(i64 {struct_size})")
            self.emit(f"  {env_cast} = bitcast i8* {env_alloc} to {env_type}*")
            env_ptr_reg = env_cast

            for i, (name, (ptr, llvm_t)) in enumerate(captured):
                val       = self.fresh_temp()
                field_ptr = self.fresh_temp()
                self.emit(f"  {val} = load {llvm_t}, {llvm_t}* {ptr}")
                self.emit(f"  {field_ptr} = getelementptr {env_type}, {env_type}* {env_cast}, i32 0, i32 {i}")
                self.emit(f"  store {llvm_t} {val}, {llvm_t}* {field_ptr}")

        # --- 3. Save state and generate lambda body ---
        saved_state = self._save_codegen_state()
        self.output           = []
        self.locals           = {}
        self.local_name_counts = {}  # tracks how many times a name has been used
        self.local_mocha_types = {}

        param_strs = [f"i8* %{p.name}_raw" for p in node.params]
        if has_capture:
            param_strs.append(f"{env_type}* %env")
        else:
            param_strs.append("i8* %env_unused")
        param_str = ", ".join(param_strs)

        ret_llvm = to_llvm_type(node.return_type) if node.return_type else "i8"

        self.emit(f"define {ret_llvm} @{lambda_name}({param_str}) {{")
        self.emit("entry:")

        for p in node.params:
            llvm_type = to_llvm_type(p.type)
            ptr       = self.fresh_temp()
            val       = self.fresh_temp()
            local_ptr = f"%{p.name}.ptr"
            self.emit(f"  {ptr} = bitcast i8* %{p.name}_raw to {llvm_type}*")
            self.emit(f"  {val} = load {llvm_type}, {llvm_type}* {ptr}")
            self.emit(f"  {local_ptr} = alloca {llvm_type}")
            self.emit(f"  store {llvm_type} {val}, {llvm_type}* {local_ptr}")
            self.locals[p.name]            = (local_ptr, llvm_type)
            self.local_mocha_types[p.name] = p.type

        if has_capture:
            saved_mocha_types = saved_state[2]
            for i, (name, (_, llvm_t)) in enumerate(captured):
                field_ptr = self.fresh_temp()
                val       = self.fresh_temp()
                local_ptr = f"%captured_{name}.ptr"
                self.emit(f"  {field_ptr} = getelementptr {env_type}, {env_type}* %env, i32 0, i32 {i}")
                self.emit(f"  {val} = load {llvm_t}, {llvm_t}* {field_ptr}")
                self.emit(f"  {local_ptr} = alloca {llvm_t}")
                self.emit(f"  store {llvm_t} {val}, {llvm_t}* {local_ptr}")
                self.locals[name]            = (local_ptr, llvm_t)
                self.local_mocha_types[name] = saved_mocha_types.get(name, "int")

        result_reg, result_type = self.gen_expr(node.body)

        if ret_llvm == "i8" and result_type == "i1":
            ext = self.fresh_temp()
            self.emit(f"  {ext} = zext i1 {result_reg} to i8")
            result_reg = ext
        elif ret_llvm == "i1" and result_type == "i8":
            trunc = self.fresh_temp()
            self.emit(f"  {trunc} = trunc i8 {result_reg} to i1")
            result_reg = trunc

        self.emit(f"  ret {ret_llvm} {result_reg}")
        self.emit("}")
        self.emit_blank()

        lambda_output = self.output
        self._restore_codegen_state(saved_state)

        self.lambda_functions = getattr(self, 'lambda_functions', [])
        self.lambda_functions.extend(lambda_output)

        # --- 4. Build and return closure bundle ---
        ret_tag = {"i8": 0, "i32": 0, "i1": 0, "double": 1, "i8*": 2}.get(ret_llvm, 0)
        fn_cast = self.fresh_temp()

        if has_capture:
            param_type_str = ", ".join(["i8*"] * len(node.params))
            self.emit(f"  {fn_cast} = bitcast {ret_llvm} ({param_type_str}, {env_type}*)* @{lambda_name} to i8*")
            env_cast2 = self.fresh_temp()
            self.emit(f"  {env_cast2} = bitcast {env_type}* {env_ptr_reg} to i8*")
            bundle = self._emit_bundle(fn_cast, env_cast2, ret_tag)
        else:
            param_type_str = ", ".join(["i8*"] * (len(node.params) + 1))
            self.emit(f"  {fn_cast} = bitcast {ret_llvm} ({param_type_str})* @{lambda_name} to i8*")
            bundle = self._emit_bundle(fn_cast, "null", ret_tag)

        return (bundle, "i8*")

    # -------------------------------------------------------
    # Statements
    # -------------------------------------------------------

    def gen_stmt(self, node: Node):
        if hasattr(node, 'line') and node.line:
            self.emit_line_update(node.line)

        if isinstance(node, VarDecl):              self.gen_var_decl(node)

        elif isinstance(node, ConstDecl):          self.gen_const_decl(node)

        elif isinstance(node, Assignment):
            if isinstance(node.target, IndexAccess):
                self.gen_index_assign(node)
            elif isinstance(node.target, Index2DAccess):
                self.gen_index2d_assign(node)
            else:
                self.gen_assignment(node)

        elif isinstance(node, CompoundAssignment): self.gen_compound_assignment(node)

        elif isinstance(node, ReturnStmt):         self.gen_return(node)

        elif isinstance(node, IfStmt):             self.gen_if(node)

        elif isinstance(node, WhileLoop):          self.gen_while(node)

        elif isinstance(node, DoWhileLoop):        self.gen_do_while(node)

        elif isinstance(node, ForLoop):            self.gen_for(node)

        elif isinstance(node, ForEachLoop):        self.gen_foreach(node)

        elif isinstance(node, MatchStmt):          self.gen_match(node)

        elif isinstance(node, BreakStmt):
            if hasattr(self, 'break_label'):
                self.emit(f"  br label %{self.break_label}")

        elif isinstance(node, ContinueStmt):
            if hasattr(self, 'continue_label'):
                self.emit(f"  br label %{self.continue_label}")

        elif isinstance(node, TryRescue):          self.gen_try_rescue(node)

        elif isinstance(node, FailStmt):           self.gen_fail(node)

        elif isinstance(node, RethrowStmt):        self.gen_rethrow(node)

        elif isinstance(node, TagDecl):
            pass #Handled in main generate()
        else:
            self.gen_expr(node)
    
    def unique_ptr_name(self, name: str) -> str:
        """Generate a unique pointer name, deduplicating if needed."""
        if name not in self.local_name_counts:
            self.local_name_counts[name] = 0
            return f"%{name}.ptr"
        else:
            self.local_name_counts[name] += 1
            return f"%{name}.{self.local_name_counts[name]}.ptr"

    def gen_var_decl(self, node):

        #Tuples!
        if node.type.startswith("("):
            val_reg, val_type = self.gen_expr(node.value)
            ptr = self.unique_ptr_name(node.name)
            self.alloca_at_entry("%MochaTuple*", ptr)
            self.emit(f"  store %MochaTuple* {val_reg}, %MochaTuple** {ptr}")
            self.locals[node.name] = (ptr, "%MochaTuple*")
            self.local_mocha_types[node.name] = node.type
            return
        
        # Dict!
        self.expected_assign_type = node.type
        val_reg, val_type = self.gen_expr(node.value)
        self.expected_assign_type = None  # reset

        if node.type == "dict":
            ptr = self.unique_ptr_name(node.name)
            self.alloca_at_entry("%MochaDict*", ptr)
            self.emit(f"  store %MochaDict* {val_reg}, %MochaDict** {ptr}")
            self.locals[node.name] = (ptr, "%MochaDict*")
            self.local_mocha_types[node.name] = "dict"
            return
        
        #Arrays!
        if "[" in node.type:
            # Check if it's a 2D array type e.g. "int[3][3]" or "int[][]"
            elem_type = node.type
            bracket = elem_type.rfind("[")
            base = elem_type[:bracket]
            is_2d = "[" in base

            ptr = self.unique_ptr_name(node.name)
            if is_2d:
                self.alloca_at_entry("%MochaArray2D*", ptr)
                self.emit(f"  store %MochaArray2D* {val_reg}, %MochaArray2D** {ptr}")
                self.locals[node.name] = (ptr, "%MochaArray2D*")
            else:
                self.alloca_at_entry("%MochaArray*", ptr)
                self.emit(f"  store %MochaArray* {val_reg}, %MochaArray** {ptr}")
                self.locals[node.name] = (ptr, "%MochaArray*")
            self.local_mocha_types[node.name] = node.type
            return
        
        # Sets!
        if node.type.startswith("set<"):
            if isinstance(node.value, SetLiteral) and not node.value.elements:
                inner = node.type[4:-1]  # "set<int>" -> "int"
                type_tags = {"int": 0, "float": 1, "str": 2, "bool": 3, "object": 4, "vast": 5}
                tag = type_tags.get(inner, 0)
                s = self.fresh_temp()
                self.emit(f"  {s} = call %MochaSet* @mocha_set_new(i32 {tag})")
                ptr = self.unique_ptr_name(node.name)
                self.alloca_at_entry("%MochaSet*", ptr)
                self.emit(f"  store %MochaSet* {s}, %MochaSet** {ptr}")
                self.locals[node.name] = (ptr, "%MochaSet*")
                self.local_mocha_types[node.name] = node.type
                return
            val_reg, val_type = self.gen_expr(node.value)
            ptr = self.unique_ptr_name(node.name)
            self.alloca_at_entry("%MochaSet*", ptr)
            self.emit(f"  store %MochaSet* {val_reg}, %MochaSet** {ptr}")
            self.locals[node.name] = (ptr, "%MochaSet*")
            self.local_mocha_types[node.name] = node.type
            return
        
        # null as opaque pointer (FFI handle)
        if node.type == "null":
            ptr = self.unique_ptr_name(node.name)
            self.alloca_at_entry("i8*", ptr)
            if node.value:
                val_reg, val_type = self.gen_expr(node.value)
                self.emit(f"  store i8* {val_reg}, i8** {ptr}")
            else:
                self.emit(f"  store i8* null, i8** {ptr}")
            self.locals[node.name] = (ptr, "i8*")
            self.local_mocha_types[node.name] = "null"
            return
        
        # General ← for int/str/float/bool/vast
        llvm_type = to_llvm_type(node.type)
        ptr = self.unique_ptr_name(node.name)
        self.alloca_at_entry(llvm_type, ptr)

        # If expression returned void, store a null/zero default instead
        if val_type == "void" or val_reg == "void":
            if llvm_type.endswith("*"):
                self.emit(f"  store {llvm_type} null, {llvm_type}* {ptr}")
            elif llvm_type == "double":
                self.emit(f"  store double 0.0, double* {ptr}")
            else:
                self.emit(f"  store {llvm_type} 0, {llvm_type}* {ptr}")
            self.locals[node.name] = (ptr, llvm_type)
            return

        # i1 → i8 for bool storage
        if llvm_type == "i8" and val_type == "i1":
            ext = self.fresh_temp()
            self.emit(f"  {ext} = zext i1 {val_reg} to i8")
            val_reg = ext

        # i32 to double promotion
        if llvm_type == "double" and val_type == "i32":
            p = self.fresh_temp()
            self.emit(f"  {p} = sitofp i32 {val_reg} to double")
            val_reg = p
        
        # i32 → i64 promotion for vast
        if llvm_type == "i64" and val_type == "i32":
            p = self.fresh_temp()
            self.emit(f"  {p} = sext i32 {val_reg} to i64")
            val_reg = p

        # i32 → pointer
        if llvm_type.endswith("*") and val_type == "i32":
            p = self.fresh_temp()
            self.emit(f"  {p} = inttoptr i32 {val_reg} to {llvm_type}")
            val_reg = p

        self.emit(f"  store {llvm_type} {val_reg}, {llvm_type}* {ptr}")
        self.locals[node.name] = (ptr, llvm_type)
        self.local_mocha_types[node.name] = node.type

    def gen_const_decl(self, node):
        if isinstance(node.value, IntLiteral):
            self.lib_constants[node.name] = (str(node.value.value), "i32")
        elif isinstance(node.value, FloatLiteral):
            self.lib_constants[node.name] = (str(node.value.value), "double")
        elif isinstance(node.value, BoolLiteral):
            self.lib_constants[node.name] = ("1" if node.value.value else "0", "i8")
        elif isinstance(node.value, UnaryOp) and node.value.op == '-':
            if isinstance(node.value.right, IntLiteral):
                self.lib_constants[node.name] = (str(-node.value.right.value), "i32")
            elif isinstance(node.value.right, FloatLiteral):
                self.lib_constants[node.name] = (str(-node.value.right.value), "double")
            else:
                self.gen_var_decl(node)
        else:
            # fallback for complex const values
            self.gen_var_decl(node)

    def gen_assignment(self, node):
        val_reg, val_type = self.gen_expr(node.value)

        if isinstance(node.target, Identifier):
            if node.target.name not in self.locals:
                raise MochaCodeGenError(f"Assignment to undeclared variable '{node.target.name}'", node.line, node.col)
            ptr, llvm_type = self.locals[node.target.name]
            
            # Coerce value type to match the target variable's declared type.
            # This handles cases where expressions return a different LLVM type
            # than what the variable expects — common with lambda returns (always i8)
            # and vast/int mismatches.

            # lambda bool/int result (i8) → int variable
            if val_type == "i8" and llvm_type == "i32":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = zext i8 {val_reg} to i32")
                val_reg = coerced
            # lambda bool/int result (i8) → float variable
            elif val_type == "i8" and llvm_type == "double":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = uitofp i8 {val_reg} to double")
                val_reg = coerced
            # lambda bool/int result (i8) → str/pointer variable
            elif val_type == "i8" and llvm_type == "i8*":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = inttoptr i8 {val_reg} to i8*")
                val_reg = coerced
            # vast → int (truncate upper 32 bits — may lose data if value > 2^31!)
            elif val_type == "i64" and llvm_type == "i32":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = trunc i64 {val_reg} to i32")
                val_reg = coerced
            # vast → float (numeric conversion, may lose precision for very large values)
            elif val_type == "i64" and llvm_type == "double":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = sitofp i64 {val_reg} to double")  # FIX: was bitcast
                val_reg = coerced
            # vast → str/pointer
            elif val_type == "i64" and llvm_type == "i8*":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = inttoptr i64 {val_reg} to i8*")
                val_reg = coerced
            # vast → bool (truncate to 1 byte)
            elif val_type == "i64" and llvm_type == "i8":
                coerced = self.fresh_temp()
                self.emit(f"  {coerced} = trunc i64 {val_reg} to i8")
                val_reg = coerced

            self.emit(f"  store {llvm_type} {val_reg}, {llvm_type}* {ptr}")

        # --- Member assignment: obj.field = value ---
        elif isinstance(node.target, MemberAccess):
            obj_reg, obj_type = self.gen_expr(node.target.obj)
            if not (obj_type.startswith("%struct.") and obj_type.endswith("*")):
                return
            class_name = obj_type[len("%struct."):-1]
            fields     = self.class_fields.get(class_name, [])
            for idx, (fname, ftype) in enumerate(fields):
                if fname == node.target.member:
                    llvm_ftype = ftype if ftype.startswith("%") or ftype in ("i32", "i64", "double", "i8", "i8*", "void") else to_llvm_type(ftype) # ← convert here
                    ptr = self.fresh_temp()
                    self.emit(
                        f"  {ptr} = getelementptr %struct.{class_name}, "
                        f"%struct.{class_name}* {obj_reg}, i32 0, i32 {idx}"
                    )
                    # Promote i32 → double if needed
                    if llvm_ftype == "double" and val_type == "i32":
                        p = self.fresh_temp()
                        self.emit(f"  {p} = sitofp i32 {val_reg} to double")
                        val_reg = p
                    self.emit(f"  store {llvm_ftype} {val_reg}, {llvm_ftype}* {ptr}")
                    break

        # --- Index assignment: arr[i] = value ---
        elif isinstance(node.target, IndexAccess):
            arr_reg, _ = self.gen_expr(node.target.obj)
            idx_reg, _ = self.gen_expr(node.target.index)
            elem_llvm  = val_type
            slot = self.alloca_at_entry(elem_llvm)
            self.emit(f"  store {elem_llvm} {val_reg}, {elem_llvm}* {slot}")
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {elem_llvm}* {slot} to i8*")
            self.emit(f"  call void @mocha_array_set(%MochaArray* {arr_reg}, i32 {idx_reg}, i8* {cast})")

        # --- Dict index assignment: d["key"] = value ---
        elif isinstance(node.target, Index2DAccess):
            pass  # handled separately if needed

    def gen_compound_assignment(self, node):
        if isinstance(node.target, Identifier):
            ptr, llvm_type = self.locals[node.target.name]

        elif isinstance(node.target, MemberAccess):
            # infer_mocha_type takes the AST node, not llvm string
            class_name = self.infer_mocha_type(node.target.obj)
            obj_reg, obj_llvm_type = self.gen_expr(node.target.obj)
            member = node.target.member
            fields = self.class_mocha_fields.get(class_name, [])
            field_index = next(
                (i for i, (n, _) in enumerate(fields) if n == member), None
            )
            if field_index is None:
                raise MochaCodeGenError(
                    f"Unknown field '{member}' on '{class_name}'",
                    node.line, node.col
                )
            _, field_mocha_type = fields[field_index]
            llvm_type = to_llvm_type(field_mocha_type)  # standalone function
            llvm_struct_type = obj_llvm_type.rstrip("*")
            ptr = self.fresh_temp()
            self.emit(f"  {ptr} = getelementptr {llvm_struct_type}, {obj_llvm_type} {obj_reg}, i32 0, i32 {field_index}")

        else:
            raise MochaCodeGenError(
                "Compound assignment target must be a variable or field",
                node.line, node.col
            )

        # ── Load, operate, store ───────────────────────────────
        old = self.fresh_temp()
        self.emit(f"  {old} = load {llvm_type}, {llvm_type}* {ptr}")
        val_reg, _ = self.gen_expr(node.value)
        new = self.fresh_temp()
        is_float = llvm_type == "double"
        if   node.op == "+=": instr = "fadd" if is_float else "add"
        elif node.op == "-=": instr = "fsub" if is_float else "sub"
        elif node.op == "*=": instr = "fmul" if is_float else "mul"
        elif node.op == "/=": instr = "fdiv" if is_float else "sdiv"
        else: raise MochaCodeGenError(f"Unknown compound op: {node.op}", node.line, node.col)
        self.emit(f"  {new} = {instr} {llvm_type} {old}, {val_reg}")
        self.emit(f"  store {llvm_type} {new}, {llvm_type}* {ptr}")

    def gen_return(self, node):
        if node.value is None or self.current_return_type == "void":
            self.emit("  call void @mocha_stack_pop()")
            self.emit("  ret void")
            return

        val_reg, val_type = self.gen_expr(node.value)

        if val_type == "void" or val_reg == "void":
            if self.current_return_type == "void":
                self.emit("  call void @mocha_stack_pop()")
                self.emit("  ret void")
            else:
                self.emit("  call void @mocha_stack_pop()")
                if self.current_return_type == "i8*":
                    self.emit("  ret i8* null")
                elif self.current_return_type.endswith("*"):
                    self.emit(f"  ret {self.current_return_type} null")
                elif self.current_return_type == "double":
                    self.emit("  ret double 0.0")
                else:
                    self.emit(f"  ret {self.current_return_type} 0")
            return

        # Promote i32 → double
        if self.current_return_type == "double" and val_type == "i32":
            p = self.fresh_temp()
            self.emit(f"  {p} = sitofp i32 {val_reg} to double")
            val_reg = p
        
        # Promote i32 → i64
        if self.current_return_type == "i64" and val_type == "i32":
            p = self.fresh_temp()
            self.emit(f"  {p} = sext i32 {val_reg} to i64")
            val_reg = p

        # Demote double → i32
        if self.current_return_type == "i32" and val_type == "double":
            p = self.fresh_temp()
            self.emit(f"  {p} = fptosi double {val_reg} to i32")
            val_reg = p

        # i32 → pointer
        if self.current_return_type.endswith("*") and val_type == "i32":
            p = self.fresh_temp()
            self.emit(f"  {p} = inttoptr i32 {val_reg} to {self.current_return_type}")
            val_reg = p
        
        # i1 → i8
        if self.current_return_type == "i8" and val_type == "i1":
            p = self.fresh_temp()
            self.emit(f"  {p} = zext i1 {val_reg} to i8")
            val_reg = p
            
        self.emit("  call void @mocha_stack_pop()")
        if self.current_return_type.endswith("*") and val_reg == "null":
            self.emit(f"  ret {self.current_return_type} null")
        else:
            self.emit(f"  ret {self.current_return_type} {val_reg}")

    def bool_to_i1(self, reg: str, reg_type: str) -> str:
        if reg_type == "i1":
            return reg
        tmp = self.fresh_temp()
        if reg_type == "i32":
            self.emit(f"  {tmp} = icmp ne i32 {reg}, 0")
        elif reg_type == "double":
            self.emit(f"  {tmp} = fcmp one double {reg}, 0.0")
        elif reg_type == "i64":
            self.emit(f"  {tmp} = icmp ne i64 {reg}, 0")
        else:
            self.emit(f"  {tmp} = trunc i8 {reg} to i1")
        return tmp

    def gen_if(self, node):
        count    = self.temp_count
        then_lbl = f"if_then_{count}"
        else_lbl = f"if_else_{count}"
        end_lbl  = f"if_end_{count}"
        self.temp_count += 1

        cond_reg, cond_type = self.gen_expr(node.condition)
        cond_i1 = self.bool_to_i1(cond_reg, cond_type)

        if node.else_body or node.else_ifs:
            self.emit(f"  br i1 {cond_i1}, label %{then_lbl}, label %{else_lbl}")
        else:
            self.emit(f"  br i1 {cond_i1}, label %{then_lbl}, label %{end_lbl}")

        self.emit(f"{then_lbl}:")
        for stmt in node.then_body:
            self.gen_stmt(stmt)
        self.emit_br_if_needed(end_lbl)

        if node.else_ifs:
            self.emit(f"{else_lbl}:")
            for i, (elif_cond, elif_body) in enumerate(node.else_ifs):
                c_reg, c_type = self.gen_expr(elif_cond)
                c_i1          = self.bool_to_i1(c_reg, c_type)
                elif_then = f"elif_then_{count}_{i}"
                elif_else = f"elif_else_{count}_{i}"
                self.emit(f"  br i1 {c_i1}, label %{elif_then}, label %{elif_else}")
                self.emit(f"{elif_then}:")
                for stmt in elif_body:
                    self.gen_stmt(stmt)
                self.emit_br_if_needed(end_lbl)
                self.emit(f"{elif_else}:")
            if node.else_body:
                for stmt in node.else_body:
                    self.gen_stmt(stmt)
            self.emit_br_if_needed(end_lbl)

        elif node.else_body:
            self.emit(f"{else_lbl}:")
            for stmt in node.else_body:
                self.gen_stmt(stmt)
            self.emit_br_if_needed(end_lbl)

        self.emit(f"{end_lbl}:")

    def gen_while(self, node):
        count    = self.temp_count
        cond_lbl = f"while_cond_{count}"
        body_lbl = f"while_body_{count}"
        end_lbl  = f"while_end_{count}"
        self.temp_count += 1

        prev_break    = getattr(self, 'break_label',    None)
        prev_continue = getattr(self, 'continue_label', None)
        self.break_label    = end_lbl
        self.continue_label = cond_lbl

        self.emit(f"  br label %{cond_lbl}")
        self.emit(f"{cond_lbl}:")
        cond_reg, cond_type = self.gen_expr(node.condition)
        cond_i1 = self.bool_to_i1(cond_reg, cond_type)
        self.emit(f"  br i1 {cond_i1}, label %{body_lbl}, label %{end_lbl}")
        self.emit(f"{body_lbl}:")
        for stmt in node.body:
            self.gen_stmt(stmt)
        self.emit_br_if_needed(cond_lbl)
        self.emit(f"{end_lbl}:")

        self.break_label    = prev_break
        self.continue_label = prev_continue

    def gen_do_while(self, node):
        count    = self.temp_count
        body_lbl = f"dowhile_body_{count}"
        end_lbl  = f"dowhile_end_{count}"
        self.temp_count += 1

        prev_break    = getattr(self, 'break_label',    None)
        prev_continue = getattr(self, 'continue_label', None)
        self.break_label    = end_lbl
        self.continue_label = body_lbl

        self.emit(f"  br label %{body_lbl}")
        self.emit(f"{body_lbl}:")
        for stmt in node.body:
            self.gen_stmt(stmt)
        cond_reg, cond_type = self.gen_expr(node.condition)
        cond_i1 = self.bool_to_i1(cond_reg, cond_type)
        self.emit(f"  br i1 {cond_i1}, label %{body_lbl}, label %{end_lbl}")
        self.emit(f"{end_lbl}:")

        self.break_label    = prev_break
        self.continue_label = prev_continue

    def gen_for(self, node):
        count    = self.temp_count
        cond_lbl = f"for_cond_{count}"
        body_lbl = f"for_body_{count}"
        end_lbl  = f"for_end_{count}"
        self.temp_count += 1

        prev_break    = getattr(self, 'break_label',    None)
        prev_continue = getattr(self, 'continue_label', None)
        self.break_label    = end_lbl
        self.continue_label = cond_lbl

        self.gen_stmt(node.init)
        self.emit(f"  br label %{cond_lbl}")
        self.emit(f"{cond_lbl}:")
        cond_reg, cond_type = self.gen_expr(node.condition)
        cond_i1 = self.bool_to_i1(cond_reg, cond_type)
        self.emit(f"  br i1 {cond_i1}, label %{body_lbl}, label %{end_lbl}")
        self.emit(f"{body_lbl}:")
        for stmt in node.body:
            self.gen_stmt(stmt)
        self.gen_expr(node.step)
        self.emit_br_if_needed(cond_lbl)
        self.emit(f"{end_lbl}:")

        self.break_label    = prev_break
        self.continue_label = prev_continue

    def gen_foreach(self, node):
        # Set iteration: for each x in <s>
        if isinstance(node.iterable, SetIterable):
            set_reg, _ = self.gen_expr(node.iterable.set_expr)
            
            # Get set size
            len_tmp = self.fresh_temp()
            self.emit(f"  {len_tmp} = call i32 @mocha_set_size(%MochaSet* {set_reg})")
            
            # Loop counter
            idx_ptr = self.fresh_temp()
            self.emit(f"  {idx_ptr} = alloca i32")
            self.emit(f"  store i32 0, i32* {idx_ptr}")
            
            # Labels
            count    = self.temp_count
            self.temp_count += 1
            cond_lbl = f"foreach_set_cond_{count}"
            body_lbl = f"foreach_set_body_{count}"
            end_lbl  = f"foreach_set_end_{count}"
            
            self.emit(f"  br label %{cond_lbl}")
            self.emit(f"{cond_lbl}:")
            
            idx_tmp = self.fresh_temp()
            cmp_tmp = self.fresh_temp()
            self.emit(f"  {idx_tmp} = load i32, i32* {idx_ptr}")
            self.emit(f"  {cmp_tmp} = icmp slt i32 {idx_tmp}, {len_tmp}")
            self.emit(f"  br i1 {cmp_tmp}, label %{body_lbl}, label %{end_lbl}")
            
            self.emit(f"{body_lbl}:")
            
            # Get element from set by index
            llvm_type = to_llvm_type(node.var_type) if node.var_type else "i32"
            elem_ptr  = self.fresh_temp()
            elem_tmp  = self.fresh_temp()
            self.emit(f"  {elem_ptr} = alloca {llvm_type}")
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {llvm_type}* {elem_ptr} to i8*")
            self.emit(f"  call void @mocha_set_get(%MochaSet* {set_reg}, i32 {idx_tmp}, i8* {cast})")
            self.emit(f"  {elem_tmp} = load {llvm_type}, {llvm_type}* {elem_ptr}")
            
            # Declare loop variable
            var_ptr = f"{node.var_name}.ptr"
            self.emit(f"  %{var_ptr} = alloca {llvm_type}")
            self.emit(f"  store {llvm_type} {elem_tmp}, {llvm_type}* %{var_ptr}")
            self.locals[node.var_name] = (f"%{var_ptr}", llvm_type)
            
            # Body
            old_break    = getattr(self, 'break_label', None)
            old_continue = getattr(self, 'continue_label', None)
            self.break_label    = end_lbl
            self.continue_label = cond_lbl
            for stmt in node.body:
                self.gen_stmt(stmt)
            self.break_label    = old_break
            self.continue_label = old_continue
            
            # Increment
            next_tmp = self.fresh_temp()
            idx_tmp2 = self.fresh_temp()
            self.emit(f"  {idx_tmp2} = load i32, i32* {idx_ptr}")
            self.emit(f"  {next_tmp} = add i32 {idx_tmp2}, 1")
            self.emit(f"  store i32 {next_tmp}, i32* {idx_ptr}")
            self.emit(f"  br label %{cond_lbl}")
            
            self.emit(f"{end_lbl}:")
            return

        # Original array iteration — unchanged
        arr_reg, _ = self.gen_expr(node.iterable)
        
        len_tmp = self.fresh_temp()
        self.emit(f"  {len_tmp} = call i32 @mocha_array_length(%MochaArray* {arr_reg})")
        
        idx_ptr = self.fresh_temp()
        self.emit(f"  {idx_ptr} = alloca i32")
        self.emit(f"  store i32 0, i32* {idx_ptr}")
        
        count    = self.temp_count
        self.temp_count += 1
        cond_lbl = f"foreach_cond_{count}"
        body_lbl = f"foreach_body_{count}"
        end_lbl  = f"foreach_end_{count}"
        
        self.emit(f"  br label %{cond_lbl}")
        self.emit(f"{cond_lbl}:")
        
        idx_tmp = self.fresh_temp()
        cmp_tmp = self.fresh_temp()
        self.emit(f"  {idx_tmp} = load i32, i32* {idx_ptr}")
        self.emit(f"  {cmp_tmp} = icmp slt i32 {idx_tmp}, {len_tmp}")
        self.emit(f"  br i1 {cmp_tmp}, label %{body_lbl}, label %{end_lbl}")
        
        self.emit(f"{body_lbl}:")
        
        llvm_type = to_llvm_type(node.var_type) if node.var_type else "i8*"
        elem_ptr  = self.fresh_temp()
        elem_tmp  = self.fresh_temp()
        self.emit(f"  {elem_ptr} = alloca {llvm_type}")
        self.emit(f"  call void @mocha_array_get(%MochaArray* {arr_reg}, i32 {idx_tmp}, i8* {elem_ptr})")
        self.emit(f"  {elem_tmp} = load {llvm_type}, {llvm_type}* {elem_ptr}")
        
        var_ptr = f"{node.var_name}.ptr"
        self.emit(f"  %{var_ptr} = alloca {llvm_type}")
        self.emit(f"  store {llvm_type} {elem_tmp}, {llvm_type}* %{var_ptr}")
        self.locals[node.var_name] = (f"%{var_ptr}", llvm_type)
        
        old_break    = getattr(self, 'break_label', None)
        old_continue = getattr(self, 'continue_label', None)
        self.break_label    = end_lbl
        self.continue_label = cond_lbl
        for stmt in node.body:
            self.gen_stmt(stmt)
        self.break_label    = old_break
        self.continue_label = old_continue
        
        next_tmp = self.fresh_temp()
        idx_tmp2 = self.fresh_temp()
        self.emit(f"  {idx_tmp2} = load i32, i32* {idx_ptr}")
        self.emit(f"  {next_tmp} = add i32 {idx_tmp2}, 1")
        self.emit(f"  store i32 {next_tmp}, i32* {idx_ptr}")
        self.emit(f"  br label %{cond_lbl}")
        
        self.emit(f"{end_lbl}:")
    
    def gen_list_comprehension(self, node):
        # Get element LLVM type
        llvm_elem_type = to_llvm_type(node.elem_type)
        src_llvm_type = to_llvm_type(node.src_elem_type)
        
        # Type tag for array
        elem_size = {"i32": 4, "double": 8, "i8*": 8, "i8": 1}.get(llvm_elem_type, 8)

        # Create result array
        result_arr = self.fresh_temp()
        self.emit(f"  {result_arr} = call %MochaArray* @mocha_array_new(i32 0, i32 {elem_size}, i32 0)")

        # Store result array in a local ptr so we can reference it
        arr_ptr = self.fresh_temp()
        self.emit(f"  {arr_ptr} = alloca %MochaArray*")
        self.emit(f"  store %MochaArray* {result_arr}, %MochaArray** {arr_ptr}")

        # Generate iterable
        iter_reg, iter_type = self.gen_expr(node.iterable)

        # Get length
        len_tmp = self.fresh_temp()
        self.emit(f"  {len_tmp} = call i32 @mocha_array_length(%MochaArray* {iter_reg})")

        # Loop counter
        count = self.temp_count
        self.temp_count += 1
        idx_ptr = f"%lc_idx_{count}"
        self.emit(f"  {idx_ptr} = alloca i32")
        self.emit(f"  store i32 0, i32* {idx_ptr}")

        loop_lbl  = f"lc_loop_{count}"
        body_lbl  = f"lc_body_{count}"
        end_lbl   = f"lc_end_{count}"

        self.emit(f"  br label %{loop_lbl}")
        self.emit(f"{loop_lbl}:")

        # Check i < length
        idx = self.fresh_temp()
        self.emit(f"  {idx} = load i32, i32* {idx_ptr}")
        cmp = self.fresh_temp()
        self.emit(f"  {cmp} = icmp slt i32 {idx}, {len_tmp}")
        self.emit(f"  br i1 {cmp}, label %{body_lbl}, label %{end_lbl}")
        self.emit(f"{body_lbl}:")

        # Load element from source array into loop variable
        raw_ptr = self.fresh_temp()
        self.emit(f"  {raw_ptr} = alloca {src_llvm_type}")
        cast_ptr = self.fresh_temp()
        self.emit(f"  {cast_ptr} = bitcast {src_llvm_type}* {raw_ptr} to i8*")
        self.emit(f"  call void @mocha_array_get(%MochaArray* {iter_reg}, i32 {idx}, i8* {cast_ptr})")

        # Register loop var in locals
        elem_ptr = f"%lc_{node.var_name}_{count}.ptr"
        self.emit(f"  {elem_ptr} = alloca {src_llvm_type}")
        val = self.fresh_temp()
        self.emit(f"  {val} = load {src_llvm_type}, {src_llvm_type}* {raw_ptr}")
        self.emit(f"  store {src_llvm_type} {val}, {src_llvm_type}* {elem_ptr}")
        self.locals[node.var_name] = (elem_ptr, src_llvm_type)

        # ── Condition handling ──
        if node.condition is not None:
            cond_reg, cond_type = self.gen_expr(node.condition)
            cond_i1 = self.bool_to_i1(cond_reg, cond_type)

            if hasattr(node, 'else_expr') and node.else_expr is not None:
                # if/else — always appends, just different value per branch
                then_lbl  = f"lc_then_{count}"
                else_lbl  = f"lc_else_{count}"
                merge_lbl = f"lc_merge_{count}"

                # alloca slot to merge both branch results
                result_slot = self.fresh_temp()
                self.emit(f"  {result_slot} = alloca {llvm_elem_type}")

                self.emit(f"  br i1 {cond_i1}, label %{then_lbl}, label %{else_lbl}")

                # then branch — use expr
                self.emit(f"{then_lbl}:")
                then_reg, _ = self.gen_expr(node.expr)
                self.emit(f"  store {llvm_elem_type} {then_reg}, {llvm_elem_type}* {result_slot}")
                self.emit(f"  br label %{merge_lbl}")

                # else branch — use else_expr
                self.emit(f"{else_lbl}:")
                else_reg, _ = self.gen_expr(node.else_expr)
                self.emit(f"  store {llvm_elem_type} {else_reg}, {llvm_elem_type}* {result_slot}")
                self.emit(f"  br label %{merge_lbl}")

                # merge — load whichever was stored
                self.emit(f"{merge_lbl}:")
                expr_reg = self.fresh_temp()
                self.emit(f"  {expr_reg} = load {llvm_elem_type}, {llvm_elem_type}* {result_slot}")

            else:
                # filter only — skip if condition false
                skip_lbl = f"lc_skip_{count}"
                self.emit(f"  br i1 {cond_i1}, label %lc_append_{count}, label %{skip_lbl}")
                self.emit(f"lc_append_{count}:")
                expr_reg, _ = self.gen_expr(node.expr)

        else:
            # no condition — always append
            expr_reg, _ = self.gen_expr(node.expr)

        # ── Box and append ──
        if llvm_elem_type == "i8*":
            box_ptr = self.fresh_temp()
            self.emit(f"  {box_ptr} = alloca i8*")
            self.emit(f"  store i8* {expr_reg}, i8** {box_ptr}")
            boxed = self.fresh_temp()
            self.emit(f"  {boxed} = bitcast i8** {box_ptr} to i8*")
        else:
            box_ptr = self.fresh_temp()
            self.emit(f"  {box_ptr} = alloca {llvm_elem_type}")
            self.emit(f"  store {llvm_elem_type} {expr_reg}, {llvm_elem_type}* {box_ptr}")
            boxed = self.fresh_temp()
            self.emit(f"  {boxed} = bitcast {llvm_elem_type}* {box_ptr} to i8*")

        arr_loaded = self.fresh_temp()
        self.emit(f"  {arr_loaded} = load %MochaArray*, %MochaArray** {arr_ptr}")
        self.emit(f"  call void @mocha_array_push(%MochaArray* {arr_loaded}, i8* {boxed})")

        # Skip label — only for filter case (not if/else)
        if node.condition is not None:
            if not (hasattr(node, 'else_expr') and node.else_expr is not None):
                self.emit(f"  br label %lc_skip_{count}")
                self.emit(f"lc_skip_{count}:")

        # Increment index
        next_idx = self.fresh_temp()
        self.emit(f"  {next_idx} = add i32 {idx}, 1")
        self.emit(f"  store i32 {next_idx}, i32* {idx_ptr}")
        self.emit(f"  br label %{loop_lbl}")
        self.emit(f"{end_lbl}:")

        # Clean up loop variable
        del self.locals[node.var_name]

        # Return result array
        final = self.fresh_temp()
        self.emit(f"  {final} = load %MochaArray*, %MochaArray** {arr_ptr}")
        return (final, "%MochaArray*")

    def gen_match(self, node):
        count   = self.temp_count
        end_lbl = f"match_end_{count}"
        self.temp_count += 1

        val_reg, val_type = self.gen_expr(node.value)

        cases         = [(i, c) for i, c in enumerate(node.cases) if not c.is_default]
        default_cases = [(i, c) for i, c in enumerate(node.cases) if c.is_default]

        # Must explicitly jump to first label
        if cases:
            self.emit(f"  br label %match_case_{count}_{cases[0][0]}")
        elif default_cases:
            self.emit(f"  br label %match_default_{count}")
        else:
            return

        for idx, (i, case) in enumerate(cases):
            case_lbl = f"match_case_{count}_{i}"
            if idx + 1 < len(cases):
                next_lbl = f"match_case_{count}_{cases[idx+1][0]}"
            elif default_cases:
                next_lbl = f"match_default_{count}"
            else:
                next_lbl = end_lbl

            self.emit(f"{case_lbl}:")

            if isinstance(case.pattern, RangeNode):
                lo_reg, _ = self.gen_expr(case.pattern.start)
                hi_reg, _ = self.gen_expr(case.pattern.end)
                ge   = self.fresh_temp()
                le   = self.fresh_temp()
                both = self.fresh_temp()
                self.emit(f"  {ge} = icmp sge {val_type} {val_reg}, {lo_reg}")
                self.emit(f"  {le} = icmp sle {val_type} {val_reg}, {hi_reg}")
                self.emit(f"  {both} = and i1 {ge}, {le}")
                body_lbl = f"match_body_{count}_{i}"
                self.emit(f"  br i1 {both}, label %{body_lbl}, label %{next_lbl}")
                self.emit(f"{body_lbl}:")
                for stmt in case.body:
                    self.gen_stmt(stmt)
                self.emit_br_if_needed(end_lbl)

            elif isinstance(case.pattern, Identifier) and case.condition:
                body_lbl = f"match_body_{count}_{i}"
                ptr = f"%match_bind_{case.pattern.name}_{count}_{i}"
                self.emit(f"  {ptr} = alloca {val_type}")
                self.emit(f"  store {val_type} {val_reg}, {val_type}* {ptr}")
                self.locals[case.pattern.name] = (ptr, val_type)
                cond_reg, cond_type = self.gen_expr(case.condition)
                cond_i1 = self.bool_to_i1(cond_reg, cond_type)
                self.emit(f"  br i1 {cond_i1}, label %{body_lbl}, label %{next_lbl}")
                self.emit(f"{body_lbl}:")
                for stmt in case.body:
                    self.gen_stmt(stmt)
                self.emit_br_if_needed(end_lbl)
                del self.locals[case.pattern.name]

            else:
                # Resolve constants directly to avoid %NAME.ptr load bug
                if isinstance(case.pattern, Identifier):
                    name = case.pattern.name
                    if name in self.lib_constants:
                        const_val, const_type = self.lib_constants[name]
                        pat_reg = const_val
                    elif name in self.globals:
                        ptr, llvm_type = self.globals[name]
                        pat_reg = self.fresh_temp()
                        self.emit(f"  {pat_reg} = load {llvm_type}, {llvm_type}* {ptr}")
                    else:
                        pat_reg, _ = self.gen_expr(case.pattern)
                else:
                    pat_reg, _ = self.gen_expr(case.pattern)
                cmp = self.fresh_temp()
                if val_type == "i8*":
                    # String comparison — must compare contents not pointers
                    eq = self.fresh_temp()
                    self.emit(f"  {eq} = call i32 @mocha_str_eq(i8* {val_reg}, i8* {pat_reg})")
                    self.emit(f"  {cmp} = icmp ne i32 {eq}, 0")
                else:
                    self.emit(f"  {cmp} = icmp eq {val_type} {val_reg}, {pat_reg}")
                body_lbl = f"match_body_{count}_{i}"
                self.emit(f"  br i1 {cmp}, label %{body_lbl}, label %{next_lbl}")
                self.emit(f"{body_lbl}:")
                for stmt in case.body:
                    self.gen_stmt(stmt)
                self.emit_br_if_needed(end_lbl)

        for i, case in default_cases:
            self.emit(f"match_default_{count}:")
            for stmt in case.body:
                self.gen_stmt(stmt)
            self.emit_br_if_needed(end_lbl)

        self.emit(f"{end_lbl}:")

    # -------------------------------------------------------
    # Functions
    # -------------------------------------------------------

    def gen_function(self, node) -> str:
        # Skip entry point in lib compilation
        if self.is_lib and getattr(node, 'has_didLoad', False):
            return node.name

        # Native function — just emit declare and register, no body
        if getattr(node, 'is_native', False) and node.native_name:
            # null return for native = i8* (opaque pointer)
            ret_llvm = "i8*" if node.return_type == "null" else to_llvm_type(node.return_type)
            llvm_params = [
                "i8*" if p.type == "null" else to_llvm_type(p.type)
                for p in node.params
            ]    
            param_str   = ", ".join(llvm_params)
            # Register mocha name → C name so call sites route correctly
            self.lib_functions[node.name] = (node.native_name, ret_llvm, llvm_params, [p.name for p in node.params])
            self.method_return_types[node.name]        = ret_llvm
            self.method_return_types[node.native_name] = ret_llvm
            # Emit declare for the actual C symbol
            declare = f"declare {ret_llvm} @{node.native_name}({param_str})"
            if declare not in self.extra_declares:
                self.extra_declares.append(declare)
            return node.name
        
        ret_llvm = to_llvm_type(node.return_type)
        params   = [f"{to_llvm_type(p.type)} %{p.name}" for p in node.params]

        if self.current_class and not getattr(node, 'is_shared', False):
            this_type = f"%struct.{self.current_class}*"
            params.insert(0, f"{this_type} %this")

        param_str = ", ".join(params)
        self.method_return_types[node.name] = ret_llvm

        prev_return  = self.current_return_type
        prev_locals  = self.locals.copy()
        self.current_return_type = ret_llvm
        self.in_function         = True

        # ── TWO-PASS: generate body into a side buffer ──
        main_output   = self.output        # save real output
        self.output   = []                 # redirect to temp buffer
        self.entry_allocas = []            # collect allocas separately
        self.local_name_counts = {}        # ← ADD THIS HERE

        # Store 'this'
        if self.current_class and not getattr(node, 'is_shared', False):
            this_type = f"%struct.{self.current_class}*"
            this_ptr  = "%this.ptr"
            self.entry_allocas.append(f"  {this_ptr} = alloca {this_type}")
            self.emit(f"  store {this_type} %this, {this_type}* {this_ptr}")
            self.locals["this"] = (this_ptr, this_type)

        # Store params
        for p in node.params:
            pt  = to_llvm_type(p.type)
            ptr = f"%{p.name}.ptr"
            self.entry_allocas.append(f"  {ptr} = alloca {pt}")
            self.emit(f"  store {pt} %{p.name}, {pt}* {ptr}")
            self.locals[p.name] = (ptr, pt)
            self.local_mocha_types[p.name] = p.type

        # Generate body — allocas will go to entry_allocas, rest to self.output
        for stmt in node.body:
            self.gen_stmt(stmt)

        # Terminator
        if not self.last_is_terminator():
            if ret_llvm == "void":
                self.emit("  call void @mocha_stack_pop()")
                self.emit("  ret void")
            elif ret_llvm == "i8*" or ret_llvm.endswith("*"):
                self.emit("  call void @mocha_stack_pop()")
                self.emit(f"  ret {ret_llvm} null")
            elif ret_llvm == "double":
                self.emit("  call void @mocha_stack_pop()")
                self.emit("  ret double 0.0")
            else:
                self.emit("  call void @mocha_stack_pop()")
                self.emit(f"  ret {ret_llvm} 0")

        body_lines = self.output          # capture body
        self.output = main_output         # restore real output

        # ── Now emit in correct order ──
        mangled = mangle_function_name(node.name)
        self.emit(f"define {ret_llvm} @{mangled}({param_str}) uwtable {{")
        self.emit("entry:")
        # All allocas first
        for line in self.entry_allocas:
            self.output.append(line)
        #Strip mocha_entry_ before displaying
        display_name = node.name
        if display_name.startswith("mocha_entry_"):
            display_name = display_name[len("mocha_entry_"):]
        func_ptr = self.get_func_name_ptr(display_name)
        # Stack push
        file_ptr = self.get_source_file_ptr()
        self.emit(f"  call void @mocha_stack_push(i8* {func_ptr}, i8* {file_ptr}, i32 {node.line})")
        # Then body (stores, operations, etc.)
        for line in body_lines:
            self.output.append(line)
        self.emit("}")
        self.emit_blank()

        self.current_return_type = prev_return
        self.locals              = prev_locals
        self.local_name_counts = {}  # tracks how many times a name has been used
        self.in_function         = False
        self.entry_allocas       = []

        return node.name
    
    def alloca_at_entry(self, llvm_type: str, name: Optional[str] = None) -> str:
        if name is None:
            name = self.fresh_temp()
        if not any(a.startswith(f"  {name} = alloca") for a in self.entry_allocas):
            self.entry_allocas.append(f"  {name} = alloca {llvm_type}")
        return name

    #This if for extend block for arrays since [] is not a valid IR Symbol
    def sanitize_type_name(self, type_name: str) -> str:
        return type_name.replace("[]", "_arr").replace("[", "_").replace("]", "")
    
    def gen_extend(self, node: ExtendDecl):
        self.entry_allocas = []
        # Map Mocha type names to LLVM types for 'this'
        type_to_llvm = {
            "str":      "i8*",
            "int":      "i32",
            "vast":     "i64",
            "float":    "double",
            "bool":     "i8",
            "int[]":    "%MochaArray*",
            "float[]":  "%MochaArray*",
            "str[]":    "%MochaArray*",
            "bool[]":   "%MochaArray*",
            "vast[]":   "%MochaArray*",
            "int[][]":  "%MochaArray2D*",
            "float[][]":"%MochaArray2D*",
        }

        this_llvm = type_to_llvm.get(node.type_name, f"%struct.{node.type_name}*")

        prev_class = self.current_class
        self.current_class = node.type_name

        for func in node.body:
            method_name = f"mocha_ext_{self.sanitize_type_name(node.type_name)}_{func.name}"
            ret_llvm    = to_llvm_type(func.return_type)
            self.method_return_types[method_name] = ret_llvm

            if getattr(func, 'is_native', False):
                continue

            params = [f"{to_llvm_type(p.type)} %{p.name}" for p in func.params]
            params.insert(0, f"{this_llvm} %this")
            param_str = ", ".join(params)

            prev_return              = self.current_return_type
            prev_locals              = self.locals.copy()
            self.current_return_type = ret_llvm
            self.in_function         = True

            # ── TWO-PASS ──
            main_output        = self.output
            self.output        = []
            self.entry_allocas = []

            # Store 'this'
            this_ptr = "%this.ptr"
            self.entry_allocas.append(f"  {this_ptr} = alloca {this_llvm}")
            self.emit(f"  store {this_llvm} %this, {this_llvm}* {this_ptr}")
            self.locals["this"] = (this_ptr, this_llvm)
            self.local_mocha_types["this"] = node.type_name

            # Store params
            for p in func.params:
                pt  = to_llvm_type(p.type)
                ptr = f"%{p.name}.ptr"
                self.entry_allocas.append(f"  {ptr} = alloca {pt}")
                self.emit(f"  store {pt} %{p.name}, {pt}* {ptr}")
                self.locals[p.name] = (ptr, pt)
                self.local_mocha_types[p.name] = p.type

            for stmt in func.body:
                self.gen_stmt(stmt)

            if not self.last_is_terminator():
                if ret_llvm == "void":
                    self.emit("  ret void")
                elif ret_llvm == "i8*" or ret_llvm.endswith("*"):
                    self.emit(f"  ret {ret_llvm} null")
                elif ret_llvm == "double":
                    self.emit("  ret double 0.0")
                else:
                    self.emit(f"  ret {ret_llvm} 0")

            body_lines  = self.output
            self.output = main_output

            # ── Emit in correct order ──
            self.emit(f"define {ret_llvm} @{method_name}({param_str}) {{")
            self.emit("entry:")
            for line in self.entry_allocas:
                self.output.append(line)
            for line in body_lines:
                self.output.append(line)
            self.emit("}")
            self.emit_blank()

            self.current_return_type = prev_return
            self.locals              = prev_locals
            self.local_name_counts = {}  # tracks how many times a name has been used
            self.in_function         = False
            self.entry_allocas       = []

        self.current_class = prev_class

    # -------------------------------------------------------
    # Classes
    # -------------------------------------------------------

    def get_inherited_methods(self, class_name: str, visited=None) -> dict:
        """Recursively collect all inherited methods. Returns {method_name: (parent_func, ret_type, params)}"""
        if visited is None:
            visited = set()
        if class_name in visited:
            return {}
        visited.add(class_name)
        
        node = self.class_nodes.get(class_name)
        if not node:
            return {}
        
        methods = {}
        # First recurse into grandparents so closer parents override further ones
        for parent_name in node.parents:
            for method_name, info in self.get_inherited_methods(parent_name, visited).items():
                methods[method_name] = info
        
        # Then own methods override inherited ones
        for member in node.body:
            if isinstance(member, MethodDecl):
                if member.name == "constructor":
                    continue  # constructors are never inherited
                func_name = f"{class_name}_{member.name}"
                ret_type  = self.method_return_types.get(func_name, "void")
                methods[member.name] = (class_name, func_name, ret_type, member.params)
        
        return methods
    
    def get_all_fields_for_class(self, class_name: str) -> list:
        """Returns all fields in inheritance order — parents first."""
        node = self.class_nodes.get(class_name)
        if not node:
            return []
        fields = []
        for parent_name in node.parents:
            fields += self.get_all_fields_for_class(parent_name)
        for m in node.body:
            if isinstance(m, FieldDecl):
                fields.append((m.name, to_llvm_type(m.type)))
        return fields

    def gen_class(self, node):
        if node.parents:
            self.class_parents[node.name] = node.parents[0]
            self.class_all_parents[node.name] = node.parents

        all_fields = self.get_all_fields_for_class(node.name)
        self.class_fields[node.name] = all_fields

        # Also store original Mocha types
        mocha_fields = []
        for parent_name in (node.parents or []):
            mocha_fields += self.class_mocha_fields.get(parent_name, [])
        for m in node.body:
            if isinstance(m, FieldDecl):
                mocha_fields.append((m.name, m.type))
        self.class_mocha_fields[node.name] = mocha_fields

        for member in node.body:
            if isinstance(member, MethodDecl):
                prev_class         = self.current_class
                self.current_class = node.name
                original_name      = member.name
                member.name        = f"{node.name}_{original_name}"
                self.classes_with_constructors.add(node.name) if original_name == "constructor" else None
                self.method_return_types[f"{node.name}_{original_name}"] = to_llvm_type(member.return_type)
                self.gen_function(member)
                member.name = original_name  # restore
                self.current_class = prev_class
        
        # Emit delegation wrappers for inherited methods
        own_method_names = {m.name for m in node.body if isinstance(m, MethodDecl)}
        inherited = self.get_inherited_methods(node.name)

        for method_name, (parent_class, parent_func, ret_type, params) in inherited.items():
            if method_name in own_method_names:
                continue

            child_func = f"{node.name}_{method_name}"
            self.method_return_types[child_func] = ret_type

            params_str = f"%struct.{node.name}* %self"
            for p in params:
                lt = to_llvm_type(p.type)
                params_str += f", {lt} %{p.name}"

            if ret_type == "void":
                self.emit(f"define void @{child_func}({params_str}) {{")
                self.emit("entry:")
                cast = self.fresh_temp()
                self.emit(f"  {cast} = bitcast %struct.{node.name}* %self to %struct.{parent_class}*")
                args_str = f"%struct.{parent_class}* {cast}"
                for p in params:
                    lt = to_llvm_type(p.type)
                    args_str += f", {lt} %{p.name}"
                self.emit(f"  call void @{parent_func}({args_str})")
                self.emit("  ret void")
            else:
                self.emit(f"define {ret_type} @{child_func}({params_str}) {{")
                self.emit("entry:")
                cast = self.fresh_temp()
                self.emit(f"  {cast} = bitcast %struct.{node.name}* %self to %struct.{parent_class}*")
                args_str = f"%struct.{parent_class}* {cast}"
                for p in params:
                    lt = to_llvm_type(p.type)
                    args_str += f", {lt} %{p.name}"
                tmp = self.fresh_temp()
                self.emit(f"  {tmp} = call {ret_type} @{parent_func}({args_str})")
                self.emit(f"  ret {ret_type} {tmp}")
            self.emit("}")
            self.emit_blank()

        if "constructor" not in own_method_names:
            # Auto-generate default constructor for fields with default values
            fields_with_defaults = [
                m for m in node.body
                if isinstance(m, FieldDecl) and m.value is not None
            ]
            if fields_with_defaults:
                child_func = f"{node.name}_constructor"
                self.method_return_types[child_func] = "void"
                self.classes_with_constructors.add(node.name)

                self.emit(f"define void @{child_func}(%struct.{node.name}* %self) {{")
                self.emit("entry:")

                all_fields = self.class_fields.get(node.name, [])
                for m in fields_with_defaults:
                    idx = next((i for i, (fn, _) in enumerate(all_fields) if fn == m.name), None)
                    if idx is None:
                        continue
                    lt = to_llvm_type(m.type)
                    prev_in_function = self.in_function
                    self.in_function = True
                    if m.value is None:
                        continue
                    val_reg, _ = self.gen_expr(m.value)
                    self.in_function = prev_in_function
                    ptr = self.fresh_temp()
                    self.emit(f"  {ptr} = getelementptr %struct.{node.name}, %struct.{node.name}* %self, i32 0, i32 {idx}")
                    self.emit(f"  store {lt} {val_reg}, {lt}* {ptr}")

                self.emit("  ret void")
                self.emit("}")
                self.emit_blank()

            else:
                found_parent_constructor = False
                # Delegate to parent constructor if one exists
                for parent_name in node.parents:
                    parent_node = self.class_nodes.get(parent_name)
                    if not parent_node:
                        continue
                    for member in parent_node.body:
                        if isinstance(member, MethodDecl) and member.name == "constructor":
                            parent_func = f"{parent_name}_constructor"
                            child_func  = f"{node.name}_constructor"
                            self.method_return_types[child_func] = "void"

                            params_str = f"%struct.{node.name}* %self"
                            for p in member.params:
                                lt = to_llvm_type(p.type)
                                params_str += f", {lt} %{p.name}"

                            self.emit(f"define void @{child_func}({params_str}) {{")
                            self.emit("entry:")
                            cast = self.fresh_temp()
                            self.emit(f"  {cast} = bitcast %struct.{node.name}* %self to %struct.{parent_name}*")
                            args_str = f"%struct.{parent_name}* {cast}"
                            for p in member.params:
                                lt = to_llvm_type(p.type)
                                args_str += f", {lt} %{p.name}"
                            self.emit(f"  call void @{parent_func}({args_str})")
                            self.emit("  ret void")
                            self.emit("}")
                            self.emit_blank()
                            self.classes_with_constructors.add(node.name)
                            found_parent_constructor = True
                            break
                    if found_parent_constructor:
                        break

                if not found_parent_constructor:
                    # No fields, no parent constructor — emit trivial no-op
                    child_func = f"{node.name}_constructor"
                    self.method_return_types[child_func] = "void"
                    self.classes_with_constructors.add(node.name)
                    self.emit(f"define void @{child_func}(%struct.{node.name}* %self) {{")
                    self.emit("entry:")
                    self.emit("  ret void")
                    self.emit("}")
                    self.emit_blank()

    #=========== For Virtual Inheritance ===========#
    def gen_qualified_method_call(self, node):
        # Bird.p.breathe() -> call Bird_breathe(p)
        obj_ptr, obj_llvm_type = self.locals[node.obj]
        obj_reg = self.fresh_temp()
        self.emit(f"  {obj_reg} = load {obj_llvm_type}, {obj_llvm_type}* {obj_ptr}")
        
        func_name = f"{node.parent_class}_{node.method}"
        ret_type  = self.method_return_types.get(func_name, "void")
        
        args = [(obj_reg, obj_llvm_type)]
        for arg in node.args:
            reg, typ = self.gen_expr(arg)
            args.append((reg, typ))
        
        arg_str = ", ".join(f"{t} {r}" for r, t in args)
        tmp = self.fresh_temp()
        
        if ret_type == "void":
            self.emit(f"  call void @{func_name}({arg_str})")
            return ("void", "void")
        else:
            self.emit(f"  {tmp} = call {ret_type} @{func_name}({arg_str})")
        return (tmp, ret_type)

    # ---------------- #
    #      ARRAYS      #
    # ---------------- #

    def array_elem_info(self, array_type: str):
        """
        "int[]" -> ("i32", 4)
        "float[]" -> ("double", 8)
        "str[]" -> ("i8*", 8)
        Returns (llvm_elem_type, byte_size)
        """
        # Strip last dimension to get element type string
        bracket = array_type.rfind("[")
        elem_type_str = array_type[:bracket]

        type_map = {
            "int":   ("i32",    4),
            "vast":  ("i64",    8),
            "float": ("double", 8),
            "str":   ("i8*",    8),
            "bool":  ("i8",     1),
        }
        return type_map.get(elem_type_str, ("i8*", 8))
    
    def gen_array_literal(self, node):
        count = len(node.elements)

        # Check if this is a 2D literal — first element is also ArrayLiteral
        if count > 0 and isinstance(node.elements[0], ArrayLiteral):
            rows = count
            cols = len(node.elements[0].elements)
            # Get element type from first element of first row
            first_elem_reg, elem_llvm = self.gen_expr(node.elements[0].elements[0])
            elem_size = {"i32": 4, "double": 8, "i8*": 8, "i8": 1}.get(elem_llvm, 4)

            arr = self.fresh_temp()
            self.emit(f"  {arr} = call %MochaArray2D* @mocha_array2d_new(i32 {rows}, i32 {cols}, i32 {elem_size}, i32 1, i32 1)")

            # Init set each element
            for r, row_node in enumerate(node.elements):
                for c, elem_node in enumerate(row_node.elements):
                    if r == 0 and c == 0:
                        reg = first_elem_reg
                    else:
                        reg, _ = self.gen_expr(elem_node)
                    slot = self.alloca_at_entry(elem_llvm)
                    self.emit(f"  store {elem_llvm} {reg}, {elem_llvm}* {slot}")
                    cast = self.fresh_temp()
                    self.emit(f"  {cast} = bitcast {elem_llvm}* {slot} to i8*")
                    self.emit(f"  call void @mocha_array2d_set(%MochaArray2D* {arr}, i32 {r}, i32 {c}, i8* {cast})")

            return (arr, "%MochaArray2D*")

        # Original 1D path unchanged
        if count > 0:
            first_reg, first_type = self.gen_expr(node.elements[0])
            elem_llvm = first_type
            elem_size = {"i32": 4, "double": 8, "i8*": 8, "i8": 1}.get(elem_llvm, 8)
        else:
            elem_llvm, elem_size = "i8*", 8

        arr = self.fresh_temp()
        self.emit(f"  {arr} = call %MochaArray* @mocha_array_new(i32 {count}, i32 {elem_size}, i32 0)")

        if count > 0:
            self.gen_array_init_elem(arr, 0, first_reg, elem_llvm)
            for i, elem in enumerate(node.elements[1:], 1):
                reg, _ = self.gen_expr(elem)
                self.gen_array_init_elem(arr, i, reg, elem_llvm)

        return (arr, "%MochaArray*")

    def gen_array_init_elem(self, arr, index, val_reg, elem_llvm):
        """Store one element during array initialization."""
        slot = self.alloca_at_entry(elem_llvm)
        self.emit(f"  store {elem_llvm} {val_reg}, {elem_llvm}* {slot}")
        cast = self.fresh_temp()
        self.emit(f"  {cast} = bitcast {elem_llvm}* {slot} to i8*")
        self.emit(f"  call void @mocha_array_init_set(%MochaArray* {arr}, i32 {index}, i8* {cast})")

    def gen_index_access(self, node):
        arr_reg, _ = self.gen_expr(node.obj)
        idx_reg, _ = self.gen_expr(node.index)

        MOCHA_DICT_TYPE_TAG = {
            "int":   0,
            "float": 1,
            "str":   2,
            "bool":  3,
            "dict":  4,
            "vast":  6,
        }
        if isinstance(node.obj, Identifier):
            mocha_type = self.local_mocha_types.get(node.obj.name, "") or \
                         self.global_mocha_types.get(node.obj.name, "")
            if mocha_type == "dict":
                expected = self.expected_assign_type or ""
                tag_int = MOCHA_DICT_TYPE_TAG.get(expected, -1)

                raw = self.fresh_temp()
                if tag_int == -1:
                    self.emit(
                        f"  {raw} = call i8* @mocha_dict_get("
                        f"%MochaDict* {arr_reg}, i8* {idx_reg})"
                    )
                else:
                    self.emit(
                        f"  {raw} = call i8* @mocha_dict_get_typed("
                        f"%MochaDict* {arr_reg}, i8* {idx_reg}, i32 {tag_int})"
                    )
                
                # Unbox based on expected type
                if expected == "int":
                    ptr = self.fresh_temp()
                    val = self.fresh_temp()
                    self.emit(f"  {ptr} = bitcast i8* {raw} to i32*")
                    self.emit(f"  {val} = load i32, i32* {ptr}")
                    return (val, "i32")
                
                elif expected == "float":
                    ptr = self.fresh_temp()
                    val = self.fresh_temp()
                    self.emit(f"  {ptr} = bitcast i8* {raw} to double*")
                    self.emit(f"  {val} = load double, double* {ptr}")
                    return (val, "double")
                
                elif expected == "bool":
                    ptr = self.fresh_temp()
                    val = self.fresh_temp()
                    self.emit(f"  {ptr} = bitcast i8* {raw} to i8*")
                    self.emit(f"  {val} = load i8, i8* {ptr}")
                    return (val, "i8")
                
                elif expected == "str":
                    # str is already i8* — no unbox needed
                    return (raw, "i8*")
                
                elif expected == "vast":
                    ptr = self.fresh_temp()
                    val = self.fresh_temp()
                    self.emit(f"  {ptr} = bitcast i8* {raw} to i64*")
                    self.emit(f"  {val} = load i64, i64* {ptr}")
                    return (val, "i64")
                
                else:
                    # dict/object/unknown — return raw ptr
                    return (raw, "i8*")

        # Chained dict access: d["person"]["name"]
        # Inner access already returned i8* — cast to MochaDict* and get again
        if isinstance(node.obj, IndexAccess):
            if isinstance(node.obj.obj, Identifier):
                inner_mocha = self.local_mocha_types.get(node.obj.obj.name, "")
                if inner_mocha == "dict":
                    cast = self.fresh_temp()
                    self.emit(f"  {cast} = bitcast i8* {arr_reg} to %MochaDict*")
                    
                    expected = self.expected_assign_type or ""
                    tag_int = MOCHA_DICT_TYPE_TAG.get(expected, -1)

                    raw = self.fresh_temp()
                    if tag_int == -1:
                        self.emit(
                            f"  {raw} = call i8* @mocha_dict_get("
                            f"%MochaDict* {arr_reg}, i8* {idx_reg})"
                        )
                    else:
                        self.emit(
                            f"  {raw} = call i8* @mocha_dict_get_typed("
                            f"%MochaDict* {arr_reg}, i8* {idx_reg}, i32 {tag_int})"
                        )
                    
                    # Unbox based on expected type
                    if expected == "int":
                        ptr = self.fresh_temp()
                        val = self.fresh_temp()
                        self.emit(f"  {ptr} = bitcast i8* {raw} to i32*")
                        self.emit(f"  {val} = load i32, i32* {ptr}")
                        return (val, "i32")
                    elif expected == "float":
                        ptr = self.fresh_temp()
                        val = self.fresh_temp()
                        self.emit(f"  {ptr} = bitcast i8* {raw} to double*")
                        self.emit(f"  {val} = load double, double* {ptr}")
                        return (val, "double")
                    elif expected == "bool":
                        ptr = self.fresh_temp()
                        val = self.fresh_temp()
                        self.emit(f"  {ptr} = bitcast i8* {raw} to i8*")
                        self.emit(f"  {val} = load i8, i8* {ptr}")
                        return (val, "i8")
                    elif expected == "vast":
                        ptr = self.fresh_temp()
                        val = self.fresh_temp()
                        self.emit(f"  {ptr} = bitcast i8* {raw} to i64*")
                        self.emit(f"  {val} = load i64, i64* {ptr}")
                        return (val, "i64")
                    elif expected == "str":
                        return (raw, "i8*")
                    else:
                        return (raw, "i8*")

        # Array code
        elem_llvm = "i32"  # default
        mocha_type = self.infer_mocha_type(node.obj)

        if not mocha_type:
            # fallback to old identifier-only lookup
            if isinstance(node.obj, Identifier):
                mocha_type = self.local_mocha_types.get(node.obj.name, "") or \
                            self.global_mocha_types.get(node.obj.name, "")
        if mocha_type and mocha_type != "dict":
            bracket = mocha_type.rfind("[")
            if bracket != -1:
                elem_mocha = mocha_type[:bracket]
                elem_llvm = to_llvm_type(elem_mocha)

        if elem_llvm == "%MochaArray*":
            # 2D array — get row via proper runtime call
            result = self.fresh_temp()
            self.emit(f"  {result} = call %MochaArray* @mocha_array2d_get_row(%MochaArray2D* {arr_reg}, i32 {idx_reg})")
            return (result, "%MochaArray*")
        else:
            # 1D array — standard element get
            slot = self.alloca_at_entry(elem_llvm)
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {elem_llvm}* {slot} to i8*")
            self.emit(f"  call void @mocha_array_get(%MochaArray* {arr_reg}, i32 {idx_reg}, i8* {cast})")
            result = self.fresh_temp()
            self.emit(f"  {result} = load {elem_llvm}, {elem_llvm}* {slot}")
            return (result, elem_llvm)
    
    def gen_index2d_access(self, node):
        arr_reg, _ = self.gen_expr(node.obj)
        row_reg, _ = self.gen_expr(node.row)
        col_reg, _ = self.gen_expr(node.col)

        # Chained dict access: d["person"]["name"]
        if isinstance(node.obj, Identifier):
            mocha_type = self.local_mocha_types.get(node.obj.name, "")
            if mocha_type == "dict":
                # First access: d["person"] -> i8*
                inner_tmp = self.fresh_temp()
                self.emit(f"  {inner_tmp} = call i8* @mocha_dict_get(%MochaDict* {arr_reg}, i8* {row_reg})")
                # Cast i8* to MochaDict*
                cast = self.fresh_temp()
                self.emit(f"  {cast} = bitcast i8* {inner_tmp} to %MochaDict*")
                # Second access: inner["name"] -> i8*
                val_tmp = self.fresh_temp()
                self.emit(f"  {val_tmp} = call i8* @mocha_dict_get(%MochaDict* {cast}, i8* {col_reg})")
                return (val_tmp, "i8*")

        elem_llvm = "i32"  # default
        if isinstance(node.obj, Identifier):
            mocha_type = self.local_mocha_types.get(node.obj.name, "")
            if mocha_type:
                bracket = mocha_type.rfind("[")
                base = mocha_type[:bracket]
                bracket2 = base.rfind("[")
                elem_mocha = base[:bracket2] if "[" in base else base
                elem_llvm = to_llvm_type(elem_mocha)
        elif isinstance(node.obj, MemberAccess):
            mocha_type = self.infer_mocha_type(node.obj)
            if mocha_type:
                bracket = mocha_type.rfind("[")
                base = mocha_type[:bracket]
                bracket2 = base.rfind("[")
                elem_mocha = base[:bracket2] if "[" in base else base
                elem_llvm = to_llvm_type(elem_mocha)


        slot = self.alloca_at_entry(elem_llvm)
        cast = self.fresh_temp()
        self.emit(f"  {cast} = bitcast {elem_llvm}* {slot} to i8*")
        self.emit(f"  call void @mocha_array2d_get(%MochaArray2D* {arr_reg}, i32 {row_reg}, i32 {col_reg}, i8* {cast})")
        result = self.fresh_temp()
        self.emit(f"  {result} = load {elem_llvm}, {elem_llvm}* {slot}")
        return (result, elem_llvm)
    
    def gen_index_assign(self, node):
        arr_reg, _ = self.gen_expr(node.target.obj)
        idx_reg, _ = self.gen_expr(node.target.index)
        val_reg, val_type = self.gen_expr(node.value)

        # Dict assign: d["key"] = val
        if isinstance(node.target.obj, Identifier):
            mocha_type = self.local_mocha_types.get(node.target.obj.name, "")
            if mocha_type == "dict":
                if val_type == "i32":
                    self.emit(f"  call void @mocha_dict_set_int(%MochaDict* {arr_reg}, i8* {idx_reg}, i32 {val_reg})")
                elif val_type == "double":
                    self.emit(f"  call void @mocha_dict_set_float(%MochaDict* {arr_reg}, i8* {idx_reg}, double {val_reg})")
                elif val_type == "i8":
                    self.emit(f"  call void @mocha_dict_set_bool(%MochaDict* {arr_reg}, i8* {idx_reg}, i8 {val_reg})")
                elif val_type == "i64":
                    self.emit(f"  call void @mocha_dict_set_vast(%MochaDict* {arr_reg}, i8* {idx_reg}, i64 {val_reg})")
                elif val_type == "%MochaDict*":
                    self.emit(f"  call void @mocha_dict_set_dict(%MochaDict* {arr_reg}, i8* {idx_reg}, %MochaDict* {val_reg})")
                elif val_type.startswith("%struct."):
                    cast = self.fresh_temp()
                    self.emit(f"  {cast} = bitcast {val_type} {val_reg} to i8*")
                    self.emit(f"  call void @mocha_dict_set_object(%MochaDict* {arr_reg}, i8* {idx_reg}, i8* {cast})")
                else:
                    self.emit(f"  call void @mocha_dict_set_str(%MochaDict* {arr_reg}, i8* {idx_reg}, i8* {val_reg})")
                return

        slot = self.alloca_at_entry(val_type)
        self.emit(f"  store {val_type} {val_reg}, {val_type}* {slot}")
        cast = self.fresh_temp()
        self.emit(f"  {cast} = bitcast {val_type}* {slot} to i8*")
        self.emit(f"  call void @mocha_array_set(%MochaArray* {arr_reg}, i32 {idx_reg}, i8* {cast})")

    def gen_index2d_assign(self, node):
        arr_reg, _ = self.gen_expr(node.target.obj)
        row_reg, _ = self.gen_expr(node.target.row)
        col_reg, _ = self.gen_expr(node.target.col)
        val_reg, val_type = self.gen_expr(node.value)

        slot = self.alloca_at_entry(val_type)  # ← was fresh_temp + inline alloca
        self.emit(f"  store {val_type} {val_reg}, {val_type}* {slot}")
        cast = self.fresh_temp()
        self.emit(f"  {cast} = bitcast {val_type}* {slot} to i8*")
        self.emit(f"  call void @mocha_array2d_set(%MochaArray2D* {arr_reg}, i32 {row_reg}, i32 {col_reg}, i8* {cast})")

    def gen_row_slice(self, node):
        arr_reg, _ = self.gen_expr(node.obj)
        row_reg, _ = self.gen_expr(node.row)
        tmp = self.fresh_temp()
        self.emit(f"  {tmp} = call %MochaArray* @mocha_array2d_get_row(%MochaArray2D* {arr_reg}, i32 {row_reg})")
        return (tmp, "%MochaArray*")

    def gen_col_slice(self, node):
        arr_reg, _ = self.gen_expr(node.obj)
        col_reg, _ = self.gen_expr(node.col)
        tmp = self.fresh_temp()
        self.emit(f"  {tmp} = call %MochaArray* @mocha_array2d_get_col(%MochaArray2D* {arr_reg}, i32 {col_reg})")
        return (tmp, "%MochaArray*")
    
    # ---------------- #
    #      TUPLES      #
    # ---------------- #
    
    def gen_tuple_literal(self, node):
        count = len(node.elements)
        tup = self.fresh_temp()
        self.emit(f"  {tup} = call %MochaTuple* @mocha_tuple_new(i32 {count})")

        for i, elem in enumerate(node.elements):
            reg, typ = self.gen_expr(elem)
            
            # Bitcast value to i8* to store in void* slot
            if typ == "i8*":
                slot = reg  # already a pointer
            elif typ in ("i32", "i8", "i1"):
                # HEAP allocation with malloc!
                size = 4 if typ == "i32" else 1
                heap_ptr = self.fresh_temp()
                self.emit(f"  {heap_ptr} = call i8* @malloc(i64 {size})")
                
                typed_ptr = self.fresh_temp()
                self.emit(f"  {typed_ptr} = bitcast i8* {heap_ptr} to {typ}*")
                self.emit(f"  store {typ} {reg}, {typ}* {typed_ptr}")
                slot = heap_ptr
            elif typ == "double":
                # HEAP allocation for double
                heap_ptr = self.fresh_temp()
                self.emit(f"  {heap_ptr} = call i8* @malloc(i64 8)")
                
                typed_ptr = self.fresh_temp()
                self.emit(f"  {typed_ptr} = bitcast i8* {heap_ptr} to double*")
                self.emit(f"  store double {reg}, double* {typed_ptr}")
                slot = heap_ptr
            else:
                slot = self.fresh_temp()
                self.emit(f"  {slot} = bitcast {typ} {reg} to i8*")

            self.emit(f"  call void @mocha_tuple_set(%MochaTuple* {tup}, i32 {i}, i8* {slot})")

        return (tup, "%MochaTuple*")
    
    def gen_tuple_access(self, node):
        tup_reg, _ = self.gen_expr(node.obj)

        # Get element LLVM type from Mocha type info
        elem_llvm = "i32"  # default
        if isinstance(node.obj, Identifier):
            mocha_type = self.local_mocha_types.get(node.obj.name, "") or \
                        self.global_mocha_types.get(node.obj.name, "")
            if mocha_type.startswith("("):
                inner = mocha_type[1:-1].strip()
                parts = [p.strip() for p in inner.rsplit(",", 1)]
                if len(parts) == 2 and parts[1].isdigit():
                    # (float[][], 3) — homogeneous with count
                    elem_llvm = to_llvm_type(parts[0])
                elif len(parts) == 1:
                    # (float[][]) — homogeneous, no count, single type
                    elem_llvm = to_llvm_type(parts[0])
                else:
                    # mixed — index into elements
                    elems = [t.strip() for t in inner.split(",")]
                    if node.index < len(elems):
                        elem_llvm = to_llvm_type(elems[node.index])

        raw = self.fresh_temp()
        self.emit(f"  {raw} = call i8* @mocha_tuple_get(%MochaTuple* {tup_reg}, i32 {node.index})")

        # Unbox back to correct type
        # Pointer types: just bitcast from i8*
        # Value types: bitcast to ptr then load
        if elem_llvm.endswith("*"):
            ptr = self.fresh_temp()
            self.emit(f"  {ptr} = bitcast i8* {raw} to {elem_llvm}")
            return (ptr, elem_llvm)
        else:
            ptr = self.fresh_temp()
            result = self.fresh_temp()
            self.emit(f"  {ptr} = bitcast i8* {raw} to {elem_llvm}*")
            self.emit(f"  {result} = load {elem_llvm}, {elem_llvm}* {ptr}")
            return (result, elem_llvm)
        
    # ---------------- #
    #    DICTIONARY    #
    # ---------------- #
        
    def gen_dict_literal(self, node):
        d = self.fresh_temp()
        self.emit(f"  {d} = call %MochaDict* @mocha_dict_new()")

        for key_node, val_node in node.pairs:
            key_reg, key_type = self.gen_expr(key_node)
            val_reg, val_type = self.gen_expr(val_node)

            if val_type == "i32":
                self.emit(f"  call void @mocha_dict_set_int(%MochaDict* {d}, i8* {key_reg}, i32 {val_reg})")
            elif val_type == "double":
                self.emit(f"  call void @mocha_dict_set_float(%MochaDict* {d}, i8* {key_reg}, double {val_reg})")
            elif val_type == "i8":
                self.emit(f"  call void @mocha_dict_set_bool(%MochaDict* {d}, i8* {key_reg}, i8 {val_reg})")
            elif val_type == "i64":
                self.emit(f"  call void @mocha_dict_set_vast(%MochaDict* {d}, i8* {key_reg}, i64 {val_reg})")
            elif val_type == "%MochaDict*":
                self.emit(f"  call void @mocha_dict_set_dict(%MochaDict* {d}, i8* {key_reg}, %MochaDict* {val_reg})")
            elif val_type.startswith("%struct."):
                cast = self.fresh_temp()
                self.emit(f"  {cast} = bitcast {val_type} {val_reg} to i8*")
                self.emit(f"  call void @mocha_dict_set_object(%MochaDict* {d}, i8* {key_reg}, i8* {cast})")
            else:
                self.emit(f"  call void @mocha_dict_set_str(%MochaDict* {d}, i8* {key_reg}, i8* {val_reg})")

        return (d, "%MochaDict*")
    
    # ---------------- #
    #       SETS       #
    # ---------------- #
    
    def gen_set_literal(self, node, elem_type=None):
        type_tags = {"i32": 0, "double": 1, "i8*": 2, "i8": 3, "i64": 4}
        # structs → tag 5

        # Infer from first element if available
        if node.elements:
            first_reg, first_llvm = self.gen_expr(node.elements[0])
            # Check for object type
            if first_llvm.startswith("%struct."):
                tag = 5  # MOCHA_SET_OBJECT
            else:
                tag = type_tags.get(first_llvm, 0)
        else:
            # Empty set — default to int
            first_reg, first_llvm = None, "i32"
            tag = type_tags.get(elem_type or "i32", 0)

        s = self.fresh_temp()
        self.emit(f"  {s} = call %MochaSet* @mocha_set_new(i32 {tag})")

        # Insert first element
        if node.elements and first_reg:
            slot = self.fresh_temp()
            self.emit(f"  {slot} = alloca {first_llvm}")
            self.emit(f"  store {first_llvm} {first_reg}, {first_llvm}* {slot}")
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {first_llvm}* {slot} to i8*")
            self.emit(f"  call void @mocha_set_insert(%MochaSet* {s}, i8* {cast})")

        # Insert remaining elements
        for elem in node.elements[1:]:
            reg, llvm = self.gen_expr(elem)
            slot = self.fresh_temp()
            self.emit(f"  {slot} = alloca {llvm}")
            self.emit(f"  store {llvm} {reg}, {llvm}* {slot}")
            cast = self.fresh_temp()
            self.emit(f"  {cast} = bitcast {llvm}* {slot} to i8*")
            self.emit(f"  call void @mocha_set_insert(%MochaSet* {s}, i8* {cast})")

        return (s, "%MochaSet*")
    
    def gen_lib_qualified_call(self, node):
        # "mocha-math".sin(45.0)
        lib_key = f"{node.source}.{node.method}"
        if lib_key not in self.lib_functions:
            raise MochaCodeGenError(
                f"'{node.method}' not found in lib '{node.source}'",
                node.line, node.col
            )
        entry = self.lib_functions[lib_key]
        c_name, llvm_ret, llvm_params = entry[0], entry[1], entry[2]
        arg_regs = []
        for i, arg in enumerate(node.args):
            reg, typ = self.gen_expr(arg)
            # Promote i32 to double if needed
            if i < len(llvm_params) and llvm_params[i] == "double" and typ == "i32":
                p = self.fresh_temp()
                self.emit(f"  {p} = sitofp i32 {reg} to double")
                reg = p
            arg_regs.append((reg, llvm_params[i] if i < len(llvm_params) else typ))
        
        args_str = ", ".join(f"{t} {r}" for r, t in arg_regs)
        if llvm_ret == "void":
            self.emit(f"  call void @{c_name}({args_str})")
            return ("void", "void")
        else:
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call {llvm_ret} @{c_name}({args_str})")
            return (tmp, llvm_ret)
    
    def gen_alloc_array(self, node: AllocArray) -> tuple:
        size_reg, _ = self.gen_expr(node.size_expr)
        
        elem_sizes = {
            "int":   4,
            "vast":  8,
            "float": 8,
            "bool":  1,
            "str":   8,
        }
        esize = elem_sizes.get(node.elem_type, 8)

        # 2D alloc: alloc int[n][m]
        if node.size_expr2 is not None:
            size2_reg, _ = self.gen_expr(node.size_expr2)
            tmp = self.fresh_temp()
            self.emit(f"  {tmp} = call %MochaArray2D* @mocha_array2d_new(i32 {size_reg}, i32 {size2_reg}, i32 {esize}, i32 0, i32 {size2_reg})")
            return (tmp, "%MochaArray2D*")

        # 1D alloc (unchanged)
        tmp = self.fresh_temp()
        self.emit(f"  {tmp} = call %MochaArray* @mocha_array_alloc_filled(i32 {size_reg}, i32 {esize})")
        return (tmp, "%MochaArray*")
    
    def gen_tag_decl(self, node: TagDecl) -> None:
        _tag_types_registry.add(node.name)

        # Emit each member as a global i32 constant
        for i, member in enumerate(node.members):
            global_name = f"@{node.name}__{member}"
            self.emit(f"{global_name} = constant i32 {i}")
            self.globals[f"{node.name}.{member}"] = (global_name, "i32")

        # Emit .name() lookup function
        self.emit(f"define i8* @{node.name}__name(i32 %v) {{")
        self.emit(f"entry:")
        self.emit(f"  switch i32 %v, label %tag_default [")
        for i, member in enumerate(node.members):
            self.emit(f"    i32 {i}, label %tag_case{i}")
        self.emit(f"  ]")
        for i, member in enumerate(node.members):
            str_name = self.fresh_str_global(member)
            length   = len(member.encode('utf-8')) + 1
            self.emit(f"tag_case{i}:")
            self.emit(f"  ret i8* getelementptr inbounds "
                    f"([{length} x i8], [{length} x i8]* {str_name}, i32 0, i32 0)")
        unk_name = self.fresh_str_global("unknown")
        self.emit(f"tag_default:")
        self.emit(f"  ret i8* getelementptr inbounds "
                f"([8 x i8], [8 x i8]* {unk_name}, i32 0, i32 0)")
        self.emit(f"}}")
        self.emit_blank()

    def gen_fail(self, node: FailStmt):
        msg_reg, msg_type = self.gen_expr(node.message)
        if msg_type != "i8*":
            raise MochaCodeGenError(
                f"'fail' expects a str expression, got LLVM type '{msg_type}'",
                node.line, node.col
            )
        self.emit(f"  call void @mocha_ex_throw(i8* {msg_reg})")
        self.emit(f"  unreachable")

    def gen_rethrow(self, node: RethrowStmt):
        self.emit(f"  call void @mocha_ex_rethrow()")
        self.emit(f"  unreachable")

    def gen_try_rescue(self, node: TryRescue):
        if not self.in_function:
            raise MochaCodeGenError(
                "'try/rescue' block must be inside a function",
                node.line, node.col
            )

        try_lbl    = self.fresh_label("try_body")
        rescue_lbl = self.fresh_label("rescue_body")
        after_lbl  = self.fresh_label("after_try")

        # push frame
        frame_reg = self.fresh_temp()
        self.emit(f"  {frame_reg} = call %MochaExFrame* @mocha_ex_push()")

        # enter — C handles setjmp and sets internal flag
        self.emit(f"  call void @mocha_ex_enter(%MochaExFrame* {frame_reg})")

        # query flag — did longjmp land?
        landed_reg = self.fresh_temp()
        self.emit(f"  {landed_reg} = call i32 @mocha_ex_did_land()")
        is_throw = self.fresh_temp()
        self.emit(f"  {is_throw} = icmp ne i32 {landed_reg}, 0")
        self.emit(f"  br i1 {is_throw}, label %{rescue_lbl}, label %{try_lbl}")

        # try body
        self.emit(f"{try_lbl}:")
        for stmt in node.try_body:
            self.gen_stmt(stmt)
        if not self.last_is_terminator():
            self.emit(f"  call i8* @mocha_ex_pop()")
            self.emit(f"  br label %{after_lbl}")

        # rescue body
        self.emit(f"{rescue_lbl}:")
        msg_reg = self.fresh_temp()
        self.emit(f"  {msg_reg} = call i8* @mocha_ex_pop()")
        if node.binding:
            bind_ptr = self.unique_ptr_name(node.binding)
            self.entry_allocas.append(f"  {bind_ptr} = alloca i8*")
            self.emit(f"  store i8* {msg_reg}, i8** {bind_ptr}")
            self.locals[node.binding] = (bind_ptr, "i8*")
            self.local_mocha_types[node.binding] = "str"
        for stmt in node.rescue_body:
            self.gen_stmt(stmt)
        if not self.last_is_terminator():
            self.emit(f"  br label %{after_lbl}")

        # after
        self.emit(f"{after_lbl}:")
    
    def emit_line_update(self, line: int):
        if line > 0 and line != self.current_emitted_line:
            self.emit(f"  call void @mocha_stack_update_line(i32 {line})")
            self.current_emitted_line = line

    def get_source_file_ptr(self) -> str:
        if not hasattr(self, '_source_file_global'):
            self._source_file_global = self.fresh_str_global(self.source_file)
        name   = self._source_file_global
        length = len(self.source_file) + 1
        return f"getelementptr ([{length} x i8], [{length} x i8]* {name}, i32 0, i32 0)"

    def get_func_name_ptr(self, func_name: str) -> str:
        name   = self.fresh_str_global(func_name)
        length = len(func_name) + 1
        return f"getelementptr ([{length} x i8], [{length} x i8]* {name}, i32 0, i32 0)"

    # -------------------------------------------------------
    # Top-level entry point
    # -------------------------------------------------------

    def generate(self, program: Program) -> str:
        entry_func = None

        # ============================================================
        # PRE-PASS: Generate top-level globals
        # ============================================================

        # Pre-register all tag types
        for node in program.statements:
            if isinstance(node, TagDecl):
                _tag_types_registry.add(node.name)

        # Collect all class nodes for inheritance lookup
        for node in program.statements:
            if isinstance(node, ClassDecl):
                self.class_nodes[node.name] = node

        # Register all native function declarations first
        # so extend methods can call them during codegen
        for node in program.statements:
            if isinstance(node, FunctionDecl) and getattr(node, 'is_native', False) and node.native_name:
                # null return for native = i8* (opaque pointer)
                ret_llvm = "i8*" if node.return_type == "null" else to_llvm_type(node.return_type)
                llvm_params = [
                    "i8*" if p.type == "null" else to_llvm_type(p.type)
                    for p in node.params
                ]
                param_str   = ", ".join(llvm_params)
                self.lib_functions[node.name] = (node.native_name, ret_llvm, llvm_params, [p.name for p in node.params])
                self.method_return_types[node.name]        = ret_llvm
                self.method_return_types[node.native_name] = ret_llvm
                declare = f"declare {ret_llvm} @{node.native_name}({param_str})"
                if declare not in self.extra_declares:
                    self.extra_declares.append(declare)

        # ============================================================
        # PASS 0: Generate top-level globals
        # ============================================================
        top_level_vars = [n for n in program.statements 
                         if isinstance(n, (VarDecl))] #ConstDecl removed
        
        if top_level_vars or self.is_lib:
            # Emit global pointer slots at module level
            for node in top_level_vars:
                if "[" in node.type:
                    self.emit(f"@__global_{node.name} = global %MochaArray* null")
                elif node.type == "dict":
                    self.emit(f"@__global_{node.name} = global %MochaDict* null")
                elif node.type.startswith("set<"):
                    self.emit(f"@__global_{node.name} = global %MochaSet* null")
                else:
                    llvm_type = to_llvm_type(node.type)
                    if llvm_type == "double":
                        self.emit(f"@__global_{node.name} = global {llvm_type} 0.0")
                    elif llvm_type.endswith("*"):
                        self.emit(f"@__global_{node.name} = global {llvm_type} null")
                    else:
                        self.emit(f"@__global_{node.name} = global {llvm_type} 0")
            self.emit_blank()

            if not self.globals_init_emitted:
                self.globals_init_emitted = True
                init_name = f"__mocha_globals_init_{self.lib_name.replace('-','_')}" if self.is_lib else "__mocha_globals_init"
                self.emit(f"define void @{init_name}() {{")
                self.emit("entry:")
                self.in_function = True
                for node in top_level_vars:
                    self.gen_var_decl(node)
                    if node.name in self.locals:
                        ptr, llvm_type = self.locals[node.name]
                        tmp = self.fresh_temp()
                        self.emit(f"  {tmp} = load {llvm_type}, {llvm_type}* {ptr}")
                        self.emit(f"  store {llvm_type} {tmp}, {llvm_type}* @__global_{node.name}")
                        self.globals[node.name] = (f"@__global_{node.name}", llvm_type)
                    if node.name in self.local_mocha_types:
                        self.global_mocha_types[node.name] = self.local_mocha_types[node.name]
                self.emit("  ret void")
                self.emit("}")
                self.emit_blank()
                self.in_function = False

        # ============================================================
        # PASS 1: Register ALL function signatures first
        # ============================================================
        for node in program.statements:
            if isinstance(node, FunctionDecl):
                ret_llvm = to_llvm_type(node.return_type)
                self.method_return_types[node.name] = ret_llvm
                if node.has_didLoad:
                    entry_func = (node.name, node.params)
                    self.method_return_types[f"mocha_entry_{node.name}"] = ret_llvm
                
                if node.is_native and node.native_name:
                    safe_name = self.sanitize_type_name(node.native_name)
                    
                    # null return for native = i8* always
                    # (void* in C side, so i8* is correct and unused returns are fine in LLVM)
                    ret_llvm = "i8*" if node.return_type == "null" else to_llvm_type(node.return_type)
                    
                    params_str = ", ".join(to_llvm_param_type(p.type) for p in node.params)
                    if node.is_variadic:
                        params_str = params_str + ", ..." if params_str else "..."
                    
                    declare = f"declare {ret_llvm} @{safe_name}({params_str})"
                    if declare not in self.extra_declares and safe_name not in STDLIB_NAMES:
                        self.extra_declares.append(declare)
                    
                    self.method_return_types[node.name] = ret_llvm
                    self.method_return_types[safe_name] = ret_llvm
            
            elif isinstance(node, MethodDecl):
                ret_llvm = to_llvm_type(node.return_type)
                self.method_return_types[node.name] = ret_llvm
                if node.has_didLoad:
                    entry_func = (node.name, node.params)
                    self.method_return_types[f"mocha_entry_{node.name}"] = ret_llvm
            
            elif isinstance(node, ClassDecl):
                # Register class methods
                for member in node.body:
                    if isinstance(member, MethodDecl):
                        ret_llvm = to_llvm_type(member.return_type)
                        method_name = f"{node.name}_{member.name}"
                        self.method_return_types[method_name] = ret_llvm
                        if member.has_didLoad:
                            entry_func = (method_name, member.params)

            elif isinstance(node, ExtendDecl):
                # Register extension method return types
                for func in node.body:
                    ret_llvm = to_llvm_type(func.return_type)
                    raw_type = str(node.type_name).strip()
                    sanitized = self.sanitize_type_name(raw_type)

                    method_name = f"mocha_ext_{sanitized}_{func.name}"
                    self.method_return_types[method_name] = ret_llvm
                    self.method_return_types[method_name] = ret_llvm

                    # ← ADD THIS BLOCK
                    if getattr(func, 'is_native', False) and func.native_name:
                        safe_name = self.sanitize_type_name(func.native_name)
                        ret_llvm_native = "i8*" if func.return_type == "null" else to_llvm_type(func.return_type)
                        this_llvm = to_llvm_param_type(raw_type)
                        params_str = ", ".join(to_llvm_param_type(p.type) for p in func.params)
                        params_str = f"{this_llvm}, {params_str}" if params_str else this_llvm
                        declare = f"declare {ret_llvm_native} @{safe_name}({params_str})"
                        if declare not in self.extra_declares and safe_name not in STDLIB_NAMES:
                            self.extra_declares.append(declare)
                        self.method_return_types[safe_name] = ret_llvm_native
        
        # ============================================================
        # PASS 1.5: Emit all struct type definitions before any code
        # ============================================================

        for node in program.statements:
            if isinstance(node, ClassDecl):
                all_fields = self.get_all_fields_for_class(node.name)
                self.class_fields[node.name] = all_fields
                field_types = [lt for _, lt in all_fields]
                if field_types:
                    self.type_declarations.append(f"%struct.{node.name} = type {{ {', '.join(field_types)} }}")
                else:
                    self.type_declarations.append(f"%struct.{node.name} = type {{ i32 }}")
                self.type_declarations.append('')

        # ============================================================
        # PASS 2: Generate function bodies
        # ============================================================

        for node in program.statements:
            if isinstance(node, FunctionDecl):
                if node.is_native:
                    pass  # declare already emitted in PASS 1, no body needed
                elif node.has_didLoad:
                    original_name = node.name
                    node.name = f"mocha_entry_{node.name}"
                    self.gen_function(node)
                    node.name = original_name
                else:
                    self.gen_function(node)
            
            elif isinstance(node, MethodDecl):
                if node.has_didLoad:
                    original_name = node.name
                    node.name = f"mocha_entry_{node.name}"
                    self.gen_function(node)
                    node.name = original_name
                else:
                    self.gen_function(node)
            
            elif isinstance(node, ClassDecl):
                self.gen_class(node)
            
            elif isinstance(node, ExtendDecl):
                self.gen_extend(node)
            
            elif isinstance(node, ConstDecl):
                self.gen_const_decl(node)
            
            elif isinstance(node, TagDecl):
                self.gen_tag_decl(node)

        # ============================================================
        # Top-level statements (if any)
        # ============================================================
        top_level = [
            n for n in program.statements
            if not isinstance(n, (FunctionDecl, MethodDecl, ClassDecl,
                                ImportStmt, InterfaceDecl, ExtendDecl, VarDecl, ConstDecl))
        ]

        if top_level:
            self.emit("define void @mocha_main() uwtable {")
            self.emit("entry:")
            self.in_function = True
            for node in top_level:
                self.gen_stmt(node)
            if not self.last_is_terminator():
                self.emit("  ret void")
            self.emit("}")
            self.emit_blank()

        # ============================================================
        # Generate main() entry point
        # ============================================================
        if not self.is_lib:
            self.emit("define i32 @main(i32 %argc, i8** %argv) uwtable {")
            self.emit("entry:")
            self.emit("  call i32 @SetConsoleOutputCP(i32 65001)")
            self.emit("  call void @mocha_gc_init()")
            for lib_init in self.lib_init_calls:
                self.emit(f"  call void @{lib_init}()")
            if top_level_vars:
                self.emit("  call void @__mocha_globals_init()")

            if entry_func:
                func_name, params = entry_func
                ir_func_name = f"mocha_entry_{func_name}"
                args = []
                for i, param in enumerate(params):
                    llvm_type = to_llvm_type(param.type)
                    argv_idx  = i + 1
                    gep = self.fresh_temp()
                    raw = self.fresh_temp()
                    self.emit(f"  {gep} = getelementptr i8*, i8** %argv, i32 {argv_idx}")
                    self.emit(f"  {raw} = load i8*, i8** {gep}")
                    if llvm_type == "i32":
                        converted = self.fresh_temp()
                        self.emit(f"  {converted} = call i32 @atoi(i8* {raw})")
                        args.append(f"i32 {converted}")
                    elif llvm_type == "double":
                        converted = self.fresh_temp()
                        self.emit(f"  {converted} = call double @atof(i8* {raw})")
                        args.append(f"double {converted}")
                    else:
                        args.append(f"i8* {raw}")

                arg_str  = ", ".join(args)
                ret_type = self.method_return_types.get(ir_func_name, "void")
                if ret_type == "void":
                    self.emit(f"  call void @{ir_func_name}({arg_str})")
                else:
                    tmp = self.fresh_temp()
                    self.emit(f"  {tmp} = call {ret_type} @{ir_func_name}({arg_str})")
            else:
                if top_level:
                    self.emit("  call void @mocha_main()")

            self.emit("  call void @mocha_gc_shutdown()")
            self.emit("  ret i32 0")
            self.emit("}")

        return self.get_ir()