# ============================================================
# Mocha AST Nodes
# ============================================================

from dataclasses import dataclass, field
from typing import Optional

# --- Base Class ---
class Node:
    line: int = 0
    col:  int = 0

# --- Literals ---
@dataclass
class IntLiteral(Node):
    value: int

@dataclass
class FloatLiteral(Node):
    value: float

@dataclass
class ComplexLiteral(Node):
    real: float
    imag: float

@dataclass
class StrLiteral(Node):
    value: str

@dataclass
class BoolLiteral(Node):
    value: bool

@dataclass
class NullLiteral(Node):
    pass

@dataclass
class DictLiteral(Node):
    pairs: list  # list of (key_node, value_node) tuples

# --- Identifier ---
@dataclass
class Identifier(Node):
    name: str

# --- Member Access: this.name or obj.field ---
@dataclass
class MemberAccess(Node):
    obj:    Node
    member: str

# --- Binary Operation ---
@dataclass
class BinaryOp(Node):
    left:  Node
    op:    str
    right: Node
    inferred_type: str = None # type: ignore
    op_kind: str = None #type: ignore

# --- Unary Operation ---
@dataclass
class UnaryOp(Node):
    op:    str
    right: Node

# --- Post Increment/Decrement: i++, i-- ---
@dataclass
class PostIncrement(Node):
    operand: Node
    op:      str        # "++" or "--"

# --- Pre Increment/Decrement: ++i, --i ---
@dataclass
class PreIncrement(Node):
    op:      str        # "++"
    operand: Node

@dataclass
class PreDecrement(Node):
    op:      str        # "--"
    operand: Node

# --- Type Cast: int(x), str(42) ---
@dataclass
class TypeCast(Node):
    to_type: str
    value:   Node

# --- Variable Declaration: var x: int = 5; ---
@dataclass
class VarDecl(Node):
    name:  str
    type:  str
    value: Node

# --- Constant Declaration: const MAX_SIZE: int = 100; ---
@dataclass
class ConstDecl(Node):
    name:  str
    type:  str
    value: Node

# --- Assignment: x = 5; ---
@dataclass
class Assignment(Node):
    target: Node
    value:  Node

# --- Compound Assignment: x += 5; ---
@dataclass
class CompoundAssignment(Node):
    target: Node
    op:     str         # "+=", "-=", "*=", "/="
    value:  Node

# --- Function Parameter ---
@dataclass
class Param(Node):
    name: str
    type: str

# --- Function Declaration ---
@dataclass
class FunctionDecl(Node):
    name:        str
    params:      list
    return_type: str
    body:        list
    is_async:    bool = False
    has_didLoad: bool = False
    is_native:   bool = False
    native_name: str  = "" # None
    is_variadic: bool = False

# --- Function Call: add(1, 2) ---
@dataclass
class FunctionCall(Node):
    name: Node          # can be Identifier or MemberAccess
    args: list

# --- Return Statement ---
@dataclass
class ReturnStmt(Node):
    value: Optional[Node]

# --- If Statement ---
@dataclass
class IfStmt(Node):
    condition:  Node
    then_body:  list
    else_ifs:   list        # list of (condition, body) tuples
    else_body:  Optional[list]

# --- While Loop ---
@dataclass
class WhileLoop(Node):
    condition: Node
    body:      list

# --- Do While Loop ---
@dataclass
class DoWhileLoop(Node):
    body:      list
    condition: Node

# --- For Loop ---
@dataclass
class ForLoop(Node):
    init:      Node
    condition: Node
    step:      Node
    body:      list

# --- For Each Loop ---
@dataclass
class ForEachLoop(Node):
    var_name:  str
    iterable:  Node
    body:      list
    var_type:  str = ""    # filled in by type checker

@dataclass
class SetIterable(Node):
    set_expr: Node  # the set being iterated

# --- Break / Continue ---
@dataclass
class BreakStmt(Node):
    pass

@dataclass
class ContinueStmt(Node):
    pass

# --- Range: 90..99 ---
@dataclass
class RangeNode(Node):
    start: Node
    end:   Node

# --- Match Statement ---
@dataclass
class MatchStmt(Node):
    value: Node
    cases: list

# --- Case Node ---
@dataclass
class CaseNode(Node):
    pattern:    Optional[Node]      # None if default
    condition:  Optional[Node]      # the "when x < 60" part
    body:       list
    is_default: bool = False

