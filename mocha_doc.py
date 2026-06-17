"""
mocha_doc.py — Mocha documentation generator
Usage: python mocha_doc.py <file.mch> [--out <output.html>]
After .bat wrapper it has become, mocha doc file.mch
"""

import sys
import os
import argparse
import html

# ── Reuse Mocha's own lexer/parser ──────────────────────────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mocha_lexer  import Lexer,  MochaLexError
from mocha_parser import Parser, MochaParseError
from mocha_ast    import FunctionDecl, MethodDecl, ClassDecl


# ── Doc line parsing ─────────────────────────────────────────────────────────

def parse_doc_lines(lines):
    """
    Split raw doc lines into:
      description  : [str]
      params       : [(name, desc)]
      returns      : str | None
    """
    if not lines:
        return [], [], None

    description = []
    params      = []
    returns     = None

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("@param"):
            rest = stripped[len("@param"):].strip()
            parts = rest.split(None, 1)
            pname = parts[0] if parts else ""
            pdesc = parts[1] if len(parts) > 1 else ""
            params.append((pname, pdesc))
        elif stripped.startswith("@return"):
            returns = stripped[len("@return"):].strip()
        else:
            description.append(stripped)

    return description, params, returns


# ── AST walker ───────────────────────────────────────────────────────────────

def collect_items(ast):
    """
    Returns a list of dicts, one per documented item:
      kind        : "function" | "class" | "method"
      name        : str
      parent      : str | None   (class name for methods)
      params      : [(name, type)]
      return_type : str
      doc_desc    : [str]
      doc_params  : [(name, desc)]
      doc_return  : str | None
      is_native   : bool
      is_shared   : bool
      visibility  : str
    """
    items = []

    for node in ast.statements:

        if isinstance(node, FunctionDecl):
            desc, dparams, dreturn = parse_doc_lines(node.doc or [])
            items.append({
                "kind":        "function",
                "name":        node.name,
                "parent":      None,
                "params":      [(p.name, p.type) for p in node.params],
                "return_type": node.return_type,
                "doc_desc":    desc,
                "doc_params":  dparams,
                "doc_return":  dreturn,
                "is_native":   node.is_native,
                "is_shared":   False,
                "visibility":  "public",
                "has_doc":     node.doc is not None,
            })

        elif isinstance(node, ClassDecl):
            cdesc, _, _ = parse_doc_lines(node.doc or [])
            cls_item = {
                "kind":        "class",
                "name":        node.name,
                "parent":      None,
                "parents":     node.parents,
                "interfaces":  node.interfaces,
                "doc_desc":    cdesc,
                "has_doc":     node.doc is not None,
                "methods":     [],
            }

            for member in node.body:
                if isinstance(member, MethodDecl):
                    desc, dparams, dreturn = parse_doc_lines(member.doc or [])
                    cls_item["methods"].append({
                        "kind":        "method",
                        "name":        member.name,
                        "parent":      node.name,
                        "params":      [(p.name, p.type) for p in member.params],
                        "return_type": member.return_type,
                        "doc_desc":    desc,
                        "doc_params":  dparams,
                        "doc_return":  dreturn,
                        "is_shared":   member.is_shared,
                        "visibility":  member.visibility,
                        "has_doc":     member.doc is not None,
                    })

            items.append(cls_item)

    return items


# ── HTML helpers ─────────────────────────────────────────────────────────────

def e(s):
    return html.escape(str(s))

def slug(name, parent=None):
    if parent:
        return f"{parent.lower()}-{name.lower()}"
    return name.lower()

def render_signature(item):
    """Render a function/method signature as HTML."""
    params = ", ".join(
        f'<span class="param-name">{e(pn)}</span><span class="colon">:</span> <span class="param-type">{e(pt)}</span>'
        for pn, pt in item["params"]
    )
    ret = item["return_type"]

    badges = []
    if item.get("is_native"):
        badges.append('<span class="badge badge-native">native</span>')
    if item.get("is_shared"):
        badges.append('<span class="badge badge-shared">shared</span>')
    if item.get("visibility") == "private":
        badges.append('<span class="badge badge-private">private</span>')
    elif item.get("visibility") == "protected":
        badges.append('<span class="badge badge-protected">protected</span>')

    badge_html = " ".join(badges)

    return f'''
<div class="sig">
  <span class="kw">function</span>
  <span class="fn-name">{e(item["name"])}</span><span class="paren">(</span>{params}<span class="paren">)</span>
  <span class="arrow">→</span>
  <span class="ret-type">{e(ret)}</span>
  {badge_html}
</div>'''

