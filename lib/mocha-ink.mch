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
class Heatmap {};
class PieChart {};
class Histogram {};
class BoxPlot {};
class ViolinPlot {};
class AreaChart {};
class BubbleChart {};
class CurvePlot {};
class ErrorPlot{};
class LMPlot {};
class NetworkChart {};
class SankeyChart {};

// =============================================
// CONSTRUCTORS
// =============================================
function line(x: float[], y: float[]) -> LinePlot native ink_new_line_mocha;
function scatter(x: float[], y: float[]) -> ScatterPlot native ink_new_scatter_mocha;
function bar(labels: str[], values: float[]) -> BarChart native ink_new_bar_mocha;
function heatmap(matrix: float[][]) -> Heatmap native ink_new_heatmap_mocha;
function pie(labels: str[], values: float[]) -> PieChart native ink_new_pie_mocha;
function histogram(data: float[]) -> Histogram native ink_new_histogram_mocha;
function boxplot(data: float[]) -> BoxPlot native ink_new_boxplot_mocha;
function violin(data: float[]) -> ViolinPlot native ink_new_violin_mocha;
function area(x: float[], y: float[]) -> AreaChart native ink_ac_new;
function bubble(x: float[], y: float[], z: float[]) -> BubbleChart native ink_new_bubble_mocha;
function curve(data: float[]) -> CurvePlot native ink_new_curve_mocha;
function errorplot(x: float[], y: float[], err: float[]) -> ErrorPlot native ink_new_errorplot_mocha;
function lmplot(x: float[], y: float[]) -> LMPlot native ink_new_lmplot_mocha;
function network() -> NetworkChart native ink_new_network_mocha;
function sankey() -> SankeyChart native ink_new_sankey_mocha;

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

// =============================================
// Heatmap methods
// =============================================

extend Heatmap {
    function title(t: str) -> null native ink_hm_set_title;
    function xlabel(l: str) -> null native ink_hm_set_xlabel;
    function ylabel(l: str) -> null native ink_hm_set_ylabel;
    function row_label(i: int, l: str) -> null native ink_hm_set_row_label;
    function col_label(i: int, l: str) -> null native ink_hm_set_col_label;
    function blue_red() -> null native ink_hm_set_scheme_blue_red;
    function white_blue() -> null native ink_hm_set_scheme_white_blue;
    function black_yellow() -> null native ink_hm_set_scheme_black_yellow;
    function save(path: str) -> null native ink_hm_save;
    function show() -> null native ink_hm_show;
};

// =============================================
// PieChart methods
// =============================================

extend PieChart {
    function title(t: str) -> null native ink_pc_set_title;
    function show_percent() -> null native ink_pc_set_show_percent;
    function show_values() -> null native ink_pc_set_show_values;
    function color(i: int, c: str) -> null native ink_pc_set_color;
    function save(path: str) -> null native ink_pc_save;
    function show() -> null native ink_pc_show;
};

// =============================================
// Histogram methods
// =============================================

extend Histogram {
    function title(t: str) -> null native ink_hg_set_title;
    function xlabel(l: str) -> null native ink_hg_set_xlabel;
    function ylabel(l: str) -> null native ink_hg_set_ylabel;
    function bins(n: int) -> null native ink_hg_set_bins;
    function density() -> null native ink_hg_set_density;
    function normal_curve() -> null native ink_hg_set_normal_curve;
    function grid(on: bool) -> null native ink_hg_set_grid;
    function color(c: str) -> null native ink_hg_set_color;
    function label(l: str) -> null native ink_hg_set_label;
    function add(data: float[]) -> null native ink_hg_add;
    function save(path: str) -> null native ink_hg_save;
    function show() -> null native ink_hg_show;
};

// =============================================
// BoxPlot methods
// =============================================

extend BoxPlot {
    function title(t: str) -> null native ink_bp_set_title;
    function xlabel(l: str) -> null native ink_bp_set_xlabel;
    function ylabel(l: str) -> null native ink_bp_set_ylabel;
    function color(c: str) -> null native ink_bp_set_color;
    function label(l: str) -> null native ink_bp_set_label;
    function grid(on: bool) -> null native ink_bp_set_grid;
    function horizontal() -> null native ink_bp_set_horizontal;
    function confidence() -> null native ink_bp_set_confidence;
    function add(data: float[]) -> null native ink_bp_add;
    function save(path: str) -> null native ink_bp_save;
    function show() -> null native ink_bp_show;
};

// =============================================
// ViolinPlot methods
// =============================================

extend ViolinPlot {
    function title(t: str) -> null native ink_vn_set_title;
    function xlabel(l: str) -> null native ink_vn_set_xlabel;
    function ylabel(l: str) -> null native ink_vn_set_ylabel;
    function color(c: str) -> null native ink_vn_set_color;
    function label(l: str) -> null native ink_vn_set_label;
    function grid(on: bool) -> null native ink_vn_set_grid;
    function horizontal() -> null native ink_vn_set_horizontal;
    function no_box() -> null native ink_vn_set_no_box;
    function bandwidth(h: float) -> null native ink_vn_set_bandwidth;
    function add(data: float[]) -> null native ink_vn_add;
    function save(path: str) -> null native ink_vn_save;
    function show() -> null native ink_vn_show;
};

// =============================================
// AreaChart methods
// =============================================

