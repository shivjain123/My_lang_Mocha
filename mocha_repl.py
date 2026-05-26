import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from mocha_lexer import Lexer
from mocha_parser import Parser
from mocha_ast import *

# ══════════════════════════════════════════
# ENVIRONMENT — persistent state
# ══════════════════════════════════════════

class Environment:
    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent

    def get(self, name):
        if name in self.vars:
            return self.vars[name]
        if self.parent:
            return self.parent.get(name)
        raise NameError(f"Undefined variable '{name}'")

    def set(self, name, value):
        self.vars[name] = value

    def assign(self, name, value):
        if name in self.vars:
            self.vars[name] = value
            return
        if self.parent:
            self.parent.assign(name, value)
            return
        raise NameError(f"Undefined variable '{name}'")

    def child(self):
        return Environment(parent=self)


# ══════════════════════════════════════════
# RETURN / BREAK / CONTINUE signals
# ══════════════════════════════════════════

class ReturnSignal(Exception):
    def __init__(self, value):
        self.value = value

class BreakSignal(Exception):
    pass

class ContinueSignal(Exception):
    pass


# ══════════════════════════════════════════
# EVALUATOR
# ══════════════════════════════════════════

class Evaluator:
    def __init__(self):
        self.functions = {}  # user-defined functions

    def eval(self, node, env):
        t = type(node).__name__

        if t == 'Program':
            result = None
            for stmt in node.statements:
                result = self.eval(stmt, env)
            return result

        elif t == 'IntLiteral':
            return int(node.value)

        elif t == 'FloatLiteral':
            return float(node.value)

        elif t == 'StrLiteral':
            return str(node.value)

        elif t == 'BoolLiteral':
            return bool(node.value)

        elif t == 'NullLiteral':
            return None

        elif t == 'Identifier':
            return env.get(node.name)

        elif t == 'BinaryOp':
            left = self.eval(node.left, env)
            right = self.eval(node.right, env)
            op = node.op
            if op == '+':   return left + right
            if op == '-':   return left - right
            if op == '*':   return left * right
            if op == '/':
                if right == 0:
                    raise ZeroDivisionError("Division by zero is prohibited in Mocha")
                return left / right
            if op == '%':   return left % right
            if op == '==':  return left == right
            if op == '!=':  return left != right
            if op == '<':   return left < right
            if op == '>':   return left > right
            if op == '<=':  return left <= right
            if op == '>=':  return left >= right
            if op == '&&':  return left and right
            if op == '||':  return left or right
            raise NotImplementedError(f"Unknown operator: {op}")

        elif t == 'UnaryOp':
            val = self.eval(node.right, env)
            if node.op == '-': return -val
            if node.op == '!': return not val
            return val

        elif t == 'PostIncrement':
            val = self.eval_lvalue_get(node.operand, env)
            if node.op == '++':
                new_val = val + 1 # type: ignore
            elif node.op == '--':
                new_val = val - 1 # type: ignore
            else:
                raise ValueError(f"Unknown postfix operator: {node.op}")
            self.eval_lvalue_set(node.operand, new_val, env)
            return val  # post: return old value

        elif t == 'PreIncrement':
            val = self.eval_lvalue_get(node.operand, env)
            new_val = val + 1 # type: ignore
            self.eval_lvalue_set(node.operand, new_val, env)
            return new_val  # pre: return new value
        
        elif t == 'PreDecrement':
            val = self.eval_lvalue_get(node.operand, env)
            new_val = val - 1 #type:ignore
            self.eval_lvalue_set(node.operand, new_val, env)
            return new_val

        elif t == 'TypeCast':
            val = self.eval(node.value, env)
            if node.to_type == 'int':   return int(val)
            if node.to_type == 'float': return float(val)
            if node.to_type == 'str':   return str(val)
            if node.to_type == 'bool':  return bool(val)
            return val

        elif t == 'VarDecl':
            val = self.eval(node.value, env) if node.value else None
            env.set(node.name, val)
            return None

        elif t == 'ConstDecl':
            val = self.eval(node.value, env)
            env.set(node.name, val)
            return None

        elif t == 'Assignment':
            val = self.eval(node.value, env)
            self.eval_lvalue_set(node.target, val, env)
            return val

        elif t == 'CompoundAssignment':
            current = self.eval_lvalue_get(node.target, env)
            val = self.eval(node.value, env)
            if node.op == '+=':   result = current + val
            elif node.op == '-=': result = current - val
            elif node.op == '*=': result = current * val
            elif node.op == '/=':
                if val == 0:
                    raise ZeroDivisionError("Division by zero is prohibited in Mocha")
                result = current / val
            else:
                result = val
            self.eval_lvalue_set(node.target, result, env)
            return result

        elif t == 'IfStmt':
            if self.eval(node.condition, env):
                child = env.child()
                for stmt in node.then_body:
                    self.eval(stmt, child)
            else:
                for elif_node in node.else_ifs:
                    if self.eval(elif_node.condition, env):
                        child = env.child()
                        for stmt in elif_node.then_body:
                            self.eval(stmt, child)
                        return None
                if node.else_body:
                    child = env.child()
                    for stmt in node.else_body:
                        self.eval(stmt, child)
            return None

        elif t == 'WhileLoop':
            while self.eval(node.condition, env):
                child = env.child()
                try:
                    for stmt in node.body:
                        self.eval(stmt, child)
                except BreakSignal:
                    break
                except ContinueSignal:
                    continue
            return None

        elif t == 'DoWhileLoop':
            while True:
                child = env.child()
                try:
                    for stmt in node.body:
                        self.eval(stmt, child)
                except BreakSignal:
                    break
                except ContinueSignal:
                    pass
                if not self.eval(node.condition, env):
                    break
            return None

        elif t == 'ForLoop':
            child = env.child()
            if node.init:
                self.eval(node.init, child)
            while True:
                if node.condition and not self.eval(node.condition, child):
                    break
                try:
                    for stmt in node.body:
                        self.eval(stmt, child)
                except BreakSignal:
                    break
                except ContinueSignal:
                    pass
                if node.step:
                    self.eval(node.step, child)
            return None

        elif t == 'ForEachLoop':
            iterable = self.eval(node.iterable, env)
            for item in iterable:
                child = env.child()
                child.set(node.var_name, item)
                try:
                    for stmt in node.body:
                        self.eval(stmt, child)
                except BreakSignal:
                    break
                except ContinueSignal:
                    continue
            return None

        elif t == 'FunctionDecl':
            self.functions[node.name] = node
            env.set(node.name, node)
            return None

        elif t == 'FunctionCall':
            return self.eval_call(node, env)

        elif t == 'ReturnStmt':
            val = self.eval(node.value, env) if node.value else None
            raise ReturnSignal(val)

        elif t == 'BreakStmt':
            raise BreakSignal()

        elif t == 'ContinueStmt':
            raise ContinueSignal()

        elif t == 'ArrayLiteral':
            return [self.eval(e, env) for e in node.elements]

        elif t == 'AllocArray':
            size = self.eval(node.size_expr, env)
            return [None] * size

        elif t == 'IndexAccess':
            arr = self.eval(node.obj, env)
            idx = self.eval(node.index, env)
            return arr[idx]

        elif t == 'Index2DAccess':
            arr = self.eval(node.obj, env)
            row = self.eval(node.row, env)
            col = self.eval(node.col, env)
            return arr[row][col]

        elif t == 'MemberAccess':
            obj = self.eval(node.obj, env)
            if node.member == 'length' and isinstance(obj, (str, list)):
                return len(obj)
            return None

        elif t == 'MatchStmt':
            val = self.eval(node.value, env)
            for case in node.cases:
                if case.is_default:
                    child = env.child()
                    for stmt in case.body:
                        self.eval(stmt, child)
                    return None
                if case.pattern is not None:
                    case_val = self.eval(case.pattern, env)
                    if val == case_val:
                        if case.condition is None or self.eval(case.condition, env):
                            child = env.child()
                            for stmt in case.body:
                                self.eval(stmt, child)
                            return None
            return None

        elif t == 'TupleLiteral':
            return tuple(self.eval(e, env) for e in node.elements)

        elif t == 'TupleAccess':
            tup = self.eval(node.obj, env)
            return tup[node.index]

        elif t == 'LambdaExpr':
            return node  # store as-is, eval when called

        elif t == 'DictLiteral':
            return {self.eval(k, env): self.eval(v, env) for k, v in node.pairs}

        elif t == 'RangeNode':
            start = self.eval(node.start, env)
            end = self.eval(node.end, env)
            return list(range(start, end + 1))

        elif t == 'ListComprehension':
            iterable = self.eval(node.iterable, env)
            result = []
            for item in iterable:
                child = env.child()
                child.set(node.var_name, item)
                if node.condition is None or self.eval(node.condition, child):
                    result.append(self.eval(node.expr, child))
                elif node.else_expr is not None:
                    result.append(self.eval(node.else_expr, child))
            return result
        
        elif t == 'LibQualifiedCall':
            raise NameError(
                f"Cannot call methods on string literals directly in REPL.\n"
                f"  Assign to a variable first:\n"
                f"  var s: str = \"{node.source}\"\n"
                f"  s.{node.method}()"
            )

        else:
            return None

    # ══════════════════════════════════════════
    # LVALUE HELPERS — get/set for any assignable target
    # ══════════════════════════════════════════

    def eval_lvalue_get(self, node, env):
        t = type(node).__name__
        if t == 'Identifier':
            return env.get(node.name)
        if t == 'IndexAccess':
            arr = self.eval(node.obj, env)
            idx = self.eval(node.index, env)
            return arr[idx]
        if t == 'Index2DAccess':
            arr = self.eval(node.obj, env)
            row = self.eval(node.row, env)
            col = self.eval(node.col, env)
            return arr[row][col]
        if t == 'MemberAccess':
            obj = self.eval(node.obj, env)
            if isinstance(obj, dict):
                return obj[node.member]
            return getattr(obj, node.member, None)
        raise NotImplementedError(f"Cannot read from lvalue of type '{t}'")

    def eval_lvalue_set(self, node, value, env):
        t = type(node).__name__
        if t == 'Identifier':
            env.assign(node.name, value)
            return
        if t == 'IndexAccess':
            arr = self.eval(node.obj, env)
            idx = self.eval(node.index, env)
            arr[idx] = value
            return
        if t == 'Index2DAccess':
            arr = self.eval(node.obj, env)
            row = self.eval(node.row, env)
            col = self.eval(node.col, env)
            arr[row][col] = value
            return
        if t == 'MemberAccess':
            obj = self.eval(node.obj, env)
            if isinstance(obj, dict):
                obj[node.member] = value
            else:
                setattr(obj, node.member, value)
            return
        raise NotImplementedError(f"Cannot assign to lvalue of type '{t}'")

    # ══════════════════════════════════════════
    # FUNCTION CALLS
    # ══════════════════════════════════════════

    def eval_call(self, node, env):
        if isinstance(node.name, Identifier):
            name = node.name.name

            if name == 'print':
                return self.eval_print(node, env)

            if name in ('str', 'int', 'float', 'bool'):
                val = self.eval(node.args[0], env)
                if name == 'str':
                    if isinstance(val, bool):
                        return "true" if val else "false"
                    if isinstance(val, float) and val == int(val):
                        return str(int(val)) + ".0"
                    return str(val)
                if name == 'int':   return int(val)
                if name == 'float': return float(val)
                if name == 'bool':  return bool(val)

            if name == 'abs':
                return abs(self.eval(node.args[0], env))

            if name in self.functions:
                return self.eval_user_func(self.functions[name], node.args, env)

            try:
                fn = env.get(name)
                if isinstance(fn, FunctionDecl):
                    return self.eval_user_func(fn, node.args, env)
            except NameError:
                pass

            raise NameError(f"Unknown function '{name}'")

        elif isinstance(node.name, MemberAccess):
            return self.eval_method_call(node, env)

        return None

    def eval_user_func(self, fn, arg_nodes, env):
        call_env = env.child()
        for i, param in enumerate(fn.params):
            if i < len(arg_nodes):
                arg = arg_nodes[i]
                val = self.eval(arg.value if isinstance(arg, Assignment) else arg, env)
                call_env.set(param.name, val)
        try:
            for stmt in fn.body:
                self.eval(stmt, call_env)
        except ReturnSignal as r:
            return r.value
        return None

    def eval_print(self, node, env):
        newline = True
        parts = []
        for arg in node.args:
            if isinstance(arg, Assignment):
                if isinstance(arg.target, Identifier) and arg.target.name == 'newLine':
                    newline = self.eval(arg.value, env)
            else:
                val = self.eval(arg, env)
                if isinstance(val, bool):
                    parts.append("true" if val else "false")
                elif val is None:
                    parts.append("null")
                else:
                    parts.append(str(val))
        print("".join(parts), end="\n" if newline else "")
        return None

    def eval_method_call(self, node, env):
        obj = self.eval(node.name.obj, env)
        member = node.name.member
        args = [self.eval(a, env) for a in node.args if not isinstance(a, Assignment)]

        if isinstance(obj, str):
            if member == 'length':      return len(obj)
            if member == 'toUpper':     return obj.upper()
            if member == 'toLower':     return obj.lower()
            if member == 'contains':    return args[0] in obj
            if member == 'startsWith':  return obj.startswith(args[0])
            if member == 'endsWith':    return obj.endswith(args[0])
            if member == 'indexOf':     return obj.find(args[0])
            if member == 'replace':     return obj.replace(args[0], args[1], args[2])
            if member == 'replaceAll':  return obj.replace(args[0], args[1])
            if member == 'split':       return obj.split(args[0])
            if member in ('trim', 'rip'):   return obj.strip()
            if member == 'trimLeft':    return obj.lstrip()
            if member == 'trimRight':   return obj.rstrip()
            if member == 'substring':   return obj[args[0]:args[1]+1]
            if member == 'reverse':     return obj[::-1]
            if member == 'charAt':      return obj[args[0]]
            if member == 'repeat':      return obj * args[0]
            if member == 'isAlpha':     return obj.isalpha()
            if member == 'isNumeric':   return obj.isnumeric()
            if member == 'isAlphaNumeric': return obj.isalnum()
            if member == 'padLeft':     return obj.rjust(args[0], args[1])
            if member == 'padRight':    return obj.ljust(args[0], args[1])

        if isinstance(obj, list):
            if member == 'length':  return len(obj)
            if member == 'push':    obj.append(args[0]); return None
            if member == 'pop':     return obj.pop() if obj else None
            if member == 'copy':    return obj.copy()
            if member == 'join':    return args[0].join(str(x) for x in obj)
            if member == 'mean':    return sum(obj) / len(obj) if obj else 0.0
            if member == 'min':     return min(obj) if obj else None
            if member == 'max':     return max(obj) if obj else None

        if isinstance(obj, dict):
            if member == 'length':      return len(obj)
            if member == 'has':         return args[0] in obj
            if member == 'allKeys':     return list(obj.keys())
            if member == 'allValues':   return list(obj.values())
            if member == 'remove':      obj.pop(args[0], None); return None
            if member == 'clean':       obj.clear(); return None

        raise NotImplementedError(f"Method '.{member}' not supported in REPL on type {type(obj).__name__}")


