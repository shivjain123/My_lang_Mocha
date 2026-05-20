# Mocha VS Code Language Support
Version 0.5.0 — matches Mocha compiler v0.5

## File Structure

```
mocha-vscode/
├── package.json                    ← Extension manifest
├── language-configuration.json    ← Brackets, comments, indentation
├── settings.json                  ← Copy this into your .vscode/settings.json
├── syntaxes/
│   └── mocha.tmLanguage.json      ← TextMate grammar (syntax highlighting)
└── snippets/
    └── mocha.json                 ← Code snippets
```

---

## Setup — Two Options

### Option A: Local Extension (Full Setup)

1. Create a folder: `~/.vscode/extensions/mocha-language-0.5.0/`
2. Copy these files into it:
   - `package.json`
   - `language-configuration.json`
   - `syntaxes/mocha.tmLanguage.json`
   - `snippets/mocha.json`
3. Restart VS Code
4. `.mch` and `.mchi` files will automatically highlight

### Option B: Workspace Settings Only (Quick Setup)

1. In your Mocha project folder, create `.vscode/` if it doesn't exist
2. Copy `settings.json` into `.vscode/settings.json`
3. Copy `syntaxes/mocha.tmLanguage.json` into `.vscode/syntaxes/`
4. In VS Code settings, add to `files.associations`: `"*.mch": "mocha"`
5. Restart VS Code

---

## Colour Scheme

| Element | Colour | Example |
|---|---|---|
| Functions (declaration + call) | Yellow `#DCDCAA` | `function greet`, `greet()` |
| SCREAMING_CASE constants | Bright Blue `#4FC1FF` | `PI`, `MAX_SIZE` |
| `true` / `false` / `null` | Blue `#569CD6` | `null`, `true` |
| Class names + type annotations | Teal Green `#4EC9B0` | `class Animal`, `: Animal` |
| Primitive types | Teal Green `#4EC9B0` | `int`, `str`, `vast` |
| Control keywords | Purple `#C586C0` | `if`, `for`, `match`, `when` |
| Declaration keywords | Blue `#569CD6` | `function`, `var`, `const`, `class` |
| Strings | Orange `#CE9178` | `"hello"` |
| Numbers | Light Green `#B5CEA8` | `42`, `3.14` |
| Comments | Grey-Green `#6A9955` italic | `// comment`, `"""block"""` |
| `..` range + `#` tuple | Gold `#F8C555` | `90..99`, `point#0` |
| Semicolons | Grey `#808080` | `;` |

Colour scheme follows VS Code Dark+ conventions so it feels native.

---

## Snippets

| Prefix | Expands To |
|---|---|
| `fn` | function declaration |
| `entry` | didLoad entry point |
| `cls` | class with constructor |
| `if` | if statement |
| `ife` | if-else |
| `match` | match with default |
| `for` | C-style for loop |
| `foreach` | for each loop |
| `while` | while loop |
| `var` | variable declaration |
| `const` | constant (SCREAMING_CASE) |
| `lam` | lambda expression |
| `native` | FFI declaration |
| `import` | named import |
| `importall` | wildcard import |
| `print` | print with newLine=true |
| `arr` | array declaration |
| `dict` | dict declaration |
| `set` | set declaration |
| `extend` | extension method |
| `symdiff` | SymCha differentiation |

---

## What Gets Highlighted

- All keywords: `function`, `class`, `var`, `const`, `if`, `match`, `for`, `each`, `in`, `when`, `native`, `extend`, `alloc`, `didLoad`, `shared`, `private`, `protected`
- All primitive types: `int`, `float`, `bool`, `char`, `str`, `vast`, `null`, `dict`, `set`, `tuple`
- Function names at declaration and call sites
- SCREAMING_CASE constants (enforced blue — matches parser enforcement)
- Class names after `class`, `interface`, `extends`, `implements`
- Type annotations after `:` when uppercase (user-defined classes)
- String literals (double quotes) and char literals (single quotes)
- `"""` block comments
- Numbers (int and float)
- All operators including `->`, `..`, `#`
- `.mch` and `.mchi` files both recognised

---

## To Rebuild After VS Code Updates

If VS Code wipes your config again (😄):

1. Download this zip
2. Copy `settings.json` → `.vscode/settings.json`
3. Copy the `syntaxes/` folder → `.vscode/syntaxes/`
4. Restart VS Code

Everything restores in under a minute.