def render_doc_body(item):
    """Render description, @param, @return sections."""
    parts = []

    if item["doc_desc"]:
        desc_html = ". ".join(e(l) for l in item["doc_desc"] if l) + "."
        if desc_html:
            parts.append(f'<p class="doc-desc">{desc_html}</p>')

    if item["doc_params"]:
        rows = ""
        for pname, pdesc in item["doc_params"]:
            rows += f'<tr><td class="tag-name">{e(pname)}</td><td class="tag-desc">{e(pdesc)}</td></tr>'
        parts.append(f'<table class="tag-table"><thead><tr><th>parameter</th><th>description</th></tr></thead><tbody>{rows}</tbody></table>')

    if item["doc_return"]:
        parts.append(f'<div class="return-row"><span class="tag-label">returns</span><span class="tag-desc">{e(item["doc_return"])}</span></div>')

    if not parts:
        parts.append('<p class="no-doc">No documentation.</p>')

    return "\n".join(parts)

def render_function_card(item, is_method=False):
    anchor = slug(item["name"], item.get("parent"))
    return f'''
<div class="card" id="{anchor}">
  {render_signature(item)}
  <div class="doc-body">
    {render_doc_body(item)}
  </div>
</div>'''

def render_class_card(item):
    anchor = slug(item["name"])
    
    header_desc = ""
    if item["doc_desc"]:
        header_desc = f'<p class="class-desc">{e(" ".join(item["doc_desc"]))}</p>'

    inherit = ""
    if item["parents"]:
        inherit += f'<span class="inherit-label">extends</span> ' + ", ".join(f'<span class="type-ref">{e(p)}</span>' for p in item["parents"])
    if item["interfaces"]:
        inherit += f' <span class="inherit-label">implements</span> ' + ", ".join(f'<span class="type-ref">{e(i)}</span>' for i in item["interfaces"])

    methods_html = ""
    if item["methods"]:
        methods_html = '<div class="methods-section"><h4>Methods</h4>'
        for m in item["methods"]:
            methods_html += render_function_card(m, is_method=True)
        methods_html += '</div>'
    else:
        methods_html = '<p class="no-doc">No methods.</p>'

    return f'''
<div class="card class-card" id="{anchor}">
  <div class="class-header">
    <span class="kw">class</span>
    <span class="class-name">{e(item["name"])}</span>
    <span class="inherit">{inherit}</span>
  </div>
  {header_desc}
  {methods_html}
</div>'''


# ── Sidebar ───────────────────────────────────────────────────────────────────

def render_sidebar(items, source_file):
    links = []
    for item in items:
        if item["kind"] == "class":
            a = slug(item["name"])
            links.append(f'<li class="sb-class"><a href="#{a}"><i class="ti ti-box"></i> {e(item["name"])}</a>')
            if item["methods"]:
                links.append('<ul class="sb-methods">')
                for m in item["methods"]:
                    ma = slug(m["name"], item["name"])
                    links.append(f'<li><a href="#{ma}">{e(m["name"])}</a></li>')
                links.append('</ul>')
            links.append('</li>')
        else:
            a = slug(item["name"])
            links.append(f'<li class="sb-fn"><a href="#{a}"><i class="ti ti-function"></i> {e(item["name"])}</a></li>')

    return f'''
<nav class="sidebar">
  <div class="sb-title">{e(os.path.basename(source_file))}</div>
  <ul class="sb-list">{"".join(links)}</ul>
</nav>'''


# ── Full HTML page ────────────────────────────────────────────────────────────

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  font-size: 15px;
  line-height: 1.6;
  background: #f7f7f5;
  color: #1a1a1a;
  display: flex;
  min-height: 100vh;
}

.sidebar {
  width: 240px;
  min-width: 240px;
  background: #fff;
  border-right: 1px solid #e8e8e4;
  padding: 1.5rem 0;
  position: sticky;
  top: 0;
  height: 100vh;
  overflow-y: auto;
}

.sb-title {
  font-size: 12px;
  font-weight: 500;
  color: #888;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 0 1.25rem 1rem;
  border-bottom: 1px solid #e8e8e4;
  margin-bottom: 0.75rem;
}

