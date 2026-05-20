# ============================================================
# Mocha Type Checker
#
# Walks the AST and verifies:
# - Variables are declared before use
# - Types match on assignments
# - Function return types are correct
# - Operations are between compatible types
# - Constants are never reassigned
# - Private fields are not accessed from outside
# ============================================================

from mocha_ast import *


# ============================================================
# TYPE CHECKER ERROR
# ============================================================

class MochaTypeError(Exception):
    def __init__(self, message, line=0, col=0):
        loc = f" at line {line}, col {col}" if line else ""
        super().__init__(f"MochaTypeError{loc}: {message}")

class MochaCompileError(Exception):
    def __init__(self, message, line=0, col=0):
        loc = f" at line {line}, col {col}" if line else ""
        super().__init__(f"MochaCompileError{loc}: {message}")


# ============================================================
# SYMBOL TABLE
#
# A symbol table is like a dictionary that tracks every
# variable, function and class the type checker has seen.
# It has "scopes" - when you enter a function or block,
# a new inner scope is pushed. When you leave, it's popped.
#
# Example:
#   global scope: { MAX: int, add: function }
#     function scope: { a: int, b: int }
#
# Looking up a variable searches from innermost to outermost!
# ============================================================

class SymbolTable:

    def __init__(self):
        # Stack of scopes. Each scope is a dict of name -> info
        self.scopes = [{}]

    def push_scope(self):
        """ Enter a new block (function body, if body etc.) """
        self.scopes.append({})

    def pop_scope(self):
        """ Leave the current block """
        self.scopes.pop()

    def declare(self, name: str, type_: str,
                is_const=False, is_function=False,
                is_class=False, visibility="public"):
        """
        Declare a new name in the CURRENT scope.
        Raises error if already declared in this scope.
        """
        current = self.scopes[-1]
        if name in current:
            raise MochaTypeError(
                f"'{name}' is already declared in this scope"
            )
        current[name] = {
            "type":        type_,
            "is_const":    is_const,
            "is_function": is_function,
            "is_class":    is_class,
            "visibility":  visibility,
        }

    def lookup(self, name: str) -> dict:
        """
        Find a name by searching from innermost scope outward.
        Returns the symbol info dict or raises an error.
        """
        for scope in reversed(self.scopes):
            if name in scope:
                return scope[name]
        raise MochaTypeError(
            f"'{name}' is not declared. "
            f"Did you forget 'var {name}: type = value;'?"
        )

    def lookup_safe(self, name: str):
        """ Like lookup but returns None instead of raising """
        for scope in reversed(self.scopes):
            if name in scope:
                return scope[name]
        return None


# ============================================================
# TYPE CHECKER
# ============================================================

