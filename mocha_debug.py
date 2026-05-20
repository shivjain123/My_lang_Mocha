import sys
from mocha_lexer import Token
from mocha_ast import Node


def print_tokens(tokens: list[Token], stream=sys.stdout):
    #PRETTY PRINT BECAUSE -v of gcc is TERRIBLE!
    print(f"\n{'TYPE':<20} {'VALUE':<20} {'LINE':<6} {'COL'}", file=stream)
    print("-" * 55, file=stream)
    for tok in tokens:
        print(
            f"{tok.type.name:<20} "
            f"{repr(tok.value):<20} "
            f"{tok.line:<6} "
            f"{tok.column}",
            file=stream
        )


def print_ast(node, indent=0, stream=sys.stdout):
    prefix = "  " * indent
    if isinstance(node, list):
        for item in node:
            print_ast(item, indent, stream)  # ← pass stream through
        return

    if not isinstance(node, Node):
        print(f"{prefix}{repr(node)}", file=stream)
        return

    name = type(node).__name__
    fields = node.__dataclass_fields__ if hasattr(node, '__dataclass_fields__') else {}  # type: ignore

    if not fields:
        print(f"{prefix}{name}", file=stream)
        return

    print(f"{prefix}{name}", file=stream)
    for field_name, _ in fields.items():
        value = getattr(node, field_name)
        if isinstance(value, list):
            if value:
                print(f"{prefix}  {field_name}:", file=stream)
                for item in value:
                    print_ast(item, indent + 2, stream)  # ← pass stream through
        elif isinstance(value, Node):
            print(f"{prefix}  {field_name}:", file=stream)
            print_ast(value, indent + 2, stream)  # ← pass stream through
        elif value is not None:
            print(f"{prefix}  {field_name}: {repr(value)}", file=stream)