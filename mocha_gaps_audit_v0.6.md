# Mocha Compiler — Known Gaps & Audit v3
*26th March 2026 — Post v0.6*
*Covers: mocha_lexer.py, mocha_parser.py, mocha_ast.py, mocha_typeChecker.py,*
*mocha_codegen.py, mocha_compile.py, mocha_garbageCollector.c, all libs*

### Documentations to Keep:

--- 

# Classes are always top-level in Mocha — scopes[0] is intentionally the global scope here
self.symbols.scopes[0][f"{node.name}.{member.name}"] = { ... }
**Correctly documented as intentional.**

# `is_dummy_body` — intentional design, not a bug

mocha-math functions were written before FFI existed. Single-literal-return signals to the
manifest generator that the function is C-backed. Design decision, not fragile code.
**Correctly documented as intentional.**

---

### `Result`/`OkExpr`/`ErrorExpr` — unimplemented feature
**File:** `mocha_lexer.py`, `mocha_ast.py`, `mocha_codegen.py`

`ok(value)` and `error(value)` parse and type-check to `"Result"` but no codegen path exists.
Fully orphaned stubs. Deliberate future feature.
**Correctly documented as intentional.**

---

### 1. Lambda parameter types unchecked at call site (Tried. Unsuccessful (out of 29, this one only which coudln't be done. so slight setback). will document. See later!)
**File:** `mocha_typeChecker.py`

```mocha
filter(nums, lambda (x: str) -> bool: x.length > 0)  // int[] but str lambda — no error
```

**Fix:** Store lambda param types at declaration, check against call site args.

---