# ══════════════════════════════════════════
# REPL LOOP
# ══════════════════════════════════════════

EXPR_TYPES = {
    'BinaryOp', 'UnaryOp', 'IntLiteral', 'FloatLiteral', 'StrLiteral',
    'BoolLiteral', 'FunctionCall', 'Identifier', 'IndexAccess',
    'TupleAccess', 'MemberAccess', 'PostIncrement', 'PreIncrement',
    'PreIncrement', 'PostIncrement', 'PreDecrement', 'PostDecrement'
}

def format_val(val):
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, str):
        return f'"{val}"'
    if val is None:
        return "null"
    return str(val)

def parse_input(source):
    s = source.strip()
    if s and not s.endswith(';'):
        s = s + ';'
    tokens = Lexer(s).tokenise()
    return Parser(tokens).parse()

def run_repl():
    env = Environment()
    evaluator = Evaluator()

    print("╔══════════════════════════════════╗")
    print("║   Mocha REPL v0.9  🐶            ║")
    print("║   'exit' to quit                 ║")
    print("║   'clear' to reset state         ║")
    print("║   'vars' to show variables       ║")
    print("╚══════════════════════════════════╝")
    print("⚠️  REPL uses Python runtime for collections.\nType safety is enforced at runtime.\nFor true Mocha semantics (fixed-point, FFI, etc.), compile with `mocha`.")

    buffer = ""
    prompt = "mocha> "
    depth = 0

    while True:
        try:
            line = input(prompt)
        except (EOFError, KeyboardInterrupt):
            print("\nBye!")
            break

        stripped = line.strip()

        if line.strip() == 'exit':
            print("Bye!")
            break

        if line.strip() == 'clear':
            env = Environment()
            evaluator = Evaluator()
            print("State cleared.")
            continue

        if line.strip() == 'vars':
            if env.vars:
                variables = {k: v for k, v in env.vars.items() if not isinstance(v, FunctionDecl)}
                if variables:
                    print("  Variables:")
                    for k, v in variables.items():
                        if isinstance(v, list):
                            print(f"    {k} = [{', '.join(str(x) for x in v)}]")
                        else:
                            print(f"    {k} = {v}")
                else:
                    print("  (no variables defined)")
            else:
                print("  (no variables defined)")
            continue

        if line.strip() == 'funcs':
            functions = {k: v for k, v in env.vars.items() if isinstance(v, FunctionDecl)}
            if functions:
                print("  User-defined functions:")
                for k, v in functions.items():
                    params = ", ".join(f"{p.name}: {p.type}" for p in v.params)
                    print(f"    {k}({params}) -> {v.return_type}")
            else:
                print("  (no functions defined)")
            continue

        if line.strip() == 'help':
            print("""
        ╔══════════════════════════════════════════════════════╗
        ║              Mocha REPL v0.9 — Help                  ║
        ╠══════════════════════════════════════════════════════╣
        ║  COMMANDS                                            ║
        ║    help      show this help                          ║
        ║    vars      show all variables                      ║
        ║    funcs     show all defined functions              ║
        ║    clear     reset all state                         ║
        ║    exit      quit the REPL                           ║
        ╠══════════════════════════════════════════════════════╣
        ║  BUILT-IN FUNCTIONS                                  ║
        ║    str(x)      convert to string                     ║
        ║    int(x)      convert to int                        ║
        ║    float(x)    convert to float                      ║
        ║    bool(x)     convert to bool                       ║
        ║    abs(x)      absolute value                        ║
        ║    print(x)    print value                           ║
        ╠══════════════════════════════════════════════════════╣
        ║  STRING METHODS (on variables only)                  ║
        ║    s.toUpper()           s.toLower()                 ║
        ║    s.length              s.reverse()                 ║
        ║    s.contains(sub)       s.indexOf(sub)              ║
        ║    s.startsWith(pre)     s.endsWith(suf)             ║
        ║    s.split(delim)        s.replace(old,new,n)        ║
        ║    s.replaceAll(old,new) s.substring(start,end)      ║
        ║    s.trimLeft()          s.trimRight()               ║
        ║    s.rip()               s.charAt(i)                 ║
        ║    s.repeat(n)           s.padLeft(w,fill)           ║
        ║    s.padRight(w,fill)    s.isPalindrome()            ║
        ║    s.isAlpha()           s.isNumeric()               ║
        ║    s.isAlphaNumeric()    s.occurs(sub)               ║
        ╠══════════════════════════════════════════════════════╣
        ║  ARRAY METHODS                                       ║
        ║    arr.length            arr.push(x)                 ║
        ║    arr.pop()             arr.copy()                  ║
        ║    arr.join(delim)       arr.mean()                  ║
        ║    arr.min()             arr.max()                   ║
        ╠══════════════════════════════════════════════════════╣
        ║  LANGUAGE FEATURES                                   ║
        ║    var x: int = 5        variable declaration        ║
        ║    const PI: float = 3.14  constant                  ║
        ║    if / while / for      control flow                ║
        ║    function f(x:int)->int  user functions            ║
        ║    match / case          pattern matching            ║
        ║    [1,2,3]               array literal               ║
        ╠══════════════════════════════════════════════════════╣
        ║  LIMITATIONS                                         ║
        ║    No FFI / native functions                         ║
        ║    No lib imports                                     ║
        ║    String literals need var: var s:str="hi"          ║
        ║    Python float semantics (not fixed-point)          ║
        ║    For full Mocha: compile with `mocha`              ║
        ╚══════════════════════════════════════════════════════╝
        """)
            continue

        depth += line.count('{') - line.count('}')

        if stripped and not stripped.endswith((';', '{', '}')):
            line = line.rstrip() + ';'

        buffer += line + "\n"

        if depth > 0:
            prompt = "  ... "
            continue

        prompt = "mocha> "
        source = buffer.strip()
        buffer = ""
        depth = 0

        if not source:
            continue

        try:
            ast = parse_input(source)
            result = evaluator.eval(ast, env)
            # change this condition to be more permissive
            if result is not None:
                node_type = type(ast.statements[0]).__name__
                if node_type not in ('VarDecl', 'ConstDecl', 'FunctionDecl', 
                                    'WhileLoop', 'ForLoop', 'DoWhileLoop',
                                    'IfStmt', 'Assignment', 'CompoundAssignment'):
                    if isinstance(result, bool):
                        print("=> " + ("true" if result else "false"))
                    elif isinstance(result, str):
                        print(f'=> "{result}"')
                    else:
                        print(f"=> {result}")
        except NameError as e:
            print(f"  ❌ MochaNameError: {e}")
        except ZeroDivisionError:
            print(f"  ❌ Division by zero in mocha")
        except NotImplementedError as e:
            print(f"  ❌ Not supported in REPL: {e}")
        except RecursionError:
            print(f"  ❌ Stack overflow — infinite recursion or too deep")
        except IndexError as e:
            print(f"  ❌ Index_out_of_bounds Error: {e}")
        except TypeError as e:
            print(f"  ❌ MochaTypeError: {e}")
        except Exception as e:
            # try to give helpful message based on error type
            msg = str(e)
            if 'MochaParseError' in msg or 'Expected' in msg:
                print(f"  ❌ Syntax error: {msg}")
            elif 'Undefined variable' in msg:
                print(f"  ❌ {msg} — did you forget to declare it with 'var'?")
            else:
                print(f"  ❌ Error: {msg}")

if __name__ == '__main__':
    run_repl()