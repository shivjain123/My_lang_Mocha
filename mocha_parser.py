# ============================================================
# Mocha Language Parser v0.9
# mocha_parser.py
# Pratt-style
#
# Converts token stream into an Abstract Syntax Tree (AST)
# via recursive descent parsing with precedence climbing
#
# ============================================================
#
#   ── Algorithm ───────────────────────────────────────────
#   Recursive descent with operator precedence encoding via
#   parse chain. Intentionally no backtracking — lookahead is
#   minimal (current token + peek). Pre-scans tokens to collect
#   class and tag names for use during expression parsing
#   (enables TagAccess and QualifiedMethodCall detection).
#
#   ── Error Handling ──────────────────────────────────────
#   MochaParseError class captures token location (line/col)
#   and current token type/value in error message. Synchronization
#   via synchronize() which consumes tokens until reaching a
#   top-level declaration boundary (next function/class/import
#   or unmatched RBRACE at depth 0). On error, continues
#   parsing remaining top-level items rather than stopping
#   cold (soft error recovery).
#
#   ── Type Parsing ────────────────────────────────────────
#   Handles all Mocha types:
#     - Primitives: int, vast, float, str, bool, Result, null
#     - Tuples: (T, N) where N is literal int count
#     - Arrays: T[], T[N], T[][N], etc. (1D/2D max; 3D+ rejected)
#     - Sets: set<T> (type-parameterized)
#     - Dicts: dict (untyped at parse time)
#     - Custom: any IDENTIFIER (class/interface names)
#   Postfix dimension syntax (int[5][]) parsed left-to-right.
#   No generic syntax e.g. List<T>; parameterized types are
#   library-level abstractions, not parser-level generics.
#
#   ── Operator Precedence (14 levels, low to high) ────────
#    1. || (logical or)
#    2. && (logical and)
#    3. | (bitwise or)
#    4. ^ (bitwise xor)
#    5. & (bitwise and)
#    6. == != (equality)
#    7. < > <= >= (comparison)
#    8. << >> (bit shift)
#    9. + - (addition)
#   10. * / % (multiplication)
#   11. ! - ~ (unary: not, negate, bitwise-not)
#   12. ++ -- (pre/post increment)
#   13. () [] . # (call, index, member access, tuple access)
#   14. literals, identifiers, type casts, lambdas (primary)
#
#   Climbing from OR down to PRIMARY is how 2+3*4=14 holds
#   (multiplication parsed deeper = higher precedence).
#
#   ── Expressions ─────────────────────────────────────────
#   - Binary: all arithmetic, comparison, logical, bitwise ops
#   - Unary: ! (not), - (negate), ~ (bitwise-not), ++ -- (pre)
#   - Postfix: ++ --, member access (.), index access ([]),
#     tuple element access (#), function call (())
#   - Casts: int(x), str(n), float(z) — strict validation,
#     no implicit coercion at parse time (checked by type checker)
#   - Literals: int, float, complex (with im suffix), string,
#     bool, null
#   - Collections: array [], dict {}, set <>, tuple ()
#   - Lambda: lambda (x: int) -> int: x * 2
#   - List comprehension: [x*2 for each x in arr if x > 0]
#     with optional else clause for filtered values
#   - Function calls: name(args), Class.obj.method(args) for
#     qualified dispatch, "mocha-lib".func(args) for cross-lib
#   - ok(value), error(value) — Result type constructors
#   - await expr — async operation suspension
#
#   ── Collections & Literals ──────────────────────────────
#   - Array: [1, 2, 3] or [] (empty, type inferred by checker)
#   - Dict: {"key": val, ...} or {} (untyped at parse time)
#   - Set: <1, 2, 3> or <> (empty set)
#   - Tuple: (1, 2, 3) or (x, 5) — homogeneous + fixed size
#   - Tuple access: expr#0, expr#1 (not expr[0] — enforces
#     distinction from array indexing; # is index operator)
#   - 2D array access: arr[i][j], arr[0][] (row slice),
#     arr[][1] (col slice) — special syntax for clarity
#   - Trailing commas allowed in all collection literals
#   - Dict literals require explicit str-typed keys (type checker
#     enforces string-only keys; parser allows any expression)
#
#   ── Control Flow ────────────────────────────────────────
#   - if/else if/else: conditions must be bool (type checker
#     enforces; parser accepts any expr)
#   - while/do-while: same condition rule
#   - for loops: init stmt, bool condition, step expr
#   - for-each: for each var in <set> or for each var in iterable
#     (set iteration uses <> syntax; array/dict use bare iterable)
#   - match/case: pattern matching with optional when guards
#     (guards are bool exprs, scoped per-case)
#   - All loops tracked via loop_depth (break/continue validated
#     by type checker, not parser)
#   - Explicit semicolons required (no ASI)
#
#   ── Functions ───────────────────────────────────────────
#   - Regular: function name(params) -> type { body };
#   - Async: async function name(params) -> type { body };
#   - Native: function name(params) -> type native c_name;
#     (zero-body, delegates to C implementation)
#   - Parameters: name: type, optional default values
#   - Variadic: function printf(fmt: str, +) -> int native printf;
#     (+ as last param marker, no parsing of varargs in Mocha
#     proper — used only for native interop)
#   - didLoad marker: function main(didLoad, name: str) → entry point
#     (didLoad must be first param if present; type checker enforces
#     exactly one didLoad per module)
#   - Lambda: lambda (params) -> type: expr (expr-only body, no stmts)
#   - Forward references allowed (type checker resolves)
#
#   ── Classes & OOP ───────────────────────────────────────
#   - Declarations: class Name extends Parent1, Parent2
#     implements Interface1, Interface2 { ... };
#   - Multiple inheritance allowed (parser accepts N parents;
#     type checker detects diamond conflicts on fields, warns
#     on method conflicts)
#   - Field declarations: var name: type; or var name: type = default;
#   - Method declarations: function name(...) { ... };
#   - Visibility: public (default), private, protected (enforced
#     by type checker, parsed as modifiers)
#   - Shared (static): shared function create() { ... };
#   - this keyword: only valid inside instance methods
#     (type checker validates; parser just parses as identifier)
#   - Two-pass checking deferred to type checker (parser does not
#     validate forward references)
#
#   ── Interfaces ──────────────────────────────────────────
#   - Declarations: interface Name { ... };
#   - Method signatures only: function name(...) -> type;
#   - No implementation allowed (parser rejects method bodies)
#   - Conformance checked by type checker (parser just captures sig)
#
#   ── Imports & Modules ───────────────────────────────────
#   - Module alias: import MochaMath from "mocha-math" as mm;
#   - Explicit wildcard: from "mocha-math" import *;
#   - Selective: from "mocha-math" import sin_deg(), PI, cos_deg();
#   - Function imports recognized by () suffix (purely syntactic;
#     type checker resolves actual symbol types)
#   - Source strings are literal paths ("mocha-math", "mocha-bio")
#   - Circular imports not detected (checked at link time)
#
#   ── Tags (Enumerations) ─────────────────────────────────
#   - Declaration: tag TokenType { IDENTIFIER, INT_LIT, ... };
#   - Members must be SCREAMING_CASE (enforced at parse time,
#     matching const naming rule)
#   - No associated values (pure tag membership, not tagged unions)
#   - Access: TokenType.IDENTIFIER (parsed as member access,
#     distinguished from method calls by absence of parentheses)
#   - Type checker enforces exhaustiveness in match statements
#
#   ── Exception Handling ──────────────────────────────────
#   - try { ... } rescue, e { ... };  (with binding)
#   - try { ... } rescue { ... };     (without binding)
#   - fail "message"; (throw, always str message)
#   - rethrow; (re-raise current exception, only in rescue block)
#   - Binding is single identifier, scoped to rescue block
#   - No finally clause (codegen implements via flag)
#
#   ── Extension Methods (extend blocks) ────────────────────
#   - extend PrimitiveType { function method() { ... } };
#   - Extends built-in types (int, str, float, arrays, etc.)
#     with new methods
#   - Parser accepts any type (int[], set<str>, custom classes)
#   - Methods have implicit 'this' of extended type
#   - Parser does not validate method signatures; type checker
#     ensures no conflicts with existing methods
#
#   ── Qualified Method Calls (Diamond Inheritance) ────────
#   - Pattern: Class.obj.method() (detect via pre-scan of classes)
#   - Example: Bird.p.breathe() resolves via Bird class name
#   - Parser builds QualifiedMethodCall node; codegen uses
#     parent-precedence fallback
#   - Type checker flags ambiguous cases with both candidate
#     parents named in the error
#
#   ── Doc Comments ────────────────────────────────────────
#   - Lexer produces DOC_COMMENT tokens (~~-prefixed lines)
#   - Parser collects preceding doc tokens via collect_doc()
#   - Attached to FunctionDecl, ClassDecl, MethodDecl nodes
#   - Docs generator extracts and formats for output
#   - File-top-level restriction enforced by type checker
#     (parser just captures the tokens)
#
#   ── Notable Non-Features ────────────────────────────────
#   - No generics (List<T>; type parameters are lib-level)
#   - No function overloading (parser rejects duplicate operators)
#   - No default parameters in classes (only functions allowed)
#   - No destructuring in for-each (single var only)
#   - No guard clauses on function params (only match/case)
#   - No implicit returns (explicit return required)
#   - No string interpolation syntax (use .format())
# ============================================================