.sb-list { list-style: none; padding: 0 0.5rem; }
.sb-list li { margin: 1px 0; }
.sb-list a {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 5px 0.75rem;
  border-radius: 6px;
  text-decoration: none;
  color: #444;
  font-size: 13.5px;
  transition: background 0.1s;
}
.sb-list a:hover { background: #f0f0ec; color: #111; }
.sb-list a .ti { font-size: 14px; color: #aaa; }
.sb-class > a { font-weight: 500; color: #222; }
.sb-methods { list-style: none; padding-left: 1.5rem; }
.sb-methods li a { font-size: 13px; color: #666; }

.main {
  flex: 1;
  padding: 2.5rem 3rem;
  max-width: 860px;
}

h1 { font-size: 22px; font-weight: 500; margin-bottom: 0.25rem; color: #111; }
h2 { font-size: 18px; font-weight: 500; margin: 2.5rem 0 1rem; color: #111; border-bottom: 1px solid #e8e8e4; padding-bottom: 0.4rem; }
h3 { font-size: 15px; font-weight: 500; margin: 1.5rem 0 0.5rem; color: #333; }
h4 { font-size: 14px; font-weight: 500; margin: 1.25rem 0 0.75rem; color: #555; text-transform: uppercase; letter-spacing: 0.04em; }

.subtitle { font-size: 13px; color: #888; margin-bottom: 2.5rem; }

.card {
  background: #fff;
  border: 1px solid #e8e8e4;
  border-radius: 10px;
  padding: 1.25rem 1.5rem;
  margin-bottom: 1rem;
}

.class-card { border-left: 3px solid #7F77DD; }

.class-header {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}

.class-name { font-size: 17px; font-weight: 500; color: #3C3489; }
.class-desc { font-size: 14px; color: #555; margin-bottom: 1rem; }

.inherit { font-size: 13px; color: #888; }
.inherit-label { color: #aaa; margin-right: 2px; }
.type-ref { color: #185FA5; }

.methods-section { margin-top: 1.25rem; }
.methods-section .card {
  border-left: none;
  background: #fafaf8;
  margin-bottom: 0.75rem;
}

.sig {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  font-family: "SF Mono", "Fira Code", "Cascadia Code", monospace;
  font-size: 13.5px;
  margin-bottom: 0.85rem;
}

.kw   { color: #9333ea; }
.fn-name { color: #111; font-weight: 500; }
.paren { color: #888; }
.colon { color: #888; }
.arrow { color: #aaa; }
.param-name { color: #185FA5; }
.param-type { color: #0F6E56; }
.ret-type   { color: #B45309; }

.badge {
  font-family: -apple-system, sans-serif;
  font-size: 11px;
  padding: 2px 7px;
  border-radius: 4px;
  font-weight: 500;
  letter-spacing: 0.02em;
}
.badge-native    { background: #f0f0ec; color: #666; }
.badge-shared    { background: #E6F1FB; color: #185FA5; }
.badge-private   { background: #FCEBEB; color: #A32D2D; }
.badge-protected { background: #FAEEDA; color: #854F0B; }

.doc-body { font-size: 14px; color: #444; }
.doc-desc { margin-bottom: 0.75rem; line-height: 1.65; }
.no-doc   { color: #bbb; font-style: italic; font-size: 13px; }

.tag-table {
  border-collapse: collapse;
  width: 100%;
  margin-bottom: 0.75rem;
  font-size: 13.5px;
}
.tag-table th {
  text-align: left;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #aaa;
  font-weight: 500;
  padding: 0 8px 6px 0;
  border-bottom: 1px solid #e8e8e4;
}
.tag-table td { padding: 5px 8px 5px 0; vertical-align: top; }
.tag-name { font-family: monospace; color: #185FA5; font-size: 13px; white-space: nowrap; }
.tag-desc { color: #444; }

.return-row {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-top: 0.5rem;
  font-size: 13.5px;
}
.tag-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #aaa;
  font-weight: 500;
  min-width: 52px;
}

@media (max-width: 700px) {
  .sidebar { display: none; }
  .main { padding: 1.5rem 1.25rem; }
}
"""

def build_html(items, source_file):
    fname = os.path.basename(source_file)
    
    functions = [i for i in items if i["kind"] == "function"]
    classes   = [i for i in items if i["kind"] == "class"]

    sections = []

    if functions:
        cards = "\n".join(render_function_card(f) for f in functions)
        sections.append(f'<h2>Functions</h2>{cards}')

    if classes:
        cards = "\n".join(render_class_card(c) for c in classes)
        sections.append(f'<h2>Classes</h2>{cards}')

    sidebar   = render_sidebar(items, source_file)
    body      = "\n".join(sections) if sections else '<p style="color:#bbb">Nothing documented yet.</p>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{e(fname)} — Mocha Docs</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.34.0/dist/tabler-icons.min.css">
<style>{CSS}</style>
</head>
<body>
{sidebar}
<main class="main">
  <h1>🔥 {e(fname)}</h1>
  <p class="subtitle">Generated by <strong>mocha doc</strong></p>
  {body}
</main>
</body>
</html>"""


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Generate HTML docs from a .mch file")
    ap.add_argument("source", help="Path to .mch source file")
    ap.add_argument("--out",  help="Output HTML file (default: <source>_docs.html)")
    args = ap.parse_args()

    src = args.source
    if not os.path.isfile(src):
        print(f"❌ File not found: {src}")
        sys.exit(1)

    with open(src, encoding="utf-8") as f:
        source = f.read()

    print(f"📄 Parsing: {src}")
    try:
        tokens = Lexer(source).tokenise()
        ast    = Parser(tokens).parse()
    except (MochaLexError, MochaParseError) as e:
        print(f"❌ {e}")
        sys.exit(1)
    print("  ✅ Parsed")

    items = collect_items(ast)
    html_out = build_html(items, src)

    out_path = args.out or src.replace(".mch", "_docs.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html_out)

    print(f"  ✅ Docs written to: {out_path}")

if __name__ == "__main__":
    main()