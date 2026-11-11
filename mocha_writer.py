# mocha_writter.py  (run from corpus_current\)
import sys
from mocha_emitter import (parse_module, parse_globals, classify_function, header, emit_straight,
                           infer_returns, owner_of, EmitError, mocha_type, FIELD_NAMES, FIELD_TYPES)


def body(fn, g, pad):
    lines = [pad + header(fn)]
    for _, text in emit_straight(fn, g):
        lines.append(pad + "    " + text)
    lines.append(pad + "};")          # function closer needs its ;
    return lines


def field_lines(cls, g):
    out = []
    for k, llvm in enumerate(g.types.get("struct." + cls, [])):
        name = FIELD_NAMES.get((cls, str(k)), f"field{k}")
        ty = FIELD_TYPES.get((cls, str(k)))
        if ty is None:
            try:
                ty = mocha_type(llvm)
            except EmitError:
                ty = "?"
        out.append(f"    var {name}: {ty};")
    return out


def write_module(text):
    funcs, g = parse_module(text), parse_globals(text)
    infer_returns(funcs, g)
    kinds = {n: classify_function(f)[0] for n, f in funcs.items()}
    out = []
    for key in g.types:
        cls = key[len("struct."):]
        if cls.startswith("Mocha") or g.types[key] is None or f"{cls}_release" not in funcs:
            continue                  # runtime, opaque and library classes are not defined in this file
        out.append(f"class {cls} {{")
        out += field_lines(cls, g)
        for fn in funcs.values():
            if kinds[fn.name] in ("ctor", "method") and owner_of(fn) == cls \
                    and not (fn.params and fn.params[0][1] == "%self"):
                out += body(fn, g, "    ")
        out += ["};", ""]
    for fn in funcs.values():
        if kinds[fn.name] in ("plain", "entry"):
            out += body(fn, g, "")
            out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    print(write_module(open(sys.argv[1] + ".ll", encoding="utf-8").read()))