# --- Lambda ---
@dataclass
class LambdaExpr(Node):
    params:      list
    return_type: str
    body:        Node       # single expression

# --- Await Expression ---
@dataclass
class AwaitExpr(Node):
    value: Node

# --- Class Declaration ---
@dataclass
class ClassDecl(Node):
    name:       str
    parents:    list               #all parents for multiple inheritance. If only one, then single inh. parents[0] is used.
    interfaces: list
    body:       list

# --- Field Declaration ---
@dataclass
class FieldDecl(Node):
    name:       str
    type:       str
    visibility: str = "public"
    value:      Optional[Node] = None

# --- Method Declaration ---
@dataclass
class MethodDecl(Node):
    name:        str
    params:      list
    return_type: str
    body:        list
    visibility:  str  = "public"
    is_shared:   bool = False
    is_async:    bool = False
    has_didLoad: bool = False

@dataclass
class QualifiedMethodCall(Node):
    parent_class: str    # "Bird" — which parent's implementation to use
    obj:          str    # "p"   — the object variable
    method:       str    # "breathe" — method name
    args:         list   # call arguments

# --- Interface Declaration ---
@dataclass
class InterfaceDecl(Node):
    name:    str
    methods: list

# --- Interface Method Signature ---
@dataclass
class InterfaceMethod(Node):
    name:        str
    params:      list
    return_type: str

@dataclass
class ImportStmt(Node):
    module:   str            # module name (syntax 1) or empty string (syntax 2/3)
    source:   str            # "mocha-math"
    alias:    Optional[str]  # as mm (syntax 1 only)
    imports:  Optional[list] # ["sin_deg", "PI"] or ["*"] or None (syntax 1)

@dataclass
class LibQualifiedCall(Node):
    source:  str   # "mocha-math"
    method:  str   # sin
    args:    list

# --- Ok / Error Result ---
@dataclass
class OkExpr(Node):
    value: Node

@dataclass
class ErrorExpr(Node):
    value: Node

# --- Arrays ---
@dataclass
class ArrayLiteral(Node):
    elements: list  # list of expressions

@dataclass
class IndexAccess(Node):
    obj: Node       # the array
    index: Node     # the index expression

# 2D Arrays #
@dataclass
class Index2DAccess(Node):
    obj: Node        # the 2D array
    row: Node        # row index expression
    col: Node        # col index expression

@dataclass
class RowSlice(Node):
    obj: Node        # the 2D array
    row: Node        # row index — grid[0][]

@dataclass
class ColSlice(Node):
    obj: Node        # the 2D array
    col: Node        # col index — grid[][2]

# --- Tuples ---
@dataclass
class TupleLiteral(Node):
    elements: list  # list of expressions

@dataclass
class TupleAccess(Node):
    obj: Node       # the tuple
    index: int      # the index (0, 1, 2...)

@dataclass
class SetLiteral(Node):
    elements: list

@dataclass
class ExtendDecl(Node):
    type_name: str        # "str", "int", "float", "bool", or class name
    body:      list       # list of FunctionDecl nodes

@dataclass
class AllocArray(Node):
    elem_type: str    # "int", "float", "str", etc.
    size_expr: Node   # runtime expression for size
    size_expr2: Optional[Node] = None  # for 2D: alloc int[n][m]

@dataclass
class ListComprehension(Node):
    expr:      Node           # x*2
    var_name:  str            # "x"
    iterable:  Node           # nums
    condition: Optional[Node] # x>0, or None
    else_expr:     Optional[Node] # NEW — for "else" after if
    elem_type: str            # inferred element type
    src_elem_type: str = ""

@dataclass
class TagDecl(Node):
    name:    str
    members: list  # list of str, e.g. ["IDENTIFIER", "INT_LIT", "PLUS"]

@dataclass
class TagAccess(Node):
    tag_name:    str   # "TokenType"
    member_name: str   # "IDENTIFIER"

# --- Exception Handling ---
@dataclass
class TryRescue(Node):
    try_body:    list
    rescue_body: list
    binding:     Optional[str]   # 'e' in rescue, e — None if no binding

@dataclass
class FailStmt(Node):
    message: Node                # expression — must resolve to str

@dataclass
class RethrowStmt(Node):
    pass

# --- Program (root node) ---
@dataclass
class Program(Node):
    statements: list