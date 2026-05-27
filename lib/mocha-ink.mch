"""
   mocha-ink v0.1 — Mocha SVG Visualization Library
   Save as: lib/mocha-ink.mch
   Compile with: mocha --lib lib/mocha-ink.mch
"""

// =============================================
// OPAQUE TYPES
// =============================================
class LinePlot {};
class ScatterPlot {};
class BarChart {};

// =============================================
// CONSTRUCTORS
// =============================================
function line(x: float[], y: float[]) -> LinePlot native ink_new_line_mocha;
function scatter(x: float[], y: float[]) -> ScatterPlot native ink_new_scatter_mocha;
function bar(labels: str[], values: float[]) -> BarChart native ink_new_bar_mocha;

// =============================================
// LinePlot methods
// =============================================

extend LinePlot {
    function title(t: str) -> null native ink_lp_set_title;
    function xlabel(l: str) -> null native ink_lp_set_xlabel;
    function ylabel(l: str) -> null native ink_lp_set_ylabel;
    function color(c: str) -> null native ink_lp_set_color;
    function label(l: str) -> null native ink_lp_set_label;
    function grid(on: bool) -> null native ink_lp_set_grid;
    function add_line(x: float[], y: float[]) -> null native ink_lp_add_line;
    function add_scatter(x: float[], y: float[]) -> null native ink_lp_add_scatter;
    function save(path: str) -> null native ink_lp_save;
    function show() -> null native ink_lp_show;
};

// =============================================
// ScatterPlot methods
// =============================================

extend ScatterPlot {
    function title(t: str) -> null native ink_sp_set_title;
    function xlabel(l: str) -> null native ink_sp_set_xlabel;
    function ylabel(l: str) -> null native ink_sp_set_ylabel;
    function color(c: str) -> null native ink_sp_set_color;
    function label(l: str) -> null native ink_sp_set_label;
    function grid(on: bool) -> null native ink_sp_set_grid;
    function add_line(x: float[], y: float[]) -> null native ink_sp_add_line;
    function add_scatter(x: float[], y: float[]) -> null native ink_sp_add_scatter;
    function save(path: str) -> null native ink_sp_save;
    function show() -> null native ink_sp_show;
};

// =============================================
// BarChart methods
// =============================================

extend BarChart {
    function title(t: str) -> null native ink_bc_set_title;
    function xlabel(l: str) -> null native ink_bc_set_xlabel;
    function ylabel(l: str) -> null native ink_bc_set_ylabel;
    function color(c: str) -> null native ink_bc_set_color;
    function label(l: str) -> null native ink_bc_set_label;
    function grid(on: bool) -> null native ink_bc_set_grid;
    function horizontal() -> null native ink_bc_set_horizontal;
    function add_series(values: float[]) -> null native ink_bc_add_series;
    function save(path: str) -> null native ink_bc_save;
    function show() -> null native ink_bc_show;
};