extend AreaChart {
    function title(t: str) -> null native ink_ac_set_title;
    function xlabel(l: str) -> null native ink_ac_set_xlabel;
    function ylabel(l: str) -> null native ink_ac_set_ylabel;
    function color(c: str) -> null native ink_ac_set_color;
    function label(l: str) -> null native ink_ac_set_label;
    function grid(on: bool) -> null native ink_ac_set_grid;
    function add_area(x: float[], y: float[]) -> null native ink_ac_add_area;
    function save(path: str) -> null native ink_ac_save;
    function show() -> null native ink_ac_show;
};

// =============================================
// BubbleChart methods
// =============================================

extend BubbleChart {
    function title(t: str) -> null native ink_bc2_set_title;
    function xlabel(l: str) -> null native ink_bc2_set_xlabel;
    function ylabel(l: str) -> null native ink_bc2_set_ylabel;
    function color(c: str) -> null native ink_bc2_set_color;
    function label(l: str) -> null native ink_bc2_set_label;
    function grid(on: bool) -> null native ink_bc2_set_grid;
    function min_size(r: float) -> null native ink_bc2_set_min_size;
    function max_size(r: float) -> null native ink_bc2_set_max_size;
    function add(x: float[], y: float[], z: float[]) -> null native ink_bc2_add;
    function save(path: str) -> null native ink_bc2_save;
    function show() -> null native ink_bc2_show;
};

// =============================================
// CurvePlot methods (KDE curve)
// =============================================

extend CurvePlot {
    function title(t: str) -> null native ink_cp_set_title;
    function xlabel(l: str) -> null native ink_cp_set_xlabel;
    function ylabel(l: str) -> null native ink_cp_set_ylabel;
    function color(c: str) -> null native ink_cp_set_color;
    function label(l: str) -> null native ink_cp_set_label;
    function grid(on: bool) -> null native ink_cp_set_grid;
    function fill() -> null native ink_cp_set_fill;
    function bandwidth(h: float) -> null native ink_cp_set_bandwidth;
    function add(data: float[]) -> null native ink_cp_add;
    function save(path: str) -> null native ink_cp_save;
    function show() -> null native ink_cp_show;
};

// =============================================
// ErrorPlot methods
// =============================================

extend ErrorPlot {
    function title(t: str) -> null native ink_ep_set_title;
    function xlabel(l: str) -> null native ink_ep_set_xlabel;
    function ylabel(l: str) -> null native ink_ep_set_ylabel;
    function color(c: str) -> null native ink_ep_set_color;
    function label(l: str) -> null native ink_ep_set_label;
    function grid(on: bool) -> null native ink_ep_set_grid;
    function connect() -> null native ink_ep_set_connect;
    function asymmetric(err_lo: float[], err_hi: float[]) -> null native ink_ep_set_asymmetric;
    function add(x: float[], y: float[], err: float[]) -> null native ink_ep_add;
    function save(path: str) -> null native ink_ep_save;
    function show() -> null native ink_ep_show;
};

// =============================================
// LMPlot methods
// =============================================

extend LMPlot {
    function title(t: str) -> null native ink_lm_set_title_mocha;
    function xlabel(l: str) -> null native ink_lm_set_xlabel_mocha;
    function ylabel(l: str) -> null native ink_lm_set_ylabel_mocha;
    function color(c: str) -> null native ink_lm_set_color_mocha;
    function linecolor(c: str) -> null native ink_lm_set_linecolor_mocha;
    function label(l: str) -> null native ink_lm_set_label_mocha;
    function grid(on: bool) -> null native ink_lm_set_grid_mocha;
    function ci(level: float) -> null native ink_lm_set_ci_mocha;
    function noband() -> null native ink_lm_set_noband_mocha;
    function add(x: float[], y: float[]) -> null native ink_lm_add_mocha;
    function save(path: str) -> null native ink_lm_save_mocha;
    function show() -> null native ink_lm_show_mocha;
};

// =============================================
// NetworkChart methods
// =============================================

extend NetworkChart {
    function node(id: str, label: str) -> null native ink_net_add_node_mocha;
    function edge(src: str, dst: str) -> null native ink_net_add_edge_mocha;
    function edgeweight(src: str, dst: str, weight: float) -> null native ink_net_add_edge_weight_mocha;
    function nodecolor(id: str, color: str) -> null native ink_net_set_node_color_mocha;
    function nodesize(id: str, size: float) -> null native ink_net_set_node_size_mocha;
    function edgecolor(src: str, dst: str, color: str) -> null native ink_net_set_edge_color_mocha;
    function labels(on: bool) -> null native ink_net_set_labels_mocha;
    function title(t: str) -> null native ink_net_set_title_mocha;
    function directed(on: bool) -> null native ink_net_set_directed_mocha;
    function save(path: str) -> null native ink_net_save_mocha;
    function show() -> null native ink_net_show_mocha;
};

// =============================================
// NetworkChart methods
// =============================================

extend SankeyChart {
    function flow(src: str, dst: str, value: float) -> null native ink_sk_add_flow_mocha;
    function nodecolor(id: str, color: str) -> null native ink_sk_set_node_color_mocha;
    function title(t: str) -> null native ink_sk_set_title_mocha;
    function save(path: str) -> null native ink_sk_save_mocha;
    function show() -> null native ink_sk_show_mocha;
};