class TypeChecker:

    # Types that can be used in arithmetic
    NUMERIC_TYPES = {"int", "float", "vast", "Complex"} #new addition after much time

    # Types that support comparison
    COMPARABLE_TYPES = {"int", "float", "str", "vast"}

    # All primitive types
    PRIMITIVE_TYPES = {"int", "float", "str", "bool", "null", "vast"}

    def __init__(self):
        self.symbols        = SymbolTable()
        self.current_class  = None
        self.current_return = None
        self.errors         = []
        self.inheritance    = {}
        self.loop_depth     = 0
        self.class_nodes    = {}
        self.diamond_conflicts = {}
        self.interface_methods = {}
        self.tag_types = set()

        # Pre-declare built-in functions
        self.symbols.declare("print", "null", is_function=True)
        self.symbols.declare("sort", "null", is_function=True)

        self.symbols.declare("tell", "str", is_function=True)

        self.symbols.declare("open",   "File", is_function=True)
        self.symbols.declare("exists", "bool", is_function=True)

        #New Constructs
        self.symbols.declare("StringBuilder", "StringBuilder", is_class=True)
        self.symbols.declare("Complex", "Complex", is_class=True)
        self.symbols.declare("File", "File", is_class=True)
        self.symbols.declare("HashTable", "HashTable", is_class=True)

    # -------------------------------------------------------
    # Error collection
    # Collect ALL errors so user sees everything at once,
    # not just the first error like most beginner compilers (and sadly Python too LoL)!
    # -------------------------------------------------------

    def error(self, message: str, node=None):
        line = getattr(node, 'line', 0)
        col  = getattr(node, 'col', 0)
        self.errors.append(MochaTypeError(message, line, col))

    def compile_error(self, message: str, node=None):
        line = getattr(node, 'line', 0)
        col  = getattr(node, 'col', 0)
        self.errors.append(MochaCompileError(message, line, col))

    # -------------------------------------------------------
    # Type compatibility helpers
    # -------------------------------------------------------

    def types_compatible(self, expected: str, actual: str) -> bool:
        """
        Are these two types compatible?
        Mocha has NO implicit coercion so this is strict!
        The only exception is int/float can mix in arithmetic.
        """
        if expected == actual:
            return True

        # Allow unknown comes from lambda calls and any type of dict access
        if actual in ("unknown", "any") or expected in ("unknown", "any"):
            return True
        
        # int and float are compatible with each other
        if expected in self.NUMERIC_TYPES and actual in self.NUMERIC_TYPES:
            return True
        
        # anything can be null if it's not a primitive
        if actual == "null" and expected not in self.PRIMITIVE_TYPES:
            return True
        if expected == "null" and actual not in self.PRIMITIVE_TYPES:
            return True  # ← add this
        # Array compatibility: element types must be compatible
        exp_elem = self.extract_element_type(expected)
        act_elem = self.extract_element_type(actual)
        if exp_elem is not None and act_elem is not None:
            return self.types_compatible(exp_elem, act_elem)
        
        # Tuple compatibility
        if expected.startswith("(") and actual.startswith("("):
            def parse_tuple_type(t):
                inner = t[1:-1].strip()
                parts = [p.strip() for p in inner.rsplit(",", 1)]
                if len(parts) == 2 and parts[1].isdigit():
                    return (parts[0], int(parts[1]))  # (type, count)
                else:
                    return (parts[0], None)  # (type, unknown count)
            
            exp_type, exp_count = parse_tuple_type(expected)
            act_type, act_count = parse_tuple_type(actual)
            
            # Types must match
            if not self.types_compatible(exp_type, act_type):
                return False
            # Counts must match if both known
            if exp_count is not None and act_count is not None:
                return exp_count == act_count
            return True
        
        # set types
        if expected.startswith("set<") and actual.startswith("set<"):
            return True
        if expected.startswith("set<") and actual == "set<unknown>":
            return True  # empty literal assigned to typed set
        
        if expected == "dict" and actual == "dict":
            return True
        
        return False #default

    def result_type_of_op(self, op: str,
                           left: str, right: str, node=None) -> str:
        """
        Given an operator and two types, what type does
        the result have? Also validates whether the operation is legal!
        """

        # Complex promotion — wins over everything in arithmetic
        if left == "Complex" or right == "Complex":
            if op in ("+", "-", "*", "/"):
                return "Complex"
            else:
                self.error(f"Operator '{op}' not supported for Complex", node)
                return "Complex"

        # Arithmetic: + - * /
        if op in ("+", "-", "*", "/", "%"):

            # String concatenation with +
            if op == "+" and left == "str" and right == "str":
                return "str"

            if left not in self.NUMERIC_TYPES:
                self.error(
                    f"Cannot use '{op}' on type '{left}'. "
                    f"Arithmetic requires int or float", node
                )
                return "int"

            if right not in self.NUMERIC_TYPES:
                self.error(
                    f"Cannot use '{op}' on type '{right}'. "
                    f"Arithmetic requires int or float", node
                )
                return "int"

            #Precedence
            if left == "float" or right == "float":
                return "float"
            if left == "vast" or right == "vast":
                return "vast"
            return "int"

        # Comparison: < > <= >=
        if op in ("<", ">", "<=", ">="):
            if left in self.tag_types or right in self.tag_types:
                self.error(
                    f"Tag types cannot be ordered. "
                    f"Use '==' or '!=' for tag comparison.", node
                )
                return "bool"
            if left not in self.COMPARABLE_TYPES:
                self.error(
                    f"Cannot compare type '{left}' with '{op}'", node
                )
            if left != right and not (
                left in self.NUMERIC_TYPES and right in self.NUMERIC_TYPES
            ):
                self.error(
                    f"Cannot compare '{left}' with '{right}'. "
                    f"Types must match for comparison", node
                )
            return "bool"

        if op in ("==", "!="):
            if left != right and not (
                left in self.NUMERIC_TYPES
                and right in self.NUMERIC_TYPES
            ) and not (left == "null" or right == "null"):  # ← add this
                self.error(
                    f"Cannot compare '{left}' with '{right}'. "
                    f"Type coercion is prohibited in Mocha", node
                )
            return "bool"

        # Logical: && ||
        if op in ("&&", "||"):
            if left != "bool":
                self.error(
                    f"Left side of '{op}' must be bool, got '{left}'", node
                )
            if right != "bool":
                self.error(
                    f"Right side of '{op}' must be bool, got '{right}'", node
                )
            return "bool"

        return "unknown"

    # -------------------------------------------------------
    # Expression type inference
    # Given an expression node, returns its type as a string
    # -------------------------------------------------------

    def check_expr(self, node: Node) -> str:
        """
        Returns the type of an expression.
        This is the heart of the type checker!
        """

        if isinstance(node, IntLiteral):
            return "int"

        if isinstance(node, FloatLiteral):
            return "float"

        if isinstance(node, ComplexLiteral):
            return "Complex"

        if isinstance(node, StrLiteral):
            return "str"

        if isinstance(node, BoolLiteral):
            return "bool"

        if isinstance(node, NullLiteral):
            return "null"
        
        if isinstance(node, DictLiteral):
            return self.check_dict_literal(node)

        if isinstance(node, Identifier):
            return self.check_identifier(node)

        if isinstance(node, MemberAccess):
            return self.check_member_access(node)

        if isinstance(node, BinaryOp):
            return self.check_binary_op(node)

        if isinstance(node, UnaryOp):
            return self.check_unary_op(node)

        if isinstance(node, PostIncrement):
            return self.check_increment(node)

        if isinstance(node, PreIncrement):
            return self.check_increment(node)
        
        if isinstance(node, PreDecrement):
            return self.check_increment(node)

        if isinstance(node, TypeCast):
            return self.check_type_cast(node)

        if isinstance(node, FunctionCall):
            return self.check_function_call(node)

        if isinstance(node, LambdaExpr):
            self.symbols.push_scope()
            
            # Register lambda params into the new scope
            for param in node.params:
                self.symbols.declare(param.name, param.type)
            
            if node.return_type and node.return_type != "null":
                body_type = self.check_expr(node.body)
                if body_type != "unknown" and not self.types_compatible(node.return_type, body_type):
                    self.error(
                        f"Lambda return type mismatch: declared '{node.return_type}' "
                        f"but body evaluates to '{body_type}'",
                        node
                    )
            
            self.symbols.pop_scope()
            return "lambda"

        if isinstance(node, AwaitExpr):
            return self.check_expr(node.value)

        if isinstance(node, OkExpr):
            self.check_expr(node.value)
            return "Result"

        if isinstance(node, ErrorExpr):
            self.check_expr(node.value)
            return "Result"
        
        if isinstance(node, ArrayLiteral):
            return self.check_array_literal(node)

        if isinstance(node, IndexAccess):
            return self.check_index_access(node)
        
        if isinstance(node, Index2DAccess):
            return self.check_index2d_access(node)

        if isinstance(node, RowSlice):
            obj_type = self.check_expr(node.obj)
            elem = self.extract_element_type(obj_type)
            return elem if elem else "unknown"

        if isinstance(node, ColSlice):
            obj_type = self.check_expr(node.obj)
            elem = self.extract_element_type(obj_type)
            return elem if elem else "unknown"

        if isinstance(node, TupleLiteral):
            return self.check_tuple_literal(node)

        if isinstance(node, TupleAccess):
            return self.check_tuple_access(node)
        
        if isinstance(node, SetLiteral):
            return self.check_set_literal(node)

        if isinstance(node, SetIterable):
            return self.check_expr(node.set_expr)
        
        if isinstance(node, LibQualifiedCall):
            lib_key = f"{node.source}.{node.method}"
            sym = self.symbols.lookup_safe(lib_key)
            if sym:
                return sym["type"]
            return "unknown"

        if isinstance(node, AllocArray):
            size_type = self.check_expr(node.size_expr)
            if size_type != "int":
                self.error(f"alloc size must be int, got '{size_type}'", node)
            if node.size_expr2 is not None:
                size2_type = self.check_expr(node.size_expr2)
                if size2_type != "int":
                    self.error(f"alloc size must be int, got '{size2_type}'", node)
                return f"{node.elem_type}[][]"
            return f"{node.elem_type}[]"
        
        if isinstance(node, ListComprehension):
            # Check iterable is an array
            iter_type = self.check_expr(node.iterable)
            if "[" not in iter_type and iter_type != "str":
                self.error(f"List comprehension source must be an array, got '{iter_type}'", node)

            # Infer element type from iterable
            # int[] -> int, float[] -> float etc.
            if "[" in iter_type:
                elem_type = iter_type[:iter_type.index("[")]
            else:
                elem_type = "str"
            node.src_elem_type = elem_type

            # Register loop variable in a temporary scope
            self.symbols.push_scope()
            self.symbols.declare(node.var_name, elem_type)

            # Check the transform expression
            expr_type = self.check_expr(node.expr)
            node.elem_type = expr_type

            # Check condition if present
            if node.condition is not None:
                cond_type = self.check_expr(node.condition)
                if cond_type != "bool":
                    self.error(f"List comprehension condition must be bool, got '{cond_type}'", node)

             # NEW — check else_expr if present
                if hasattr(node, 'else_expr') and node.else_expr is not None:
                    else_type = self.check_expr(node.else_expr)
                    if else_type != expr_type:
                        self.error(f"List comprehension else branch type '{else_type}' must match then branch type '{expr_type}'", node)
            
            self.symbols.pop_scope()

            # Return array type of the expression type
            return f"{expr_type}[]"
        
        if isinstance(node, TagAccess):
            key = f"{node.tag_name}.{node.member_name}"
            sym = self.symbols.lookup_safe(key)
            if sym is None:
                self.error(
                    f"'{node.member_name}' is not a member of tag '{node.tag_name}'",
                    node
                )
                return "unknown"
            return sym["type"]  # returns the tag type e.g. "TokenType"
        
        return "unknown"

    def check_identifier(self, node: Identifier) -> str:
        """
        Look up a variable name and return its type.
        """
        if node.name == "this":
            if self.current_class is None:
                self.error("'this' used outside of a class", node)
                return "unknown"
            if getattr(self, 'current_shared', False):
                self.error("'this' cannot be used in a shared method", node)
                return "unknown"
            return self.current_class

        symbol = self.symbols.lookup_safe(node.name)
        if symbol is None:
            self.error(
                f"'{node.name}' is not declared. "
                f"Did you forget 'var {node.name}: type = value;'?", node
            )
            return "unknown"
        return symbol["type"]

    def check_member_access(self, node: MemberAccess) -> str:
        obj_type = self.check_expr(node.obj)

        # If inner chain already failed, don't silently propagate unknown
        if obj_type == "unknown":
            self.error(
                f"Cannot access '.{node.member}' on unresolved type. "
                f"Check the preceding expression for errors.", node
            )
            return "unknown"
    
        # Dict built-in properties and methods
        if obj_type == "dict":
            if node.member == "length":
                return "int"
            if node.member in ("remove", "clean"):
                return "null"
            if node.member == "has":
                return "bool"
            if node.member == "allKeys":
                return "str[]"
            if node.member == "allValues":
                return "str[]"
            if node.member == "merge":
                return "dict"
            self.error(f"Unknown dict method '.{node.member}'", node)
            return "unknown"
        
        # Array and string built-in properties
        if node.member == "length":
            if obj_type == "str":
                return "int"
            if self.extract_element_type(obj_type) is None:
                self.error(f"'.length' used on non-array type '{obj_type}'", node)
            return "int"
        
        if node.member in ("rows", "cols"):
            # Must be a 2D array type
            elem = self.extract_element_type(obj_type)
            if elem is None or self.extract_element_type(elem) is None:
                self.error(f"'.{node.member}' used on non-2D-array type '{obj_type}'", node)
            return "int"

        if node.member in ("push", "pop"):
            if self.extract_element_type(obj_type) is None:
                self.error(f"'.{node.member}()' used on non-array type '{obj_type}'", node)
            return "null"
        if node.member in ("resize", "drop"):
            return "null"
        
        # occs — count occurrences
        if node.member == "occs":
            if obj_type == "dict":
                self.error(f"'.occs()' is not supported on dict", node)
            return "int"
        
        # Set built-ins
        if obj_type.startswith("set<"):
            if node.member == "size":
                return "int"
            if node.member in ("insert", "delete", "clean", "negate", "retype"):
                return "null"
            if node.member == "has":
                return "bool"
            if node.member in ("union", "intersect", "xor", "rel_diff"):
                return obj_type  # returns same set type
            self.error(f"Unknown set method '.{node.member}'", node)
            return "unknown"
        
        # String built-ins
        if obj_type == "str":
            if node.member == "length":
                return "int"
            if node.member == "charAt":
                return "str"
            if node.member == "substring":
                return "str"
            
        # Complex properties
        if node.member in ("real", "imag"):
            if obj_type == "Complex":
                return "float"
            else:
                self.error(
                    f"Property '.{node.member}' does not exist on type '{obj_type}'. "
                    f"'.real' and '.imag' are properties of Complex only.",
                    node
                )
                return "unknown"
        
        # Hashtable built-ins
        if obj_type == "HashTable":
            if node.member in ("put", "remove", "clear", "free"):
                return "null"
            if node.member == "get":
                return "unknown"
            if node.member == "has":
                return "bool"
            if node.member == "size":
                return "int"
            if node.member in ("keys", "values"):
                return "str[]"
            return "unknown"
        
        #Lookup
        symbol, found_in = self.lookup_member(obj_type, node.member)

        if symbol:
            visibility = symbol.get("visibility", "public")

            if visibility == "private":
                if self.current_class != found_in:
                    self.error(
                        f"'{node.member}' is private to '{found_in}' "
                        f"and cannot be accessed from outside", node
                    )

            elif visibility == "protected":
                if self.current_class is None or \
                found_in is None or               \
                (self.current_class != found_in and \
                    not self.is_subclass_of(self.current_class, found_in)):
                    self.error(
                        f"'{node.member}' is protected in '{found_in}' "
                        f"and cannot be accessed from '{self.current_class or 'global scope'}'", node
                    )

            return symbol["type"]
        return "unknown"
    
    def lookup_member(self, obj_type: str, member: str):
        """Look up a field/method, walking up the inheritance chain"""
        current = obj_type
        while current:
            symbol = self.symbols.lookup_safe(f"{current}.{member}")
            if symbol:
                return symbol, current  # returns (symbol, class_it_was_found_in)
            current = self.inheritance.get(current)
        return None, None
    
    def op_name(self, op: str) -> str:
        return {
            "+": "add",
            "-": "sub",
            "*": "mul",
            "/": "div",
            "%": "mod",
            "==": "eq",
            "!=": "ne",
            "<": "<",
            ">": ">",
            "<=": "<=",
            ">=": ">=",
            "&&": "and",
            "||": "or",
        }[op]

    def check_binary_op(self, node: BinaryOp) -> str:
        left_type  = self.check_expr(node.left)
        right_type = self.check_expr(node.right)
        # Compile-time division by zero check
        if node.op in ("/", "%"):
            if isinstance(node.right, (IntLiteral, FloatLiteral)):
                if node.right.value == 0:
                    self.error("Dividing by zero emits undefined result.", node)
        
        # Complex promotion — any arithmetic with Complex → Complex
        if left_type == "Complex" or right_type == "Complex":
            if node.op in ("+", "-", "*", "/"):
                node.op_kind = f"complex_{self.op_name(node.op)}"
                node.inferred_type = "Complex"
                return "Complex"
            else:
                self.error(f"Operator '{node.op}' not supported for Complex", node)

        result_type = self.result_type_of_op(node.op, left_type, right_type, node)
        node.inferred_type = result_type

        # Assign op_kind based on type + op
        if node.op in ("+", "-", "*", "/", "%"):
            if result_type == "float":
                node.op_kind = f"float_{self.op_name(node.op)}"
            elif result_type == "vast":
                node.op_kind = f"vast_{self.op_name(node.op)}"
            elif result_type == "str":
                node.op_kind = "string_concat"
            else:
                node.op_kind = f"int_{self.op_name(node.op)}"

        elif node.op in ("==", "!="):
            if left_type == "str" and right_type == "str":
                node.op_kind = f"str_{self.op_name(node.op)}"
            elif left_type == "bool" or right_type == "bool":
                node.op_kind = f"bool_{self.op_name(node.op)}"
            elif left_type == "float" or right_type == "float":
                node.op_kind = f"float_{self.op_name(node.op)}"
            elif left_type == "vast" or right_type == "vast":
                node.op_kind = f"vast_{self.op_name(node.op)}"
            else:
                node.op_kind = f"int_{self.op_name(node.op)}"

        elif node.op in ("<", ">", "<=", ">="):
            if left_type == "float" or right_type == "float":
                node.op_kind = f"float_{self.op_name(node.op)}"
            elif left_type == "vast" or right_type == "vast":
                node.op_kind = f"vast_{self.op_name(node.op)}"
            elif left_type == "str" or right_type == "str":
                node.op_kind = f"str_{self.op_name(node.op)}"
            else:
                node.op_kind = f"int_{self.op_name(node.op)}"

        elif node.op in ("&&", "||"):
            node.op_kind = f"{result_type}_{self.op_name(node.op)}"
        
        return result_type

    def check_unary_op(self, node: UnaryOp) -> str:
        right_type = self.check_expr(node.right)

        if node.op == "!":
            if right_type != "bool":
                self.error(
                    f"'!' requires bool, got '{right_type}'", node
                )
            return "bool"

        if node.op == "-":
            if right_type not in self.NUMERIC_TYPES:
                self.error(
                    f"Unary '-' requires int or float, got '{right_type}'", node
                )
            return right_type

        return "unknown"

    def check_increment(self, node) -> str:
        """
        i++, i--, ++i, --i
        Operand must be int!
        """
        operand_type = self.check_expr(node.operand)
        if operand_type not in ("int", "vast"):
            self.error(
                f"'{node.op}' requires int or vast, got '{operand_type}'", node
            )
        return operand_type  # return vast if vast, int if int

    def check_type_cast(self, node: TypeCast) -> str:
        """
        int(x), float(x), str(x) etc.
        Validates if the cast makes sense.
        """
        value_type = self.check_expr(node.value)

        # Can't cast bool to number
        if value_type == "bool" and node.to_type in self.NUMERIC_TYPES:
            self.error(
                f"Cannot cast bool to {node.to_type}. "
                f"Boolean arithmetic is prohibited in Mocha!!", node
            )

        # Can't cast str to number directly
        if value_type == "str" and node.to_type in self.NUMERIC_TYPES:
            method = "toFloat()" if node.to_type == "float" else "toInt()"
            self.error(
                f"Cannot cast str to {node.to_type} directly. "
                f"Use a {method} method from mocha-string library.", node
            )

        return node.to_type

    def check_function_call(self, node: FunctionCall) -> str:
        if isinstance(node.name, Identifier):
            func_name = node.name.name
            obj_type  = None
        elif isinstance(node.name, MemberAccess):
            func_name = node.name.member
            obj_type  = self.check_expr(node.name.obj)
            # Const mutation check for array/set methods
            MUTATING_METHODS = {
                "push", "pop", "insert", "delete", "remove",
                "clean", "retype", "reverse", "sort", "occs",
                "push", "drop", "resize", 
            }
            if func_name in MUTATING_METHODS:
                if isinstance(node.name.obj, Identifier):
                    symbol = self.symbols.lookup_safe(node.name.obj.name)
                    if symbol and symbol["is_const"]:
                        self.error(
                            f"Cannot call '{func_name}()' on constant '{node.name.obj.name}'. "
                            f"Constants are immutable in Mocha", node
                        )
        else:
            func_name = "unknown"
            obj_type  = None
        
        # Lambda invocation — pred(x) where pred is of type "lambda"
        symbol = self.symbols.lookup_safe(func_name)
        if symbol and symbol.get("type") == "lambda":
            # Can't statically know return type — return "unknown" and let codegen handle it
            return "unknown"

        # Diamond conflict check — unqualified call on ambiguous method
        if obj_type and obj_type != "unknown":
            conflict_key = f"{obj_type}.{func_name}"
            if conflict_key in self.diamond_conflicts:
                parents = self.diamond_conflicts[conflict_key]
                parents_str = " and ".join(parents)
                if isinstance(node.name, MemberAccess) and isinstance(node.name.obj, Identifier):
                    obj_name = node.name.obj.name
                else:
                    obj_name = "obj"
                self.error(
                    f"Method '{func_name}()' is inherited from both {parents_str}. "
                    f"Please specify parent class to prevent the Diamond Problem. "
                    f"Use {parents[0]}.{obj_name}.{func_name}() or {parents[1]}.{obj_name}.{func_name}()", node
                )

        for arg in node.args:
            if isinstance(arg, Assignment):
                continue
            self.check_expr(arg)

        # Module alias call: mg.greet(...) — obj_type is "module"
        if obj_type == "module" and isinstance(node.name, MemberAccess):
            if isinstance(node.name.obj, Identifier):
                alias = node.name.obj.name
                symbol = self.symbols.lookup_safe(f"{alias}.{func_name}")
                if symbol:
                    return symbol["type"]
            return "unknown"
        
        # Dict method return types
        if obj_type == "dict":
            if func_name == "has":
                return "bool"
            if func_name in ("allKeys", "allValues"):
                return "str[]"
            if func_name in ("remove", "clean"):
                return "null"
            if func_name == "length":
                return "int"
            if func_name == "merge":
                # check positional arg is a dict
                positional = [a for a in node.args if not isinstance(a, Assignment)]
                if len(positional) < 1:
                    self.error("merge() requires a dict argument", node)
                arg_type = self.check_expr(positional[0])
                if arg_type != "dict":
                    self.error(f"merge() argument must be dict, got '{arg_type}'", node)
                # check override= kwarg
                for a in node.args:
                    if isinstance(a, Assignment):
                        if isinstance(a.target, Identifier) and a.target.name == "override":
                            kw_type = self.check_expr(a.value)
                            if kw_type != "bool":
                                self.error(f"merge() override= must be bool, got '{kw_type}'", node)
                        else:
                            name = a.target.name if isinstance(a.target, Identifier) else "?"
                            self.error(f"merge() unknown keyword argument '{name}'", node)
                return "dict"
            
        # HashTable method return types
        if obj_type == "HashTable":
            if func_name in ("put", "remove", "clear", "free"):
                return "null"
            if func_name == "get":
                return "unknown"
            if func_name == "has":
                return "bool"
            if func_name == "size":
                return "int"
            if func_name in ("keys", "values"):
                return "str[]"
            return "unknown"
            
        if func_name == "occs":
            return "int"
            
        # occs on 2D array — must specify row or col
        if func_name == "occs" and obj_type:
            if "[][]" in obj_type or obj_type.endswith("[][]"):
                # Check named args for row or col
                has_row_or_col = any(
                    isinstance(arg, Assignment) and 
                    isinstance(arg.target, Identifier) and 
                    arg.target.name in ("row", "col")
                    for arg in node.args
                )
            return "int"
        
        # Set method return types
        if obj_type and obj_type.startswith("set<"):
            if func_name == "has":
                return "bool"
            if func_name in ("insert", "delete", "clean", "negate"):
                return "null"
            if func_name == "retype":
                if node.args:
                    arg = node.args[0]
                    if isinstance(arg, Identifier):
                        valid_types = {"int", "float", "str", "bool", "vast"}
                        if arg.name not in valid_types:
                            self.error(
                                f"Invalid type '{arg.name}' for retype(). "
                                f"Valid types are: int, float, str, bool, vast", node
                            )
                return "null"
            if func_name in ("union", "intersect", "xor", "rel_diff"):
                if node.args:
                    arg_type = self.check_expr(node.args[0])
                    if arg_type != obj_type:
                        self.error(
                            f"Cannot call '{func_name}' on '{obj_type}' with '{arg_type}'. "
                            f"Both sets must be the same type. "
                            f"Use .retype() to convert first.", node
                        )
                return obj_type
            if func_name == "size":
                return "int"
        
        #String methods
        if obj_type == "str":
            if func_name == "charAt":
                return "str"
            if func_name == "toInt":
                return "int"
            if func_name == "toFloat":
                return "float"
            if func_name == "substring":
                return "str"

        #Lookup!
        if obj_type and obj_type != "unknown":
            symbol = self.symbols.lookup_safe(f"{obj_type}.{func_name}")
            if symbol:
                return symbol["type"]

        symbol = self.symbols.lookup_safe(func_name)
        if symbol is None:
            return "unknown"
        return symbol["type"]

    # -------------------------------------------------------
    # Statement checking
    # -------------------------------------------------------

    def check_stmt(self, node: Node):
        """
        Type-checks a single statement.
        Statements don't return values, they just have side effects!
        """

        if isinstance(node, VarDecl):
            self.check_var_decl(node)

        elif isinstance(node, ConstDecl):
            self.check_const_decl(node)

        elif isinstance(node, Assignment):
            self.check_assignment(node)

        elif isinstance(node, CompoundAssignment):
            self.check_compound_assignment(node)

        elif isinstance(node, ReturnStmt):
            self.check_return(node)

        elif isinstance(node, IfStmt):
            self.check_if(node)

        elif isinstance(node, WhileLoop):
            self.check_while(node)

        elif isinstance(node, DoWhileLoop):
            self.check_do_while(node)

        elif isinstance(node, ForLoop):
            self.check_for(node)

        elif isinstance(node, ForEachLoop):
            self.check_foreach(node)

        elif isinstance(node, MatchStmt):
            self.check_match(node)

        elif isinstance(node, (BreakStmt, ContinueStmt)):
            if self.loop_depth == 0:
                keyword = "break" if isinstance(node, BreakStmt) else "continue"
                self.error(f"'{keyword}' used outside of a loop", node)

        elif isinstance(node, FunctionCall):
            self.check_function_call(node)

        elif isinstance(node, (PostIncrement, PreIncrement)):
            self.check_increment(node)
        
        elif isinstance(node, IndexAccess):
            self.check_index_access(node)

        elif isinstance(node, TupleAccess):
            self.check_tuple_access(node)

        else:
            # Expression used as statement
            self.check_expr(node)

    def check_var_decl(self, node: VarDecl):
        value_type = self.check_expr(node.value)

        # Empty array literal [] is compatible with any array type
        if value_type == "unknown[]" and node.type.endswith("[]"):
            pass  # trust the declared type
        elif not self.types_compatible(node.type, value_type):
            self.error(
                f"Type mismatch in declaration of '{node.name}': "
                f"declared as '{node.type}' but value is '{value_type}'",
                node
            )

        # str cannot be null!
        if node.type == "str" and isinstance(node.value, NullLiteral):
            self.error(
                f"'{node.name}' is type 'str' which cannot be null. "
                f"Use empty string \"\" instead",
                node
            )

        self.symbols.declare(node.name, node.type)

    def check_const_decl(self, node: ConstDecl):
        """
        const MAX_SIZE: int = 100;
        SCREAMING_CASE already enforced by parser!
        """
        value_type = self.check_expr(node.value)

        # Empty array literal [] is compatible with any array type
        if value_type == "unknown[]" and node.type.endswith("[]"):
            pass  # trust the declared type
        elif not self.types_compatible(node.type, value_type):
            self.error(
                f"Type mismatch in constant '{node.name}': "
                f"declared as '{node.type}' but value is '{value_type}'",
                node
            )

        self.symbols.declare(node.name, node.type, is_const=True)
        
    # ---------------- #
    #      ARRAYS      #
    # ---------------- #

    def check_array_literal(self, node: ArrayLiteral) -> str:
        """
        [1, 2, 3] -> "int[]"
        All elements must be the same type!
        """
        if not node.elements:
            return "unknown[]"  # empty array, type unknown

        first_type = self.check_expr(node.elements[0])
        for i, elem in enumerate(node.elements[1:], 1):
            elem_type = self.check_expr(elem)
            if not self.types_compatible(first_type, elem_type):
                self.error(
                    f"Array element {i} has type '{elem_type}' but expected '{first_type}'. "
                    f"Arrays cannot mix types in Mocha",
                    node
                )
        return f"{first_type}[]"

    def check_index_access(self, node: IndexAccess) -> str:
        obj_type   = self.check_expr(node.obj)
        index_type = self.check_expr(node.index)

        # Dict access — str key allowed!
        if obj_type == "dict":
            if index_type != "str":
                self.error(f"Dict key must be str, got '{index_type}'", node)
            return "any"

        if index_type != "int":
            self.error(f"Array index must be int, got '{index_type}'", node)

        elem_type = self.extract_element_type(obj_type)
        if elem_type is None:
            self.error(f"Cannot index into non-array type '{obj_type}'", node)
            return "unknown"
        return elem_type
    
    def check_index2d_access(self, node: Index2DAccess) -> str:
        obj_type = self.check_expr(node.obj)

        # Dict chained access masquerading as 2D access
        if obj_type == "dict":
            row_type = self.check_expr(node.row)
            col_type = self.check_expr(node.col)
            if row_type != "str":
                self.error(f"Dict key must be str, got '{row_type}'", node)
            if col_type != "str":
                self.error(f"Dict key must be str, got '{col_type}'", node)
            return "dict"
        
        row_type = self.check_expr(node.row)
        col_type = self.check_expr(node.col)

        if row_type != "int":
            self.error(f"2D array row index must be int, got '{row_type}'", node)
        if col_type != "int":
            self.error(f"2D array col index must be int, got '{col_type}'", node)

        # Extract element type from 2D array type e.g. "int[3][3]" -> "int"
        elem_type = self.extract_element_type(obj_type)
        if elem_type is not None:
            elem_type = self.extract_element_type(elem_type)
        if elem_type is None:
            self.error(f"Cannot 2D-index into non-2D-array type '{obj_type}'", node)
            return "unknown"
        return elem_type

    def extract_element_type(self, array_type: str):
        """
        "int[]"    -> "int"
        "int[5]"   -> "int"
        "int[][]"  -> "int[]"
        "int[][3]" -> "int[]"
        "int"      -> None (not an array)
        """
        # Find the LAST [...] suffix and strip it
        if array_type.endswith("]"):
            bracket = array_type.rfind("[")
            if bracket != -1:
                return array_type[:bracket]
        return None
    
    # ---------------- #
    #      TUPLES      #
    # ---------------- #
    
    def check_tuple_literal(self, node: TupleLiteral) -> str:
        if not node.elements:
            self.error("Tuple cannot be empty.", node)
            return "unknown"
        types = [self.check_expr(elem) for elem in node.elements]
        if len(set(types)) > 1:
            self.error(
                f"Mocha tuples are homogeneous — all elements must be the same type. "
                f"Got: {', '.join(types)}. For mixed types, use a dict.", node
            )
            return "unknown"
        return f"({types[0]}, {len(types)})"

    def check_tuple_access(self, node: TupleAccess) -> str:
        tuple_type = self.check_expr(node.obj)
        if not tuple_type.startswith("("):
            self.error(f"'#' access used on non-tuple type '{tuple_type}'", node)
            return "unknown"
        inner = tuple_type[1:-1]  # strip parens
        parts = [p.strip() for p in inner.rsplit(",", 1)]
        elem_type = parts[0]
        count = int(parts[1]) if len(parts) == 2 and parts[1].isdigit() else None
        if count is not None and node.index >= count:
            self.error(
                f"Tuple index {node.index} out of range. "
                f"Tuple has {count} elements (0 to {count - 1}).", node
            )
            return "unknown"
        return elem_type
    
    # ---------------- #
    #        SET       #
    # ---------------- #
    
    def check_set_literal(self, node: SetLiteral) -> str:
        if not node.elements:
            return "set<unknown>"
        
        first_type = self.check_expr(node.elements[0])
        for elem in node.elements[1:]:
            elem_type = self.check_expr(elem)
            if not self.types_compatible(first_type, elem_type):
                self.error(
                    f"Set elements must all be the same type. "
                    f"Expected '{first_type}' but got '{elem_type}'", node
                )
        
        # Non-primitive types are treated as object
        if first_type not in ("int", "float", "str", "bool"):
            return "set<object>"
        
        return f"set<{first_type}>"

    def check_assignment(self, node: Assignment):
        """
        x = 5;  or  this.name = "Shiv";
        Checks:
        - target exists
        - target is not a constant
        - value type matches target type
        """
        if isinstance(node.target, TupleAccess):
            self.error("Cannot assign to tuple element. Tuples are immutable in Mocha.", node)
            return
        
        value_type = self.check_expr(node.value)
        # Get target name and check it's not const
        if isinstance(node.target, Identifier):
            symbol = self.symbols.lookup_safe(node.target.name)
            if symbol:
                if symbol["is_const"]:
                    self.error(
                        f"Cannot reassign constant '{node.target.name}'. "
                        f"Constants are immutable in Mocha", node
                    )
                if not self.types_compatible(symbol["type"], value_type):
                    self.error(
                        f"Type mismatch: cannot assign '{value_type}' "
                        f"to '{node.target.name}' which is '{symbol['type']}'", node
                    )

        elif isinstance(node.target, MemberAccess):
            # this.field = value - basic check
            self.check_expr(node.target)

        elif isinstance(node.target, IndexAccess):
            # Const check
            if isinstance(node.target.obj, Identifier):
                symbol = self.symbols.lookup_safe(node.target.obj.name)
                if symbol and symbol["is_const"]:
                    self.error(
                        f"Cannot mutate constant '{node.target.obj.name}'. "
                        f"Constants are immutable in Mocha", node
                    )
            obj_type = self.check_expr(node.target.obj)
            self.check_expr(node.target.index)

            # Dict assignment — always valid, values are dynamic
            if obj_type == "dict":
                self.check_expr(node.target.index)  # just check key is valid expr
                return

            elem_type = self.extract_element_type(obj_type)
            if elem_type is None:
                self.error(f"Cannot index into non-array type '{obj_type}'", node)
            elif not self.types_compatible(elem_type, value_type):
                self.error(
                    f"Cannot assign '{value_type}' to array of '{elem_type}'", node
                )
        
        elif isinstance(node.target, Index2DAccess):
            # Const check
            if isinstance(node.target.obj, Identifier):
                symbol = self.symbols.lookup_safe(node.target.obj.name)
                if symbol and symbol["is_const"]:
                    self.error(
                        f"Cannot mutate constant '{node.target.obj.name}'. "
                        f"Constants are immutable in Mocha", node
                    )
            obj_type  = self.check_expr(node.target.obj)
            elem_type = self.extract_element_type(obj_type)
            if elem_type is not None:
                elem_type = self.extract_element_type(elem_type)
            if elem_type is None:
                self.error(f"Cannot index into non-2D-array type '{obj_type}'", node)
            elif not self.types_compatible(elem_type, value_type):
                self.error(
                    f"Cannot assign '{value_type}' to 2D array of '{elem_type}'", node
                )

    # ---------------- #
    #    DICTIONARY    #
    # ---------------- #

    def check_dict_literal(self, node: DictLiteral) -> str:
        for key, value in node.pairs:
            key_type = self.check_expr(key)
            if key_type != "str":
                self.error(f"Dict keys must be str, got '{key_type}'", node)
            self.check_expr(value)
        return "dict"
    
    
    def check_compound_assignment(self, node: CompoundAssignment):
        """
        x += 5;  x -= 3;  etc.
        Target must be numeric and not const.
        """
        target_type = self.check_expr(node.target)
        value_type  = self.check_expr(node.value)

        if isinstance(node.target, Identifier):
            symbol = self.symbols.lookup_safe(node.target.name)
            if symbol and symbol["is_const"]:
                self.error(
                    f"Cannot use '{node.op}' on constant '{node.target.name}'", node
                )

        elif isinstance(node.target, IndexAccess):
            if isinstance(node.target.obj, Identifier):
                symbol = self.symbols.lookup_safe(node.target.obj.name)
                if symbol and symbol["is_const"]:
                    self.error(
                        f"Cannot mutate constant '{node.target.obj.name}'. "
                        f"Constants are immutable in Mocha", node
                    )

        elif isinstance(node.target, Index2DAccess):
            if isinstance(node.target.obj, Identifier):
                symbol = self.symbols.lookup_safe(node.target.obj.name)
                if symbol and symbol["is_const"]:
                    self.error(
                        f"Cannot mutate constant '{node.target.obj.name}'. "
                        f"Constants are immutable in Mocha", node
                    )

        if target_type not in self.NUMERIC_TYPES:
            self.error(
                f"'{node.op}' requires a numeric type, got '{target_type}'", node
            )
        if value_type not in self.NUMERIC_TYPES:
            self.error(
                f"'{node.op}' requires a numeric value, got '{value_type}'", node
            )

    def check_return(self, node: ReturnStmt):
        """
        return a + b;
        Checks return type matches the function's declared return type!
        """
        if self.current_return is None:
            self.error("'return' used outside of a function", node)
            return

        if node.value is None:
            if self.current_return != "null":
                self.error(
                    f"Empty return in function that should return "
                    f"'{self.current_return}'", node
                )
            return

        value_type = self.check_expr(node.value)
        if not self.types_compatible(self.current_return, value_type):
            self.error(
                f"Return type mismatch: function declared to return "
                f"'{self.current_return}' but returning '{value_type}'", node
            )

    def check_block(self, statements: list):
        """ Type-check a list of statements in a new scope """
        self.symbols.push_scope()
        for stmt in statements:
            self.check_stmt(stmt)
        self.symbols.pop_scope()

    def check_if(self, node: IfStmt):
        condition_type = self.check_expr(node.condition)
        if condition_type not in ("bool", "unknown"):
            self.error(
                f"If condition must be bool, got '{condition_type}'. "
                f"Mocha does not allow truthy/falsy coercion", node
            )
        self.check_block(node.then_body)

        for elif_condition, elif_body in node.else_ifs:
            c_type = self.check_expr(elif_condition)
            if c_type not in ("bool", "unknown"):
                self.error(
                    f"else if condition must be bool, got '{c_type}'", node
                )
            self.check_block(elif_body)

        if node.else_body:
            self.check_block(node.else_body)

    def check_while(self, node: WhileLoop):
        self.loop_depth += 1
        try:
            condition_type = self.check_expr(node.condition)
            if condition_type != "bool":
                self.error(f"While condition must be bool, got '{condition_type}'", node)
            self.check_block(node.body)
        finally:
            self.loop_depth -= 1

    def check_do_while(self, node: DoWhileLoop):
        self.loop_depth += 1
        try:
            self.check_block(node.body)
            condition_type = self.check_expr(node.condition)
            if condition_type != "bool":
                self.error(f"Do-while condition must be bool, got '{condition_type}'", node)
        finally:
            self.loop_depth -= 1

    def check_for(self, node: ForLoop):
        self.loop_depth += 1
        self.symbols.push_scope()
        try:
            self.check_stmt(node.init)
            condition_type = self.check_expr(node.condition)
            if condition_type != "bool":
                self.error(f"For loop condition must be bool, got '{condition_type}'", node)
            self.check_expr(node.step)
            for stmt in node.body:
                self.check_stmt(stmt)
        finally:
            self.symbols.pop_scope()
            self.loop_depth -= 1

    def check_foreach(self, node: ForEachLoop):
        self.loop_depth += 1

        # Set iteration
        if isinstance(node.iterable, SetIterable):
            set_type = self.check_expr(node.iterable.set_expr)
            if not set_type.startswith("set<"):
                self.error(f"Expected a set in 'for each ... in <...>', got '{set_type}'", node)
            # Extract element type from set<int> -> int
            elem_type = set_type[4:-1]
            node.var_type = elem_type
            self.symbols.push_scope()
            try:
                self.symbols.declare(node.var_name, elem_type)
                for stmt in node.body:
                    self.check_stmt(stmt)
            finally:
                self.symbols.pop_scope()
                self.loop_depth -= 1
            return

        iterable_type = self.check_expr(node.iterable)
        if iterable_type and iterable_type.endswith("[]"):
            elem_type = iterable_type[:-2]
        else:
            if iterable_type not in ("unknown", "dict"):
                self.error(
                    f"'for each' requires an array or set, got '{iterable_type}'. "
                    f"Use 'for each x in arr' for arrays or 'for each x in <s>' for sets.", node
                )
            elem_type = "unknown"

        var_type = node.var_type if node.var_type else elem_type
        node.var_type = var_type
        self.symbols.push_scope()
        try:
            self.symbols.declare(node.var_name, var_type)
            for stmt in node.body:
                self.check_stmt(stmt)
        finally:
            self.symbols.pop_scope()
            self.loop_depth -= 1

    def check_match(self, node: MatchStmt):
        val_type    = self.check_expr(node.value)
        has_default = False
        for case in node.cases:
            if case.is_default:
                has_default = True
            if case.pattern:
                if isinstance(case.pattern, Identifier) and case.condition:
                    self.symbols.push_scope()
                    self.symbols.declare(case.pattern.name, val_type)
                    cond_type = self.check_expr(case.condition)
                    if cond_type != "bool":
                        self.error(f"'when' condition must be bool, got '{cond_type}'", node)
                    self.check_block(case.body)
                    self.symbols.pop_scope()
                    continue
                self.check_expr(case.pattern)
            if case.condition:
                cond_type = self.check_expr(case.condition)
                if cond_type != "bool":
                    self.error(f"'when' condition must be bool, got '{cond_type}'", node)
            self.check_block(case.body)
        if not has_default:
            self.error("Match statement must have a 'default' case.", node)

    # -------------------------------------------------------
    # Function and class checking
    # -------------------------------------------------------

    def has_return(self, stmts):
        for stmt in stmts:
            if isinstance(stmt, ReturnStmt):
                return True
            if isinstance(stmt, IfStmt):
                if (self.has_return(stmt.then_body) and 
                    stmt.else_body and 
                    self.has_return(stmt.else_body)):
                    return True
            if isinstance(stmt, WhileLoop):
                pass
            if isinstance(stmt, MatchStmt):
                has_default = any(c.is_default for c in stmt.cases)
                if has_default:
                    all_return = all(
                        self.has_return(c.body) or self.has_break(c.body)
                        for c in stmt.cases
                    )
                    if all_return:
                        return True
        return False

    def has_break(self, stmts):
        for stmt in stmts:
            if isinstance(stmt, BreakStmt):
                return True
        return False
    
    def check_function(self, node):
        if not self.symbols.lookup_safe(node.name):
            self.symbols.declare(node.name, node.return_type, is_function=True)

        prev_return = self.current_return
        self.current_return = node.return_type

        # Track if we're in a shared method
        prev_shared = getattr(self, 'current_shared', False)
        self.current_shared = getattr(node, 'is_shared', False)

        self.symbols.push_scope()
        for param in node.params:
            self.symbols.declare(param.name, param.type)
        for stmt in node.body:
            self.check_stmt(stmt)
        self.symbols.pop_scope()

        self.current_return = prev_return
        self.current_shared = prev_shared

        if node.return_type != "null":
            if getattr(node, 'is_native', False):  # ← add this
                return #natuve functions have no body
            if not self.has_return(node.body):
                self.error(
                    f" : Function '{node.name}' "
                    f"declared as '{node.return_type}' "
                    f"but has no return statement. "
                    f"Clang will throw fatal error without it.", node
                )
    
    def check_extend(self, node: ExtendDecl):
        prev_class = self.current_class
        self.current_class = node.type_name

        for func in node.body:
            # Register 'this' as the extended type
            self.symbols.push_scope()
            self.symbols.declare("this", node.type_name)
            self.check_function(func)
            self.symbols.pop_scope()

        self.current_class = prev_class
    
    def is_subclass_of(self, cls: str, parent: str) -> bool:
        """Walk up the inheritance chain to see if cls descends from parent"""
        current = cls
        while current in self.inheritance:
            current = self.inheritance[current]
            if current == parent:
                return True
        return False

    def check_class(self, node: ClassDecl):
        """
        Checks a class declaration.
        Declares all fields and methods, then checks method bodies.
        """
        self.check_diamond_problem(node)
        if not self.symbols.lookup_safe(node.name):
            self.symbols.declare(node.name, node.name, is_class=True)

        # Track inheritance
        if node.parents:
            self.inheritance[node.name] = node.parents[0]

        prev_class = self.current_class
        self.current_class = node.name

        self.symbols.push_scope()

        # First pass: declare all fields and methods
        # (so methods can reference each other!)
        for member in node.body:
            if isinstance(member, FieldDecl):
                self.symbols.declare(
                    member.name, member.type,
                    visibility=member.visibility
                )
                self.symbols.scopes[0][f"{node.name}.{member.name}"] = {
                    "type": member.type, "is_const": False,
                    "is_function": False, "is_class": False,
                    "visibility": member.visibility,
                }
            elif isinstance(member, MethodDecl):
                self.symbols.declare(
                    member.name, member.return_type,
                    is_function=True,
                    visibility=member.visibility
                )
                self.symbols.scopes[0][f"{node.name}.{member.name}"] = {
                    "type": member.return_type, "is_const": False,
                    "is_function": True, "is_class": False,
                    "visibility": member.visibility,
                }

        # Second pass: check method bodies
        for member in node.body:
            if isinstance(member, MethodDecl):
                self.check_function(member)
            elif isinstance(member, FieldDecl) and member.value:
                self.check_expr(member.value)

        self.symbols.pop_scope()
        self.current_class = prev_class

        # After existing class checks
        for interface_name in node.interfaces:  # ← node.interfaces not implements
            if interface_name not in self.interface_methods:
                self.error(
                    f" : Unknown interface '{interface_name}'", node
                )
                continue

            required = self.interface_methods[interface_name]

            # Collect class's actual methods
            class_methods = {}
            for member in node.body:
                 if isinstance(member, (FunctionDecl, MethodDecl)):
                    class_methods[member.name] = {
                        "return_type": member.return_type,
                        "params": [(p.name, p.type) for p in member.params]
                    }
                    
            for method_name, sig in required.items():
                if method_name not in class_methods:
                    param_str = ", ".join(
                        f"{n}: {t}" for n, t in sig["params"]
                    )
                    self.error(
                        f"Class '{node.name}' implements "
                        f"'{interface_name}' but missing "
                        f"'{method_name}({param_str}) -> {sig['return_type']}'\n"
                        f"Hint: Add to '{node.name}':\n"
                        f"    function {method_name}({param_str}) "
                        f"-> {sig['return_type']} {{ ... }};", node
                    )
                else:
                    actual = class_methods[method_name]
                    # Check return type
                    if actual["return_type"] != sig["return_type"]:
                        self.error(
                            f" : '{node.name}.{method_name}' "
                            f"return type '{actual['return_type']}' doesn't "
                            f"match interface '{sig['return_type']}'", node
                        )
                    # Check param types
                    if len(actual["params"]) != len(sig["params"]):
                        self.error(
                            f" : '{node.name}.{method_name}' "
                            f"wrong number of parameters for "
                            f"interface '{interface_name}'", node
                        )
                    else:
                        for (an, at), (_, it) in zip(
                            actual["params"], sig["params"]
                        ):
                            if at != it:
                                self.error(
                                    f" : "
                                    f"'{node.name}.{method_name}' "
                                    f"parameter '{an}: {at}' doesn't "
                                    f"match interface type '{it}'", node
                                )
    
    def get_all_methods(self, class_name: str) -> set:
        """Recursively collect all method names from a class and its ancestors."""
        node = self.get_class_node(class_name)
        if not node:
            return set()
        methods = set()
        # Own methods
        for member in node.body:
            if isinstance(member, MethodDecl):
                methods.add(member.name)
        # Inherited methods
        for parent_name in getattr(node, 'parents', []):
            methods |= self.get_all_methods(parent_name)
        return methods
    
    def get_all_fields(self, class_name: str) -> set:
        node = self.get_class_node(class_name)
        if not node:
            return set()
        fields = set()
        for member in node.body:
            if isinstance(member, FieldDecl):
                fields.add(member.name)
        for parent_name in getattr(node, 'parents', []):
            fields |= self.get_all_fields(parent_name)
        return fields

    def check_diamond_problem(self, node: ClassDecl):
        if not hasattr(node, 'parents') or len(node.parents) < 2:
            return

        parent_methods = {}  # method_name -> [parent_names]

        for parent_name in node.parents:
            for method_name in self.get_all_methods(parent_name):
                if method_name not in parent_methods:
                    parent_methods[method_name] = []
                parent_methods[method_name].append(parent_name)

        for method_name, parents in parent_methods.items():
            if len(parents) > 1:
                key = f"{node.name}.{method_name}"
                self.diamond_conflicts[key] = parents

        # Field diamond check
        parent_fields = {}
        for parent_name in node.parents:
            for field_name in self.get_all_fields(parent_name):
                if field_name not in parent_fields:
                    parent_fields[field_name] = []
                parent_fields[field_name].append(parent_name)

        for field_name, parents in parent_fields.items():
            if len(parents) > 1:
                self.error(
                    f"Diamond conflict: field '{field_name}' is inherited from "
                    f"both {' and '.join(parents)} in class '{node.name}'. "
                    f"Mocha does not support diamond inheritance of fields — "
                    f"rename one of the conflicting fields to resolve this.", node
                )
                
    def check_interface(self, node: InterfaceDecl):
        # Store method signatures for later enforcement
        methods = {}
        for method in node.methods:
            methods[method.name] = {
                "return_type": method.return_type,
                "params": [(p.name, p.type) for p in method.params]
            }
        self.interface_methods[node.name] = methods
        self.symbols.declare(node.name, node.name, is_class=True)

    def get_class_node(self, name: str):
        return self.class_nodes.get(name, None)

    # -------------------------------------------------------
    # STEP 8: Top-level check - the entry point!
    # -------------------------------------------------------

    def check(self, program: Program) -> list:
        """
        Entry point. Checks the entire program.
        Returns list of errors (empty = all good!)
        """

        # PRE-PASS: register all top-level function signatures first
        # so functions can call each other regardless of order!
        for node in program.statements:
            if isinstance(node, FunctionDecl):
                existing = self.symbols.lookup_safe(node.name)
                if existing:
                    existing_node = next(
                        n for n in program.statements
                        if isinstance(n, FunctionDecl) and n.name == node.name
                    )
                    def fmt(n):
                        params = ", ".join(
                            f"{p.name}: {p.type}" for p in n.params
                            if p.name != "didLoad"
                        )
                        return f"function {n.name}({params}) -> {n.return_type}"

                    self.compile_error(
                        f"Illegal redefinition of "
                        f"function {node.name} in scope. Its versions are:\n"
                        f"  {fmt(existing_node)} {{...}};\n"
                        f"  and {fmt(node)} {{...}};\n"
                        f"Please resolve this ambiguity by renaming one of the functions. "
                        f"Mocha prohibits Function OverLoading",
                        node=node
                    )
                else:
                    self.symbols.declare(node.name, node.return_type, is_function=True)
            elif isinstance(node, ClassDecl):
                self.class_nodes[node.name] = node
                if not self.symbols.lookup_safe(node.name):
                    self.symbols.declare(node.name, node.name, is_class=True)
                for member in node.body:
                    if isinstance(member, FieldDecl):
                        key = f"{node.name}.{member.name}"
                        if not self.symbols.lookup_safe(key):
                            self.symbols.declare(key, member.type, visibility=member.visibility)
            elif isinstance(node, ExtendDecl):
                # Register extension methods as "type_name.method_name"
                for func in node.body:
                    key = f"{node.type_name}.{func.name}"
                    self.symbols.declare(key, func.return_type, is_function=True)
            elif isinstance(node, TagDecl):
                self.tag_types.add(node.name)
                # Register tag type itself
                if not self.symbols.lookup_safe(node.name):
                    self.symbols.declare(node.name, node.name, is_class=True)
                # Register each member as a constant of the tag's type
                for member in node.members:
                    key = f"{node.name}.{member}"
                    if not self.symbols.lookup_safe(key):
                        self.symbols.declare(key, node.name, is_const=True)


        for node in program.statements:
            if isinstance(node, ImportStmt):
                name = node.alias if node.alias else node.module
                if name:  # skip empty-named from-imports
                    self.symbols.declare(name, "module")

            elif isinstance(node, ClassDecl):
                self.check_class(node)

            elif isinstance(node, InterfaceDecl):
                self.check_interface(node)
            
            elif isinstance(node, TagDecl):
                pass  # already handled in pre-pass

            elif isinstance(node, FunctionDecl):
                self.check_function(node)

            elif isinstance(node, MethodDecl):
                self.check_function(node)

            elif isinstance(node, ExtendDecl):
                self.check_extend(node)

            else:
                try:
                    self.check_stmt(node)
                except MochaTypeError as e:
                    self.errors.append(e)
        
        # Collect all didLoad entry points
        entry_points = []
        for node in program.statements:
            if isinstance(node, FunctionDecl) and node.has_didLoad:
                entry_points.append(node.name)
            elif isinstance(node, ClassDecl):
                for member in node.body:
                    if isinstance(member, MethodDecl) and member.has_didLoad:
                        entry_points.append(f"{node.name}.{member.name}")

        if len(entry_points) == 0:
            self.compile_error(
                "No entry point found. Mark one function with 'didLoad' as its first parameter. "
                "Example: function main(didLoad, name: str) -> null { ... };"
            )
        elif len(entry_points) > 1:
            self.compile_error(
                f"Multiple entry points found: {', '.join(entry_points)}. "
                f"Only one function can have 'didLoad'."
            )

        return self.errors

if __name__ == "__main__":
    from mocha_lexer import Lexer
    from mocha_parser import Parser