from mocha_lexer import Lexer, Token, TokenType
from mocha_ast import *
import sys


# ============================================================
# PARSER ERROR
# ============================================================

class MochaParseError(Exception):
    def __init__(self, message, token):
        super().__init__(
            f"MochaParseError at line {token.line}, "
            f"col {token.column}: {message}. "
            f"Got '{token.value}' ({token.type.name})"
        )
        self.token = token

# ============================================================
# PARSER
# ============================================================

class Parser:

    # All primitive type tokens
    TYPE_TOKENS = {
        TokenType.TYPE_INT:    "int",
        TokenType.TYPE_VAST:   "vast",
        TokenType.TYPE_FLOAT:  "float",
        TokenType.TYPE_STR:    "str",
        TokenType.TYPE_BOOL:   "bool",
        TokenType.TYPE_RESULT: "Result",
        TokenType.NULL:    "null", #unified Null
    }

    # Compound assignment operators
    COMPOUND_OPS = {
        TokenType.PLUS_ASSIGN:  "+=",
        TokenType.MINUS_ASSIGN: "-=",
        TokenType.STAR_ASSIGN:  "*=",
        TokenType.SLASH_ASSIGN: "/=",
    }

    def __init__(self, tokens: list):
        self.tokens = tokens
        self.pos = 0
        self.known_classes = self._collect_class_names()
        self.known_tags = self._collect_tag_names()
    
    def _collect_tag_names(self) -> set:
        """Pre-scan tokens to collect all tag names."""
        names = set()
        for i, tok in enumerate(self.tokens):
            if tok.type == TokenType.TAG:
                if i + 1 < len(self.tokens):
                    names.add(self.tokens[i + 1].value)
        return names

    def _collect_class_names(self) -> set:
        """Pre-scan tokens to collect all class names without consuming them."""
        names = set()
        for i, tok in enumerate(self.tokens):
            if tok.type == TokenType.CLASS:
                # Next token should be the class name
                if i + 1 < len(self.tokens):
                    names.add(self.tokens[i + 1].value)
        return names

    # -------------------------------------------------------
    # Token helpers
    # -------------------------------------------------------

    def current(self) -> Token:
        return self.tokens[self.pos]

    def peek(self, offset=1) -> Token:
        idx = self.pos + offset
        if idx < len(self.tokens):
            return self.tokens[idx]
        return self.tokens[-1]

    def advance(self) -> Token:
        tok = self.tokens[self.pos]
        if self.pos < len(self.tokens) - 1:
            self.pos += 1
        return tok

    def check(self, *types) -> bool:
        return self.current().type in types

    def match(self, *types) -> bool:
        if self.check(*types):
            self.advance()
            return True
        return False

    def expect(self, type: TokenType, message: str) -> Token:
        if self.check(type):
            return self.advance()
        raise MochaParseError(message, self.current())

    def is_at_end(self) -> bool:
        return self.current().type == TokenType.EOF

    # -------------------------------------------------------
    # STEP 2A: Types
    # -------------------------------------------------------

    def parse_type(self) -> str:
        """
        Parses a type annotation and returns it as a string.
        Handles: int, str, int[], int[5], int[][3], (int, str), {str: int}, {int}
        and also user-defined class names like Animal
        """
        tok = self.current()  # capture 'var' token before consuming

        if self.check(TokenType.LPAREN):
            self.advance()
            elem_type = self.parse_type()
            count = None
            if self.match(TokenType.COMMA):
                if self.check(TokenType.INT_LIT):
                    count = int(self.current().value)
                    self.advance()
                elif self.check(TokenType.RPAREN):
                    raise MochaParseError(
                        "Expected a count after the comma in tuple type, e.g. (float, 3)",
                        self.current()
                    )
                elif self.check(TokenType.IDENTIFIER):
                    raise MochaParseError(
                        "Tuple count must be an integer literal, not an identifier. "
                        "Did you mean a dict or a named type?",
                        self.current()
                    )
                else:
                    raise MochaParseError(
                        f"Expected an integer count in tuple type, e.g. (float, 3)",
                        self.current()
                    )
            self.expect(TokenType.RPAREN, "Expected ')' to close tuple type")
            if count is not None:
                base = f"({elem_type}, {count})"
            else:
                base = f"({elem_type})"

        elif self.check(TokenType.TYPE_DICT):
            self.advance()
            return "dict"
        
        elif self.check(TokenType.TYPE_SET):
            self.advance()
            self.expect(TokenType.LT, "Expected '<' after 'set'")
            if self.check(TokenType.NULL):
                self.advance()  # null means empty typed set
                self.expect(TokenType.COMMA, "Expected ',' after null")
            inner_type = self.parse_type()
            self.expect(TokenType.GT, "Expected '>' to close set type")
            return f"set<{inner_type}>"

        else:
            tok = self.current()
            if tok.type in self.TYPE_TOKENS:
                self.advance()
                base = self.TYPE_TOKENS[tok.type]
            elif tok.type == TokenType.LAMBDA:
                self.advance()
                return "lambda"
            elif tok.type == TokenType.IDENTIFIER:
                self.advance()
                base = tok.value
            else:
                raise MochaParseError(
                        "Expected a type annotation here (e.g. int, float, str, bool, or a class name)",
                        self.current()
                    )

        # Postfix array dimensions: int[], int[5], int[][3], int[5][] etc.
        while self.check(TokenType.LBRACKET):
            self.advance()
            if self.check(TokenType.RBRACKET):
                # Dynamic dimension []
                self.advance()
                base = f"{base}[]"
            elif self.current().type == TokenType.INT_LIT:
                # Fixed dimension [5]
                size = self.current().value
                self.advance()
                self.expect(TokenType.RBRACKET, "Expected ']' to close array size")
                base = f"{base}[{size}]"
            else:
                raise MochaParseError("Expected size or ']' in array type", self.current())

        return base

    # -------------------------------------------------------
    # STEP 2B: Literals
    # -------------------------------------------------------

    def parse_literal(self) -> Node:
        """
        Parses a literal and returns the matching leaf AST node.
        42 -> IntLiteral, "hi" -> StrLiteral, true -> BoolLiteral etc.
        """
        tok = self.advance()

        if tok.type == TokenType.INT_LIT:
            node = IntLiteral(value=int(tok.value))
            node.line = tok.line
            node.col  = tok.column
            return node

        if tok.type == TokenType.FLOAT_LIT:
            node = FloatLiteral(value=float(tok.value))
            node.line = tok.line
            node.col  = tok.column
            return node
        
        if tok.type == TokenType.COMPLEX_LIT:
            node = ComplexLiteral(real=0.0, imag=float(tok.value))
            node.line = tok.line
            node.col  = tok.column
            return node

        if tok.type == TokenType.STR_LIT:
            node = StrLiteral(value=tok.value)
            node.line = tok.line
            node.col  = tok.column
            return node

        if tok.type == TokenType.BOOL_LIT:
            node = BoolLiteral(value=tok.value == "true")
            node.line = tok.line
            node.col  = tok.column
            return node

        if tok.type == TokenType.NULL:
            node = NullLiteral()
            node.line = tok.line
            node.col  = tok.column
            return node

        raise MochaParseError(
                "Expected a literal value (int, float, complex, string, bool, or null)",
                tok
            )

    # -------------------------------------------------------
    # STEP 3: Expressions
    #
    # Expressions are parsed in ORDER OF PRECEDENCE
    # lowest precedence first, highest last.
    # This is what makes 2 + 3 * 4 = 14 not 20!
    # Breaking change has occured when the marked ones were added |_|
    #
    # Precedence ladder (low to high):
    #   1. || (or)
    #   2. && (and)
    #   3. == != (equality)
    #   4. | (bit or) |_|
    #   5. ^ (bit xor) |_|
    #   6. & (bit and) |_|
    #   7. < > <= >= (comparison)
    #   8. << >> (shift) |_|
    #   9. + - (addition)
    #  10. * / % (multiplication)
    #  11. ! - ~ (unary) |_| (last one)
    #  12. ++ -- (increment)
    #  13. () [] . (call, index, member)
    #  14. literals, identifiers (primary)
    # -------------------------------------------------------

    def parse_expression(self) -> Node:
        """ Entry point for any expression """
        return self.parse_or()

    def parse_or(self) -> Node:
        """ a || b """
        left = self.parse_and()
        while self.check(TokenType.OR):
            tok = self.current()
            op = self.advance().value
            right = self.parse_and()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_and(self) -> Node:
        """ a && b """
        left = self.parse_bit_or()
        while self.check(TokenType.AND):
            tok = self.current()
            op = self.advance().value
            right = self.parse_bit_or()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left
    
    def parse_bit_or(self) -> Node:
        """ a | b """
        left = self.parse_bit_xor()
        while self.check(TokenType.BIT_OR):
            tok = self.current()
            op = self.advance().value
            right = self.parse_bit_xor()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_bit_xor(self) -> Node:
        """ a ^ b """
        left = self.parse_bit_and()
        while self.check(TokenType.BIT_XOR):
            tok = self.current()
            op = self.advance().value
            right = self.parse_bit_and()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_bit_and(self) -> Node:
        """ a & b """
        left = self.parse_equality()
        while self.check(TokenType.BIT_AND):
            tok = self.current()
            op = self.advance().value
            right = self.parse_equality()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_equality(self) -> Node:
        """ a == b  or  a != b """
        left = self.parse_comparison()
        while self.check(TokenType.EQ, TokenType.NEQ):
            tok = self.current()
            op = self.advance().value
            right = self.parse_comparison()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_comparison(self) -> Node:
        """ a < b  a > b  a <= b  a >= b """
        left = self.parse_shift()
        while self.check(TokenType.LT, TokenType.GT,
                        TokenType.LTE, TokenType.GTE):
            tok = self.current()
            op = self.advance().value
            right = self.parse_shift()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left
    
    def parse_shift(self) -> Node:
        """ a << b  or  a >> b """
        left = self.parse_addition()
        while self.check(TokenType.BIT_SHL, TokenType.BIT_SHR):
            tok = self.current()
            op = self.advance().value
            right = self.parse_addition()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_addition(self) -> Node:
        """ a + b  or  a - b """
        left = self.parse_multiplication()
        while self.check(TokenType.PLUS, TokenType.MINUS):
            tok = self.current()
            op = self.advance().value
            right = self.parse_multiplication()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_multiplication(self) -> Node:
        """ a * b  or  a / b  or  a % b """
        left = self.parse_unary()
        while self.check(TokenType.STAR, TokenType.SLASH, TokenType.PERCENT):
            tok = self.current()
            op = self.advance().value
            right = self.parse_unary()
            left = BinaryOp(left=left, op=op, right=right)
            left.line = tok.line; left.col = tok.column
        return left

    def parse_unary(self) -> Node:
        """ !flag  or  -x  or  ++i (pre-increment) or bitwise-not ~x"""
        tok = self.current()
        # Pre-increment: ++i
        if self.check(TokenType.PLUS_PLUS):
            op = self.advance().value
            operand = self.parse_unary()
            node = PreIncrement(op=op, operand=operand)
            node.line = tok.line
            node.col  = tok.column
            return node

        # Pre-decrement: --i
        if self.check(TokenType.MINUS_MINUS):
            op = self.advance().value
            operand = self.parse_unary()
            node = PreDecrement(op=op, operand=operand)
            node.line = tok.line
            node.col  = tok.column
            return node

        # Not: !flag
        if self.check(TokenType.NOT):
            op = self.advance().value
            right = self.parse_unary()
            node = UnaryOp(op=op, right=right)
            node.line = tok.line
            node.col  = tok.column
            return node

        # Negative: -x
        if self.check(TokenType.MINUS):
            op = self.advance().value
            right = self.parse_unary()
            node = UnaryOp(op=op, right=right)
            node.line = tok.line
            node.col  = tok.column
            return node
        
        # Bitwise NOT: ~x
        if self.check(TokenType.BIT_NOT):
            op = self.advance().value
            right = self.parse_unary()
            node = UnaryOp(op=op, right=right)
            node.line = tok.line
            node.col  = tok.column
            return node

        return self.parse_postfix()

    def parse_postfix(self) -> Node:
        """
        Handles post-increment (i++, i--)
        and member access (obj.field)
        and tuple indexed elements
        and array types
        and function calls (add(1, 2))
        """
        expr = self.parse_primary()

        while True:
            # Post-increment: i++
            if self.check(TokenType.PLUS_PLUS):
                tok = self.current()
                op = self.advance().value
                expr = PostIncrement(operand=expr, op=op)
                expr.line = tok.line; expr.col = tok.column

            # Post-decrement: i--
            elif self.check(TokenType.MINUS_MINUS):
                tok = self.current()
                op = self.advance().value
                expr = PostIncrement(operand=expr, op=op)
                expr.line = tok.line; expr.col = tok.column

            # Member access: obj.field or this.name
            elif self.check(TokenType.DOT):
                tok = self.current()
                self.advance()
                if self.current().type == TokenType.CONST_IDENT:
                    member = self.advance().value
                else:
                    member = self.expect(
                        TokenType.IDENTIFIER,
                        "Expected member name after '.'"
                    ).value

                # Detect TagAccess: TokenType.IDENTIFIER (tag member access)
                # Pattern: TagName.SCREAMING_MEMBER (no second dot follows)
                if (isinstance(expr, Identifier)
                        and expr.name in self.known_tags
                        and not self.check(TokenType.DOT)):
                    expr = TagAccess(tag_name=expr.name, member_name=member)
                    expr.line = tok.line; expr.col = tok.column

                # Detect qualified method call: Bird.p.breathe()
                # Pattern: UppercaseIdent . lowerIdent . method ( )
                elif (isinstance(expr, Identifier)
                        and expr.name in self.known_classes
                        and self.check(TokenType.DOT)):
                    self.advance()  # consume second dot
                    method = self.expect(
                        TokenType.IDENTIFIER,
                        "Expected method name"
                    ).value
                    self.expect(TokenType.LPAREN, "Expected '(' after method name")
                    args = []
                    if not self.check(TokenType.RPAREN):
                        args.append(self.parse_call_arg())
                        while self.match(TokenType.COMMA):
                            args.append(self.parse_call_arg())
                    self.expect(TokenType.RPAREN, "Expected ')' after arguments")
                    expr = QualifiedMethodCall(
                        parent_class=expr.name,
                        obj=member,
                        method=method,
                        args=args
                    )
                    expr.line = tok.line; expr.col = tok.column
                else:
                    expr = MemberAccess(obj=expr, member=member)
                    expr.line = tok.line; expr.col = tok.column
            
            #Element Access for Tuples
            elif self.check(TokenType.HASH):
                tok = self.current()
                self.advance()
                idx_tok = self.expect(TokenType.INT_LIT, "Expected index after '#'")
                expr = TupleAccess(obj=expr, index=int(idx_tok.value))
                expr.line = tok.line; expr.col = tok.column
            
            # Index access: arr[i], grid[i][j], grid[0][], grid[][2]
            elif self.check(TokenType.LBRACKET):
                tok = self.current()
                self.advance()

                # grid[][2] — col slice (empty first bracket)
                if self.check(TokenType.RBRACKET):
                    self.advance()  # consume ']'
                    self.expect(TokenType.LBRACKET, "Expected '[' after '[]' for column slice")
                    col = self.parse_expression()
                    self.expect(TokenType.RBRACKET, "Expected ']' to close column slice")
                    expr = ColSlice(obj=expr, col=col)
                    expr.line = tok.line
                else:
                    first_index = self.parse_expression()
                    self.expect(TokenType.RBRACKET, "Expected ']' to close index")

                    # Check what comes next
                    if self.check(TokenType.LBRACKET):
                        self.advance()

                        # grid[0][] — row slice (empty second bracket)
                        if self.check(TokenType.RBRACKET):
                            self.advance()
                            expr = RowSlice(obj=expr, row=first_index)

                        # grid[i][j] — 2D index access
                        else:
                            col = self.parse_expression()
                            self.expect(TokenType.RBRACKET, "Expected ']' to close 2D index")
                            expr = Index2DAccess(obj=expr, row=first_index, col=col)
                            expr.line = tok.line

                    # grid[i] — regular 1D index access
                    else:
                        expr = IndexAccess(obj=expr, index=first_index)
                        expr.line = tok.line; expr.col = tok.column

            # Function call: add(1, 2)
            elif self.check(TokenType.LPAREN):
                expr = self.parse_call(expr)

            else:
                break

        return expr

    def parse_call(self, callee: Node) -> Node:
        tok = self.current()
        self.expect(TokenType.LPAREN, "Expected '(' to start function call")
        args = []

        # Special case: retype(type_name) — type name would be misread as cast
        is_retype = (
            isinstance(callee, MemberAccess) and
            callee.member == "retype"
        )

        if not self.check(TokenType.RPAREN):
            if is_retype:
                # consume type name as plain identifier, not cast expression
                type_tok = self.advance()
                ident = Identifier(name=type_tok.value)
                ident.line = type_tok.line
                ident.col = type_tok.column
                args.append(ident)
            else:
                args.append(self.parse_call_arg())
                while self.match(TokenType.COMMA):
                    args.append(self.parse_call_arg())

        self.expect(TokenType.RPAREN, "Expected ')' to close function call")
        node = FunctionCall(name=callee, args=args)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_call_arg(self) -> Node:
        tok = self.current()
        # Keyword argument: newLine=true, start=true, row=N, col=N etc.
        if self.check(TokenType.NEWLINE_ARG):
            target = Identifier(name=self.advance().value)
            self.expect(TokenType.ASSIGN, "Expected '=' after keyword arg")
            value = self.parse_expression()
            node = Assignment(target=target, value=value)
            node.line = tok.line
            node.col  = tok.column
            return node
        
        if self.check(TokenType.START_ARG):
            target = Identifier(name=self.advance().value)
            self.expect(TokenType.ASSIGN, "Expected '=' after keyword arg")
            value = self.parse_expression()
            node = Assignment(target=target, value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        # Generic named arg: identifier=value
        # Peek ahead — if current is IDENTIFIER and next is ASSIGN, it's a named arg
        if (self.check(TokenType.IDENTIFIER) and 
            self.peek(1).type == TokenType.ASSIGN):
            target = Identifier(name=self.advance().value)
            self.expect(TokenType.ASSIGN, "Expected '='")
            value = self.parse_expression()
            node = Assignment(target=target, value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        return self.parse_expression()

    def parse_primary(self) -> Node:
        """
        The highest-precedence things:
        literals, identifiers, type casts, grouped expressions,
        ok(), error(), await, lambda
        """
        tok = self.current()  # capture 'var' token before consuming
        # Literals
        if self.check(TokenType.INT_LIT, TokenType.FLOAT_LIT,
                      TokenType.COMPLEX_LIT,
                      TokenType.BOOL_LIT, TokenType.NULL):
            return self.parse_literal()
        
        # Dict literal: {} or {"key": val, ...}
        if self.check(TokenType.LBRACE):
            self.advance()
            pairs = []
            if not self.check(TokenType.RBRACE):
                # Parse first pair
                key = self.parse_expression()
                self.expect(TokenType.COLON, "Expected ':' after dict key")
                value = self.parse_expression()
                pairs.append((key, value))
                # Parse remaining pairs
                while self.match(TokenType.COMMA):
                    if self.check(TokenType.RBRACE):
                        break  # trailing comma allowed!
                    key = self.parse_expression()
                    self.expect(TokenType.COLON, "Expected ':' after dict key")
                    value = self.parse_expression()
                    pairs.append((key, value))
            self.expect(TokenType.RBRACE, "Expected '}' to close dict literal")
            node = DictLiteral(pairs=pairs)
            node.line = tok.line
            node.col  = tok.column
            return node
        
        # Lib qualified call: "mocha-math".sin(45.0)
        if self.check(TokenType.STR_LIT):
            # Peek ahead to see if followed by .
            if self.peek(1).type == TokenType.DOT and self.peek(0).value.startswith("mocha-"):
                source = self.advance().value  # consume "mocha-math"
                self.advance()                 # consume .
                method = self.expect(TokenType.IDENTIFIER, "Expected function name after '.'").value
                self.expect(TokenType.LPAREN, "Expected '(' after function name")
                args = []
                if not self.check(TokenType.RPAREN):
                    args.append(self.parse_call_arg())
                    while self.match(TokenType.COMMA):
                        args.append(self.parse_call_arg())
                self.expect(TokenType.RPAREN, "Expected ')' after arguments")
                node = LibQualifiedCall(source=source, method=method, args=args)
                node.line = tok.line
                node.col  = tok.column
                return node
            # Otherwise fall through to normal string literal
            return self.parse_literal()
        
        # Set literal: <1, 2, 3> or <>
        if self.check(TokenType.LT):
            self.advance()
            elements = []
            if not self.check(TokenType.GT):
                elements.append(self.parse_primary())
                while self.match(TokenType.COMMA):
                    if self.check(TokenType.GT):
                        break  # trailing comma allowed
                    elements.append(self.parse_primary())
            self.expect(TokenType.GT, "Expected '>' to close set literal")
            node = SetLiteral(elements=elements)
            node.line = tok.line
            node.col  = tok.column
            return node
        
        # Type cast: int(x), str(42), float(n)
        if self.check(*self.TYPE_TOKENS.keys()):
            type_name = self.TYPE_TOKENS[self.current().type]
            self.advance()
            self.expect(TokenType.LPAREN, f"Expected '(' after type cast '{type_name}'")
            value = self.parse_expression()
            self.expect(TokenType.RPAREN, "Expected ')' to close type cast")
            node = TypeCast(to_type=type_name, value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        # ok(value) and error(value) - Result constructors
        if self.check(TokenType.OK):
            self.advance()
            self.expect(TokenType.LPAREN, "Expected '(' after 'ok'")
            value = self.parse_expression()
            self.expect(TokenType.RPAREN, "Expected ')' to close 'ok'")
            node = OkExpr(value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        if self.check(TokenType.ERROR):
            self.advance()
            self.expect(TokenType.LPAREN, "Expected '(' after 'error'")
            value = self.parse_expression()
            self.expect(TokenType.RPAREN, "Expected ')' to close 'error'")
            node = ErrorExpr(value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        # await expression
        if self.check(TokenType.AWAIT):
            self.advance()
            value = self.parse_expression()
            node = AwaitExpr(value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        # alloc int[n] — dynamic array allocation
        if self.check(TokenType.ALLOC):
            self.advance()
            # Allow primitive types AND class names (identifiers)
            if self.check(*self.TYPE_TOKENS.keys()):
                elem_type = self.TYPE_TOKENS[self.current().type]
                self.advance()
            elif self.check(TokenType.IDENTIFIER):
                elem_type = self.advance().value
            else:
                raise MochaParseError("Expected type after 'alloc'", self.current())
            self.expect(TokenType.LBRACKET, "Expected '[' after type in alloc")
            size_expr = self.parse_expression()
            self.expect(TokenType.RBRACKET, "Expected ']'")
            size_expr2 = None
            if self.check(TokenType.LBRACKET):
                self.advance()
                size_expr2 = self.parse_expression()
                self.expect(TokenType.RBRACKET, "Expected ']'")
            node = AllocArray(elem_type=elem_type, size_expr=size_expr, size_expr2=size_expr2)
            node.line = tok.line
            node.col  = tok.column
            return node

        # lambda (x: int) -> int: x * 2
        if self.check(TokenType.LAMBDA):
            return self.parse_lambda()

        # this
        if self.check(TokenType.THIS):
            self.advance()
            node = Identifier(name="this")
            node.line = tok.line
            node.col  = tok.column
            return node

        # Identifier or function call
        if self.check(TokenType.IDENTIFIER, TokenType.PRINT, TokenType.CONST_IDENT):
            name = self.advance().value
            node = Identifier(name=name)
            node.line = tok.line
            node.col  = tok.column
            return node
        
        # Array literal: [1, 2, 3] or List Comprehension.
        if self.check(TokenType.LBRACKET):
            self.advance()
            
            if self.check(TokenType.RBRACKET):
                # Empty array []
                self.advance()
                node = ArrayLiteral(elements=[])
                node.line = tok.line
                node.col  = tok.column
                return node
            
            # Parse first expression
            first_expr = self.parse_expression()
            
            # Check if it's a list comprehension
            if self.check(TokenType.IF) or self.check(TokenType.FOR):
                condition = None
                else_expr = None
                if self.match(TokenType.IF):
                    condition = self.parse_expression()
                    # NEW — check for else branch
                    if self.match(TokenType.ELSE):
                        else_expr = self.parse_expression()
                
                self.expect(TokenType.FOR, "Expected 'for' in list comprehension")
                self.expect(TokenType.EACH, "Expected 'each' after 'for'")
                var_name = self.expect(TokenType.IDENTIFIER, "Expected variable name").value
                self.expect(TokenType.IN, "Expected 'in' after variable")
                iterable = self.parse_expression()
                self.expect(TokenType.RBRACKET, "Expected ']' to close comprehension")
                
                node = ListComprehension(
                    expr=first_expr,
                    var_name=var_name,
                    iterable=iterable,
                    condition=condition,
                    else_expr=else_expr,
                    elem_type=""
                )
                node.line = tok.line
                node.col  = tok.column
                return node
            
            # Otherwise it's a normal array literal
            elements = [first_expr]
            while self.match(TokenType.COMMA):
                elements.append(self.parse_expression())
            self.expect(TokenType.RBRACKET, "Expected ']' to close array literal")
            node = ArrayLiteral(elements=elements)
            node.line = tok.line
            node.col  = tok.column
            return node

        #(_)
        if self.check(TokenType.LPAREN):
            self.advance()
            first = self.parse_expression()
            
            # Tuple literal: (1, 2, 3)
            if self.check(TokenType.COMMA):
                elements = [first]
                while self.match(TokenType.COMMA):
                    elements.append(self.parse_expression())
                self.expect(TokenType.RPAREN, "Expected ')' to close tuple")
                node = TupleLiteral(elements=elements)
                node.line = tok.line
                node.col  = tok.column
                return node
            
            # Grouped expression: (a + b)
            self.expect(TokenType.RPAREN, "Expected ')' to close grouped expression")
            return first

        raise MochaParseError(
            "Expected an expression (literal, variable, function call, cast, or grouped expression with '(')",
            self.current()
        )

    def parse_lambda(self) -> Node:
        """
        lambda (x: int, y: int) -> int: x + y
        """
        tok = self.current()
        self.expect(TokenType.LAMBDA, "Expected 'lambda'")
        self.expect(TokenType.LPAREN, "Expected '(' after 'lambda'")

        params = []
        if not self.check(TokenType.RPAREN):
            params.append(self.parse_param())
            while self.match(TokenType.COMMA):
                params.append(self.parse_param())

        self.expect(TokenType.RPAREN, "Expected ')' to close lambda params")
        self.expect(TokenType.ARROW,  "Expected '->' after lambda params")
        return_type = self.parse_type()
        self.expect(TokenType.COLON,  "Expected ':' before lambda body")
        body = self.parse_expression()

        node = LambdaExpr(params=params, return_type=return_type, body=body)
        node.line = tok.line
        node.col  = tok.column
        return node

    # -------------------------------------------------------
    # STEP 4: Statements
    # -------------------------------------------------------

    def parse_statement(self) -> Node:
        """
        Decides which kind of statement we're looking at
        and calls the right parse method.
        """
        tok = self.current()  # capture 'var' token before consuming

        # var declaration
        if self.check(TokenType.VAR):
            return self.parse_var_decl()

        # const declaration
        if self.check(TokenType.CONST):
            return self.parse_const_decl()

        # return
        if self.check(TokenType.RETURN):
            return self.parse_return()

        # if
        if self.check(TokenType.IF):
            return self.parse_if()

        # while
        if self.check(TokenType.WHILE):
            return self.parse_while()

        # do-while
        if self.check(TokenType.DO):
            return self.parse_do_while()

        # for / for-each
        if self.check(TokenType.FOR):
            return self.parse_for()

        # match
        if self.check(TokenType.MATCH):
            return self.parse_match()

        # break
        if self.check(TokenType.BREAK):
            self.advance()
            self.expect(TokenType.SEMICOLON, "Expected ';' after 'break'")
            node = BreakStmt()
            node.line = tok.line
            node.col  = tok.column
            return node

        # continue
        if self.check(TokenType.CONTINUE):
            self.advance()
            self.expect(TokenType.SEMICOLON, "Expected ';' after 'continue'")
            node = ContinueStmt()
            node.line = tok.line
            node.col  = tok.column
            return node

        # try/rescue
        if self.check(TokenType.TRY):
            return self.parse_try_rescue()

        # fail
        if self.check(TokenType.FAIL):
            return self.parse_fail()

        # rescue bare rethrow (inside rescue block)
        if self.check(TokenType.RETHROW):
            tok = self.current()
            self.advance()
            self.expect(TokenType.SEMICOLON, "Expected ';' after 'rethrow'")
            node = RethrowStmt()
            node.line = tok.line
            node.col  = tok.column
            return node

        # expression statement (assignment, function call, increment etc.)
        return self.parse_expression_statement()

    def parse_expression_statement(self) -> Node:
        """
        An expression used as a statement.
        Handles assignments, compound assignments, and bare expressions.
        e.g. x = 5;  i += 1;  add(1, 2);  i++;
        """
        tok = self.current()  # capture 'var' token before consuming
        expr = self.parse_expression()

        # Simple assignment: x = 5
        if self.check(TokenType.ASSIGN):
            if not isinstance(expr, (Identifier, IndexAccess, Index2DAccess, MemberAccess)):
                tok = self.current()
                # Simple assignment
                raise MochaParseError(
                    f"Invalid assignment target '{expr.__class__.__name__}' — "
                    "only variables, index accesses, and member accesses can be assigned to",
                    tok
                )
            self.advance()
            value = self.parse_expression()
            self.expect(TokenType.SEMICOLON, "Expected ';' after assignment")
            node = Assignment(target=expr, value=value)
            node.line = tok.line
            node.col  = tok.column
            return node

        # Compound assignment: x += 5
        if self.check(*self.COMPOUND_OPS.keys()):
            if not isinstance(expr, (Identifier, IndexAccess, Index2DAccess, MemberAccess)):
                tok = self.current()
                # Compound assignment
                raise MochaParseError(
                    f"Invalid compound assignment target '{expr.__class__.__name__}' — "
                    "only variables, index accesses, and member accesses can be used with +=, -=, etc.",
                    tok
                )
            op = self.COMPOUND_OPS[self.current().type]
            self.advance()
            value = self.parse_expression()
            self.expect(TokenType.SEMICOLON,
                        f"Expected ';' after compound assignment")
            node = CompoundAssignment(target=expr, op=op, value=value)
            node.line = tok.line
            node.col  = tok.column
            return node
        
        # Bare expression (function call, i++, etc.)
        self.expect(TokenType.SEMICOLON, "Expected ';' after expression")
        return expr

    def parse_var_decl(self) -> Node:
        """
        var x: int = 5;
        var s: set<int>;  // empty set, no initializer needed
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.VAR, "Expected 'var'")
        name = self.expect(TokenType.IDENTIFIER,
                           "Expected variable name").value
        self.expect(TokenType.COLON, "Expected ':' after variable name")
        type_ = self.parse_type()

        # Sets can be declared without initializer
        if type_.startswith("set<") and self.check(TokenType.SEMICOLON):
            self.advance()  # consume ';'
            return VarDecl(name=name, type=type_, value=SetLiteral(elements=[]))

        self.expect(TokenType.ASSIGN,
                    "Expected '=' after type in variable declaration")
        value = self.parse_expression()
        self.expect(TokenType.SEMICOLON,
                    "Expected ';' after variable declaration")
        node = VarDecl(name=name, type=type_, value=value)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_const_decl(self) -> Node:
        """
        const MAX_SIZE: int = 100;
        Name MUST be SCREAMING_CASE - enforced here!
        """
        self.expect(TokenType.CONST, "Expected 'const'")
        tok = self.current()

        # Enforce SCREAMING_CASE at parse time!
        if tok.type != TokenType.CONST_IDENT:
            raise MochaParseError(
                "Constant names must be SCREAMING_CASE "
                f"e.g. '{tok.value.upper()}' not '{tok.value}'",
                tok
            )

        name = self.advance().value
        self.expect(TokenType.COLON, 
                "Expected ':' after constant name — did you forget the type ? "
                f"e.g. 'const {name}: int = 9'"
            )
        type_ = self.parse_type()
        self.expect(TokenType.ASSIGN,
                    "Expected '=' after type in constant declaration")
        value = self.parse_expression()
        self.expect(TokenType.SEMICOLON,
                    "Expected ';' after constant declaration")
        node = ConstDecl(name=name, type=type_, value=value)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_return(self) -> Node:
        """
        return a + b;
        return;          (null return)
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.RETURN, "Expected 'return'")

        # Bare return with no value
        if self.check(TokenType.SEMICOLON):
            self.advance()
            return ReturnStmt(value=None)

        value = self.parse_expression()
        self.expect(TokenType.SEMICOLON, "Expected ';' after return value")
        node = ReturnStmt(value=value)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_block(self) -> list:
        """
        Parses a { ... } block and returns list of statements.
        Used by functions, if, while, for etc.
        """
        self.expect(TokenType.LBRACE, "Expected '{' to open block")
        statements = []
        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            statements.append(self.parse_statement())
        self.expect(TokenType.RBRACE, "Expected '}' to close block")
        return statements

    def parse_if(self) -> Node:
        """
        if (condition) { } else if (condition) { } else { };
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.IF, "Expected 'if'")
        self.expect(TokenType.LPAREN, "Expected '(' after 'if'")
        condition = self.parse_expression()
        self.expect(TokenType.RPAREN, "Expected ')' after if condition")
        then_body = self.parse_block()

        else_ifs  = []
        else_body = None

        while self.check(TokenType.ELSE):
            self.advance()
            if self.check(TokenType.IF):
                # else if branch
                self.advance()
                self.expect(TokenType.LPAREN, "Expected '(' after 'else if'")
                elif_condition = self.parse_expression()
                self.expect(TokenType.RPAREN,
                            "Expected ')' after else if condition")
                elif_body = self.parse_block()
                else_ifs.append((elif_condition, elif_body))
            else:
                # final else branch
                else_body = self.parse_block()
                break

        self.expect(TokenType.SEMICOLON, "Expected ';' after if statement")
        node = IfStmt(condition=condition, then_body=then_body,
                      else_ifs=else_ifs, else_body=else_body)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_while(self) -> Node:
        """
        while (condition) { };
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.WHILE, "Expected 'while'")
        self.expect(TokenType.LPAREN, "Expected '(' after 'while'")
        condition = self.parse_expression()
        self.expect(TokenType.RPAREN, "Expected ')' after while condition")
        body = self.parse_block()
        self.expect(TokenType.SEMICOLON, "Expected ';' after while loop")
        node = WhileLoop(condition=condition, body=body)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_do_while(self) -> Node:
        """
        do { } while (condition);
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.DO, "Expected 'do'")
        body = self.parse_block()
        self.expect(TokenType.WHILE,  "Expected 'while' after do block")
        self.expect(TokenType.LPAREN, "Expected '(' after 'while'")
        condition = self.parse_expression()
        self.expect(TokenType.RPAREN, "Expected ')' after do-while condition")
        self.expect(TokenType.SEMICOLON, "Expected ';' after do-while loop")
        node = DoWhileLoop(body=body, condition=condition)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_for(self) -> Node:
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.FOR, "Expected 'for'")
        
        # for each item in arr { };
        if self.check(TokenType.EACH):
            return self.parse_foreach()
        
        # Regular for loop
        self.expect(TokenType.LPAREN, "Expected '(' after 'for'")
        init = self.parse_var_decl()
        condition = self.parse_expression()
        self.expect(TokenType.SEMICOLON, "Expected ';' after for condition")
        step = self.parse_expression()
        self.expect(TokenType.RPAREN, "Expected ')' to close for loop header")
        body = self.parse_block()
        self.expect(TokenType.SEMICOLON, "Expected ';' after for loop")
        node = ForLoop(init=init, condition=condition, step=step, body=body)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_foreach(self) -> Node:
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.EACH, "Expected 'each' after 'for'")
        var_name = self.expect(TokenType.IDENTIFIER, "Expected variable name").value
        self.expect(TokenType.IN, "Expected 'in' after variable name")
        
        # Set iteration: for each x in <s> { }
        if self.check(TokenType.LT):
            self.advance()  # consume 
            set_expr = self.parse_addition()
            self.expect(TokenType.GT, "Expected '>' to close set iterable")
            iterable = SetIterable(set_expr=set_expr)
        else:
            iterable = self.parse_expression()
        
        body = self.parse_block()
        self.expect(TokenType.SEMICOLON, "Expected ';' after for-each loop")
        node = ForEachLoop(var_name=var_name, iterable=iterable, body=body)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_match(self) -> Node:
        """
        match(score) {
            case 100: return "Perfect!";
            case 90..99: return "Grade A";
            case x when x < 60: return "Grade F";
            default: return "Invalid";
        };
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.MATCH,  "Expected 'match'")
        self.expect(TokenType.LPAREN, "Expected '(' after 'match'")
        value = self.parse_expression()
        self.expect(TokenType.RPAREN, "Expected ')' after match value")
        self.expect(TokenType.LBRACE, "Expected '{' to open match block")

        cases = []
        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            cases.append(self.parse_case())

        self.expect(TokenType.RBRACE, "Expected '}' to close match block")
        self.expect(TokenType.SEMICOLON, "Expected ';' after match statement")
        node = MatchStmt(value=value, cases=cases)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_case(self) -> Node:
        """
        case 100: return "Perfect!";
        case 90..99: return "Grade A";
        case x when x < 60: return "Grade F";
        default: return "Invalid";
        """
        tok = self.current()  # capture 'var' token before consuming

        # Default case
        if self.check(TokenType.DEFAULT):
            self.advance()
            self.expect(TokenType.COLON, "Expected ':' after 'default'")
            body = []
            while not self.check(TokenType.CASE, TokenType.DEFAULT,
                                  TokenType.RBRACE):
                body.append(self.parse_statement())
            return CaseNode(pattern=None, condition=None,
                            body=body, is_default=True)

        self.expect(TokenType.CASE, "Expected 'case'")
        pattern   = None
        condition = None

        # case x when x < 60  (identifier with when condition)
        # case TokenType.INT_LIT  (member access pattern)
        if self.check(TokenType.IDENTIFIER) or self.check(TokenType.CONST_IDENT):
            name = self.advance().value
            pattern = Identifier(name=name)
            while self.check(TokenType.DOT):
                self.advance()
                if self.check(TokenType.IDENTIFIER) or self.check(TokenType.CONST_IDENT):
                    member = self.advance().value
                    pattern = MemberAccess(obj=pattern, member=member)
            if self.check(TokenType.WHEN):
                self.advance()
                condition = self.parse_expression()

        # case 90..99 or case 100
        else:
            start = self.parse_expression()
            if self.check(TokenType.RANGE):
                self.advance()
                end = self.parse_expression()
                pattern = RangeNode(start=start, end=end)
            else:
                pattern = start

        self.expect(TokenType.COLON, "Expected ':' after case pattern")

        body = []
        while not self.check(TokenType.CASE, TokenType.DEFAULT,
                              TokenType.RBRACE):
            body.append(self.parse_statement())

        node = CaseNode(pattern=pattern, condition=condition, body=body)
        node.line = tok.line
        node.col  = tok.column
        return node

    # -------------------------------------------------------
    # STEP 5: Functions
    # -------------------------------------------------------

    def collect_doc(self) -> list:
        """Collect any preceding DOC_COMMENT tokens."""
        lines = []
        while self.check(TokenType.DOC_COMMENT):
            lines.append(self.advance().value)
        return lines or None # type: ignore

    def parse_param(self) -> Param:
        """
        Parses a single function parameter: name: type
        optional: must name: type
        optional: name: type = default
        """
        if self.check(TokenType.DID_LOAD):
            raise MochaParseError(
                "'didLoad' must be the first parameter, not a positional one. "
                "If marking this as the entry point, write: function main(didLoad, ...) -> type",
                self.current()
            )
        
        tok = self.current()
        
        is_required = False
        
        name = self.expect(TokenType.IDENTIFIER,
                           "Expected parameter name").value
        self.expect(TokenType.COLON, "Expected ':' after parameter name")
        type_ = self.parse_type()
        
        default = None
        if self.match(TokenType.ASSIGN):
            default = self.parse_expression()
        
        node = Param(name=name, type=type_, is_required=is_required, default=default) # type: ignore
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_function(self, visibility="public",
                   is_shared=False, is_async=False, doc=None) -> Node:
        """
        function add(a: int, b: int) -> int { ... };
        async function fetch(url: str) -> Result { ... };
        function main(didLoad, name: str) -> null { ... };
        function printf(fmt: str, +) -> int native printf;
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.FUNCTION, "Expected 'function'")
        name = self.expect(TokenType.IDENTIFIER,
                           "Expected function name").value

        self.expect(TokenType.LPAREN, "Expected '(' after function name")

        params      = []
        has_didLoad = False
        is_variadic = False

        # Check for didLoad as first param (entry point marker)
        if self.check(TokenType.DID_LOAD):
            has_didLoad = True
            self.advance()
            if self.check(TokenType.COMMA):
                self.advance()

        # Parse remaining params
        if not self.check(TokenType.RPAREN):
            # Check for lone + (variadic marker — no regular params before it)
            if self.check(TokenType.PLUS):
                self.advance()  # consume +
                is_variadic = True
            else:
                params.append(self.parse_param())
                while self.match(TokenType.COMMA):
                    # Check for + after comma — variadic must be last param
                    if self.check(TokenType.PLUS):
                        self.advance()  # consume +
                        is_variadic = True
                        break
                    params.append(self.parse_param())

        self.expect(TokenType.RPAREN, "Expected ')' to close parameter list")

        # Return type: -> int  (defaults to null if omitted)
        return_type = "null"
        if self.match(TokenType.ARROW):
            return_type = self.parse_type()

        # Native function — body is a C implementation
        # function sin(x: float, mes: int) -> float native mocha_math_sin;
        # function printf(fmt: str, +) -> int native printf;
        is_native   = False
        native_name = None
        if self.check(TokenType.NATIVE):
            self.advance()  # consume 'native'
            native_name = self.expect(TokenType.IDENTIFIER,
                                      "Expected C function name after 'native'").value
            is_native = True
            self.expect(TokenType.SEMICOLON, "Expected ';' after native function")
            node = FunctionDecl(
                name=name,
                params=params,
                return_type=return_type,
                body=[],
                is_async=is_async,
                has_didLoad=has_didLoad,
                is_native=True,
                native_name=native_name,
                is_variadic=is_variadic,
                doc=doc # type: ignore
            )
            node.line = tok.line
            node.col  = tok.column
            return node

        body = self.parse_block()
        self.expect(TokenType.SEMICOLON, "Expected ';' after function")

        # Return MethodDecl if inside a class, FunctionDecl otherwise
        if is_shared or visibility != "public":
            node = MethodDecl(
                name=name,
                params=params,
                return_type=return_type,
                body=body,
                visibility=visibility,
                is_shared=is_shared,
                is_async=is_async,
                doc=doc #type:ignore
            )
            node.line = tok.line
            node.col  = tok.column
            return node

        node = FunctionDecl(
            name=name,
            params=params,
            return_type=return_type,
            body=body,
            is_async=is_async,
            has_didLoad=has_didLoad,
            is_variadic=is_variadic,
            doc =doc #type:ignore
        )
        node.line = tok.line
        node.col  = tok.column
        return node
    
    def parse_extend(self) -> Node:
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.EXTEND, "Expected 'extend'")
        
        # Reuse parse_type() — handles primitives, arrays, class names, all of it!
        type_name = self.parse_type()

        self.expect(TokenType.LBRACE, "Expected '{' after type name")
        
        body = []
        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            if self.check(TokenType.FUNCTION):
                body.append(self.parse_function())
            else:
                raise MochaParseError(
                    f"Only function declarations are currently supported in extend blocks, got '{self.current().value}'",
                    self.current()
                )
        
        self.expect(TokenType.RBRACE, "Expected '}' to close extend block")
        self.expect(TokenType.SEMICOLON, "Expected ';' after extend block")
        
        node = ExtendDecl(type_name=type_name, body=body)
        node.line = tok.line
        node.col  = tok.column
        return node

    # -------------------------------------------------------
    # STEP 6: Classes and Interfaces
    # -------------------------------------------------------

    def parse_class_member(self) -> Node:
        """
        Parses one member inside a class body:
        - field:  var name: str;  or  private var age: int;
        - method: function speak() -> str { }
        - shared method: shared function create() -> Animal { }
        """
        tok = self.current()  # capture 'var' token before consuming
        doc = self.collect_doc()
        visibility = "public"
        is_shared  = False
        is_async   = False

        # Visibility modifier
        if self.check(TokenType.PRIVATE):
            visibility = "private"
            self.advance()
        elif self.check(TokenType.PROTECTED):
            visibility = "protected"
            self.advance()

        # Shared modifier
        if self.check(TokenType.SHARED):
            is_shared = True
            self.advance()

        # Async modifier
        if self.check(TokenType.ASYNC):
            is_async = True
            self.advance()

        # Method
        if self.check(TokenType.FUNCTION):
            method = self.parse_function(
                visibility=visibility,
                is_shared=is_shared,
                is_async=is_async,
                doc=doc
            )
            # Always return as MethodDecl inside a class
            if isinstance(method, FunctionDecl):
                node = MethodDecl(
                    name=method.name,
                    params=method.params,
                    return_type=method.return_type,
                    body=method.body,
                    visibility=visibility,
                    is_shared=is_shared,
                    is_async=is_async,
                    has_didLoad=method.has_didLoad,
                    doc=doc
                )
                node.line = tok.line
                node.col = tok.column
                return node
            return method

        # Field: var name: str;
        if self.check(TokenType.VAR):
            self.advance()
            name = self.expect(TokenType.IDENTIFIER,
                               "Expected field name").value
            self.expect(TokenType.COLON, "Expected ':' after field name")
            type_ = self.parse_type()

            # Optional default value
            value = None
            if self.match(TokenType.ASSIGN):
                value = self.parse_expression()

            self.expect(TokenType.SEMICOLON, "Expected ';' after field")
            node = FieldDecl(name=name, type=type_,
                    visibility=visibility, value=value, is_shared=is_shared)
            node.line = tok.line
            node.col = tok.column
            return node

        raise MochaParseError(
            "Expected a field or method declaration", self.current()
        )

    def parse_class(self, doc=None) -> Node:
        """
        class Dog extends Animal implements Swimmable { ... };
        class Pegasus extends Bird, Horse implements Flyable { ... };
        """
        tok = self.current()  # capture 'var' token before consuming
        #doc = self.collect_doc()
        self.expect(TokenType.CLASS, "Expected 'class'")
        name = self.expect(TokenType.IDENTIFIER,
                           "Expected class name").value

        parents    = []
        interfaces = []

        # extends Parent1, Parent2, ...
        if self.match(TokenType.EXTENDS):
            parents.append(self.expect(TokenType.IDENTIFIER,
                                 "Expected parent class name").value)
            while self.match(TokenType.COMMA):
                parents.append(self.expect(TokenType.IDENTIFIER,
                                 "Expected parent class name").value)

        # implements Interface1, Interface2
        if self.match(TokenType.IMPLEMENTS):
            interfaces.append(
                self.expect(TokenType.IDENTIFIER,
                            "Expected interface name").value
            )
            while self.match(TokenType.COMMA):
                interfaces.append(
                    self.expect(TokenType.IDENTIFIER,
                                "Expected interface name").value
                )

        self.expect(TokenType.LBRACE, "Expected '{' to open class body")
        body = []
        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            body.append(self.parse_class_member())
        self.expect(TokenType.RBRACE, "Expected '}' to close class body")
        self.expect(TokenType.SEMICOLON, "Expected ';' after class")

        node = ClassDecl(name=name, parents=parents,
                         interfaces=interfaces, body=body, doc=doc) # type: ignore
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_interface(self) -> Node:
        """
        interface Swimmable {
            function swim() -> null;
        };
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.INTERFACE, "Expected 'interface'")
        name = self.expect(TokenType.IDENTIFIER,
                           "Expected interface name").value
        self.expect(TokenType.LBRACE, "Expected '{' to open interface body")

        methods = []
        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            self.expect(TokenType.FUNCTION,
                        "Expected 'function' in interface")
            method_name = self.expect(TokenType.IDENTIFIER,
                                      "Expected method name").value
            self.expect(TokenType.LPAREN, "Expected '('")

            params = []
            if not self.check(TokenType.RPAREN):
                params.append(self.parse_param())
                while self.match(TokenType.COMMA):
                    params.append(self.parse_param())

            self.expect(TokenType.RPAREN, "Expected ')'")

            return_type = "null"
            if self.match(TokenType.ARROW):
                return_type = self.parse_type()

            self.expect(TokenType.SEMICOLON,
                        "Expected ';' after interface method signature")
            methods.append(InterfaceMethod(
                name=method_name,
                params=params,
                return_type=return_type
            ))

        self.expect(TokenType.RBRACE, "Expected '}' to close interface")
        self.expect(TokenType.SEMICOLON, "Expected ';' after interface")
        node = InterfaceDecl(name=name, methods=methods)
        node.line = tok.line
        node.col  = tok.column
        return node

    # -------------------------------------------------------
    # STEP 7: Imports
    # -------------------------------------------------------

    def parse_import(self) -> Node:
        """
        import MochaMath from "mocha-math" as mm;
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.IMPORT, "Expected 'import'")
        module = self.expect(TokenType.IDENTIFIER,
                             "Expected module name").value
        self.expect(TokenType.FROM,   "Expected 'from' after module name")
        source = self.expect(TokenType.STR_LIT,
                             "Expected source path string").value

        alias = None
        if self.match(TokenType.AS):
            alias = self.expect(TokenType.IDENTIFIER,
                                "Expected alias name").value

        self.expect(TokenType.SEMICOLON, "Expected ';' after import")
        node = ImportStmt(module=module, source=source, alias=alias, imports=None)
        node.line = tok.line
        node.col  = tok.column
        return node
    
    def parse_from_import(self) -> Node:
        """
        from "mocha-math" import sin_deg(), cos_deg(), PI;
        from "mocha-math" import *;
        """
        tok = self.current()  # capture 'var' token before consuming
        self.expect(TokenType.FROM, "Expected 'from'")
        source = self.expect(TokenType.STR_LIT, "Expected source path string").value
        self.expect(TokenType.IMPORT, "Expected 'import' after source")

        imports = []

        # Wildcard
        if self.match(TokenType.STAR):
            imports = ["*"]
        else:
            # Parse specific imports: sin_deg(), PI, cos_deg()
            if self.check(TokenType.IDENTIFIER) or self.check(TokenType.CONST_IDENT):
                name = self.advance().value
            else:
                raise MochaParseError("Expected function or constant name", self.current())
            if self.match(TokenType.LPAREN):
                self.expect(TokenType.RPAREN, "Expected ')' after function name")
            imports.append(name)

            while self.match(TokenType.COMMA):
                if self.check(TokenType.IDENTIFIER) or self.check(TokenType.CONST_IDENT):
                    name = self.advance().value
                else:
                    raise MochaParseError("Expected function or constant name", self.current())
                if self.match(TokenType.LPAREN):
                    self.expect(TokenType.RPAREN, "Expected ')' after function name")
                imports.append(name)

        self.expect(TokenType.SEMICOLON, "Expected ';' after import")
        node = ImportStmt(module="", source=source, alias=None, imports=imports)
        node.line = tok.line
        node.col  = tok.column
        return node
    
    def parse_tag(self) -> Node:
        """
        tag TokenType {
            IDENTIFIER,
            INT_LIT,
            PLUS,
        };
        """
        self.expect(TokenType.TAG, "Expected 'tag'")
        name = self.expect(TokenType.IDENTIFIER, "Expected tag name").value

        self.expect(TokenType.LBRACE, "Expected '{' to open tag body")
        members = []

        while not self.check(TokenType.RBRACE) and not self.is_at_end():
            tok = self.current()
            # Enforce SCREAMING_CASE like const
            if tok.type != TokenType.CONST_IDENT:
                raise MochaParseError(
                    f"Tag members must be SCREAMING_CASE. "
                    f"Use '{tok.value.upper()}' not '{tok.value}'",
                    tok
                )
            members.append(self.advance().value)
            self.match(TokenType.COMMA)  # trailing comma allowed

        self.expect(TokenType.RBRACE, "Expected '}' to close tag body")
        self.expect(TokenType.SEMICOLON, "Expected ';' after tag")
        return TagDecl(name=name, members=members)

    # ---------- Exception Handling ----------- #
        
    def parse_try_rescue(self) -> Node:
        """
        try { } rescue, e { };   -- with binding
        try { } rescue { };      -- without binding
        """
        tok = self.current()
        self.expect(TokenType.TRY, "Expected 'try'")
        try_body = self.parse_block()

        self.expect(TokenType.RESCUE, "Expected 'rescue' after try block")

        # optional binding: rescue, e
        binding = None
        if self.check(TokenType.COMMA):
            self.advance()
            binding = self.expect(TokenType.IDENTIFIER, "Expected binding name after ','").value

        rescue_body = self.parse_block()
        self.expect(TokenType.SEMICOLON, "Expected ';' after try/rescue")

        node = TryRescue(try_body=try_body, rescue_body=rescue_body, binding=binding)
        node.line = tok.line
        node.col  = tok.column
        return node

    def parse_fail(self) -> Node:
        """
        fail "message";
        fail some_str_expr;
        """
        tok = self.current()
        self.expect(TokenType.FAIL, "Expected 'fail'")
        message = self.parse_expression()
        self.expect(TokenType.SEMICOLON, "Expected ';' after 'fail'")

        node = FailStmt(message=message)
        node.line = tok.line
        node.col  = tok.column
        return node

    # -------------------------------------------------------
    # STEP 8: Top-level parse - the entry point!
    # -------------------------------------------------------

    def synchronize(self):
        depth = 0
        while not self.is_at_end():
            tok = self.current()

            if tok.type == TokenType.LBRACE:
                depth += 1
                self.advance()
                continue

            if tok.type == TokenType.RBRACE:
                if depth > 0:
                    depth -= 1
                    self.advance()
                    continue
                else:
                    # We're back at the top level — consume it and return
                    self.advance()
                    return

            if tok.type == TokenType.SEMICOLON and depth == 0:
                self.advance()
                return

            if depth == 0 and (
                self.check(TokenType.FUNCTION) or
                self.check(TokenType.CLASS) or
                self.check(TokenType.INTERFACE) or
                self.check(TokenType.IMPORT) or
                self.check(TokenType.FROM)
            ):
                return

            self.advance()

    def parse(self) -> Program:
        statements = []
        errors = []

        while not self.is_at_end():
            try:
                doc = self.collect_doc()
                if self.check(TokenType.IMPORT):
                    statements.append(self.parse_import())
                elif self.check(TokenType.FROM):
                    statements.append(self.parse_from_import())
                elif self.check(TokenType.CLASS):
                    statements.append(self.parse_class(doc=doc))
                elif self.check(TokenType.INTERFACE):
                    statements.append(self.parse_interface())
                elif self.check(TokenType.ASYNC):
                    self.advance()
                    func = self.parse_function(is_async=True, doc=doc)
                    statements.append(func)
                elif self.check(TokenType.FUNCTION):
                    statements.append(self.parse_function(doc=doc))
                elif self.check(TokenType.EXTEND):
                    statements.append(self.parse_extend())
                elif self.check(TokenType.TAG):
                    statements.append(self.parse_tag())
                else:
                    statements.append(self.parse_statement())

            except MochaParseError as e:
                errors.append(e)
                self.synchronize()

        if errors:
            for e in errors:
                print(e)
            sys.exit(1)

        return Program(statements=statements)