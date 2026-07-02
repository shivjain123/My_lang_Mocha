/*
 * ============================================================
 * Mocha Language Runtime
 * mocha_runtime.c
 * ============================================================
 *
 * PLATFORM SUPPORT
 * ──────────────────────────────────────────────────────────
 *   Mocha has 15 stdlibs
 * 
 *   Windows / macOS / Linux, branched via #ifdef at:
 *     - top-level includes
 *     - Cryptographic RNG          (Windows: BCrypt | else: /dev/urandom or arc4random)
 *     - Lua 5.5 + Wren FFI          (entire section gated; Windows | macOS | Linux)
 *     - mocha-ink show()            (Windows: start | macOS: open | Linux: xdg-open)
 *     - ctype wrapper: hypot
 *     - stopwatch: wall_ms, wait    (Windows: QueryPerformanceCounter | macOS/Linux: clock_gettime)
 *   Pattern: #ifdef _WIN32 → #elif defined(__APPLE__) → #else (Linux)
 *
 * ── MEMORY MANAGEMENT ──────────────────────────────────────
 *   - Reference Counting (MochaRCHeader, rc_alloc/retain/release)
 *     Active for all heap allocations; replaces GC for strings.
 *   - Mark-and-Sweep GC (ORPHANED — codegen does not emit GC
 *     calls; kept as inert arena allocator for string literals
 *     pending full RC migration)
 *
 * ── CORE TYPES ─────────────────────────────────────────────
 *   - String operations (alloc via GC arena, concat, compare,
 *     case, charAt, length, isalpha/isdigit)
 *   - String formatting (.format — positional $0/$1 and named
 *     $name placeholders, |Nf pipe specifier, escape handling)
 *   - Complex number arithmetic (MochaComplex — add, sub, mul,
 *     div, abs, conjugate, toString; returned by domain-unsafe
 *     math ops instead of crashing)
 *   - Print functions (int, float, str, bool, vast;
 *     newline variants; Inf/NaN-aware float printing)
 *   - Type conversions (int↔float↔str↔vast↔bool)
 *   - Fixed-point arithmetic (scaled by 10^12, __int128
 *     overflow guard — add, sub, mul, div, mod)
 *
 * ── COLLECTIONS ────────────────────────────────────────────
 *   - 1D Array runtime (MochaArray — dynamic and fixed/alloc
 *     modes, push/pop/push_front, min/max, occs, copy, sort
 *     bridge, map_float straggler)
 *   - 2D Array runtime (MochaArray2D — row/col access, occs
 *     with range variants, resize-grow, drop_row/drop_col)
 *   - Tuple runtime (MochaTuple)
 *   - Dict runtime (MochaDict — string keys, typed values,
 *     Levenshtein fuzzy key suggestions, merge with override,
 *     allkeys/allvalues, typed getter with mismatch error)
 *   - Set runtime (MochaSet — unique ordered values,
 *     union/intersect/xor/rel_diff, negate, retype, min/max)
 *   - HashTable runtime (MochaHashTable — open-addressed,
 *     FNV-1a hash, quadratic probing, tombstone deletion,
 *     Levenshtein fuzzy suggestions, keys/values arrays)
 *   - StringBuilder runtime (MochaStringBuilder — append,
 *     toString, reverse with UTF-8 codepoint awareness,
 *     clear, length, free)
 *
 * ── SORTING ────────────────────────────────────────────────
 *   - Hybrid sort: selection sort (≤16 elems) + merge sort
 *   - Typed natural order:    sort_int, sort_float, sort_str
 *   - Simple comparator:      sort_{type}_cmp
 *   - Closure comparator:     sort_{type}_cmp_env
 *     (MochaClosureBundle — fn ptr + captured environment)
 *
 * ── MATH EXTENSIONS ────────────────────────────────────────
 *   - Trig: sin, cos, tan, cosec, sec, cot (rad/deg)
 *   - Inverse trig: inv_sin, inv_cos, inv_tan, inv_cosec,
 *     inv_sec, inv_cot (complex return on out-of-domain)
 *   - Hyperbolic: sinh, cosh, tanh, cosech, sech, coth
 *   - Inverse hyperbolic: inv_sinh, inv_cosh, inv_tanh,
 *     inv_cosech, inv_sech, inv_coth (complex/Inf where
 *     domain requires)
 *   - sqrt (complex on negative), cubrt, log/log2/log10
 *     (complex on negative, -Inf at zero)
 *   - fast_pow (int exponent, binary exponentiation),
 *     c_pow (float exponent, positive base), complex_pow
 *   - Numerical derivative (central difference, h=1e-7)
 *   - Numerical integral (adaptive Simpson's rule)
 *   - Limit (left/right average, h=1e-9) and limit_inf
 *
 * ── RANDOM ─────────────────────────────────────────────────
 *   - Standard RNG (rand-based: rand_int, rand_vast,
 *     rand_float, rand_seed)
 *   - Cryptographic RNG — Mocha-side renamed bcrypt_* → crypto_*
 *     (C names unchanged: bcrypt_rand_int, bcrypt_rand_float,
 *     bcrypt_rand_unit, bcrypt_rand_bool, bcrypt_rand_ints,
 *     bcrypt_rand_seed; Windows: BCryptGenRandom |
 *     macOS/Linux: platform-native secure source)
 *
 * ── I/O ────────────────────────────────────────────────────
 *   - File I/O (MochaFile — read/write/append, readline,
 *     exists; "read"/"write"/"append" mode strings)
 *   - tell() — blocking stdin input with optional prompt
 *
 * ── EXCEPTION HANDLING ─────────────────────────────────────
 *   - try/rescue/fail via setjmp/longjmp (Linux/macOS) and
 *     RtlCaptureContext/RtlRestoreContext (Windows)
 *   - Nested exception frames (MochaExFrame stack)
 *   - mocha_ex_throw, mocha_ex_rethrow, mocha_ex_push/pop
 *
 * ── RUNTIME STACK TRACKING ─────────────────────────────────
 *   - Call stack of 256 frames (func name, file, line)
 *   - mocha_stack_push/pop/update_line/print
 *   - exit() macro overridden to print traceback before _Exit
 *
 * ── FFI WRAPPERS ───────────────────────────────────────────
 *   - SQLite3 (open/exec/query/close; result cache API —
 *     query_run, query_rows/cols/cell/colname; table_exists,
 *     last_rowid, changes, errmsg)
 *   - Lua 5.5 (new/close, dostring/dofile, safe_dostring;
 *     get/set for number/string/bool/int; call variants:
 *     call_number/string/int, call1n, call1s, call2n, call2s)
 *   - Wren (new/free, dostring/dofile, safe_dostring;
 *     eval_number/string/bool/int; call variants matching Lua)
 *   - ctype (isalpha, isdigit, toupper, tolower)
 *   - math (hypot, fmod, erf, tgamma, lgamma, exp)
 *   - system (system call wrapper)
 *   - time/stopwatch (clock, time_ms, unix_time, wall_ms,
 *     wait; datetime_now, date_now, time_now, ampm_now,
 *     day_now, month_now, year_now)
 *   - Rust, C++, and Zig are interfaced with Mocha but do not
 *     need wrappers because they are directly linked via
 *     -fuse-ld=lld
 *
 * ── MISC / LIB SUPPORT ─────────────────────────────────────
 *   - mocha_missing_arg — CLI default-param error (main()
 *     param with no default and no arg supplied; not part of
 *     try/rescue exception handling)
 *   - ht_djb2 — DJB2 hash for mocha-ds Bloom Filters (mocha-ds
 *     is otherwise pure Mocha; this is its one native helper)
 *
 * ── STRAGGLER LIB WRAPPERS ─────────────────────────────────
 *   - mocha-processing: mocha_map_float (float array lambda map)
 *   - mocha-matvec:     mocha_wrap_sqrt_f
 *   - mocha-SymCha:     mocha_wrap_{sin,cos,tan,log,
 *                         asin,acos,atan,
 *                         sinh,cosh,tanh,asinh,atanh}
 *     (plain C math passthroughs — map directly to x86 fsin/
 *     fcos/fsqrt; remainder of each lib is dogfooded in Mocha)
 *
 * ── MOCHA-INK SVG VISUALISATION ─────────────────────────────
 *   - Shared infrastructure: palette (Tableau-8), named color
 *     map, nice tick/range calculation, coordinate mapping,
 *     clip regions, legend rendering
 *   - LinePlot    — polyline + dot overlay, multi-series
 *   - ScatterPlot — dot plot, multi-series
 *   - BarChart    — vertical and horizontal, multi-series,
 *                   optional value labels, grouped bars
 *   - Heatmap     — cell grid, 3 color schemes (blue-red,
 *                   white-blue, black-yellow), colorbar,
 *                   row/col labels, optional cell values
 *   - PieChart    — leader-line labels, small-slice legend,
 *                   percent/value display modes
 *   - Histogram   — Sturges auto-binning, frequency/density
 *                   modes, normal curve overlay, multi-series
 *   - BoxPlot     — Tukey whiskers, outlier circles, notched
 *                   (confidence interval) variant, horizontal
 *   - ViolinPlot  — KDE via Gaussian kernel, Silverman
 *                   auto-bandwidth, optional inner box plot,
 *                   horizontal variant
 *   - AreaChart
 *   - BubbleChart
 *   - CurvePlot
 *   - ErrorPlot
 *   - LMPlot
 *   - NetworkGraph
 *   - SankeyChart
 *   All charts: ink_*_save(path) and ink_*_show() (opens in
 *   default browser; cross-platform: start/open/xdg-open)
 *
 * ── MOCHA-METEORO v0.1 ─────────────────────────────────────
 *   Professional meteorology library. Default units: Celsius,
 *   km/h, mb, meters. Depends on mocha-math.
 *     1. Thermodynamics
 *     2. Humidity
 *     3. Pressure & Altitude
 *     4. Wind
 *     5. Precipitation
 *     6. Severe Weather Indices
 *     7. Visibility, Fog & AQI
 *     8. Solar & Radiation
 *     9. Climate Statistics
 *    10. Large-Scale Climate Indices
 *
 * ============================================================
 */

#include <stdint.h>
#include <stddef.h>
#include <time.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <setjmp.h>
#include <signal.h>

#ifdef _WIN32
    #include <windows.h>
    #include <bcrypt.h>
    #pragma comment(lib, "bcrypt.lib")
#else
    #include <sys/random.h>   // getrandom (Linux) / getentropy (macOS)
    #include <time.h>         // clock_gettime — already included above but
                              // needed explicitly for CLOCK_MONOTONIC on some distros
#endif

// ── Crash handler — replaces SIGSEGV with a readable error ────────────────
static void mocha_crash_handler(int sig) {
    fflush(stdout);
    fprintf(stderr, "\n");
    fprintf(stderr, "╔══════════════════════════════════════════════════════╗\n");
    fprintf(stderr, "║        Mocha Runtime Error (SIGSEGV)                 ║\n");
    fprintf(stderr, "╠══════════════════════════════════════════════════════╣\n");
    fprintf(stderr, "║  The program crashed due to invalid memory access.   ║\n");
    fprintf(stderr, "║  Possible causes:                                    ║\n");
    fprintf(stderr, "║   • Accessing a null object                          ║\n");
    fprintf(stderr, "║   • Array index out of bounds                        ║\n");
    fprintf(stderr, "║   • Using an object after dispose()                  ║\n");
    fprintf(stderr, "╚══════════════════════════════════════════════════════╝\n");
    fflush(stderr);
    exit(139);
}

/* ===============================================================
   Mocha Reference Counting (This is also partially working since \
   full was not possible yet.) \
   For now, it masks gc, and helps strings not baloon up somewhat, \
   better than nothing but not full \
   =============================================================== */

typedef struct {
    size_t  ref_count;
    size_t  size;
} MochaRCHeader;

#define RC_HEADER(ptr) ((MochaRCHeader*)(((uint8_t*)(ptr)) - sizeof(MochaRCHeader)))
#define RC_DATA(header) ((void*)(((uint8_t*)(header)) + sizeof(MochaRCHeader)))

typedef struct MochaRCNode {
    MochaRCHeader        header;
    struct MochaRCNode*  next;
} MochaRCNode;

static MochaRCNode* rc_head = NULL;

void* rc_alloc(size_t size) {
    MochaRCNode* node = (MochaRCNode*)malloc(sizeof(MochaRCNode) + size);
    if (!node) {
        fprintf(stderr, "MochaRuntimeError: Out of memory!\n");
        _exit(2);
    }
    node->header.ref_count = 1;
    node->header.size      = size;
    node->next             = rc_head;
    rc_head                = node;
    memset(RC_DATA(&node->header), 0, size);
    return RC_DATA(&node->header);
}

void rc_retain(void* ptr) {
    if (!ptr) return;
    RC_HEADER(ptr)->ref_count++;
}

void rc_release(void* ptr) {
    if (!ptr) return;
    MochaRCHeader* header = RC_HEADER(ptr);
    if (header->ref_count == 0) {
        fprintf(stderr, "MochaRuntimeError: rc_release called on already-freed object!\n");
        return;
    }
    header->ref_count--;
    if (header->ref_count == 0) {
        free(header);
    }
}

size_t rc_count(void* ptr) {
    if (!ptr) return 0;
    return RC_HEADER(ptr)->ref_count;
}

/* gc_alloc is now rc_alloc — existing code unchanged */
void* gc_alloc(size_t size) {
    return rc_alloc(size);
}

void gc_free(void* ptr) {
    rc_release(ptr);
}

/* ===============================================================
   Override exit to always print stack trace first
   =============================================================== */
/* Forward declaration for exit override */
void mocha_stack_print(void);

#define exit(code) do { mocha_stack_print(); _Exit(code); } while(0)


/* ============================================================
 * TYPE DEFINITIONS
 *
 * All runtime structs and typedefs in one place.
 * Individual sections only contain function implementations.
 * ============================================================ */

typedef struct GcNode {
    int           marked;
    struct GcNode *next;
    char          data[];
} GcNode; //DOES NOT WORK

typedef struct {
    double real;
    double imag;
} MochaComplex;

/* ---- Math (internal) ---- */
typedef double (*MochaFloatLambdaFn)(void*, void*);

typedef struct MochaArray {
    void    *data;
    int32_t  length;
    int32_t  capacity;
    int32_t  fixed;
    int32_t  elem_size;
} MochaArray;

typedef struct MochaArray2D {
    MochaArray **data;
    int32_t     rows, cols, elem_size, fixed_r, fixed_c;
} MochaArray2D;

typedef struct MochaTuple { void **slots; int32_t count; } MochaTuple;

typedef struct { char *key; void *value; int value_type; } MochaDictEntry;
typedef struct { MochaDictEntry *entries; int32_t size, capacity; } MochaDict;

typedef struct MochaSet {
    void    *data;
    int32_t  size, capacity, elem_type, elem_size;
} MochaSet;

/* ---- Lambda / Closure ---- */
typedef int8_t (*MochaCmpFn)(void *, void *);
typedef int8_t (*MochaCmpEnvFn)(void *, void *, void *);
typedef int8_t (*LambdaIntFn)(void *, void *, void *);
typedef double (*LambdaFltFn)(void *, void *, void *);
typedef char * (*LambdaStrFn)(void *, void *, void *);
typedef struct {
    void    *fn;
    void    *env;
    int32_t  ret_tag;  /* 0 = bool/int, 1 = float, 2 = str */
} MochaClosureBundle;

typedef struct {
    char*  data;
    int    length;
    int    capacity;
} MochaStringBuilder;

typedef struct MochaFile {
    FILE   *handle;
    char   *path;
    char   *mode;
    int8_t  is_open;
} MochaFile;

typedef struct {
    char    *key;
    void    *value;
    int8_t   state;   /* HT_EMPTY | HT_OCCUPIED | HT_MARKED */
} MochaHEntry;

typedef struct {
    MochaHEntry *entries;
    int32_t      capacity;
    int32_t      count;      /* live occupied slots only */
    int32_t      used;       /* occupied + marked (for load calc) */
} MochaHashTable;

/* ============================================================
 * MACROS
 * ============================================================ */

/* ---- General ---- */
#define MOCHA_OOM_CHECK(ptr) \
    if (!(ptr)) { \
        fflush(stdout); \
        fprintf(stderr, "\n╔══════════════════════════════════════════════════════╗\n"); \
        fprintf(stderr, "║           Mocha Runtime Error                        ║\n"); \
        fprintf(stderr, "╠══════════════════════════════════════════════════════╣\n"); \
        fprintf(stderr, "║  Out of memory — allocation failed.                  ║\n"); \
        fprintf(stderr, "║  Try reducing data size or freeing unused objects.   ║\n"); \
        fprintf(stderr, "╚══════════════════════════════════════════════════════╝\n"); \
        fflush(stderr); \
        exit(2); \
    }

static inline void* mocha_malloc_safe(size_t size) {
    void* ptr = malloc(size);
    MOCHA_OOM_CHECK(ptr);
    return ptr;
}
#define malloc(size) mocha_malloc_safe(size)

/* ---- Bounds Checking ---- */

#define MOCHA_BOUNDS_CHECK_ROW(arr, row) \
    if ((row) < 0 || (row) >= (arr)->rows) { \
        fprintf(stderr, "Index_Out_Of_Bounds Error: row %d out of range [0, %d)\n", row, (arr)->rows); \
        exit(2); \
    }

#define MOCHA_BOUNDS_CHECK_COL(arr, col) \
    if ((col) < 0 || (col) >= (arr)->cols) { \
        fprintf(stderr, "Index_Out_Of_Bounds Error: col %d out of range [0, %d)\n", col, (arr)->cols); \
        exit(2); \
    }

#define MOCHA_EPSILON        1e-13
#define MOCHA_SORT_THRESHOLD 16

double mocha_call_lambda_float(MochaClosureBundle *b, void *a, void *c);

/* ---- Garbage Collector (orphaned) ---- */
#define GC_THRESHOLD  1024
#define MAX_ROOTS     4096

/* ---- Math ---- */
#define MOCHA_MATH_PI 3.14159265358979323846

/* ---- Dict Type Tags ---- */
#define MOCHA_DICT_INT    0
#define MOCHA_DICT_FLOAT  1
#define MOCHA_DICT_STR    2
#define MOCHA_DICT_BOOL   3
#define MOCHA_DICT_DICT   4
#define MOCHA_DICT_OBJECT 5
#define MOCHA_DICT_VAST   6

/* ---- Set Type Tags ---- */
#define MOCHA_SET_INT    0
#define MOCHA_SET_FLOAT  1
#define MOCHA_SET_STR    2
#define MOCHA_SET_BOOL   3
#define MOCHA_SET_VAST   4
#define MOCHA_SET_OBJECT 5

/* ---- HashTable Slot States ---- */
#define HT_EMPTY       0
#define HT_OCCUPIED    1
#define HT_MARKED      2   /* deleted — probe chain continues */
#define HT_LOAD_FACTOR 0.7f
#define HT_INIT_CAP    16

/* ---- Min/Max Generators ---- */
#define ARRAY_MINMAX(suffix, ctype)                                           \
ctype mocha_array_min_##suffix(MochaArray *arr) {                             \
    if (arr->length == 0) {                                                   \
        fprintf(stderr, "MochaRuntimeError: min() on empty array\n");        \
        _exit(2);                                                             \
    }                                                                         \
    ctype m;                                                                  \
    memcpy(&m, arr->data, sizeof(ctype));                                     \
    for (int32_t i = 1; i < arr->length; i++) {                              \
        ctype v;                                                              \
        memcpy(&v, (char*)arr->data + i * arr->elem_size, sizeof(ctype));    \
        if (v < m) m = v;                                                    \
    }                                                                         \
    return m;                                                                 \
}                                                                             \
ctype mocha_array_max_##suffix(MochaArray *arr) {                             \
    if (arr->length == 0) {                                                   \
        fprintf(stderr, "MochaRuntimeError: max() on empty array\n");        \
        _exit(2);                                                             \
    }                                                                         \
    ctype m;                                                                  \
    memcpy(&m, arr->data, sizeof(ctype));                                     \
    for (int32_t i = 1; i < arr->length; i++) {                              \
        ctype v;                                                              \
        memcpy(&v, (char*)arr->data + i * arr->elem_size, sizeof(ctype));    \
        if (v > m) m = v;                                                    \
    }                                                                         \
    return m;                                                                 \
}

#define SET_MINMAX(suffix, ctype)                                             \
ctype mocha_set_min_##suffix(MochaSet *s) {                                  \
    if (s->size == 0) {                                                       \
        fprintf(stderr, "MochaRuntimeError: min() on empty set\n");          \
        _exit(2);                                                             \
    }                                                                         \
    ctype m;                                                                  \
    memcpy(&m, s->data, sizeof(ctype));                                       \
    for (int32_t i = 1; i < s->size; i++) {                                  \
        ctype v;                                                              \
        memcpy(&v, (char*)s->data + i * s->elem_size, sizeof(ctype));        \
        if (v < m) m = v;                                                     \
    }                                                                         \
    return m;                                                                 \
}                                                                             \
ctype mocha_set_max_##suffix(MochaSet *s) {                                  \
    if (s->size == 0) {                                                       \
        fprintf(stderr, "MochaRuntimeError: max() on empty set\n");          \
        _exit(2);                                                             \
    }                                                                         \
    ctype m;                                                                  \
    memcpy(&m, s->data, sizeof(ctype));                                       \
    for (int32_t i = 1; i < s->size; i++) {                                  \
        ctype v;                                                              \
        memcpy(&v, (char*)s->data + i * s->elem_size, sizeof(ctype));        \
        if (v > m) m = v;                                                     \
    }                                                                         \
    return m;                                                                 \
}

/* ============================================================
 * GARBAGE COLLECTOR (exists orphaned in runtime. inits everything per compile but codegen uses nothing)
 *
 * Every string allocated by Mocha is wrapped in a GcNode:
 *   GcNode { marked, next, data[] }
 *
 * MARK phase: walk all roots, mark reachable nodes alive.
 * SWEEP phase: free all unmarked nodes.
 * Runs automatically when allocation count hits GC_THRESHOLD.
 * THIS WILL BE REPLACED BY REFERENCE COUNTING BECAUSE GC PAUSES FOR ML IS CATASTROPHIC
 * ============================================================ */

static GcNode  *gc_head        = NULL;
static size_t   gc_alloc_count = 0;
static char   **gc_roots[MAX_ROOTS];
static int      gc_root_count  = 0;


/* ---- GC Lifecycle ---- */

void mocha_gc_init() {
    signal(SIGSEGV, mocha_crash_handler);
    signal(SIGILL,  mocha_crash_handler); // illegal instruction
    gc_head = NULL;
    gc_alloc_count = 0;
    gc_root_count = 0;
}

void mocha_gc_shutdown() {
    /* Free old GC linked list */
    GcNode* node = gc_head;
    while (node) {
        GcNode* next = node->next;
        free(node);
        node = next;
    }
    gc_head = NULL;
    gc_alloc_count = 0;

    /* Free all RC allocations */
    MochaRCNode* rc_node = rc_head;
    while (rc_node) {
        MochaRCNode* next = rc_node->next;
        free(rc_node);
        rc_node = next;
    }
    rc_head = NULL;
}

void mocha_gc_add_root(char **root_ptr) {
    if (gc_root_count < MAX_ROOTS) gc_roots[gc_root_count++] = root_ptr;
}

void mocha_gc_remove_root(char **root_ptr) {
    for (int i = 0; i < gc_root_count; i++) {
        if (gc_roots[i] == root_ptr) { gc_roots[i] = gc_roots[--gc_root_count]; return; }
    }
}

static GcNode* ptr_to_node(char *ptr) {
    if (!ptr) return NULL;
    return (GcNode *)(ptr - offsetof(GcNode, data));
}

static void gc_mark() {
    for (GcNode *n = gc_head; n; n = n->next) n->marked = 0;
    for (int i = 0; i < gc_root_count; i++) {
        char *ptr = *gc_roots[i];
        if (!ptr) continue;
        GcNode *node = ptr_to_node(ptr);
        if (node) node->marked = 1;
    }
}

static void gc_sweep() {
    GcNode **current = &gc_head;
    while (*current) {
        GcNode *node = *current;
        if (!node->marked) { *current = node->next; free(node); gc_alloc_count--; }
        else current = &node->next;
    }
}

void mocha_gc_collect() { gc_mark(); gc_sweep(); }

static char* gc_alloc_string(size_t len) {
    //if (gc_alloc_count >= GC_THRESHOLD) mocha_gc_collect(); HAD STARTED DOING
    // DANGLING POINTERS SO NOW IT IS JUST A FAKE ARENA ALLOCATION!
    GcNode *node = (GcNode*)malloc(sizeof(GcNode) + len + 1);
    if (!node) { fprintf(stderr, "MochaRuntimeError: Out of memory!\n"); exit(2); }
    node->marked = 0; node->next = gc_head; gc_head = node; gc_alloc_count++;
    return node->data;
}

void mocha_gc_stats() {
    size_t total = 0;
    for (GcNode *n = gc_head; n; n = n->next) total++;
    printf("[GC] live objects: %zu | roots: %d\n", total, gc_root_count);
}

/* ============================================================
 * STRING OPERATIONS
 * ============================================================ */

/* ---- Core (alloc, concat, compare) ---- */

char* mocha_str_literal(char *src) {
    if (!src) return gc_alloc_string(0);
    size_t len = strlen(src);
    char *dest = gc_alloc_string(len);
    memcpy(dest, src, len + 1);
    return dest;
}

char* mocha_str_concat(char *a, char *b) {
    if (!a) a = ""; if (!b) b = "";
    size_t la = strlen(a), lb = strlen(b);
    char *dest = gc_alloc_string(la + lb);
    memcpy(dest, a, la); memcpy(dest + la, b, lb + 1);
    return dest;
}

int mocha_str_eq(char *a, char *b) {
    if (!a && !b) return 1; if (!a || !b) return 0;
    return strcmp(a, b) == 0 ? 1 : 0;
}

int mocha_wrap_isalpha_str(const char *s) { return isalpha((unsigned char)s[0]); }
int mocha_wrap_isdigit_str(const char *s) { return isdigit((unsigned char)s[0]); }

/* ---- Inspection ---- */
int32_t mocha_str_length(char *s) { 
    return s ? (int32_t)strlen(s) : 0; 
}

char* mocha_str_charat(char *s, int32_t index) {
    if (index < 0 || index >= (int32_t)strlen(s)) {
        fprintf(stderr, "MochaRuntimeError: charAt(%d) out of bounds for string of length %zu\n", index, strlen(s));
        exit(2);
    }
    char *result = gc_alloc_string(1);
    result[0] = s[index]; result[1] = '\0';
    return result;
}

/* ---- Type → str conversions ---- */
char* mocha_int_to_str(int32_t n) {
    char *dest = gc_alloc_string(12);
    snprintf(dest, 12, "%d", n);
    return dest;
}

char* mocha_float_to_str(double f) {
    char *dest = gc_alloc_string(32);
    snprintf(dest, 32, "%g", f);
    return dest;
}

char* mocha_bool_to_str(int8_t b) {
    return mocha_str_literal(b ? "true" : "false");
}

char* mocha_vast_to_str(int64_t n) {
    char *buf = gc_alloc_string(32);
    snprintf(buf, 32, "%lld", (long long)n);
    return buf;
}

/* ---- str → Type conversions ---- */
int64_t mocha_str_to_vast(char *s)  { return (int64_t)atoll(s); }
int32_t mocha_str_to_int(char *s)   { return (int32_t)atoi(s); }
double  mocha_str_to_float(char *s) { return atof(s); }
int8_t mocha_str_to_bool(char *s) { return (strcmp(s, "true") == 0 || strcmp(s, "1") == 0) ? 1 : 0; }

/* ---- Case conversion ---- */
char* mocha_str_toupper(char *s) {
    if (!s) return gc_alloc_string(0);
    size_t len = strlen(s);
    char *result = gc_alloc_string(len);
    for (size_t i = 0; i < len; i++) {
        result[i] = toupper((unsigned char)s[i]);
    }
    result[len] = '\0';
    return result;
}

char* mocha_str_tolower(char *s) {
    if (!s) return gc_alloc_string(0);
    size_t len = strlen(s);
    char *result = gc_alloc_string(len);
    for (size_t i = 0; i < len; i++) {
        result[i] = tolower((unsigned char)s[i]);
    }
    result[len] = '\0';
    return result;
}

static char* mocha_format_float(const char* val_str, int decimals) {
    // parse the string back to double, apply half-up rounding, reformat
    double val = atof(val_str);
    double factor = pow(10.0, decimals);
    double rounded = floor(val * factor + 0.5) / factor;
    char* buf = gc_alloc_string(32);
    snprintf(buf, 32, "%.*f", decimals, rounded);
    return buf;
}

static int mocha_parse_pipe_spec(const char* p, int* out_decimals) {
    // p points to char after '|'
    // format: Nf where N is digits
    int n = 0;
    int has_digits = 0;
    while (*p && isdigit(*p)) {
        n = n * 10 + (*p - '0');
        p++;
        has_digits = 1;
    }
    if (!has_digits || *p != 'f') return 0;  // not a valid specifier
    *out_decimals = n;
    return 1;  // valid
}

char* mocha_str_format(const char* template, char** args, int argc) {
    // Phase 1: calculate output length
    size_t out_len = 0;
    const char* p = template;

    while (*p) {
        if (*p == '\\' && *(p + 1) == '$') {
            out_len++;
            p += 2;
        } else if (*p == '$' && (isalpha(*(p+1)) || *(p+1) == '_')) {
            fprintf(stderr,
                "MochaRuntimeError (.format): positional format string contains named "
                "placeholder '$%c...'. Do not mix positional and named placeholders.\n",
                *(p+1));
            exit(2);
        } else if (*p == '$' && !isdigit(*(p+1))) {
            fprintf(stderr,
                "MochaRuntimeError (.format): invalid placeholder '$%c': "
                "'$' must be followed by a digit (positional) or letter/underscore (named)\n",
                *(p+1));
            exit(2);
        } else if (*p == '$' && isdigit(*(p+1))) {
            p++;
            int idx = 0;
            while (isdigit(*p)) {
                idx = idx * 10 + (*p - '0');
                p++;
            }
            if (isalpha(*p) || *p == '_') {
                fprintf(stderr,
                    "MochaRuntimeError (.format): invalid placeholder '$%d%c...': "
                    "positional index cannot be followed by letters.\n",
                    idx, *p);
                exit(2);
            }
            if (idx >= argc) {
                fprintf(stderr,
                    "MochaRuntimeError (.format): index $%d out of range "
                    "(%d argument%s provided)\n",
                    idx, argc, argc == 1 ? "" : "s");
                exit(2);
            }
            // check for pipe specifier
            if (*p == '|') {
                p++;
                int decimals = 0;
                if (!mocha_parse_pipe_spec(p, &decimals)) {
                    fprintf(stderr,
                        "MochaRuntimeError (.format): invalid format specifier after '|'. "
                        "Expected format: Nf (e.g. |2f)\n");
                    exit(2);
                }
                // skip past Nf
                while (isdigit(*p)) p++;
                p++;  // skip 'f'
                char* formatted = mocha_format_float(args[idx], decimals);
                out_len += strlen(formatted);
            } else {
                out_len += strlen(args[idx]);
            }
        } else {
            out_len++;
            p++;
        }
    }

    // Phase 2: build output
    char* out = gc_alloc_string(out_len + 1);
    char* q = out;
    p = template;

    while (*p) {
        if (*p == '\\' && *(p + 1) == '$') {
            *q++ = '$';
            p += 2;
        } else if (*p == '$' && isdigit(*(p+1))) {
            p++;
            int idx = 0;
            while (isdigit(*p)) {
                idx = idx * 10 + (*p - '0');
                p++;
            }
            if (*p == '|') {
                p++;
                int decimals = 0;
                mocha_parse_pipe_spec(p, &decimals);
                while (isdigit(*p)) p++;
                p++;  // skip 'f'
                char* formatted = mocha_format_float(args[idx], decimals);
                size_t slen = strlen(formatted);
                memcpy(q, formatted, slen);
                q += slen;
            } else {
                size_t slen = strlen(args[idx]);
                memcpy(q, args[idx], slen);
                q += slen;
            }
        } else {
            *q++ = *p++;
        }
    }
    *q = '\0';

    return out;
}

char* mocha_str_format_named(const char* template, char** keys, char** values, int argc) {
    // Phase 1: calculate output length
    size_t out_len = 0;
    const char* p = template;

    while (*p) {
        if (*p == '\\' && *(p + 1) == '$') {
            out_len++;
            p += 2;
        } else if (*p == '$') {
            p++;
            if (isdigit(*p)) {
                int idx = 0;
                while (isdigit(*p)) {
                    idx = idx * 10 + (*p - '0');
                    p++;
                }
                if (isalpha(*p) || *p == '_') {
                    fprintf(stderr,
                        "MochaRuntimeError (.format): invalid placeholder '$%d%c...': "
                        "positional index cannot be followed by letters.\n",
                        idx, *p);
                    exit(2);
                }
                fprintf(stderr,
                    "MochaRuntimeError (.format): named format string contains positional "
                    "placeholder '$%d'. Do not mix positional and named placeholders.\n",
                    idx);
                exit(2);
            } else if (isalpha(*p) || *p == '_') {
                char name[256]; int ni = 0;
                while (isalnum(*p) || *p == '_') {
                    if (ni >= 255) {
                        fprintf(stderr, "MochaRuntimeError (.format): placeholder name too long.\n");
                        exit(2);
                    }
                    name[ni++] = *p++;
                }
                name[ni] = '\0';

                // check for pipe specifier
                int decimals = -1;
                if (*p == '|') {
                    p++;
                    if (!mocha_parse_pipe_spec(p, &decimals)) {
                        fprintf(stderr,
                            "MochaRuntimeError (.format): invalid format specifier after '|'. "
                            "Expected format: Nf (e.g. |2f)\n");
                        exit(2);
                    }
                    while (isdigit(*p)) p++;
                    p++;  // skip 'f'
                }

                // look up key
                int found = 0;
                for (int i = 0; i < argc; i++) {
                    if (strcmp(keys[i], name) == 0) {
                        if (decimals >= 0) {
                            char* formatted = mocha_format_float(values[i], decimals);
                            out_len += strlen(formatted);
                        } else {
                            out_len += strlen(values[i]);
                        }
                        found = 1;
                        break;
                    }
                }
                if (!found) {
                    fprintf(stderr,
                        "MochaRuntimeError (.format): unknown named placeholder '$%s': "
                        "no matching argument provided\n", name);
                    exit(2);
                }
            } else {
                fprintf(stderr,
                    "MochaRuntimeError (.format): invalid placeholder '$%c': "
                    "'$' must be followed by a digit (positional) or letter/underscore (named)\n",
                    *p);
                exit(2);
            }
        } else {
            out_len++;
            p++;
        }
    }

    // Phase 2: build output
    char* out = gc_alloc_string(out_len + 1);
    char* q = out;
    p = template;

    while (*p) {
        if (*p == '\\' && *(p + 1) == '$') {
            *q++ = '$';
            p += 2;
        } else if (*p == '$') {
            p++;
            if (isalpha(*p) || *p == '_') {
                char name[256]; int ni = 0;
                while (isalnum(*p) || *p == '_') {
                    name[ni++] = *p++;
                }
                name[ni] = '\0';

                int decimals = -1;
                if (*p == '|') {
                    p++;
                    mocha_parse_pipe_spec(p, &decimals);
                    while (isdigit(*p)) p++;
                    p++;  // skip 'f'
                }

                for (int i = 0; i < argc; i++) {
                    if (strcmp(keys[i], name) == 0) {
                        char* val;
                        if (decimals >= 0) {
                            val = mocha_format_float(values[i], decimals);
                        } else {
                            val = values[i];
                        }
                        size_t slen = strlen(val);
                        memcpy(q, val, slen);
                        q += slen;
                        break;
                    }
                }
            }
            // positional/invalid already errored in phase 1
        } else {
            *q++ = *p++;
        }
    }
    *q = '\0';

    return out;
}

// ============================================================
// COMPLEX NUMBERS
// ============================================================

MochaComplex* mocha_complex_new(double real, double imag) {
    MochaComplex* c = (MochaComplex*)malloc(sizeof(MochaComplex));
    c->real = real;
    c->imag = imag;
    return c;
}

MochaComplex* mocha_complex_add(MochaComplex* a, MochaComplex* b) {
    return mocha_complex_new(a->real + b->real, a->imag + b->imag);
}

MochaComplex* mocha_complex_sub(MochaComplex* a, MochaComplex* b) {
    return mocha_complex_new(a->real - b->real, a->imag - b->imag);
}

MochaComplex* mocha_complex_mul(MochaComplex* a, MochaComplex* b) {
    return mocha_complex_new(
        a->real * b->real - a->imag * b->imag,
        a->real * b->imag + a->imag * b->real
    );
}

MochaComplex* mocha_complex_div(MochaComplex* a, MochaComplex* b) {
    double denom = b->real * b->real + b->imag * b->imag;
    if (denom == 0.0) {
        printf("MochaRuntimeError: Division by zero in Complex\n");
        exit(2);
    }
    return mocha_complex_new(
        (a->real * b->real + a->imag * b->imag) / denom,
        (a->imag * b->real - a->real * b->imag) / denom
    );
}

double mocha_complex_abs(MochaComplex* c) {
    return sqrt(c->real * c->real + c->imag * c->imag);
}

char* mocha_complex_tostring(MochaComplex* c) {
    char* buf = (char*)malloc(64);
    double real = fabs(c->real) < MOCHA_EPSILON ? 0.0 : c->real;
    double imag = fabs(c->imag) < MOCHA_EPSILON ? 0.0 : c->imag;
    if (imag >= 0)
        snprintf(buf, 64, "%.6g+%.6gim", real, imag);
    else
        snprintf(buf, 64, "%.6g%.6gim", real, imag);
    return buf;
}

MochaComplex* mocha_complex_conjugate(MochaComplex* c) {
    return mocha_complex_new(c->real, -c->imag);
}

/* ============================================================
 * PRINT FUNCTIONS
 * newline: 1 = print newline before value, 0 = don't
 * my \n is unique. it precees the string not suceeds it
 * ============================================================ */

void mocha_print_str(char *s, int8_t newline) {
    if (!s) s = "";
    if (newline) printf("\n");
    printf("%s", s);
    fflush(stdout);
}

void mocha_print_int(int32_t n, int8_t newline) {
    if (newline) printf("\n");
    printf("%d", n);
    fflush(stdout);
}

void mocha_print_float(double f, int8_t newline) {
    if (newline) printf("\n");
    if (isinf(f)) {
        printf("%s", f > 0 ? "POS Infinity" : "NEG Infinity");
    } else if (isnan(f)) {
        printf("From C's NaN: Number does exist.");
    } else if (f == (int64_t)f && f >= -1e15 && f <= 1e15) {
        printf("%.1f", f);
    } else {
        printf("%g", f);
    }
    fflush(stdout);
}

void mocha_print_bool(int8_t b, int8_t newline) {
    if (newline) printf("\n");
    printf("%s", b ? "true" : "false");
    fflush(stdout);
}

void mocha_print_vast(int64_t n, int8_t newline) {
    if (newline) printf("\n");
    printf("%lld", (long long)n);
    fflush(stdout);
}

/* ============================================================
 * FIXED-POINT FLOAT ARITHMETIC
 *
 * Scaled by 10^12 to avoid IEEE 754 errors like
 * 0.1 + 0.2 = 0.30000000000000004.
 * 
 * Upgraded with __int128 for add/sub to prevent overflow
 * ============================================================ */

 /* ---- Fixed-Point Arithmetic ---- */
#define MOCHA_DECIMAL_SCALE 1000000000000LL

typedef __int128 mocha_decimal;

static mocha_decimal decimal_from(double x) { 
    return (mocha_decimal)(x * (double)MOCHA_DECIMAL_SCALE);
}

static double decimal_to(mocha_decimal f) { 
    mocha_decimal int_part  = f / MOCHA_DECIMAL_SCALE;
    mocha_decimal frac_part = f % MOCHA_DECIMAL_SCALE;
    return (double)int_part + (double)frac_part / (double)MOCHA_DECIMAL_SCALE;
}

double mocha_float_add(double a, double b) { 
    if (a > 1e25 || a < -1e25 || b > 1e25 || b < -1e25) {
        return a + b;  // raw IEEE 754 fallback for large numbers
    }
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to(a_s + b_s);
}

double mocha_float_sub(double a, double b) { 
    if (a > 1e25 || a < -1e25 || b > 1e25 || b < -1e25) {
        return a - b;  // raw IEEE 754 fallback for large numbers
    }
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to(a_s - b_s);
}

double mocha_float_mul(double a, double b) {
    if (a > 1e25 || a < -1e25 || b > 1e25 || b < -1e25) {
        return a * b;  // raw IEEE 754 fallback for large numbers
    }
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to((a_s * b_s) / (mocha_decimal)MOCHA_DECIMAL_SCALE);
}

double mocha_float_div(double a, double b) {
    if (b == 0.0) { fprintf(stderr, "MochaRuntimeError: Division by zero!\n"); exit(2); }
    if (a > 1e25 || a < -1e25 || b > 1e25 || b < -1e25) {
        return a / b;  // raw IEEE 754 fallback for large numbers
    }
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to((a_s * (mocha_decimal)MOCHA_DECIMAL_SCALE) / b_s);
}

double mocha_float_mod(double a, double b) {
    if (b == 0.0) { fprintf(stderr, "MochaRuntimeError: Division by zero!\n"); exit(2); }
    if (a > 1e25 || a < -1e25 || b > 1e25 || b < -1e25) {
        return fmod(a, b);  // raw IEEE 754 fallback for large numbers
    }
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to(a_s % b_s);
}

/* ============================================================
 * 1D ARRAY RUNTIME
 * ============================================================ 
*/

/* ---- Internal helpers ---- */

static void bounds_check(MochaArray *arr, int32_t index) {
    if (index < 0 || index >= arr->length) {
        fprintf(stderr,
            "Index_Out_Of_Bounds Error: index %d is out of range.\n"
            "Hint: valid indices are 0 to %d\n",
            index, arr->length - 1);
        exit(2);
    }
}

static void fixed_check(MochaArray *arr, const char *op) {
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot %s a fixed-size array\n", op);
        exit(2);
    }
}

/* Grow capacity by 2x if needed */
static void ensure_capacity(MochaArray *arr) {
    if (arr->length < arr->capacity) return;
    arr->capacity = arr->capacity == 0 ? 8 : arr->capacity * 2;
    arr->data = realloc(arr->data, arr->capacity * arr->elem_size);
    MOCHA_OOM_CHECK(arr->data);
}

/* ---- Public API ---- */


int32_t mocha_array_length(MochaArray *arr) { return arr->length; }

MochaArray* mocha_array_new(int32_t capacity, int32_t elem_size, int32_t fixed) {
    MochaArray *arr = (MochaArray *)malloc(sizeof(MochaArray));
    int32_t cap = capacity > 0 ? capacity : 4;
    arr->data = calloc(cap, elem_size);
    MOCHA_OOM_CHECK(arr->data);
    arr->capacity  = cap;
    arr->elem_size = elem_size;
    arr->fixed     = fixed;
    
    if (fixed) {
        arr->length = cap;  // Static array: length = capacity
    } else {
        arr->length = 0;    // Dynamic array: starts empty
    }
    return arr;
}

MochaArray* mocha_array_alloc_filled(int32_t size, int32_t elem_size) {
    MochaArray *arr = mocha_array_new(size, elem_size, 1);  // fixed = 1 for static
    memset(arr->data, 0, size * elem_size);
    return arr;
}

void mocha_array_set(MochaArray *arr, int32_t index, void *value) {
    // For dynamic arrays: auto-resize if index is out of bounds
    if (!arr->fixed && index >= arr->length) {
        // Grow capacity as needed
        while (index >= arr->capacity) {
            arr->capacity = arr->capacity * 2;
            arr->data = realloc(arr->data, arr->capacity * arr->elem_size);
            MOCHA_OOM_CHECK(arr->data);
        }
        arr->length = index + 1;
    }
    
    bounds_check(arr, index);
    memcpy((char *)arr->data + index * arr->elem_size, value, arr->elem_size);
}

/* Init-time only — raw write during array literal construction.
 * No bounds check, no resize. Do not use for general assignment;
 * use mocha_array_set instead. */
void mocha_array_init_set(MochaArray *arr, int32_t index, void *value) {
    memcpy((char *)arr->data + index * arr->elem_size, value, arr->elem_size);
    if (index >= arr->length) arr->length = index + 1;
}

void mocha_array_get(MochaArray *arr, int32_t index, void *out) {
    bounds_check(arr, index);
    memcpy(out, (char *)arr->data + index * arr->elem_size, arr->elem_size);
}

MochaArray* mocha_array_copy(MochaArray *arr) {
    MochaArray *copy = (MochaArray *)malloc(sizeof(MochaArray));
    MOCHA_OOM_CHECK(copy);
    copy->data = malloc(arr->capacity * arr->elem_size);
    MOCHA_OOM_CHECK(copy->data);
    memcpy(copy->data, arr->data, arr->length * arr->elem_size);
    copy->length    = arr->length;
    copy->capacity  = arr->capacity;
    copy->fixed     = arr->fixed;
    copy->elem_size = arr->elem_size;
    return copy;
}

int32_t mocha_array_occs(MochaArray *arr, void *value) {
    int32_t count = 0;
    for (int32_t i = 0; i < arr->length; i++)
        if (memcmp((char *)arr->data + i * arr->elem_size, value, arr->elem_size) == 0)
            count++;
    return count;
}

void mocha_array_push(MochaArray *arr, void *value) {
    // Static arrays (the ones created by alloc) cannot be pushed to
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot push to static array (created with 'alloc'). Use indexing instead.");
        exit(2);
    }
    ensure_capacity(arr);
    memcpy((char *)arr->data + arr->length * arr->elem_size, value, arr->elem_size);
    arr->length++;
}

void mocha_array_push_front(MochaArray *arr, void *value) {
    // Static arrays cannot be pushed to
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot push_front to static array (created with 'alloc'). Use indexing instead.");
        exit(2);
    }
    ensure_capacity(arr);
    memmove((char *)arr->data + arr->elem_size, arr->data, arr->length * arr->elem_size);
    memcpy(arr->data, value, arr->elem_size);
    arr->length++;
}

void mocha_array_pop(MochaArray *arr, void *out) {
    // Static arrays cannot be popped from
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot pop from static array (created with 'alloc'). Static arrays have fixed size.");
        exit(2);
    }
    if (arr->length == 0) {
        fprintf(stderr, "MochaRuntimeError: Cannot pop from empty array\n");
        exit(2);
    }
    arr->length--;
    if (out) memcpy(out, (char *)arr->data + arr->length * arr->elem_size, arr->elem_size);
}

// Expand for each type — one line each!
ARRAY_MINMAX(int,   int32_t)
ARRAY_MINMAX(float, double)
ARRAY_MINMAX(vast,  int64_t)

char* mocha_array_min_str(MochaArray *arr) {
    if (arr->length == 0) {
        fprintf(stderr, "MochaRuntimeError: min() on empty array\n");
        _exit(2);
    }
    char *m;
    memcpy(&m, arr->data, sizeof(char*));
    for (int32_t i = 1; i < arr->length; i++) {
        char *v;
        memcpy(&v, (char*)arr->data + i * arr->elem_size, sizeof(char*));
        if (strcmp(v, m) < 0) m = v;
    }
    return m;
}

char* mocha_array_max_str(MochaArray *arr) {
    if (arr->length == 0) {
        fprintf(stderr, "MochaRuntimeError: max() on empty array\n");
        _exit(2);
    }
    char *m;
    memcpy(&m, arr->data, sizeof(char*));
    for (int32_t i = 1; i < arr->length; i++) {
        char *v;
        memcpy(&v, (char*)arr->data + i * arr->elem_size, sizeof(char*));
        if (strcmp(v, m) > 0) m = v;
    }
    return m;
}

/* Map a float lambda over every element, returning a new float array.
 * Straggler from mocha-processing — remainder of lib is in Mocha. */
MochaArray* mocha_map_float(MochaArray *arr, MochaClosureBundle *bundle) {
    MochaArray *result = mocha_array_new(arr->length, sizeof(double), 0);
    for (int32_t i = 0; i < arr->length; i++) {
        double x;
        mocha_array_get(arr, i, &x);
        double val = mocha_call_lambda_float(bundle, &x, NULL);
        mocha_array_push(result, &val);
    }
    return result;
}

/* ============================================================
 * 2D ARRAY RUNTIME
 * ============================================================
*/

/* ---- Internal helpers ---- */
//Allocate and zero-initialise a single row of `cols` elements
static MochaArray* alloc_row(int32_t cols, int32_t elem_size, int32_t fixed_c) {
    MochaArray *row = mocha_array_new(cols, elem_size, fixed_c);
    for (int32_t c = 0; c < cols; c++) {
        void *slot = calloc(1, elem_size);
        mocha_array_init_set(row, c, slot);
        free(slot);
    }
    return row;
}

static void resize_cols(MochaArray2D *arr, int32_t new_cols, int32_t elem_size) {
    for (int32_t r = 0; r < arr->rows; r++) {
        for (int32_t c = arr->cols; c < new_cols; c++) {
            void *slot = calloc(1, elem_size);
            mocha_array_init_set(arr->data[r], c, slot);
            free(slot);
        }
        arr->data[r]->length = arr->data[r]->capacity = new_cols;
    }
}

static void resize_rows(MochaArray2D *arr, int32_t new_rows,
                         int32_t new_cols, int32_t elem_size) {
    arr->data = (MochaArray **)realloc(arr->data, new_rows * sizeof(MochaArray *));
    MOCHA_OOM_CHECK(arr->data);
    for (int32_t r = arr->rows; r < new_rows; r++)
        arr->data[r] = alloc_row(new_cols, elem_size, arr->fixed_c);
}

/* ---- Access ---- */        // set, get, get_row, get_col, rows, cols
MochaArray2D* mocha_array2d_new(int32_t rows, int32_t cols,
                                 int32_t elem_size, int32_t fixed_r, int32_t fixed_c) {
    MochaArray2D *arr = (MochaArray2D *)malloc(sizeof(MochaArray2D));
    MOCHA_OOM_CHECK(arr);
    arr->rows     = rows;
    arr->cols     = cols;
    arr->elem_size = elem_size;
    arr->fixed_r  = fixed_r;
    arr->fixed_c  = fixed_c;
    arr->data = (MochaArray **)malloc(rows * sizeof(MochaArray *));
    MOCHA_OOM_CHECK(arr->data);
    for (int32_t r = 0; r < rows; r++)
        arr->data[r] = alloc_row(cols, elem_size, fixed_c);
    return arr;
}

void mocha_array2d_set(MochaArray2D *arr, int32_t row, int32_t col, void *value) {
    MOCHA_BOUNDS_CHECK_ROW(arr, row);
    MOCHA_BOUNDS_CHECK_COL(arr, col);
    mocha_array_set(arr->data[row], col, value);
}

void mocha_array2d_get(MochaArray2D *arr, int32_t row, int32_t col, void *out) {
    MOCHA_BOUNDS_CHECK_ROW(arr, row);
    MOCHA_BOUNDS_CHECK_COL(arr, col);
    mocha_array_get(arr->data[row], col, out);
}

MochaArray* mocha_array2d_get_row(MochaArray2D *arr, int32_t row) {
    MOCHA_BOUNDS_CHECK_ROW(arr, row);
    return arr->data[row];
}

MochaArray* mocha_array2d_get_col(MochaArray2D *arr, int32_t col) {
    MOCHA_BOUNDS_CHECK_COL(arr, col);
    MochaArray* result = mocha_array_new(arr->rows, arr->data[0]->elem_size, 0);
    for (int32_t r = 0; r < arr->rows; r++) {
        void* elem = (char*)arr->data[r]->data + col * arr->data[r]->elem_size;
        mocha_array_push(result, elem);
    }
    return result;
}

int32_t mocha_array2d_rows(MochaArray2D *arr) { return arr->rows; }
int32_t mocha_array2d_cols(MochaArray2D *arr) { return arr->cols; }

/* ---- Occurrence counting ---- */

int32_t mocha_array2d_occs(MochaArray2D *arr, void *value) {
    int32_t count = 0;
    for (int32_t r = 0; r < arr->rows; r++)
        count += mocha_array_occs(arr->data[r], value);
    return count;
}

int32_t mocha_array2d_occs_row(MochaArray2D *arr, void *value, int32_t row) {
    MOCHA_BOUNDS_CHECK_ROW(arr, row);
    return mocha_array_occs(arr->data[row], value);
}

int32_t mocha_array2d_occs_col(MochaArray2D *arr, void *value, int32_t col) {
    MOCHA_BOUNDS_CHECK_COL(arr, col);
    int32_t count = 0;
    for (int32_t r = 0; r < arr->rows; r++) {
        void *elem = (char *)arr->data[r]->data + col * arr->data[r]->elem_size;
        if (memcmp(elem, value, arr->data[r]->elem_size) == 0)
            count++;
    }
    return count;
}

int32_t mocha_array2d_occs_rowrange(MochaArray2D *arr, void *value,
                                     int32_t start, int32_t end) {
    if (start < 0 || end >= arr->rows || start > end) {
        fprintf(stderr, "Index_Out_Of_Bounds Error: row range [%d, %d] out of bounds\n", start, end);
        exit(2);
    }
    int32_t count = 0;
    for (int32_t r = start; r <= end; r++)
        count += mocha_array_occs(arr->data[r], value);
    return count;
}

int32_t mocha_array2d_occs_colrange(MochaArray2D *arr, void *value,
                                     int32_t start, int32_t end) {
    if (start < 0 || end >= arr->cols || start > end) {
        fprintf(stderr, "Index_Out_Of_Bounds Error: col range [%d, %d] out of bounds\n", start, end);
        exit(2);
    }
    int32_t count = 0;
    for (int32_t r = 0; r < arr->rows; r++) {
        for (int32_t c = start; c <= end; c++) {
            void *elem = (char *)arr->data[r]->data + c * arr->data[r]->elem_size;
            if (memcmp(elem, value, arr->data[r]->elem_size) == 0)
                count++;
        }
    }
    return count;
}

/* ---- Push row / col ---- */

void mocha_array2d_push_row(MochaArray2D *arr, MochaArray *row) {
    arr->data = (MochaArray **)realloc(arr->data, (arr->rows + 1) * sizeof(MochaArray *));
    MOCHA_OOM_CHECK(arr->data);
    arr->data[arr->rows] = row;
    arr->rows++;
    if (arr->cols == 0)
        arr->cols = row->length;
}

void mocha_array2d_push_col(MochaArray2D *arr, MochaArray *col) {
    if (col->length != arr->rows) {
        fprintf(stderr, "MochaRuntimeError: push_col column length %d does not match row count %d.\n",
                col->length, arr->rows);
        exit(2);
    }
    for (int32_t r = 0; r < arr->rows; r++) {
        void *elem = (char *)col->data + r * col->elem_size;
        mocha_array_push(arr->data[r], elem);
    }
    arr->cols++;
}

/* ---- Resize — grow only, never shrink ---- */
void mocha_array2d_resize(MochaArray2D *arr, int32_t new_rows,
                           int32_t new_cols, int32_t elem_size) {
    if (new_rows < arr->rows || new_cols < arr->cols) {
        fprintf(stderr, "MochaRuntimeError: resize() can only grow a 2D array, not shrink it.\n");
        exit(2);
    }
    if (new_cols > arr->cols) resize_cols(arr, new_cols, elem_size);
    if (new_rows > arr->rows) resize_rows(arr, new_rows, new_cols, elem_size);
    arr->rows = new_rows;
    arr->cols = new_cols;
}

/* ---- Drop row / col ---- */

void mocha_array2d_drop_row(MochaArray2D *arr, int32_t row) {
    MOCHA_BOUNDS_CHECK_ROW(arr, row);
    free(arr->data[row]->data);
    free(arr->data[row]);
    for (int32_t r = row; r < arr->rows - 1; r++)
        arr->data[r] = arr->data[r + 1];
    arr->rows--;
}

void mocha_array2d_drop_col(MochaArray2D *arr, int32_t col) {
    MOCHA_BOUNDS_CHECK_COL(arr, col);
    for (int32_t r = 0; r < arr->rows; r++) {
        char *data = (char *)arr->data[r]->data;
        for (int32_t c = col; c < arr->cols - 1; c++)
            memcpy(data + c * arr->elem_size,
                   data + (c + 1) * arr->elem_size,
                   arr->elem_size);
        arr->data[r]->length--;
    }
    arr->cols--;
}

/* ============================================================
 * TUPLE RUNTIME
 * ============================================================ */

MochaTuple* mocha_tuple_new(int32_t count) {
    MochaTuple *t = (MochaTuple*)malloc(sizeof(MochaTuple));
    MOCHA_OOM_CHECK(t);
    t->slots = (void**)malloc(count * sizeof(void*));
    MOCHA_OOM_CHECK(t->slots);
    t->count = count;
    return t;
}

void  mocha_tuple_set(MochaTuple *t, int32_t i, void *v) { 
    t->slots[i] = v; 
}

void* mocha_tuple_get(MochaTuple *t, int32_t i) {
    if (i < 0 || i >= t->count) {
        fprintf(stderr, "MochaRuntimeError: Tuple index %d out of range\n", i);
        exit(2);
    }
    return t->slots[i];
}

/* ============================================================
 * SORTING
 *
 * Hybrid sort: Selection sort for <= 16 elements (avoids
 * merge overhead on tiny arrays, not chosen insertion because of huge number of swaps in worst case), 
 * Merge sort above that.
 *
 * Why so many functions?
 *   C has no generics — int, float, str need separate typed
 *   variants. Comparator variants exist because Mocha lambdas
 *   are either simple function pointers or closure bundles
 *   (function + captured environment). That gives us:
 *
 *   Typed natural order:   sort_int, sort_float, sort_str
 *   Simple comparator:     sort_int_cmp, sort_float_cmp, sort_str_cmp
 *   Closure comparator:    sort_int_cmp_env, sort_float_cmp_env, sort_str_cmp_env
 * ============================================================ */

/* ---- INT ---- */

static void selection_sort_int(int32_t *a, int32_t n) {
    for (int32_t i = 0; i < n - 1; i++) {
        int32_t min = i;
        for (int32_t j = i + 1; j < n; j++)
            if (a[j] < a[min]) min = j;
        if (min != i) {
            int32_t tmp = a[i]; a[i] = a[min]; a[min] = tmp;
        }
    }
}

static void merge_int(int32_t *a, int32_t l, int32_t m, int32_t r) {
    int32_t n1 = m - l + 1, n2 = r - m;
    int32_t *L = malloc(n1 * sizeof(int32_t));
    int32_t *R = malloc(n2 * sizeof(int32_t));

    for (int32_t i = 0; i < n1; i++) L[i] = a[l + i];
    for (int32_t i = 0; i < n2; i++) R[i] = a[m + 1 + i];

    int32_t i = 0, j = 0, k = l;
    while (i < n1 && j < n2)
        a[k++] = L[i] <= R[j] ? L[i++] : R[j++];
    while (i < n1) a[k++] = L[i++];
    while (j < n2) a[k++] = R[j++];

    free(L); free(R);
}

static void merge_sort_int(int32_t *a, int32_t l, int32_t r) {
    if (r - l + 1 <= MOCHA_SORT_THRESHOLD) {
        selection_sort_int(a + l, r - l + 1);
        return;
    }
    int32_t m = l + (r - l) / 2;
    merge_sort_int(a, l, m);
    merge_sort_int(a, m + 1, r);
    merge_int(a, l, m, r);
}

void mocha_sort_int(MochaArray *arr) {
    if (arr->length > 1)
        merge_sort_int((int32_t *)arr->data, 0, arr->length - 1);
}

/* ---- FLOAT ---- */

static void selection_sort_float(double *a, int32_t n) {
    for (int32_t i = 0; i < n - 1; i++) {
        int32_t min = i;
        for (int32_t j = i + 1; j < n; j++)
            if (a[j] < a[min]) min = j;
        if (min != i) {
            double tmp = a[i]; a[i] = a[min]; a[min] = tmp;
        }
    }
}

static void merge_float(double *a, int32_t l, int32_t m, int32_t r) {
    int32_t n1 = m - l + 1, n2 = r - m;
    double *L = malloc(n1 * sizeof(double));
    double *R = malloc(n2 * sizeof(double));

    for (int32_t i = 0; i < n1; i++) L[i] = a[l + i];
    for (int32_t i = 0; i < n2; i++) R[i] = a[m + 1 + i];

    int32_t i = 0, j = 0, k = l;
    while (i < n1 && j < n2)
        a[k++] = L[i] <= R[j] ? L[i++] : R[j++];
    while (i < n1) a[k++] = L[i++];
    while (j < n2) a[k++] = R[j++];

    free(L); free(R);
}

static void merge_sort_float(double *a, int32_t l, int32_t r) {
    if (r - l + 1 <= MOCHA_SORT_THRESHOLD) {
        selection_sort_float(a + l, r - l + 1);
        return;
    }
    int32_t m = l + (r - l) / 2;
    merge_sort_float(a, l, m);
    merge_sort_float(a, m + 1, r);
    merge_float(a, l, m, r);
}

void mocha_sort_float(MochaArray *arr) {
    if (arr->length > 1)
        merge_sort_float((double *)arr->data, 0, arr->length - 1);
}

/* ---- STR ---- */

static void selection_sort_str(char **a, int32_t n) {
    for (int32_t i = 0; i < n - 1; i++) {
        int32_t min = i;
        for (int32_t j = i + 1; j < n; j++)
            if (strcmp(a[j], a[min]) < 0) min = j;
        if (min != i) {
            char *tmp = a[i]; a[i] = a[min]; a[min] = tmp;
        }
    }
}

static void merge_str(char **a, int32_t l, int32_t m, int32_t r) {
    int32_t n1 = m - l + 1, n2 = r - m;
    char **L = malloc(n1 * sizeof(char *));
    char **R = malloc(n2 * sizeof(char *));

    for (int32_t i = 0; i < n1; i++) L[i] = a[l + i];
    for (int32_t i = 0; i < n2; i++) R[i] = a[m + 1 + i];

    int32_t i = 0, j = 0, k = l;
    while (i < n1 && j < n2)
        a[k++] = strcmp(L[i], R[j]) <= 0 ? L[i++] : R[j++];
    while (i < n1) a[k++] = L[i++];
    while (j < n2) a[k++] = R[j++];

    free(L); free(R);
}

static void merge_sort_str(char **a, int32_t l, int32_t r) {
    if (r - l + 1 <= MOCHA_SORT_THRESHOLD) {
        selection_sort_str(a + l, r - l + 1);
        return;
    }
    int32_t m = l + (r - l) / 2;
    merge_sort_str(a, l, m);
    merge_sort_str(a, m + 1, r);
    merge_str(a, l, m, r);
}

void mocha_sort_str(MochaArray *arr) {
    if (arr->length > 1)
        merge_sort_str((char **)arr->data, 0, arr->length - 1);
}

/* ============================================================
 * SIMPLE COMPARATOR — no closure, plain function pointer
 *
 * Elements are boxed as void* pointers so one sort engine
 * works for all types. After sorting the pointers, values
 * are copied back into the original array.
 * ============================================================ */

static void selection_sort_cmp(void **a, int32_t n, MochaCmpFn cmp) {
    for (int32_t i = 0; i < n - 1; i++) {
        int32_t min = i;
        for (int32_t j = i + 1; j < n; j++)
            if (cmp(a[j], a[min])) min = j;
        if (min != i) {
            void *tmp = a[i]; a[i] = a[min]; a[min] = tmp;
        }
    }
}

static void merge_cmp(void **a, int32_t l, int32_t m, int32_t r, MochaCmpFn cmp) {
    int32_t n1 = m - l + 1, n2 = r - m;
    void **L = malloc(n1 * sizeof(void *));
    void **R = malloc(n2 * sizeof(void *));

    for (int32_t i = 0; i < n1; i++) L[i] = a[l + i];
    for (int32_t i = 0; i < n2; i++) R[i] = a[m + 1 + i];

    int32_t i = 0, j = 0, k = l;
    while (i < n1 && j < n2)
        a[k++] = cmp(L[i], R[j]) ? L[i++] : R[j++];
    while (i < n1) a[k++] = L[i++];
    while (j < n2) a[k++] = R[j++];

    free(L); free(R);
}

static void merge_sort_cmp(void **a, int32_t l, int32_t r, MochaCmpFn cmp) {
    if (r - l + 1 <= MOCHA_SORT_THRESHOLD) {
        selection_sort_cmp(a + l, r - l + 1, cmp);
        return;
    }
    int32_t m = l + (r - l) / 2;
    merge_sort_cmp(a, l, m, cmp);
    merge_sort_cmp(a, m + 1, r, cmp);
    merge_cmp(a, l, m, r, cmp);
}

/* Box int array into void* pointers, sort, copy back */
void mocha_sort_int_cmp(MochaArray *arr, MochaCmpFn cmp) {
    if (arr->length <= 1) return;
    int32_t *data = (int32_t *)arr->data;

    void **ptrs = malloc(arr->length * sizeof(void *));
    for (int32_t i = 0; i < arr->length; i++)
        ptrs[i] = &data[i];

    merge_sort_cmp(ptrs, 0, arr->length - 1, cmp);

    int32_t *sorted = malloc(arr->length * sizeof(int32_t));
    for (int32_t i = 0; i < arr->length; i++)
        sorted[i] = *(int32_t *)ptrs[i];

    memcpy(arr->data, sorted, arr->length * sizeof(int32_t));
    free(sorted);
    free(ptrs);
}

/* Box float array into void* pointers, sort, copy back */
void mocha_sort_float_cmp(MochaArray *arr, MochaCmpFn cmp) {
    if (arr->length <= 1) return;
    double *data = (double *)arr->data;

    void **ptrs = malloc(arr->length * sizeof(void *));
    for (int32_t i = 0; i < arr->length; i++)
        ptrs[i] = &data[i];

    merge_sort_cmp(ptrs, 0, arr->length - 1, cmp);

    double *sorted = malloc(arr->length * sizeof(double));
    for (int32_t i = 0; i < arr->length; i++)
        sorted[i] = *(double *)ptrs[i];

    memcpy(arr->data, sorted, arr->length * sizeof(double));
    free(sorted);
    free(ptrs);
}

/* Strings are already pointers — box as void*, sort, write back */
void mocha_sort_str_cmp(MochaArray *arr, MochaCmpFn cmp) {
    if (arr->length <= 1) return;
    char **data = (char **)arr->data;

    void **ptrs = malloc(arr->length * sizeof(void *));
    for (int32_t i = 0; i < arr->length; i++)
        ptrs[i] = data[i];

    merge_sort_cmp(ptrs, 0, arr->length - 1, cmp);

    for (int32_t i = 0; i < arr->length; i++)
        data[i] = (char *)ptrs[i];

    free(ptrs);
}

/* ============================================================
 * CLOSURE COMPARATOR — env-aware, carries captured variables
 *
 * A MochaClosureBundle wraps a function pointer + environment
 * pointer (the captured variables from the lambda's scope).
 * The sort engine passes env to every comparison call.
 * ============================================================ */

int32_t mocha_call_lambda_int  (MochaClosureBundle *b, void *a, void *c) { return (int32_t)((LambdaIntFn)b->fn)(a, c, b->env); }
double  mocha_call_lambda_float(MochaClosureBundle *b, void *a, void *c) { return          ((LambdaFltFn)b->fn)(a, c, b->env); }
char*   mocha_call_lambda_str  (MochaClosureBundle *b, void *a, void *c) { return          ((LambdaStrFn)b->fn)(a, c, b->env); }
int8_t  mocha_call_lambda_bool (MochaClosureBundle *b, void *a)          { return          ((LambdaIntFn)b->fn)(a, NULL, b->env); }

static void selection_sort_cmp_env(void **a, int32_t n, MochaCmpEnvFn cmp, void *env) {
    for (int32_t i = 0; i < n - 1; i++) {
        int32_t min = i;
        for (int32_t j = i + 1; j < n; j++)
            if (cmp(a[j], a[min], env)) min = j;
        if (min != i) {
            void *tmp = a[i]; a[i] = a[min]; a[min] = tmp;
        }
    }
}

static void merge_cmp_env(void **a, int32_t l, int32_t m, int32_t r,
                          MochaCmpEnvFn cmp, void *env) {
    int32_t n1 = m - l + 1, n2 = r - m;
    void **L = malloc(n1 * sizeof(void *));
    void **R = malloc(n2 * sizeof(void *));

    for (int32_t i = 0; i < n1; i++) L[i] = a[l + i];
    for (int32_t i = 0; i < n2; i++) R[i] = a[m + 1 + i];

    int32_t i = 0, j = 0, k = l;
    while (i < n1 && j < n2)
        a[k++] = cmp(L[i], R[j], env) ? L[i++] : R[j++];
    while (i < n1) a[k++] = L[i++];
    while (j < n2) a[k++] = R[j++];

    free(L); free(R);
}

static void merge_sort_cmp_env(void **a, int32_t l, int32_t r,
                                MochaCmpEnvFn cmp, void *env) {
    if (r - l + 1 <= MOCHA_SORT_THRESHOLD) {
        selection_sort_cmp_env(a + l, r - l + 1, cmp, env);
        return;
    }
    int32_t m = l + (r - l) / 2;
    merge_sort_cmp_env(a, l, m, cmp, env);
    merge_sort_cmp_env(a, m + 1, r, cmp, env);
    merge_cmp_env(a, l, m, r, cmp, env);
}

/*
 * Generic closure sort engine — works for any element size.
 * Boxes elements as void* pointers, sorts them via the closure
 * comparator, then copies the sorted values back in place.
 */
static void sort_generic_cmp_env(MochaArray *arr, MochaClosureBundle *bundle) {
    if (arr->length <= 1) return;

    int32_t n     = arr->length;
    int32_t esize = arr->elem_size;

    /* Copy data so pointer arithmetic is stable during sort */
    void *data_copy = malloc(n * esize);
    memcpy(data_copy, arr->data, n * esize);

    /* Box each element as a void* into a pointer array */
    void **ptrs = malloc(n * sizeof(void *));
    for (int32_t i = 0; i < n; i++)
        ptrs[i] = (char *)data_copy + i * esize;

    merge_sort_cmp_env(ptrs, 0, n - 1,
                       (MochaCmpEnvFn)bundle->fn, bundle->env);

    /* Copy sorted elements back into the original array */
    void *sorted = malloc(n * esize);
    for (int32_t i = 0; i < n; i++)
        memcpy((char *)sorted + i * esize, ptrs[i], esize);

    memcpy(arr->data, sorted, n * esize);

    free(sorted);
    free(ptrs);
    free(data_copy);
}

/* Public entry points — all delegate to the generic engine */
void mocha_sort_int_cmp_env  (MochaArray *arr, MochaClosureBundle *b) { sort_generic_cmp_env(arr, b); }
void mocha_sort_float_cmp_env(MochaArray *arr, MochaClosureBundle *b) { sort_generic_cmp_env(arr, b); }
void mocha_sort_str_cmp_env  (MochaArray *arr, MochaClosureBundle *b) { sort_generic_cmp_env(arr, b); }

/* ============================================================
 * MATH EXTENSIONS (mocha-math runtime)
 *
 * Float extension methods: sin, cos, tan, inv_sin, inv_cos,
 * inv_tan, sqrt, cubrot, log, log2, log10.
 * Standalone: pow, derivative, integral, limit, limit_inf.
 *
 * Return type policy:
 *   sqrt, log, log2, log10  → MochaComplex* (imaginary when domain requires)
 *   tan(π/2)                → double INFINITY (IEEE 754, no crash)
 *   inv_sin/inv_cos outside [-1,1] → MochaComplex* (fully defined)
 * ============================================================ */

double mocha_ext_float_sin(double x, int32_t mes) {
    if (mes == 1) x = x * MOCHA_MATH_PI / 180.0;
    double r = sin(x);
    return fabs(r) < MOCHA_EPSILON ? 0.0 : r;
}

double mocha_ext_float_cos(double x, int32_t mes) {
    if (mes == 1) x = x * MOCHA_MATH_PI / 180.0;
    double r = cos(x);
    return fabs(r) < MOCHA_EPSILON ? 0.0 : r;
}

double mocha_ext_float_tan(double x, int32_t mes) {
    if (mes == 1) x = x * MOCHA_MATH_PI / 180.0;
    if (fabs(cos(x)) < MOCHA_EPSILON) {
        fprintf(stderr, "MochaWarning (tan): argument %.6g is at a pole (cos = 0), returning Inf\n", x);
        return INFINITY;
    }
    double r = tan(x);
    return fabs(r) < MOCHA_EPSILON ? 0.0 : r;
}

double mocha_ext_float_cosec_impl(double x, int32_t mes) {
    return 1.0 / mocha_ext_float_sin(x, mes);
}
double mocha_ext_float_sec_impl(double x, int32_t mes) {
    return 1.0 / mocha_ext_float_cos(x, mes);
}
double mocha_ext_float_cot_impl(double x, int32_t mes) {
    return 1.0 / mocha_ext_float_tan(x, mes);
}

MochaComplex* mocha_ext_float_inv_sin(double x) {
    if (x >= -1.0 && x <= 1.0)
        return mocha_complex_new(asin(x), 0.0);
    fprintf(stderr, "MochaWarning (inv_sin): argument %.6g is outside real domain [-1, 1], returning complex result\n", x);
    double inner = x + sqrt(x * x - 1.0);
    if (x > 1.0)
        return mocha_complex_new(MOCHA_MATH_PI / 2.0, -log(inner));
    else
        return mocha_complex_new(3.0 * MOCHA_MATH_PI / 2.0, -log(-inner));
}

MochaComplex* mocha_ext_float_inv_cos(double x) {
    if (x >= -1.0 && x <= 1.0)
        return mocha_complex_new(acos(x), 0.0);
    fprintf(stderr, "MochaWarning (inv_cos): argument %.6g is outside real domain [-1, 1], returning complex result\n", x);
    MochaComplex* s = mocha_ext_float_inv_sin(x);
    return mocha_complex_new(MOCHA_MATH_PI / 2.0 - s->real, -s->imag);
}

double mocha_ext_float_inv_tan(double x) { return atan(x); }

MochaComplex* mocha_ext_float_inv_cosec_impl(double x) {
    double recip = 1.0 / x;
    return mocha_ext_float_inv_sin(recip);
}

MochaComplex* mocha_ext_float_inv_sec_impl(double x) {
    double recip = 1.0 / x;
    return mocha_ext_float_inv_cos(recip);
}

double mocha_ext_float_inv_cot_impl(double x) {
    double recip = 1.0 / x;
    return mocha_ext_float_inv_tan(recip);
}

/* ── Hyperbolic Trig ── */

double mocha_ext_float_sinh(double x) {
    return sinh(x);
}

double mocha_ext_float_cosh(double x) {
    return cosh(x);
}

double mocha_ext_float_tanh(double x) {
    return tanh(x);
}

double mocha_ext_float_inv_sinh(double x) {
    // defined for all real x — no domain restriction
    return asinh(x);
}

MochaComplex* mocha_ext_float_inv_cosh(double x) {
    if (x >= 1.0)
        return mocha_complex_new(acosh(x), 0.0);
    fprintf(stderr, "MochaWarning (inv_cosh): argument %.6g is outside real domain (x >= 1), returning complex result\n", x);
    return mocha_complex_new(0.0, acos(x));
}

double mocha_ext_float_inv_tanh(double x) {
    if (x <= -1.0) {
        fprintf(stderr, "MochaWarning (inv_tanh): argument %.6g is outside domain |x| < 1, returning -Inf\n", x);
        return -INFINITY;
    }
    if (x >= 1.0) {
        fprintf(stderr, "MochaWarning (inv_tanh): argument %.6g is outside domain |x| < 1, returning Inf\n", x);
        return INFINITY;
    }
    return atanh(x);
}

/* ── Reciprocal Hyperbolic ── */

double mocha_ext_float_cosech_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (cosech): argument is 0, cosech is undefined at 0.\n");
        exit(2);
    }
    return 1.0 / sinh(x);
}

double mocha_ext_float_sech_c(double x) {
    // cosh(x) >= 1 always, never zero — no domain error possible
    return 1.0 / cosh(x);
}

double mocha_ext_float_coth_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (coth): argument is 0, coth is undefined at 0.\n");
        exit(2);
    }
    return 1.0 / tanh(x);
}

/* ── Inverse Reciprocal Hyperbolic ── */

double mocha_ext_float_inv_cosech_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (inv_cosech): argument is 0, inv_cosech is undefined at 0.\n");
        exit(2);
    }
    // inv_cosech(x) = asinh(1/x) — defined for all x != 0
    return asinh(1.0 / x);
}

MochaComplex* mocha_ext_float_inv_sech_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (inv_sech): argument is 0, inv_sech is undefined at 0.\n");
        exit(2);
    }
    // inv_sech(x) = inv_cosh(1/x), real only for 0 < x <= 1
    double arg = 1.0 / x;
    if (arg >= 1.0)
        return mocha_complex_new(acosh(arg), 0.0);
    fprintf(stderr, "MochaWarning (inv_sech): argument %.6g is outside real domain (0 < x <= 1), returning complex result\n", x);
    return mocha_complex_new(0.0, acos(arg));
}

double mocha_ext_float_inv_coth_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (inv_coth): argument is 0, inv_coth is undefined at 0.\n");
        exit(2);
    }
    // inv_coth(x) = inv_tanh(1/x), real only for |x| > 1
    double arg = 1.0 / x;
    if (arg <= -1.0) {
        fprintf(stderr, "MochaWarning (inv_coth): argument %.6g is outside domain |x| > 1, returning -Inf\n", x);
        return -INFINITY;
    }
    if (arg >= 1.0) {
        fprintf(stderr, "MochaWarning (inv_coth): argument %.6g is outside domain |x| > 1, returning Inf\n", x);
        return INFINITY;
    }
    return atanh(arg);
}

MochaComplex* mocha_ext_float_sqrt(double x) {
    if (x >= 0.0) {
        return mocha_complex_new(sqrt(x), 0.0);
    } else {
        return mocha_complex_new(0.0, sqrt(-x));
    }
}

double mocha_ext_float_cubrot(double x) { return cbrt(x); }

MochaComplex* mocha_ext_float_log(double x) {
    if (x == 0.0) return mocha_complex_new(-INFINITY, 0.0);
    if (x < 0.0)  return mocha_complex_new(log(fabs(x)), MOCHA_MATH_PI);
    return mocha_complex_new(log(x), 0.0);
}

MochaComplex* mocha_ext_float_log2(double x) {
    if (x == 0.0) return mocha_complex_new(-INFINITY, 0.0);
    if (x < 0.0)  return mocha_complex_new(log2(fabs(x)), MOCHA_MATH_PI / log(2.0));
    return mocha_complex_new(log2(x), 0.0);
}

MochaComplex* mocha_ext_float_log10(double x) {
    if (x == 0.0) return mocha_complex_new(-INFINITY, 0.0);
    if (x < 0.0)  return mocha_complex_new(log10(fabs(x)), MOCHA_MATH_PI / log(10.0));
    return mocha_complex_new(log10(x), 0.0);
}

double mocha_math_fast_pow(double base, int32_t n) {
    double result = 1.0;
    int negative = n < 0;
    if (negative) n = -n;
    while (n > 0) {
        if (n & 1) result *= base;
        base *= base;
        n >>= 1;
    }
    return negative ? 1.0 / result : result;
}

double mocha_math_c_pow(double base, double exp) {
    if (base < 0.0) { fprintf(stderr, "MochaMathError: c_pow requires positive base\n"); exit(2); }
    return pow(base, exp);
}

// Note: uses libm transcendental functions internally,
// IEEE 754 drift possible, unlike innate Mocha functions. MOCHA_EPSILON compensates
// for near-zero libm artifacts.
MochaComplex* mocha_math_complex_pow(MochaComplex* base, double exp) {
    double r     = sqrt(base->real * base->real + base->imag * base->imag);
    double theta = atan2(base->imag, base->real);

    double new_r     = pow(r, exp);
    double new_theta = exp * theta;

    double real = new_r * cos(new_theta);
    double imag = new_r * sin(new_theta);
    return mocha_complex_new(
        fabs(real) < MOCHA_EPSILON ? 0.0 : real,
        fabs(imag) < MOCHA_EPSILON ? 0.0 : imag
    );
}

/* Numerical derivative: central difference, h = 1e-7 */
double mocha_math_derivative(double x, MochaClosureBundle *bundle) {
    double h = 1e-7;
    double *box1 = malloc(sizeof(double)), *box2 = malloc(sizeof(double));
    *box1 = x + h; *box2 = x - h;
    MochaFloatLambdaFn fn = (MochaFloatLambdaFn)bundle->fn;
    double r = (fn(box1, bundle->env) - fn(box2, bundle->env)) / (2.0 * h);
    free(box1); free(box2);
    return r;
}

/* Numerical integral: Simpson's rule, adaptive n */
double mocha_math_integral(MochaClosureBundle *bundle, double a, double b) {
    int32_t n = (int32_t)(fabs(b - a) * 1000);
    if (n < 100)    n = 100;
    if (n > 100000) n = 100000;
    if (n % 2 != 0) n++;

    double h = (b - a) / n;
    MochaFloatLambdaFn fn = (MochaFloatLambdaFn)bundle->fn;
    double *box = malloc(sizeof(double));

    *box = a; double sum = fn(box, bundle->env);
    *box = b; sum += fn(box, bundle->env);

    for (int32_t i = 1; i < n; i++) {
        *box = a + i * h;
        sum += (i % 2 == 0) ? 2.0 * fn(box, bundle->env) : 4.0 * fn(box, bundle->env);
    }

    free(box);
    return (h / 3.0) * sum;
}

/* Limit: average of left/right approach, h = 1e-9 */
double mocha_math_limit(double x, MochaClosureBundle *bundle) {
    double h = 1e-9;
    MochaFloatLambdaFn fn = (MochaFloatLambdaFn)bundle->fn;
    double *br = malloc(sizeof(double)), *bl = malloc(sizeof(double));
    *br = x + h; double right = fn(br, bundle->env);
    *bl = x - h; double left  = fn(bl, bundle->env);
    free(br); free(bl);
    double diff = fabs(right - left);
    if (diff > 1e-6)
        fprintf(stderr, "\n### BEWARE!! limit at x=%g may not exist. Left: %g, Right: %g — returning average.\n\n", x, left, right);
    return (right + left) / 2.0;
}

/* Limit at infinity: evaluate at 1e300 */
double mocha_math_limit_inf(MochaClosureBundle *bundle) {
    double *box = malloc(sizeof(double));
    *box = 1e300;
    double r = ((MochaFloatLambdaFn)bundle->fn)(box, bundle->env);
    free(box);
    return r;
}

int32_t mocha_rand_int(int32_t min, int32_t max) {
    return min + (rand() % (max - min + 1));
}

int64_t mocha_rand_vast(int64_t min, int64_t max) {
    return min + (rand() % (max - min + 1));
}

double mocha_rand_float(double min, double max) {
    return min + ((double)rand() / (double)RAND_MAX) * (max - min);
}

void* mocha_rand_seed(int32_t seed) {
    srand((unsigned int)seed);
    return NULL;
}

/* ============================================================
 * Cryptographic RNG — cross-platform
 * Windows:        BCryptGenRandom
 * Linux/macOS:    getrandom() (Linux 3.17+) / getentropy() (macOS 10.12+)
 * ============================================================ */

#ifdef _WIN32
    #include <bcrypt.h>
    #pragma comment(lib, "bcrypt.lib")

    static void crypto_random_bytes(void* buf, size_t n) {
        BCryptGenRandom(NULL, (PUCHAR)buf, (ULONG)n, BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    }

#elif defined(__APPLE__)
    #include <sys/random.h>

    static void crypto_random_bytes(void* buf, size_t n) {
        getentropy(buf, n);   // blocks until entropy available, never fails on macOS 10.12+
    }

#else
    // Linux
    #include <sys/random.h>

    static void crypto_random_bytes(void* buf, size_t n) {
        ssize_t got = getrandom(buf, n, 0);  // 0 = block until ready
        (void)got;
    }

#endif

/* ── All functions below are now platform-agnostic ── */

int mocha_bcrypt_rand_int(int min, int max) {
    if (min >= max) return min;
    unsigned int range = (unsigned int)(max - min + 1);
    unsigned int limit = UINT_MAX - (UINT_MAX % range);
    unsigned int raw;
    do {
        crypto_random_bytes(&raw, sizeof(raw));
    } while (raw >= limit);
    return min + (int)(raw % range);
}

double mocha_bcrypt_rand_float(double min, double max) {
    unsigned int raw = 0;
    crypto_random_bytes(&raw, sizeof(raw));
    double normalized = (double)raw / (double)UINT_MAX;
    return min + normalized * (max - min);
}

double mocha_bcrypt_rand_unit() {
    unsigned int raw = 0;
    crypto_random_bytes(&raw, sizeof(raw));
    return (double)raw / (double)UINT_MAX;
}

const char* mocha_bcrypt_rand_ints(int min, int max, int count) {
    if (count <= 0 || count > 10000) return "";
    static char buf[131072];
    buf[0] = '\0';
    int pos = 0;
    for (int i = 0; i < count; i++) {
        unsigned int raw = 0;
        crypto_random_bytes(&raw, sizeof(raw));
        int range = max - min + 1;
        int val = min + (int)(raw % (unsigned int)range);
        pos += snprintf(buf + pos, sizeof(buf) - pos,
                       i < count-1 ? "%d|" : "%d", val);
    }
    return buf;
}

int mocha_bcrypt_rand_bool() {
    unsigned char raw = 0;
    crypto_random_bytes(&raw, sizeof(raw));
    return raw % 2;
}

int mocha_bcrypt_rand_seed() {
    unsigned int raw = 0;
    crypto_random_bytes(&raw, sizeof(raw));
    return (int)(raw & 0x7FFFFFFF);
}

/* ============================================================
 * MOCHA-SYMCHA / MOCHA-MATVEC STRAGGLER WRAPPERS
 *
 * Plain C math passthroughs — remainder of these libs is
 * implemented in Mocha itself via dogfooding.
 *
 * These cannot be implemented in Mocha because they map
 * directly to hardware instructions (x86: fsin, fcos, fsqrt)
 * via C's math.h. Calling them through Mocha would add
 * unnecessary indirection over already-optimal CPU ops.
 * Also these are needed when I cannot afford my great Complex Semantices 😂
 * ============================================================ */

double mocha_wrap_sin(double x)  { return sin(x);  }
double mocha_wrap_cos(double x)  { return cos(x);  }
double mocha_wrap_log(double x)  { return log(x);  }
double mocha_wrap_tan(double x)  { return tan(x); }
double mocha_wrap_asin(double x) { return asin(x); }
double mocha_wrap_acos(double x) { return acos(x); }
double mocha_wrap_atan(double x) { return atan(x); }
double mocha_wrap_sinh(double x) { return sinh(x); }
double mocha_wrap_cosh(double x) { return cosh(x); }
double mocha_wrap_tanh(double x) { return tanh(x); }
double mocha_wrap_asinh(double x) { return asinh(x); }
double mocha_wrap_atanh(double x) { return atanh(x); }
double mocha_wrap_sqrt_f(double x) { return sqrt(x); }

/* ============================================================
 * DICT RUNTIME
 *
 * Hash map (not so real one LoL because HashTable is the actual one if you need) 
 * with string keys and typed values.
 * Supports int, float, str, bool, nested dict, and opaque objects.
 * Fuzzy key suggestions via Levenshtein distance on key errors.
 * ============================================================ */

/* Internal Helpers */

static int mocha_dict_find(MochaDict *d, const char *key) {
    for (int32_t i = 0; i < d->size; i++)
        if (strcmp(d->entries[i].key, key) == 0) return i;
    return -1;
}

static void dict_grow(MochaDict *d) {
    if (d->size >= d->capacity) {
        d->capacity *= 2;
        d->entries = realloc(d->entries, sizeof(MochaDictEntry) * d->capacity);
        MOCHA_OOM_CHECK(d->entries);
    }
}

static void dict_set_entry(MochaDict *d, char *key, void *value, int value_type) {
    int idx = mocha_dict_find(d, key);
    if (idx >= 0) {
        d->entries[idx].value      = value;
        d->entries[idx].value_type = value_type;
        return;
    }
    dict_grow(d);
    d->entries[d->size].key        = strdup(key);
    d->entries[d->size].value      = value;
    d->entries[d->size].value_type = value_type;
    d->size++;
}

static int levenshtein(const char *a, int alen, const char *b, int blen) {
    if (alen >= 64 || blen >= 64) return 999;
    int dp[64][64];
    for (int i = 0; i <= alen; i++) dp[i][0] = i;
    for (int j = 0; j <= blen; j++) dp[0][j] = j;
    for (int i = 1; i <= alen; i++) {
        for (int j = 1; j <= blen; j++) {
            int cost = a[i-1] == b[j-1] ? 0 : 1;
            int del  = dp[i-1][j] + 1;
            int ins  = dp[i][j-1] + 1;
            int sub  = dp[i-1][j-1] + cost;
            dp[i][j] = del < ins ? (del < sub ? del : sub)
                                 : (ins < sub ? ins : sub);
        }
    }
    return dp[alen][blen];
}

static const char* mocha_dict_type_name(int type) {
    switch(type) {
        case MOCHA_DICT_INT:    return "int";
        case MOCHA_DICT_FLOAT:  return "float";
        case MOCHA_DICT_STR:    return "str";
        case MOCHA_DICT_BOOL:   return "bool";
        case MOCHA_DICT_DICT:   return "dict";
        case MOCHA_DICT_OBJECT: return "object";
        case MOCHA_DICT_VAST:   return "vast";
        default:                return "unknown";
    }
}

/* ---- Construction ---- */
MochaDict* mocha_dict_new() {
    MochaDict *d = malloc(sizeof(MochaDict));
    d->entries = malloc(sizeof(MochaDictEntry) * 8);
    d->size = 0; d->capacity = 8; return d;
}

/* ---- Setters ---- */
void mocha_dict_set_int(MochaDict *d, char *key, int32_t val) {
    int32_t *v = malloc(sizeof(int32_t)); *v = val;
    dict_set_entry(d, key, v, MOCHA_DICT_INT);
}

void mocha_dict_set_float(MochaDict *d, char *key, double val) {
    double *v = malloc(sizeof(double)); *v = val;
    dict_set_entry(d, key, v, MOCHA_DICT_FLOAT);
}

void mocha_dict_set_str(MochaDict *d, char *key, char *val) {
    dict_set_entry(d, key, strdup(val), MOCHA_DICT_STR);
}

void mocha_dict_set_bool(MochaDict *d, char *key, int8_t val) {
    int8_t *v = malloc(sizeof(int8_t)); *v = val;
    dict_set_entry(d, key, v, MOCHA_DICT_BOOL);
}

void mocha_dict_set_vast(MochaDict *d, char *key, int64_t val) {
    int64_t *v = malloc(sizeof(int64_t)); *v = val;
    dict_set_entry(d, key, v, MOCHA_DICT_VAST);
}

void mocha_dict_set_dict(MochaDict *d, char *key, MochaDict *val) {
    dict_set_entry(d, key, val, MOCHA_DICT_DICT);
}

void mocha_dict_set_object(MochaDict *d, char *key, void *val) {
    dict_set_entry(d, key, val, MOCHA_DICT_OBJECT);
}

/* ---- Getters ---- */
void* mocha_dict_get(MochaDict *d, char *key) {
    int idx = mocha_dict_find(d, key);
    if (idx >= 0) return d->entries[idx].value;

    // Key not found — fuzzy search for suggestion
    int qlen      = (int)strlen(key);
    int threshold = qlen / 3 < 1 ? 1 : qlen / 3;
    int best_dist = 999;
    char *best_key = NULL;

    for (int32_t i = 0; i < d->size; i++) {
        char *k    = d->entries[i].key;
        int   klen = (int)strlen(k);
        int   dist = levenshtein(k, klen, key, qlen);
        if (dist < best_dist) {
            best_dist = dist;
            best_key  = k;
        }
    }

    if (best_key && best_dist <= threshold)
        fprintf(stderr, "MochaRuntimeError: Key '%s' not found.\n"
                        "    Did you mean '%s'?\n", key, best_key);
    else
        fprintf(stderr, "MochaRuntimeError: Key '%s' not found in dict.\n", key);

    exit(2);
}

MochaDict* mocha_dict_get_dict(MochaDict *d, char *key) {
    int idx = mocha_dict_find(d, key);
    if (idx < 0) {
        fprintf(stderr, "MochaRuntimeError: Key '%s' not found in dict.\n", key);
        exit(2);
    }
    if (d->entries[idx].value_type != MOCHA_DICT_DICT) {
        fprintf(stderr, "MochaRuntimeError: Key '%s' is not a dict.\n", key);
        exit(2);
    }
    return (MochaDict*)d->entries[idx].value;
}

void* mocha_dict_get_typed(MochaDict *d, char *key, int32_t expected) {
    int idx = mocha_dict_find(d, key);
    if (idx < 0) mocha_dict_get(d, key); // triggers fuzzy error + exit
    
    void *val = d->entries[idx].value;   // ← get val from idx directly
    int actual = d->entries[idx].value_type;
    
    if (actual == MOCHA_DICT_OBJECT) return val;
    if (actual != expected) {
        fprintf(stderr,
            "MochaRuntimeError: Dict key '%s' holds %s, "
            "but used as %s.\n"
            "Hint: check your dict value types.\n",
            key,
            mocha_dict_type_name(actual),
            mocha_dict_type_name(expected)
        );
        exit(2);
    }
    return val;
}
/* ---- Utility ---- */
int mocha_dict_get_type(MochaDict *d, char *key) {
    int idx = mocha_dict_find(d, key);
    return idx < 0 ? -1 : d->entries[idx].value_type;
}
int8_t mocha_dict_has(MochaDict *d, char *key) {
    return mocha_dict_find(d, key) >= 0 ? 1 : 0;
}
int32_t mocha_dict_length(MochaDict *d) { return d->size; }
void    mocha_dict_clean(MochaDict *d)  { d->size = 0;    }
void mocha_dict_remove(MochaDict *d, char *key) {
    int idx = mocha_dict_find(d, key);
    if (idx < 0) { fprintf(stderr, "MochaRuntimeError: Cannot remove key '%s' — not found.\n", key); exit(2); }
    for (int32_t i=idx; i<d->size-1; i++) d->entries[i]=d->entries[i+1];
    d->size--;
}

/* ---- Bulk operations ---- */
MochaArray* mocha_dict_allkeys(MochaDict *d) {
    MochaArray *arr = mocha_array_new(d->size, 8, 1);
    for (int32_t i=0; i<d->size; i++) { char *k=strdup(d->entries[i].key); mocha_array_init_set(arr,i,(void*)&k); }
    return arr;
}

MochaArray* mocha_dict_allvalues(MochaDict *d) {
    MochaArray *arr = mocha_array_new(d->size, 8, 1);
    for (int32_t i=0; i<d->size; i++) {
        char *buf = malloc(64);
        switch (d->entries[i].value_type) {
            case MOCHA_DICT_INT:    snprintf(buf,64,"%d",  *(int32_t*)d->entries[i].value); break;
            case MOCHA_DICT_FLOAT:  snprintf(buf,64,"%g",  *(double*)d->entries[i].value);  break;
            case MOCHA_DICT_STR:    snprintf(buf,64,"%s",  (char*)d->entries[i].value);      break;
            case MOCHA_DICT_BOOL:   snprintf(buf,64,"%s",  *(int8_t*)d->entries[i].value?"true":"false"); break;
            case MOCHA_DICT_DICT:   snprintf(buf,64,"[dict]");   break;
            case MOCHA_DICT_OBJECT: snprintf(buf,64,"[object]"); break;
            case MOCHA_DICT_VAST:   snprintf(buf, 64, "%lld", *(int64_t*)d->entries[i].value); break;
        }
        mocha_array_init_set(arr,i,(void*)&buf);
    }
    return arr;
}

MochaDict* mocha_dict_merge(MochaDict *a, MochaDict *b, int8_t override) {
    MochaDict *result = mocha_dict_new();

    // Copy all entries from a
    for (int32_t i = 0; i < a->size; i++) {
        dict_set_entry(result,
            strdup(a->entries[i].key),
            a->entries[i].value,
            a->entries[i].value_type);
    }

    // Merge entries from b
    for (int32_t i = 0; i < b->size; i++) {
        char *key = b->entries[i].key;
        if (mocha_dict_find(result, key) >= 0) {
            if (!override) {
                fprintf(stderr,
                    "MochaRuntimeError: Dict merge conflict on key '%s'.\n"
                    "    Hint: remove the key from one dict, or use merge(dict2, override=true).\n",
                    key);
                exit(2);
            }
            // override=true — b wins, update existing entry
            dict_set_entry(result, key,
                b->entries[i].value,
                b->entries[i].value_type);
        } else {
            dict_set_entry(result, strdup(key),
                b->entries[i].value,
                b->entries[i].value_type);
        }
    }

    return result;
}

/* ---- Output ---- */

void mocha_dict_print_value(MochaDict *d, char *key, int8_t newline) {
    int idx = mocha_dict_find(d, key);
    if (idx < 0) { fprintf(stderr, "MochaRuntimeError: Key '%s' not found.\n", key); exit(2); }
    if (newline) printf("\n");
    switch (d->entries[idx].value_type) {
        case MOCHA_DICT_INT:    printf("%d",  *(int32_t*)d->entries[idx].value); break;
        case MOCHA_DICT_FLOAT:  printf("%g",  *(double*)d->entries[idx].value);  break;
        case MOCHA_DICT_STR:    printf("%s",  (char*)d->entries[idx].value);      break;
        case MOCHA_DICT_BOOL:   printf("%s",  *(int8_t*)d->entries[idx].value?"true":"false"); break;
        case MOCHA_DICT_DICT:   printf("[dict]");   break;
        case MOCHA_DICT_OBJECT: printf("[object]"); break;
        case MOCHA_DICT_VAST: printf("%lld", *(int64_t*)d->entries[idx].value); break;
    }
}

MochaDict* mocha_dict_copy(MochaDict *src) {
    MochaDict *d = mocha_dict_new();
    for (int32_t i = 0; i < src->size; i++) {
        dict_set_entry(d,
            strdup(src->entries[i].key),
            src->entries[i].value,
            src->entries[i].value_type);
    }
    return d;
}

/* ============================================================
 * SET RUNTIME
 *
 * Ordered set of unique values. Supports int, float, str, bool.
 * Operations: insert, delete, has, union, intersect, xor, rel_diff, min and max.
 * ============================================================ */

/* ---- Internal helpers ---- */

//Map elem_type constant to its size in bytes
static int32_t set_elem_size(int32_t elem_type) {
    switch (elem_type) {
        case MOCHA_SET_INT:    return sizeof(int32_t);
        case MOCHA_SET_FLOAT:  return sizeof(double);
        case MOCHA_SET_STR:    return sizeof(char *);
        case MOCHA_SET_BOOL:   return sizeof(int8_t);
        case MOCHA_SET_VAST:   return sizeof(int64_t);
        case MOCHA_SET_OBJECT: return sizeof(void *);
        default:               return sizeof(int32_t);
    }
}

//Returns index of value in set, or -1 if not found
static int32_t mocha_set_find(MochaSet *s, void *value) {
    for (int32_t i = 0; i < s->size; i++) {
        void *elem = (char *)s->data + i * s->elem_size;
        if (s->elem_type == MOCHA_SET_STR)
            { if (strcmp(*(char **)elem, *(char **)value) == 0) return i; }
        else if (s->elem_type == MOCHA_SET_OBJECT)
            { if (*(void **)elem == *(void **)value) return i; }
        else
            { if (memcmp(elem, value, s->elem_size) == 0) return i; }
    }
    return -1;
}

//Grow capacity 2x if needed
static void set_ensure_capacity(MochaSet *s) {
    if (s->size < s->capacity) return;
    s->capacity *= 2;
    s->data = realloc(s->data, s->elem_size * s->capacity);
    MOCHA_OOM_CHECK(s->data);
}

/* ---- Construction ---- */
MochaSet* mocha_set_new(int32_t elem_type) {
    MochaSet *s  = malloc(sizeof(MochaSet));
    s->elem_type = elem_type;
    s->elem_size = set_elem_size(elem_type);
    s->size      = 0;
    s->capacity  = 8;
    s->data      = malloc(s->elem_size * s->capacity);
    MOCHA_OOM_CHECK(s->data);
    return s;
}

/* ---- Mutation ---- */
void mocha_set_insert(MochaSet *s, void *value) {
    if (mocha_set_find(s, value) >= 0) return;  /* already present */
    set_ensure_capacity(s);
    void *slot = (char *)s->data + s->size * s->elem_size;
    if (s->elem_type == MOCHA_SET_STR)
        *(char **)slot = strdup(*(char **)value);
    else
        memcpy(slot, value, s->elem_size);
    s->size++;
}

void mocha_set_delete(MochaSet *s, void *value) {
    int32_t idx = mocha_set_find(s, value);
    if (idx < 0) {
        fprintf(stderr, "MochaRuntimeError: Cannot delete value — not found in set.\n");
        exit(2);
    }
    /* Shift elements left to fill the gap */
    for (int32_t i = idx; i < s->size - 1; i++) {
        void *curr = (char *)s->data + i       * s->elem_size;
        void *next = (char *)s->data + (i + 1) * s->elem_size;
        memcpy(curr, next, s->elem_size);
    }
    s->size--;
}

static const char* set_type_name(int32_t type) {
    switch(type) {
        case 0: return "int";
        case 1: return "float";
        case 2: return "str";
        case 3: return "bool";
        case 4: return "vast";
        default: return "unknown";
    }
}

void mocha_set_retype(MochaSet *s, int32_t new_type) {
    if (s->size > 0) {
        fprintf(stderr, "MochaRuntimeWarning: retype() called on a non-empty set. "
                        "Call .clean() first to avoid data loss.\n");
    }
    fprintf(stderr, "MochaWarning: retype() — all existing data will be lost. "
                    "New type: %s\n", set_type_name(new_type));
    s->size      = 0;
    s->elem_type = new_type;
    s->elem_size = set_elem_size(new_type);
}

void mocha_set_negate(MochaSet *s) {
    if (s->elem_type == MOCHA_SET_INT) {
        for (int32_t i = 0; i < s->size; i++)
            *(int32_t *)((char *)s->data + i * s->elem_size) *= -1;
    } else if (s->elem_type == MOCHA_SET_FLOAT) {
        for (int32_t i = 0; i < s->size; i++)
            *(double *)((char *)s->data + i * s->elem_size) *= -1.0;
    } else if (s->elem_type == MOCHA_SET_VAST) {
        for (int32_t i = 0; i < s->size; i++)
            *(int64_t *)((char *)s->data + i * s->elem_size) *= -1;
    } else {
        fprintf(stderr, "MochaRuntimeError: negate() only works on int, float, or vast sets.\n");
        exit(2);
    }
}

/* ---- Utility ---- */
void mocha_set_get(MochaSet *s, int32_t index, void *out) {
    if (index < 0 || index >= s->size) {
        fprintf(stderr, "MochaRuntimeError: Set index %d out of bounds [0, %d).\n",
                index, s->size);
        exit(2);
    }
    memcpy(out, (char *)s->data + index * s->elem_size, s->elem_size);
}

int8_t  mocha_set_has  (MochaSet *s, void *v) { return mocha_set_find(s, v) >= 0 ? 1 : 0; }
int32_t mocha_set_size (MochaSet *s)           { return s->size; }
void    mocha_set_clean(MochaSet *s)           { s->size = 0; }


/* ---- Set operations — all return a new set ---- */
MochaSet* mocha_set_union(MochaSet *s1, MochaSet *s2) {
    MochaSet *r = mocha_set_new(s1->elem_type);
    for (int32_t i = 0; i < s1->size; i++)
        mocha_set_insert(r, (char *)s1->data + i * s1->elem_size);
    for (int32_t i = 0; i < s2->size; i++)
        mocha_set_insert(r, (char *)s2->data + i * s2->elem_size);
    return r;
}

MochaSet* mocha_set_intersect(MochaSet *s1, MochaSet *s2) {
    MochaSet *r = mocha_set_new(s1->elem_type);
    for (int32_t i = 0; i < s1->size; i++) {
        void *elem = (char *)s1->data + i * s1->elem_size;
        if (mocha_set_find(s2, elem) >= 0)
            mocha_set_insert(r, elem);
    }
    return r;
}

MochaSet* mocha_set_xor(MochaSet *s1, MochaSet *s2) {
    MochaSet *u     = mocha_set_union(s1, s2);
    MochaSet *inter = mocha_set_intersect(s1, s2);
    MochaSet *r     = mocha_set_new(s1->elem_type);
    for (int32_t i = 0; i < u->size; i++) {
        void *elem = (char *)u->data + i * u->elem_size;
        if (mocha_set_find(inter, elem) < 0)
            mocha_set_insert(r, elem);
    }
    return r;
}

MochaSet* mocha_set_rel_diff(MochaSet *s1, MochaSet *s2) {
    MochaSet *r = mocha_set_new(s1->elem_type);
    for (int32_t i = 0; i < s1->size; i++) {
        void *elem = (char *)s1->data + i * s1->elem_size;
        if (mocha_set_find(s2, elem) < 0)
            mocha_set_insert(r, elem);
    }
    return r;
}

/* ---- Min / Max ---- */
SET_MINMAX(int,   int32_t)
SET_MINMAX(float, double)
SET_MINMAX(vast,  int64_t)

char* mocha_set_min_str(MochaSet *s) {
    if (s->size == 0) {
        fprintf(stderr, "MochaRuntimeError: min() on empty set\n");
        _exit(2);
    }
    char *m;
    memcpy(&m, s->data, sizeof(char*));
    for (int32_t i = 1; i < s->size; i++) {
        char *v;
        memcpy(&v, (char*)s->data + i * s->elem_size, sizeof(char*));
        if (strcmp(v, m) < 0) m = v;
    }
    return m;
}

char* mocha_set_max_str(MochaSet *s) {
    if (s->size == 0) {
        fprintf(stderr, "MochaRuntimeError: max() on empty set\n");
        _exit(2);
    }
    char *m;
    memcpy(&m, s->data, sizeof(char*));
    for (int32_t i = 1; i < s->size; i++) {
        char *v;
        memcpy(&v, (char*)s->data + i * s->elem_size, sizeof(char*));
        if (strcmp(v, m) > 0) m = v;
    }
    return m;
}

/* ---- Set Similarity Metrics ---- */

double mocha_set_jaccard(MochaSet *a, MochaSet *b) {
    if (a->size == 0 && b->size == 0) return 1.0;
    int32_t inter = 0;
    for (int32_t i = 0; i < a->size; i++) {
        void *elem = (char *)a->data + i * a->elem_size;
        if (mocha_set_find(b, elem) >= 0) inter++;
    }
    int32_t uni = a->size + b->size - inter;
    return (double)inter / (double)uni;
}

double mocha_set_dice(MochaSet *a, MochaSet *b) {
    if (a->size == 0 && b->size == 0) return 1.0;
    int32_t inter = 0;
    for (int32_t i = 0; i < a->size; i++) {
        void *elem = (char *)a->data + i * a->elem_size;
        if (mocha_set_find(b, elem) >= 0) inter++;
    }
    return (2.0 * inter) / (double)(a->size + b->size);
}

double mocha_set_overlap(MochaSet *a, MochaSet *b) {
    if (a->size == 0 || b->size == 0) return 0.0;
    int32_t inter = 0;
    for (int32_t i = 0; i < a->size; i++) {
        void *elem = (char *)a->data + i * a->elem_size;
        if (mocha_set_find(b, elem) >= 0) inter++;
    }
    int32_t smaller = a->size < b->size ? a->size : b->size;
    return (double)inter / (double)smaller;
}

/* ============================================================
 * MOCHA-STOPWATCH LIB FFI
 * ============================================================ */

int mocha_wrap_clock()              { return (int)clock();  }

double mocha_wrap_time_ms() {
    return (double)clock() / CLOCKS_PER_SEC * 1000.0;
}

double mocha_wrap_unix_time() {
    return (double)time(NULL);
}

static char mocha_time_buf[64];

char* mocha_wrap_datetime_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%Y-%m-%d %H:%M:%S", tm_info);
    return mocha_time_buf;
}

char* mocha_wrap_date_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%Y-%m-%d", tm_info);
    return mocha_time_buf;
}

char* mocha_wrap_time_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%H:%M:%S", tm_info);
    return mocha_time_buf;
}

char* mocha_wrap_ampm_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%I:%M:%S %p", tm_info);
    return mocha_time_buf;
}

char* mocha_wrap_day_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%A", tm_info);
    return mocha_time_buf;
}

char* mocha_wrap_month_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%B", tm_info);
    return mocha_time_buf;
}

char* mocha_wrap_year_now() {
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    strftime(mocha_time_buf, sizeof(mocha_time_buf), "%Y", tm_info);
    return mocha_time_buf;
}

static double mocha_wall_start = 0.0;

double mocha_wrap_wall_ms() {
#ifdef _WIN32
    LARGE_INTEGER freq, count;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&count);
    double ms = (double)count.QuadPart / (double)freq.QuadPart * 1000.0;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    double ms = ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
#endif
    if (mocha_wall_start == 0.0) { mocha_wall_start = ms; }
    return ms - mocha_wall_start;
}

void mocha_stopwatch_wait(double ms) {
#ifdef _WIN32
    LARGE_INTEGER freq, start, now;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&start);
    double target_counts = ms * 0.001 * (double)freq.QuadPart;
    while (1) {
        QueryPerformanceCounter(&now);
        if ((double)(now.QuadPart - start.QuadPart) >= target_counts) break;
    }
#else
    struct timespec start, now;
    clock_gettime(CLOCK_MONOTONIC, &start);
    double target_ns = ms * 1e6;
    while (1) {
        clock_gettime(CLOCK_MONOTONIC, &now);
        double elapsed = (now.tv_sec - start.tv_sec) * 1e9
                       + (now.tv_nsec - start.tv_nsec);
        if (elapsed >= target_ns) break;
    }
#endif
}

/* ============================================================
 * FFI WRAPPERS
 *
 * C stdlib wrappers — needed because clang+lld rejects
 * redeclaration of stdlib symbols in generated LLVM IR.
 * ============================================================ */

/* ---- ctype wrappers ---- */
int mocha_wrap_isalpha(int c) { return isalpha(c); }
int mocha_wrap_isdigit(int c) { return isdigit(c); }
int mocha_wrap_toupper(int c) { return toupper(c); }
int mocha_wrap_tolower(int c) { return tolower(c); }

/* ---- math wrappers ---- */
double mocha_wrap_hypot(double x, double y) { 
#ifdef _WIN32
    return _hypot(x, y);
#else
    return hypot(x, y);
#endif
}
double mocha_wrap_fmod(double x, double y)  { return fmod(x, y);   }
double mocha_wrap_erf(double x)    { return erf(x);    }
double mocha_wrap_tgamma(double x) { return tgamma(x); }
double mocha_wrap_lgamma(double x) { return lgamma(x); }
double mocha_wrap_exp(double x)    { return exp(x);    }

/* ---- system wrappers ---- */
int mocha_wrap_system(const char *cmd) { return system(cmd); }

/* ---- RUNTIME Exception ---- */

//Flush stdout before writing — prevents interleaved output on error
void* mocha_print_stderr(const char *msg) { //this is called c_print_error in Mocha-side
    fflush(stdout);
    fprintf(stderr, "\n%s\n", msg);  // \n before AND after
    fflush(stderr);
    return NULL;
}

//Flush both streams before exit — ensures no output is lost
void* mocha_exit(int code) {
    fflush(stdout);
    fflush(stderr);
    _Exit(code); //not exit because handlers are a headache
    return NULL; // unreachable but satisfies type
}

/* ============================================================
 * SQLITE3 FFI
 * ============================================================ */

#include "sqlite-amalgamation-3510300/sqlite3.h"

/* Open a database file, returns handle or NULL on failure */
void* mocha_sqlite3_open(const char *path) {
    sqlite3 *db;
    int rc = sqlite3_open(path, &db);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "MochaSQLiteError: Cannot open '%s': %s\n", 
                path, sqlite3_errmsg(db));
        sqlite3_close(db);  // must close even on failure!
        return NULL;
    }
    return (void*)db;
}

/* Execute a non-query SQL statement (CREATE, INSERT, etc.) */
int mocha_sqlite3_exec(void *db, const char *sql) {
    if (!db) return -1;
    char *errmsg = NULL;
    int rc = sqlite3_exec((sqlite3*)db, sql, 0, 0, &errmsg);
    if (rc != SQLITE_OK && errmsg) {
        fprintf(stderr, "MochaSQLiteError (exec): %s\n", errmsg);
        sqlite3_free(errmsg);  // must free this!
    }
    return rc;
}

/* Close the database handle */
void* mocha_sqlite3_close(void *db) {
    if (db) sqlite3_close((sqlite3*)db);
    return NULL;
}

/* Callback for mocha_sqlite3_query — prints each row to stdout */
static int mocha_sqlite3_callback(void *unused, int argc,
                                   char **argv, char **col_names) {
    for (int i = 0; i < argc; i++)
        printf("%s: %s\n", col_names[i], argv[i] ? argv[i] : "NULL");
    printf("---\n");
    return 0;
}

/* Execute a SELECT query, printing results via callback */
int mocha_sqlite3_query(void *db, const char *sql) {
    if (!db) return -1;
    char *errmsg = NULL;
    int rc = sqlite3_exec((sqlite3*)db, sql, mocha_sqlite3_callback, 0, &errmsg);
    if (rc != SQLITE_OK && errmsg) {
        fprintf(stderr, "MochaSQLiteError (query): %s\n", errmsg);
        sqlite3_free(errmsg);
    }
    return rc;
}

/* ============================================================
 * SQLITE3 QUERY RESULT API
 * ============================================================ */

/* Internal result cache — stores last query results */
static char ***mocha_sqlite3_result_rows = NULL;
static char **mocha_sqlite3_result_colnames = NULL;
static int mocha_sqlite3_result_nrows = 0;
static int mocha_sqlite3_result_ncols = 0;

/* Free the cached results */
static void mocha_sqlite3_free_results() {
    if (mocha_sqlite3_result_rows) {
        for (int i = 0; i < mocha_sqlite3_result_nrows; i++) {
            if (mocha_sqlite3_result_rows[i]) {
                for (int j = 0; j < mocha_sqlite3_result_ncols; j++) {
                    if (mocha_sqlite3_result_rows[i][j])
                        free(mocha_sqlite3_result_rows[i][j]);
                }
                free(mocha_sqlite3_result_rows[i]);
            }
        }
        free(mocha_sqlite3_result_rows);
        mocha_sqlite3_result_rows = NULL;
    }
    if (mocha_sqlite3_result_colnames) {
        for (int j = 0; j < mocha_sqlite3_result_ncols; j++) {
            if (mocha_sqlite3_result_colnames[j])
                free(mocha_sqlite3_result_colnames[j]);
        }
        free(mocha_sqlite3_result_colnames);
        mocha_sqlite3_result_colnames = NULL;
    }
    mocha_sqlite3_result_nrows = 0;
    mocha_sqlite3_result_ncols = 0;
}

/* Callback — collects rows into cache */
static int mocha_sqlite3_collect_callback(void *unused, int argc,
                                           char **argv, char **col_names) {
    /* first row — allocate column names */
    if (mocha_sqlite3_result_ncols == 0) {
        mocha_sqlite3_result_ncols = argc;
        mocha_sqlite3_result_colnames = malloc(argc * sizeof(char*));
        for (int j = 0; j < argc; j++) {
            mocha_sqlite3_result_colnames[j] = col_names[j]
                ? strdup(col_names[j]) : strdup("");
        }
    }
    /* grow rows array */
    mocha_sqlite3_result_rows = realloc(mocha_sqlite3_result_rows,
        (mocha_sqlite3_result_nrows + 1) * sizeof(char**));
    mocha_sqlite3_result_rows[mocha_sqlite3_result_nrows] = malloc(argc * sizeof(char*));
    for (int j = 0; j < argc; j++) {
        mocha_sqlite3_result_rows[mocha_sqlite3_result_nrows][j] =
            argv[j] ? strdup(argv[j]) : strdup("NULL");
    }
    mocha_sqlite3_result_nrows++;
    return 0;
}

/* Run a SELECT query and cache results — call this first */
int mocha_sqlite3_query_run(void *db, const char *sql) {
    if (!db) return -1;
    mocha_sqlite3_free_results();
    char *errmsg = NULL;
    int rc = sqlite3_exec((sqlite3*)db, sql, mocha_sqlite3_collect_callback, 0, &errmsg);
    if (rc != SQLITE_OK && errmsg) {
        fprintf(stderr, "MochaSQLiteError (query_run): %s\n", errmsg);
        sqlite3_free(errmsg);
    }
    return rc;
}

/* How many rows in last query result */
int mocha_sqlite3_query_rows(void *db) {
    return mocha_sqlite3_result_nrows;
}

/* How many columns in last query result */
int mocha_sqlite3_query_cols(void *db) {
    return mocha_sqlite3_result_ncols;
}

/* Get cell value at row i, col j */
const char* mocha_sqlite3_query_cell(void *db, int row, int col) {
    if (row < 0 || row >= mocha_sqlite3_result_nrows) return "";
    if (col < 0 || col >= mocha_sqlite3_result_ncols) return "";
    return mocha_sqlite3_result_rows[row][col];
}

/* Get column name at index j */
const char* mocha_sqlite3_query_colname(void *db, int col) {
    if (col < 0 || col >= mocha_sqlite3_result_ncols) return "";
    return mocha_sqlite3_result_colnames[col];
}

/* Error message */
const char* mocha_sqlite3_errmsg(void *db) {
    if (!db) return "no database";
    return sqlite3_errmsg((sqlite3*)db);
}

/* Last inserted rowid */
int mocha_sqlite3_last_rowid(void *db) {
    if (!db) return -1;
    return (int)sqlite3_last_insert_rowid((sqlite3*)db);
}

/* Number of rows affected by last INSERT/UPDATE/DELETE */
int mocha_sqlite3_changes(void *db) {
    if (!db) return -1;
    return sqlite3_changes((sqlite3*)db);
}

/* Check if table exists — returns 1 if yes, 0 if no */
int mocha_sqlite3_table_exists(void *db, const char *table) {
    if (!db) return 0;
    char sql[512];
    snprintf(sql, sizeof(sql),
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='%s'", table);
    mocha_sqlite3_free_results();
    sqlite3_exec((sqlite3*)db, sql, mocha_sqlite3_collect_callback, 0, 0);
    if (mocha_sqlite3_result_nrows > 0 && mocha_sqlite3_result_ncols > 0) {
        int exists = atoi(mocha_sqlite3_result_rows[0][0]);
        mocha_sqlite3_free_results();
        return exists;
    }
    return 0;
}

/* ============================================================
 * LUA FFI
 * ============================================================ */

#ifdef MOCHA_WITH_LUA
#include "lua-5.5.0_Win64_dllw6_lib/include/lua.h"
#include "lua-5.5.0_Win64_dllw6_lib/include/lualib.h"
#include "lua-5.5.0_Win64_dllw6_lib/include/lauxlib.h"

/* Create a new Lua state with all standard libs loaded */
void* mocha_lua_new() {
    lua_State *L = luaL_newstate();
    if (!L) return NULL;
    luaL_openlibs(L);
    return (void*)L;
}

/* Execute a Lua string — returns 0 on success, error code otherwise */
int mocha_lua_dostring(void *L, const char *code) {
    return luaL_dostring((lua_State*)L, code);
}

/* Execute a Lua file — returns 0 on success, error code otherwise */
int mocha_lua_dofile(void *L, const char *filename) {
    return luaL_dofile((lua_State*)L, filename);
}

/* Close and free the Lua state */
void* mocha_lua_close(void *L) {
    lua_close((lua_State*)L);
    return NULL;
}

/* Read a global number variable from Lua state */
double mocha_lua_getnumber(void *L, const char *varname) {
    lua_getglobal((lua_State*)L, varname);
    double r = lua_tonumber((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

/* Read a global string variable from Lua state */
const char* mocha_lua_getstring(void *L, const char *varname) {
    lua_getglobal((lua_State*)L, varname);
    const char *r = lua_tostring((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

/* ── Get values from Lua ── */

int mocha_lua_getbool(void *L, const char *varname) {
    lua_getglobal((lua_State*)L, varname);
    int r = lua_toboolean((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

int mocha_lua_getint(void *L, const char *varname) {
    lua_getglobal((lua_State*)L, varname);
    int r = (int)lua_tointeger((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

/* ── Set values into Lua from Mocha ── */

void* mocha_lua_setnumber(void *L, const char *varname, double val) {
    lua_pushnumber((lua_State*)L, val);
    lua_setglobal((lua_State*)L, varname);
    return NULL;
}

void* mocha_lua_setstring(void *L, const char *varname, const char *val) {
    lua_pushstring((lua_State*)L, val);
    lua_setglobal((lua_State*)L, varname);
    return NULL;
}

void* mocha_lua_setbool(void *L, const char *varname, int val) {
    lua_pushboolean((lua_State*)L, val);
    lua_setglobal((lua_State*)L, varname);
    return NULL;
}

void* mocha_lua_setint(void *L, const char *varname, int val) {
    lua_pushinteger((lua_State*)L, val);
    lua_setglobal((lua_State*)L, varname);
    return NULL;
}

/* ── Protected execution ── */

const char* mocha_lua_safe_dostring(void *L, const char *code) {
    int r = luaL_dostring((lua_State*)L, code);
    if (r != 0) {
        const char *err = lua_tostring((lua_State*)L, -1);
        lua_pop((lua_State*)L, 1);
        return err;
    }
    return "";  // empty string = success (NULL would crash Mocha)
}

/* ── Stack utilities ── */

int mocha_lua_stack_size(void *L) {
    return lua_gettop((lua_State*)L);
}

void* mocha_lua_clear_stack(void *L) {
    lua_settop((lua_State*)L, 0);
    return NULL;
}

/* ── Call Lua functions from Mocha ── */

// call func() → number
double mocha_lua_call_number(void *L, const char *funcname) {
    lua_getglobal((lua_State*)L, funcname);
    if (lua_pcall((lua_State*)L, 0, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return 0.0;
    }
    double r = lua_tonumber((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

// call func() → string
const char* mocha_lua_call_string(void *L, const char *funcname) {
    lua_getglobal((lua_State*)L, funcname);
    if (lua_pcall((lua_State*)L, 0, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return "";
    }
    const char *r = lua_tostring((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

// call func() → int
int mocha_lua_call_int(void *L, const char *funcname) {
    lua_getglobal((lua_State*)L, funcname);
    if (lua_pcall((lua_State*)L, 0, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return 0;
    }
    int r = (int)lua_tointeger((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

// call func(number) → number
double mocha_lua_call1n_number(void *L, const char *funcname, double arg) {
    lua_getglobal((lua_State*)L, funcname);
    lua_pushnumber((lua_State*)L, arg);
    if (lua_pcall((lua_State*)L, 1, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return 0.0;
    }
    double r = lua_tonumber((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

// call func(string) → string
const char* mocha_lua_call1s_string(void *L, const char *funcname, const char *arg) {
    lua_getglobal((lua_State*)L, funcname);
    lua_pushstring((lua_State*)L, arg);
    if (lua_pcall((lua_State*)L, 1, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return "";
    }
    const char *r = lua_tostring((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

// call func(number, number) → number
double mocha_lua_call2n_number(void *L, const char *funcname, double a, double b) {
    lua_getglobal((lua_State*)L, funcname);
    lua_pushnumber((lua_State*)L, a);
    lua_pushnumber((lua_State*)L, b);
    if (lua_pcall((lua_State*)L, 2, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return 0.0;
    }
    double r = lua_tonumber((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

// call func(string, string) → string
const char* mocha_lua_call2s_string(void *L, const char *funcname, const char *a, const char *b) {
    lua_getglobal((lua_State*)L, funcname);
    lua_pushstring((lua_State*)L, a);
    lua_pushstring((lua_State*)L, b);
    if (lua_pcall((lua_State*)L, 2, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return "";
    }
    const char *r = lua_tostring((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

const char* mocha_lua_call1n_string(void *L, const char *funcname, double arg) {
    lua_getglobal((lua_State*)L, funcname);
    lua_pushnumber((lua_State*)L, arg);
    if (lua_pcall((lua_State*)L, 1, 1, 0) != LUA_OK) {
        lua_pop((lua_State*)L, 1);
        return "";
    }
    const char *r = lua_tostring((lua_State*)L, -1);
    lua_pop((lua_State*)L, 1);
    return r;
}

#endif /* MOCHA_WITH_LUA */

/* ============================================================
 * WREN FFI
 * ============================================================ */

#ifdef MOCHA_WITH_WREN
#include "wren/include/wren.h"

/* Module load callback — returns source for imported modules */
static WrenLoadModuleResult mocha_wren_load_module(WrenVM* vm, const char* name) {
    WrenLoadModuleResult result = {0};
    return result;  // no module loading for now
}

/* Write callback — Wren's print goes here */
static void mocha_wren_write(WrenVM* vm, const char* text) {
    printf("%s", text);
}

/* Error callback */
static void mocha_wren_error(WrenVM* vm, WrenErrorType type,
                              const char* module, int line, const char* msg) {
    if (type == WREN_ERROR_COMPILE)
        fprintf(stderr, "WrenCompileError [%s line %d]: %s\n", module, line, msg);
    else if (type == WREN_ERROR_RUNTIME)
        fprintf(stderr, "WrenRuntimeError: %s\n", msg);
    else
        fprintf(stderr, "WrenStackTrace [%s line %d]: %s\n", module, line, msg);
}

/* Create a new Wren VM */
void* mocha_wren_new() {
    WrenConfiguration config;
    wrenInitConfiguration(&config);
    config.writeFn        = mocha_wren_write;
    config.errorFn        = mocha_wren_error;
    config.loadModuleFn   = mocha_wren_load_module;
    WrenVM* vm = wrenNewVM(&config);
    return (void*)vm;
}

/* Free the Wren VM */
void* mocha_wren_free(void* vm) {
    wrenFreeVM((WrenVM*)vm);
    return NULL;
}

/* Execute a Wren string — returns 0 on success */
int mocha_wren_dostring(void* vm, const char* module, const char* code) {
    WrenInterpretResult r = wrenInterpret((WrenVM*)vm, module, code);
    return (r == WREN_RESULT_SUCCESS) ? 0 : 1;
}

/* Execute a Wren file */
int mocha_wren_dofile(void* vm, const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "WrenError: cannot open file '%s'\n", filename);
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    rewind(f);
    char* src = (char*)malloc(len + 1);
    fread(src, 1, len, f);
    src[len] = '\0';
    fclose(f);
    int r = mocha_wren_dostring(vm, filename, src);
    free(src);
    return r;
}

/* ── Get global variables from Wren ── */
/* In Wren, globals live in class fields — access via slot API after interpret */

double mocha_wren_getnumber(void* vm, const char* module, const char* classname, const char* field) {
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* handle = wrenGetSlotHandle((WrenVM*)vm, 0);
    // call getter via method handle
    wrenReleaseHandle((WrenVM*)vm, handle);
    // simpler: evaluate inline expression
    char code[256];
    snprintf(code, sizeof(code), "System.print(%s.%s)", classname, field);
    // actually just use a temp eval approach
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    double r = wrenGetSlotDouble((WrenVM*)vm, 0);
    return r;
}

static int wren_eval_counter = 0;

double mocha_wren_eval_number(void* vm, const char* expr) {
    char module[32];
    char code[1024];
    snprintf(module, sizeof(module), "eval_%d", wren_eval_counter++);
    snprintf(code, sizeof(code),
    "class MochaEval {\n  static run {\n    return %s\n  }\n}", expr);
    wrenInterpret((WrenVM*)vm, module, code);
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, "MochaEval", 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, "run");
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenCall((WrenVM*)vm, method);
    double r = wrenGetSlotDouble((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

const char* mocha_wren_eval_string(void* vm, const char* expr) {
    char module[32];
    char code[1024];
    snprintf(module, sizeof(module), "eval_%d", wren_eval_counter++);
    snprintf(code, sizeof(code),
    "class MochaEval {\n  static run {\n    return %s\n  }\n}", expr);
    wrenInterpret((WrenVM*)vm, module, code);
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, "MochaEval", 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, "run");
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenCall((WrenVM*)vm, method);
    const char* r = wrenGetSlotString((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

int mocha_wren_eval_bool(void* vm, const char* expr) {
    char module[32];
    char code[1024];
    snprintf(module, sizeof(module), "eval_%d", wren_eval_counter++);
    snprintf(code, sizeof(code),
    "class MochaEval {\n  static run {\n    return %s\n  }\n}", expr);
    wrenInterpret((WrenVM*)vm, module, code);
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, "MochaEval", 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, "run");
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenCall((WrenVM*)vm, method);
    int r = wrenGetSlotBool((WrenVM*)vm, 0) ? 1 : 0;
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

int mocha_wren_eval_int(void* vm, const char* expr) {
    return (int)mocha_wren_eval_number(vm, expr);
}

/* ── Call Wren methods from Mocha ── */
/* Pattern: get receiver → make call handle → call → read result */

// call Class.method() → number
double mocha_wren_call_number(void* vm, const char* module,
                               const char* classname, const char* signature) {
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, signature);
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenCall((WrenVM*)vm, method);
    double r = wrenGetSlotDouble((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

// call Class.method() → string
const char* mocha_wren_call_string(void* vm, const char* module,
                                    const char* classname, const char* signature) {
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, signature);
    wrenEnsureSlots((WrenVM*)vm, 1);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenCall((WrenVM*)vm, method);
    const char* r = wrenGetSlotString((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

// call Class.method() → int
int mocha_wren_call_int(void* vm, const char* module,
                         const char* classname, const char* signature) {
    return (int)mocha_wren_call_number(vm, module, classname, signature);
}

// call Class.method(number) → number
double mocha_wren_call1n_number(void* vm, const char* module,
                                 const char* classname, const char* signature, double arg) {
    wrenEnsureSlots((WrenVM*)vm, 2);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, signature);
    wrenEnsureSlots((WrenVM*)vm, 2);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenSetSlotDouble((WrenVM*)vm, 1, arg);
    wrenCall((WrenVM*)vm, method);
    double r = wrenGetSlotDouble((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

// call Class.method(string) → string
const char* mocha_wren_call1s_string(void* vm, const char* module,
                                      const char* classname, const char* signature,
                                      const char* arg) {
    wrenEnsureSlots((WrenVM*)vm, 2);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, signature);
    wrenEnsureSlots((WrenVM*)vm, 2);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenSetSlotString((WrenVM*)vm, 1, arg);
    wrenCall((WrenVM*)vm, method);
    const char* r = wrenGetSlotString((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

// call Class.method(number, number) → number
double mocha_wren_call2n_number(void* vm, const char* module,
                                 const char* classname, const char* signature,
                                 double a, double b) {
    wrenEnsureSlots((WrenVM*)vm, 3);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, signature);
    wrenEnsureSlots((WrenVM*)vm, 3);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenSetSlotDouble((WrenVM*)vm, 1, a);
    wrenSetSlotDouble((WrenVM*)vm, 2, b);
    wrenCall((WrenVM*)vm, method);
    double r = wrenGetSlotDouble((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

// call Class.method(string, string) → string
const char* mocha_wren_call2s_string(void* vm, const char* module,
                                      const char* classname, const char* signature,
                                      const char* a, const char* b) {
    wrenEnsureSlots((WrenVM*)vm, 3);
    wrenGetVariable((WrenVM*)vm, module, classname, 0);
    WrenHandle* receiver = wrenGetSlotHandle((WrenVM*)vm, 0);
    WrenHandle* method   = wrenMakeCallHandle((WrenVM*)vm, signature);
    wrenEnsureSlots((WrenVM*)vm, 3);
    wrenSetSlotHandle((WrenVM*)vm, 0, receiver);
    wrenSetSlotString((WrenVM*)vm, 1, a);
    wrenSetSlotString((WrenVM*)vm, 2, b);
    wrenCall((WrenVM*)vm, method);
    const char* r = wrenGetSlotString((WrenVM*)vm, 0);
    wrenReleaseHandle((WrenVM*)vm, receiver);
    wrenReleaseHandle((WrenVM*)vm, method);
    return r;
}

/* ── Safe execution with error string return ── */
const char* mocha_wren_safe_dostring(void* vm, const char* module, const char* code) {
    WrenInterpretResult r = wrenInterpret((WrenVM*)vm, module, code);
    return (r == WREN_RESULT_SUCCESS) ? "" : "WrenError: script failed";
}

#endif /* MOCHA_WITH_WREN */

/* INSERT HERE NEXT FFI*/

// ============================================================
// STRING BUILDER
// ============================================================

MochaStringBuilder* mocha_sb_new() {
    MochaStringBuilder *sb = (MochaStringBuilder*)malloc(sizeof(MochaStringBuilder));
    MOCHA_OOM_CHECK(sb);
    sb->capacity = 256;
    sb->length   = 0;
    sb->data     = (char*)malloc(sb->capacity);
    MOCHA_OOM_CHECK(sb->data);
    sb->data[0]  = '\0';
    return sb;
}

void mocha_sb_append(MochaStringBuilder* sb, const char* s) {
    int slen = strlen(s);
    int needed = sb->length + slen + 1;
    if (needed > sb->capacity) {
        while (sb->capacity < needed)
            sb->capacity *= 2;
        sb->data = (char*)realloc(sb->data, sb->capacity);
        MOCHA_OOM_CHECK(sb->data);
    }
    memcpy(sb->data + sb->length, s, slen + 1);
    sb->length += slen;
}

char* mocha_sb_tostring(MochaStringBuilder* sb) {
    /* Returns a malloc'd copy — caller owns the memory */
    char* result = (char*)malloc(sb->length + 1);
    memcpy(result, sb->data, sb->length + 1);
    return result;
}

char* mocha_sb_reverse(MochaStringBuilder* sb) {
    // Step 1: collect codepoint boundaries
    int *starts = malloc(sb->length * sizeof(int));
    int *sizes  = malloc(sb->length * sizeof(int));
    int count = 0;
    int i = 0;
    while (i < sb->length) {
        unsigned char c = (unsigned char)sb->data[i];
        int size;
        if      (c < 0x80)   size = 1;
        else if (c < 0xE0)   size = 2;
        else if (c < 0xF0)   size = 3;
        else                  size = 4;
        starts[count] = i;
        sizes[count]  = size;
        count++;
        i += size;
    }

    // Step 2: write codepoints in reverse order
    char* result = (char*)malloc(sb->length + 1);
    int pos = 0;
    for (int j = count - 1; j >= 0; j--) {
        memcpy(result + pos, sb->data + starts[j], sizes[j]);
        pos += sizes[j];
    }
    result[sb->length] = '\0';

    free(starts);
    free(sizes);
    return result;
}

void mocha_sb_clear(MochaStringBuilder* sb) { sb->length  = 0; sb->data[0] = '\0'; }
int mocha_sb_length(MochaStringBuilder* sb) { return sb->length; }
void mocha_sb_free(MochaStringBuilder* sb) {free(sb->data); free(sb); }

/* ============================================================
 * TELL — built-in user input
 *
 * Reads a line from stdin, returns it as a heap-allocated
 * string with the trailing newline stripped.
 * Optional prompt is printed to stdout before blocking.
 *
 * tell()             — no prompt, just waits
 * tell("Enter: ")    — prints prompt first
 * ============================================================ */

char* mocha_tell(char *prompt) {
    if (prompt && prompt[0] != '\0') {
        printf("%s", prompt);
        fflush(stdout);  /* ensure prompt appears before blocking on read */
    }

    int32_t capacity = 128;
    char   *buf      = malloc(capacity);
    MOCHA_OOM_CHECK(buf);

    int32_t len = 0;
    int     ch;

    /* Read char by char so arbitrarily long input can be handled */
    while ((ch = getchar()) != '\n' && ch != EOF) {
        if (len + 1 >= capacity) {
            capacity *= 2;
            buf = realloc(buf, capacity);
            MOCHA_OOM_CHECK(buf);
        }
        buf[len++] = (char)ch;
    }
    buf[len] = '\0';
    return buf;
}

/* ============================================================
 * FILE I/O RUNTIME
 *
 * File object wrapping C's FILE*.
 * Modes: "read", "write", "append"
 *
 * open(path, mode)  → MochaFile*
 * f.read()          → str  (entire file)
 * f.readLine()      → str  (one line, "" at EOF)
 * f.write(str)      → void
 * f.close()         → void
 * f.exists(path)    → bool (static — no handle needed)
 * ============================================================ */

/* ---- Internal Helper ---- */
static const char* resolve_mode(const char *mode) {
    if (strcmp(mode, "read")   == 0) return "r";
    if (strcmp(mode, "write")  == 0) return "w";
    if (strcmp(mode, "append") == 0) return "a";
    fprintf(stderr, "MochaRuntimeError: Unknown file mode '%s'.\n"
                    "    Valid modes are: \"read\", \"write\", \"append\"\n", mode);
    exit(2);
}

/* ---- Construction ---- */ 
MochaFile* mocha_file_open(char *path, char *mode) {
    const char *c_mode = resolve_mode(mode);
    FILE *handle = fopen(path, c_mode);
    if (!handle) {
        fprintf(stderr, "MochaRuntimeError: Could not open file '%s' in mode \"%s\".\n"
                        "    Check the path exists and permissions are correct.\n",
                        path, mode);
        exit(2);
    }
    MochaFile *f = malloc(sizeof(MochaFile));
    MOCHA_OOM_CHECK(f);
    f->handle  = handle;
    f->path = strdup(path);
    MOCHA_OOM_CHECK(f->path);
    f->mode = strdup(mode);
    MOCHA_OOM_CHECK(f->mode);
    f->is_open = 1;
    return f;
}

/* ---- Read operations ---- */
//Read entire file into a heap string
char* mocha_file_read(MochaFile *f) {
    if (!f->is_open) {
        fprintf(stderr, "MochaRuntimeError: Cannot read from closed file '%s'.\n", f->path);
        exit(2);
    }
    //Seek to end to get size, then back to start
    fseek(f->handle, 0, SEEK_END);
    long size = ftell(f->handle);
    fseek(f->handle, 0, SEEK_SET);

    char *buf = malloc(size + 1);
    MOCHA_OOM_CHECK(buf);
    size_t read_bytes = fread(buf, 1, size, f->handle);
    buf[read_bytes] = '\0';
    if (read_bytes < size && ferror(f->handle)) {
        fprintf(stderr, "MochaRuntimeError: File read failed for '%s'.\n", f->path);
        exit(2);
    }
    return buf;
}

//Read one line — returns "" at EOF
char* mocha_file_readline(MochaFile *f) {
    if (!f->is_open) {
        fprintf(stderr, "MochaRuntimeError: Cannot read from closed file '%s'.\n", f->path);
        exit(2);
    }

    int32_t capacity = 128;
    char   *buf      = malloc(capacity);
    MOCHA_OOM_CHECK(buf);

    int32_t len = 0;
    int     ch;

    while ((ch = fgetc(f->handle)) != '\n' && ch != EOF) {
        if (len + 1 >= capacity) {
            capacity *= 2;
            buf = realloc(buf, capacity);
            MOCHA_OOM_CHECK(buf);
        }
        buf[len++] = (char)ch;
    }

    /* EOF with nothing read — return empty string to signal end */
    if (len == 0 && ch == EOF) {
        buf[0] = '\0';
        return buf;
    }

    if (len > 0 && buf[len - 1] == '\r')
        buf[--len] = '\0';
    buf[len] = '\0';
    return buf;
}

/* ---- Write operation ---- */ 
void mocha_file_write(MochaFile *f, char *content) {
    if (!f->is_open) {
        fprintf(stderr, "MochaRuntimeError: Cannot write to closed file '%s'.\n", f->path);
        exit(2);
    }
    fputs(content, f->handle);
    fflush(f->handle);
}

/* ---- Destruction ---- */
void mocha_file_close(MochaFile *f) {
    if (!f->is_open) return;
    fclose(f->handle);
    free(f->path);
    free(f->mode);
    f->path    = NULL;
    f->mode    = NULL;
    f->is_open = 0;
}

/* Standalone Utility — no handle needed */
int8_t mocha_file_exists(char *path) {
    FILE *test = fopen(path, "r");
    if (!test) return 0;
    fclose(test);
    return 1;
}

/* ============================================================
 * HASH TABLE RUNTIME
 *
 * Open-addressed hash table with quadratic probing.
 * Keys and values are heap strings (char*).
 *
 * Slot states:
 *   EMPTY    — never used
 *   OCCUPIED — live key-value pair
 *   MARKED   — deleted, probe chain must continue through it
 *
 * Hash function : FNV-1a (fast, excellent string distribution)
 * Probe sequence: index = (hash + i²) % capacity
 * Load factor   : 0.7  — resize (double) when exceeded
 * Initial cap   : 16   — always a power of 2
 *
 * HashTable ht = HashTable();
 * ht.put("name", "Shiv");
 * ht.get("name");          // "Shiv"
 * ht.has("name");          // true
 * ht.remove("name");
 * ht.size;                 // 0
 * ht.clear();
 * ht.keys();               // str[]
 * ht.values();             // str[]
 * ============================================================ */

/* ---- Internal helpers ---- */

//FNV-1a hash — fast, excellent string distribution
uint32_t ht_fnv1a(const char *key) { //static removed for mocha-ds lib Bloom Filter
    uint32_t hash = 2166136261u;
    while (*key) {
        hash ^= (uint8_t)*key++;
        hash *= 16777619u;
    }
    return hash;
}

/* ============================================================
 * INTERNAL — find slot index for a key
 *
 * Returns the index of:
 *   - the OCCUPIED slot with matching key (found)
 *   - the first EMPTY slot (not found, insert here)
 *   - the first MARKED slot seen (not found, reuse for insert)
 *
 * Returns -1 only if table is completely full with no EMPTY
 * slots (should never happen if load factor is respected).
 * ============================================================ */

static int32_t ht_find_slot(MochaHashTable *ht, const char *key) {
    uint32_t hash      = ht_fnv1a(key);
    int32_t  first_marked = -1;

    for (int32_t i = 0; i < ht->capacity; i++) {
        int32_t idx = (int32_t)((hash + (uint32_t)(i * i)) % (uint32_t)ht->capacity);
        MochaHEntry *slot = &ht->entries[idx];

        if (slot->state == HT_EMPTY) {
            /* Not found — return marked slot if we passed one,
               otherwise return this empty slot for insertion */
            return first_marked != -1 ? first_marked : idx;
        }

        if (slot->state == HT_MARKED) {
            /* Remember first marked slot — can reuse for insert */
            if (first_marked == -1) first_marked = idx;
            continue;
        }

        /* HT_OCCUPIED — check key match */
        if (strcmp(slot->key, key) == 0) {
            return idx;
        }
    }

    /* All slots visited — return first marked if any */
    if (first_marked != -1){
        return first_marked;
    }
    fprintf(stderr, "MochaRuntimeError: HashTable completely full.\n");
    exit(2);
}

//Resize table 2x and rehash all live entries
static void ht_resize(MochaHashTable *ht) {
    int32_t      old_cap     = ht->capacity;
    MochaHEntry *old_entries = ht->entries;

    ht->capacity = old_cap * 2;
    ht->entries  = (MochaHEntry*)calloc(ht->capacity, sizeof(MochaHEntry));
    MOCHA_OOM_CHECK(ht->entries);
    ht->count = 0;
    ht->used  = 0;

    /* Rehash all live entries into new table */
    for (int32_t i = 0; i < old_cap; i++) {
        if (old_entries[i].state != HT_OCCUPIED) continue;

        int32_t idx = ht_find_slot(ht, old_entries[i].key);
        ht->entries[idx].key   = old_entries[i].key;
        ht->entries[idx].value = old_entries[i].value;
        ht->entries[idx].state = HT_OCCUPIED;
        ht->count++;
        ht->used++;
    }

    free(old_entries);
}

/* ============================================================
 * PUBLIC API
 * ============================================================ */

MochaHashTable* mocha_ht_new() {
    MochaHashTable *ht = (MochaHashTable*)malloc(sizeof(MochaHashTable));
    MOCHA_OOM_CHECK(ht);
    ht->capacity = HT_INIT_CAP;
    ht->count    = 0;
    ht->used     = 0;
    ht->entries  = (MochaHEntry*)calloc(HT_INIT_CAP, sizeof(MochaHEntry));
    MOCHA_OOM_CHECK(ht->entries);
    return ht;
}

void mocha_ht_put(MochaHashTable *ht, char *key, char *value) {
    /* Resize before inserting if load factor exceeded */
    if ((float)(ht->used + 1) / (float)ht->capacity > HT_LOAD_FACTOR) {
        ht_resize(ht);
    }

    int32_t idx = ht_find_slot(ht, key);
    if (idx == -1) {
        fprintf(stderr, "MochaRuntimeError: HashTable is full — this should never happen.\n"
                        "    Please report this as a Mocha compiler bug.\n");
        exit(2);
    }

    MochaHEntry *slot = &ht->entries[idx];

    /* If key already exists — update value in place */
    if (slot->state == HT_OCCUPIED) {
        /* Value not freed — caller owns it, not the HashTable */
        slot->value = value;
        return;
    }

    /* New slot (EMPTY or MARKED reuse) */
    int8_t was_marked = (slot->state == HT_MARKED);
    slot->key   = strdup(key);
    MOCHA_OOM_CHECK(slot->key);
    slot->value = value;
    slot->state = HT_OCCUPIED;
    ht->count++;
    if (!was_marked) ht->used++;  /* marked slot reuse doesn't increase used */
}

void* mocha_ht_get(MochaHashTable *ht, char *key) {
    int32_t idx = ht_find_slot(ht, key);
    if (idx == -1 || ht->entries[idx].state != HT_OCCUPIED) {
        /* Key not found — Levenshtein hint like dict */
        int   qlen      = (int)strlen(key);
        int   threshold = qlen / 3 < 1 ? 1 : qlen / 3;
        int   best_dist = 999;
        char *best_key  = NULL;
        for (int32_t i = 0; i < ht->capacity; i++) {
            if (ht->entries[i].state != HT_OCCUPIED) continue;
            char *k    = ht->entries[i].key;
            int   klen = (int)strlen(k);
            int   dist = levenshtein(k, klen, key, qlen);
            if (dist < best_dist) {
                best_dist = dist;
                best_key  = k;
            }
        }
        if (best_key && best_dist <= threshold)
            fprintf(stderr,
                "MochaRuntimeError: Key '%s' not found in HashTable.\n"
                "    Did you mean '%s'?\n", key, best_key);
        else
            fprintf(stderr,
                "MochaRuntimeError: Key '%s' not found in HashTable.\n", key);
        exit(2);
    }
    return ht->entries[idx].value;
}

int8_t mocha_ht_has(MochaHashTable *ht, char *key) {
    int32_t idx = ht_find_slot(ht, key);
    return (idx != -1 && ht->entries[idx].state == HT_OCCUPIED) ? 1 : 0;
}

void mocha_ht_remove(MochaHashTable *ht, char *key) {
    int32_t idx = ht_find_slot(ht, key);
    if (idx == -1 || ht->entries[idx].state != HT_OCCUPIED) {
        fprintf(stderr,
            "MochaRuntimeError: Cannot remove key '%s' — not found in HashTable.\n", key);
        exit(2);
    }
    /* Free key (owned by HT via strdup), leave value (owned by caller).
    Mark as MARKED tombstone — probe chain only needs the state flag,
    not the key/value data, to maintain open addressing correctness. */
    free(ht->entries[idx].key);
    // value intentionally not freed — caller owns it
    ht->entries[idx].key   = NULL;
    ht->entries[idx].value = NULL;
    ht->entries[idx].state = HT_MARKED;
    ht->count--;
    /* ht->used unchanged — MARKED slot still occupies probe chain */
}

int32_t mocha_ht_size(MochaHashTable *ht) {
    return ht->count;
}

void mocha_ht_clear(MochaHashTable *ht) {
    for (int32_t i = 0; i < ht->capacity; i++) {
        if (ht->entries[i].state == HT_OCCUPIED) {
            free(ht->entries[i].key);
            // no freeing value because value is owned by caller, not freed here
        }
        ht->entries[i].key   = NULL;
        ht->entries[i].value = NULL;
        ht->entries[i].state = HT_EMPTY;
    }
    ht->count = 0;
    ht->used  = 0;
}

/* Returns a MochaArray* of all live keys */
MochaArray* mocha_ht_keys(MochaHashTable *ht) {
    MochaArray *arr = mocha_array_new(ht->count, 8, 0);
    for (int32_t i = 0; i < ht->capacity; i++) {
        if (ht->entries[i].state != HT_OCCUPIED) continue;
        char *k = strdup(ht->entries[i].key);
        MOCHA_OOM_CHECK(k);
        mocha_array_init_set(arr, arr->length, &k);
    }
    return arr;
}

/* Returns a MochaArray* of all live values */
MochaArray* mocha_ht_values(MochaHashTable *ht) {
    MochaArray *arr = mocha_array_new(ht->count, 8, 0);
    for (int32_t i = 0; i < ht->capacity; i++) {
        if (ht->entries[i].state != HT_OCCUPIED) continue;
        char *v = strdup(ht->entries[i].value);
        MOCHA_OOM_CHECK(v);
        mocha_array_init_set(arr, arr->length, &v);
    }
    return arr;
}

/* Destroy the HashTable! */
void mocha_ht_free(MochaHashTable *ht) {
    mocha_ht_clear(ht);
    free(ht->entries);
    free(ht);
}

/* ===============================================================================
   Mocha Exception Handling Runtime — setjmp/longjmp based
   Supports: try/rescue, fail (Java's throw and Python's raise) nesting, re-throw
   =============================================================================== */

#ifdef _WIN32
#include <windows.h>

typedef struct MochaExFrame {
    CONTEXT              ctx;
    const char*          message;
    int                  active;
    struct MochaExFrame* prev;
} MochaExFrame;

static volatile MochaExFrame* mocha_ex_top = NULL;
static volatile int mocha_ex_landed = 0;

__attribute__((noinline)) void mocha_ex_enter(MochaExFrame* frame) {
    mocha_ex_landed = 0;
    RtlCaptureContext(&frame->ctx);
    // when RtlRestoreContext brings us back, landed will be 1
    // then we set it to 2 to avoid infinite loop
    if (mocha_ex_landed == 1) {
        mocha_ex_landed = 2;
    }
}

int mocha_ex_did_land(void) {
    return (mocha_ex_landed == 2) ? 1 : 0;
}

void mocha_ex_throw(const char* msg) {
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Unhandled exception: %s\n", msg);
        exit(2);
    }
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    frame->message = msg;
    frame->active  = 1;
    mocha_ex_landed = 1;
    RtlRestoreContext(&frame->ctx, NULL);
}

void mocha_ex_rethrow(void) {
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): rethrow with no active exception.\n");
        exit(2);
    }
    const char* msg = ((MochaExFrame*)mocha_ex_top)->message;
    mocha_ex_top = ((MochaExFrame*)mocha_ex_top)->prev;
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Unhandled exception: %s\n", msg);
        exit(2);
    }
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    frame->message = msg;
    frame->active  = 1;
    mocha_ex_landed = 1;
    RtlRestoreContext(&frame->ctx, NULL);
}

const char* mocha_ex_pop(void) {
    if (!mocha_ex_top) return NULL;
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    const char*   msg   = frame->message;
    mocha_ex_top        = frame->prev;
    return msg;
}

MochaExFrame* mocha_ex_push(void) {
    MochaExFrame* frame = (MochaExFrame*)malloc(sizeof(MochaExFrame));
    if (!frame) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Out of memory.\n");
        exit(2);
    }
    frame->message = NULL;
    frame->active  = 0;
    frame->prev    = (MochaExFrame*)mocha_ex_top;
    mocha_ex_top   = frame;
    return frame;
}

#else
// ── Linux / macOS ──────────────────────────────────────────
#include <setjmp.h>

typedef struct MochaExFrame {
    jmp_buf              env;
    const char*          message;
    int                  active;
    struct MochaExFrame* prev;
} MochaExFrame;

static volatile MochaExFrame* mocha_ex_top = NULL;
static volatile int mocha_ex_landed = 0;

__attribute__((noinline)) void mocha_ex_enter(MochaExFrame* frame) {
    mocha_ex_landed = 0;
    if (setjmp(frame->env) != 0) {
        mocha_ex_landed = 1;
    }
}

int mocha_ex_did_land(void) {
    return mocha_ex_landed;
}

void mocha_ex_throw(const char* msg) {
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Unhandled exception: %s\n", msg);
        exit(2);
    }
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    frame->message = msg;
    frame->active  = 1;
    longjmp(frame->env, 1);
}

void mocha_ex_rethrow(void) {
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): rethrow with no active exception.\n");
        exit(2);
    }
    const char* msg = ((MochaExFrame*)mocha_ex_top)->message;
    mocha_ex_top = ((MochaExFrame*)mocha_ex_top)->prev;
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Unhandled exception: %s\n", msg);
        exit(2);
    }
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    frame->message = msg;
    frame->active  = 1;
    longjmp(frame->env, 1);
}

const char* mocha_ex_pop(void) {
    if (!mocha_ex_top) return NULL;
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    const char*   msg   = frame->message;
    mocha_ex_top        = frame->prev;
    return msg;
}

MochaExFrame* mocha_ex_push(void) {
    MochaExFrame* frame = (MochaExFrame*)malloc(sizeof(MochaExFrame));
    if (!frame) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Out of memory.\n");
        exit(2);
    }
    frame->message = NULL;
    frame->active  = 0;
    frame->prev    = (MochaExFrame*)mocha_ex_top;
    mocha_ex_top   = frame;
    return frame;
}
#endif

/* ===============================================================
   Mocha Runtime Stack Tracking
   =============================================================== */

typedef struct {
    const char* func_name;
    const char* file_name;
    int         line;
} MochaStackFrame;

static MochaStackFrame mocha_call_stack[256];
static int             mocha_call_stack_top = 0;

void mocha_stack_push(const char* func_name, const char* file_name, int line) {
    if (mocha_call_stack_top >= 256) return;
    mocha_call_stack[mocha_call_stack_top].func_name = func_name;
    mocha_call_stack[mocha_call_stack_top].file_name = file_name;
    mocha_call_stack[mocha_call_stack_top].line      = line;
    mocha_call_stack_top++;
}

void mocha_stack_pop(void) {
    if (mocha_call_stack_top > 0)
        mocha_call_stack_top--;
}

void mocha_stack_update_line(int line) {
    if (mocha_call_stack_top > 0)
        mocha_call_stack[mocha_call_stack_top - 1].line = line;
}

void mocha_stack_print(void) {
    fprintf(stderr, "Mocha's Traceback (this error resulted from the following calls):\n");
    for (int i = 0; i < mocha_call_stack_top; i++) {
        fprintf(stderr, "  at %s (%s:%d)\n",
            mocha_call_stack[i].func_name,
            mocha_call_stack[i].file_name,
            mocha_call_stack[i].line);
    }
}

/* ============================================================
 * mocha-ink — SVG Visualization Runtime
 * Output: SVG files, optionally opened in browser
 * ============================================================ */

/* ── Constants ── */
#define INK_WIDTH         900
#define INK_HEIGHT        600
#define INK_MARGIN_TOP     50
#define INK_MARGIN_RIGHT   30
#define INK_MARGIN_BOTTOM  70
#define INK_MARGIN_LEFT    80
#define INK_MAX_SERIES      8
#define INK_MAX_POINTS   1024
#define INK_STROKE_WIDTH    2
#define INK_DOT_RADIUS      4

/* ── Default color palette (Tableau 8, colorblind-friendly) ── */
static const char* INK_PALETTE[] = {
    "#4E79A7",  /* steelblue */
    "#F28E2B",  /* orange    */
    "#E15759",  /* red       */
    "#76B7B2",  /* teal      */
    "#59A14F",  /* green     */
    "#EDC948",  /* gold      */
    "#B07AA1",  /* purple    */
    "#FF9DA7",  /* pink      */
};

/* ── Named color map ── */
typedef struct { const char* name; const char* hex; } InkColor;
static const InkColor INK_COLORS[] = {
    {"red",         "#E15759"},
    {"blue",        "#4E79A7"},
    {"green",       "#59A14F"},
    {"orange",      "#F28E2B"},
    {"purple",      "#B07AA1"},
    {"pink",        "#FF9DA7"},
    {"brown",       "#9C755F"},
    {"gray",        "#BAB0AC"},
    {"grey",        "#BAB0AC"},
    {"black",       "#000000"},
    {"white",       "#FFFFFF"},
    {"yellow",      "#EDC948"},
    {"cyan",        "#76B7B2"},
    {"magenta",     "#E15759"},
    {"coral",       "#FF6B6B"},
    {"teal",        "#76B7B2"},
    {"navy",        "#1F3A5F"},
    {"lime",        "#8BC34A"},
    {"maroon",      "#7B2D2D"},
    {"gold",        "#EDC948"},
    {"steelblue",   "#4E79A7"},
    {NULL, NULL}
};

/* ── Series ── */
typedef struct {
    double  x[INK_MAX_POINTS];
    double  y[INK_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
    int     is_scatter;
    int     is_area;     /* new */

} InkSeries;

/* ── Plot ── */
typedef struct {
    InkSeries series[INK_MAX_SERIES];
    int       n_series;
    char      title[128];
    char      xlabel[64];
    char      ylabel[64];
    int       width;
    int       height;
    int       grid;
} InkPlot;

typedef InkPlot LinePlot;
typedef InkPlot ScatterPlot;

/* ── Color lookup ── */
static const char* ink_resolve_color(const char* name) {
    for (int i = 0; INK_COLORS[i].name != NULL; i++) {
        if (strcmp(INK_COLORS[i].name, name) == 0)
            return INK_COLORS[i].hex;
    }
    /* if not found, assume it's already a hex or valid SVG color */
    return name;
}

/* ── Nice tick calculation ── */
static double ink_nice_step(double range, int target_ticks) {
    double rough = range / target_ticks;
    double mag   = pow(10.0, floor(log10(rough)));
    double norm  = rough / mag;
    double nice;
    if      (norm < 1.5) nice = 1.0;
    else if (norm < 3.0) nice = 2.0;
    else if (norm < 7.0) nice = 5.0;
    else                 nice = 10.0;
    return nice * mag;
}

static void ink_nice_range(double data_min, double data_max,
                           double* out_min, double* out_max, double* out_step) {
    double range = data_max - data_min;
    if (range == 0.0) range = 1.0;
    double step  = ink_nice_step(range, 6);
    *out_min  = floor(data_min / step) * step;
    *out_max  = ceil(data_max  / step) * step;
    *out_step = step;
}

/* ── Coordinate mapping ── */
static double ink_map_x(double val, double min, double max,
                         int plot_x, int plot_w) {
    return plot_x + (val - min) / (max - min) * plot_w;
}

static double ink_map_y(double val, double min, double max,
                         int plot_y, int plot_h) {
    /* SVG y is inverted */
    return plot_y + plot_h - (val - min) / (max - min) * plot_h;
}

/* ── Constructor helpers ── */
static InkPlot* ink_new(int is_scatter,
                        double* x, double* y, int n) {
    InkPlot* p = (InkPlot*)malloc(sizeof(InkPlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkPlot));
    p->width  = INK_WIDTH;
    p->height = INK_HEIGHT;
    p->grid   = 1;

    /* first series */
    InkSeries* s = &p->series[0];
    int count = n < INK_MAX_POINTS ? n : INK_MAX_POINTS;
    for (int i = 0; i < count; i++) {
        s->x[i] = x[i];
        s->y[i] = y[i];
    }
    s->n          = count;
    s->is_scatter = is_scatter;
    strncpy(s->color, INK_PALETTE[0], 31);
    strncpy(s->label, "", 63);
    p->n_series = 1;

    strncpy(p->title,  "", 127);
    strncpy(p->xlabel, "", 63);
    strncpy(p->ylabel, "", 63);
    return p;
}

InkPlot* ink_new_line(double* x, double* y, int n) {
    return ink_new(0, x, y, n);
}

InkPlot* ink_new_scatter(double* x, double* y, int n) {
    return ink_new(1, x, y, n);
}

/* ── Setters ── */
void ink_set_title(InkPlot* p, const char* t) {
    strncpy(p->title, t, 127);
}

void ink_set_xlabel(InkPlot* p, const char* l) {
    strncpy(p->xlabel, l, 63);
}

void ink_set_ylabel(InkPlot* p, const char* l) {
    strncpy(p->ylabel, l, 63);
}

void ink_set_color(InkPlot* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color,
            ink_resolve_color(c), 31);
}

void ink_set_grid(InkPlot* p, int8_t on) {
    p->grid = on ? 1 : 0;
}

/* ── Add series ── */
static void ink_add_series(InkPlot* p, int is_scatter,
                           double* x, double* y, int n) {
    if (p->n_series >= INK_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max series (%d) reached, ignoring\n",
                INK_MAX_SERIES);
        return;
    }
    InkSeries* s = &p->series[p->n_series];
    int count = n < INK_MAX_POINTS ? n : INK_MAX_POINTS;
    for (int i = 0; i < count; i++) {
        s->x[i] = x[i];
        s->y[i] = y[i];
    }
    s->n          = count;
    s->is_scatter = is_scatter;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

void ink_add_line(InkPlot* p, double* x, double* y, int n) {
    ink_add_series(p, 0, x, y, n);
}

void ink_add_scatter(InkPlot* p, double* x, double* y, int n) {
    ink_add_series(p, 1, x, y, n);
}

void ink_set_label(InkPlot* p, const char* label) {
    strncpy(p->series[p->n_series - 1].label, label, 63);
}

/* ── SVG generation ── */
void ink_save(InkPlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W = p->width;
    int H = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;   /* plot area width  */
    int ph = H - mt - mb;   /* plot area height */

    /* ── find data range across all series ── */
    double xmin = p->series[0].x[0], xmax = xmin;
    double ymin = p->series[0].y[0], ymax = ymin;
    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double xi = p->series[s].x[i];
            double yi = p->series[s].y[i];
            if (xi < xmin) xmin = xi;
            if (xi > xmax) xmax = xi;
            if (yi < ymin) ymin = yi;
            if (yi > ymax) ymax = yi;
        }
    }

    double nx_min, nx_max, nx_step;
    double ny_min, ny_max, ny_step;
    ink_nice_range(xmin, xmax, &nx_min, &nx_max, &nx_step);
    ink_nice_range(ymin, ymax, &ny_min, &ny_max, &ny_step);

    /* ── SVG header ── */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* ── background ── */
    fprintf(f,
        "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n",
        W, H
    );

    /* ── plot area background ── */
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* ── grid lines ── */
    if (p->grid) {
        /* horizontal grid lines (y axis) */
        for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
            double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
        /* vertical grid lines (x axis) */
        for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
            double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                gx, mt, gx, mt + ph
            );
        }
    }

    /* ── x axis ticks and labels ── */
    for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
        double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
        /* tick mark */
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            gx, mt + ph, gx, mt + ph + 5
        );
        /* label */
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" class=\"ink-tick\">%g</text>\n",
            gx, mt + ph + 18, v
        );
    }

    /* ── y axis ticks and labels ── */
    for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
        double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
        /* tick mark */
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            ml - 5, gy, ml, gy
        );
        /* label */
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
            ml - 8, gy, v
        );
    }

    /* ── axis border lines ── */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph   /* x axis */
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph              /* y axis */
    );

    /* ── clip region for data ── */
    fprintf(f,
        "<clipPath id=\"ink-clip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n",
        ml - INK_DOT_RADIUS, mt - INK_DOT_RADIUS, 
        pw + INK_DOT_RADIUS * 2, ph + INK_DOT_RADIUS * 2
    );

    /* ── draw series ── */
    for (int s = 0; s < p->n_series; s++) {
        InkSeries* sr = &p->series[s];
        const char* col = sr->color;

        if (sr->is_area) {
            /* filled polygon — line on top, baseline at y=0 */
            double baseline = ink_map_y(0.0, ny_min, ny_max, mt, ph);
            /* clamp baseline to plot area */
            if (baseline > mt + ph) baseline = mt + ph;
            if (baseline < mt)      baseline = mt;

            /* filled area polygon */
            fprintf(f,
                "<polygon fill=\"%s\" opacity=\"0.3\" "
                "clip-path=\"url(#ink-clip)\" points=\"",
                col
            );
            /* start at baseline left */
            double px0 = ink_map_x(sr->x[0], nx_min, nx_max, ml, pw);
            fprintf(f, "%.2f,%.2f ", px0, baseline);
            /* top edge */
            for (int i = 0; i < sr->n; i++) {
                double px = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
                double py = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            /* end at baseline right */
            double pxn = ink_map_x(sr->x[sr->n-1], nx_min, nx_max, ml, pw);
            fprintf(f, "%.2f,%.2f ", pxn, baseline);
            fprintf(f, "\"/>\n");

            /* line on top */
            fprintf(f,
                "<polyline fill=\"none\" stroke=\"%s\" stroke-width=\"%d\" "
                "stroke-linejoin=\"round\" stroke-linecap=\"round\" "
                "clip-path=\"url(#ink-clip)\" points=\"",
                col, INK_STROKE_WIDTH
            );
            for (int i = 0; i < sr->n; i++) {
                double px = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
                double py = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f, "\"/>\n");

        } else if (sr->is_scatter) {
            /* scatter — dots */
            for (int i = 0; i < sr->n; i++) {
                double cx = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
                double cy = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
                fprintf(f,
                    "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"%d\" "
                    "fill=\"%s\" opacity=\"0.8\" clip-path=\"url(#ink-clip)\"/>\n",
                    cx, cy, INK_DOT_RADIUS, col
                );
            }
        } else {
            /* line — polyline */
            fprintf(f,
                "<polyline fill=\"none\" stroke=\"%s\" stroke-width=\"%d\" "
                "stroke-linejoin=\"round\" stroke-linecap=\"round\" "
                "clip-path=\"url(#ink-clip)\" points=\"",
                col, INK_STROKE_WIDTH
            );
            for (int i = 0; i < sr->n; i++) {
                double px = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
                double py = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f, "\"/>\n");

            /* dots on line */
            for (int i = 0; i < sr->n; i++) {
                double cx = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
                double cy = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
                fprintf(f,
                    "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"3\" "
                    "fill=\"%s\" clip-path=\"url(#ink-clip)\"/>\n",
                    cx, cy, col
                );
            }
        }
    }

    /* ── title ── */
    if (p->title[0]) {
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );
    }

    /* ── x axis label ── */
    if (p->xlabel[0]) {
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );
    }

    /* ── y axis label (rotated) ── */
    if (p->ylabel[0]) {
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );
    }

    /* ── legend (only if multi-series or label set) ── */
    int show_legend = 0;
    for (int s = 0; s < p->n_series; s++) {
        if (p->series[s].label[0]) { show_legend = 1; break; }
    }
    if (p->n_series > 1) show_legend = 1;

    if (show_legend) {
        int lx = ml + pw - 10;
        int ly = mt + 10;
        int lw = 130;
        int lh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" rx=\"4\" opacity=\"0.9\"/>\n",
            lx - lw, ly, lw, lh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = ly + 10 + s * 22;
            const char* col = p->series[s].color;
            const char* lbl = p->series[s].label[0]
                              ? p->series[s].label
                              : (s == 0 ? "Series 1" :
                                 s == 1 ? "Series 2" :
                                 s == 2 ? "Series 3" : "Series");
            fprintf(f,
                "<rect x=\"%d\" y=\"%d\" width=\"14\" height=\"14\" fill=\"%s\" rx=\"2\"/>\n",
                lx - lw + 8, iy, col
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx - lw + 28, iy + 11, lbl
            );
        }
    }

    fprintf(f, "</svg>\n");
    fclose(f);
}

/* ── show — save to temp and open in browser ── */
void ink_show(InkPlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── free ── */
void ink_free(InkPlot* p) {
    free(p);
}

/* ── Mocha array bridge ── */
InkPlot* ink_new_line_mocha(MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    InkPlot* p = ink_new_line(xd, yd, n);
    free(xd);
    free(yd);
    return p;
}

InkPlot* ink_new_scatter_mocha(MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    InkPlot* p = ink_new_scatter(xd, yd, n);
    free(xd);
    free(yd);
    return p;
}

void ink_add_line_mocha(InkPlot* p, MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    ink_add_line(p, xd, yd, n);
    free(xd);
    free(yd);
}

void ink_add_scatter_mocha(InkPlot* p, MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    ink_add_scatter(p, xd, yd, n);
    free(xd);
    free(yd);
}

// LinePlot wrappers
void ink_lp_set_title(LinePlot* p, const char* t)  { ink_set_title(p, t); }
void ink_lp_set_xlabel(LinePlot* p, const char* l) { ink_set_xlabel(p, l); }
void ink_lp_set_ylabel(LinePlot* p, const char* l) { ink_set_ylabel(p, l); }
void ink_lp_set_color(LinePlot* p, const char* c)  { ink_set_color(p, c); }
void ink_lp_set_label(LinePlot* p, const char* l)  { ink_set_label(p, l); }
void ink_lp_set_grid(LinePlot* p, int8_t on)       { ink_set_grid(p, on); }
void ink_lp_add_line(LinePlot* p, MochaArray* x, MochaArray* y)    { ink_add_line_mocha(p, x, y); }
void ink_lp_add_scatter(LinePlot* p, MochaArray* x, MochaArray* y) { ink_add_scatter_mocha(p, x, y); }
void ink_lp_save(LinePlot* p, const char* path)    { ink_save(p, path); }
void ink_lp_show(LinePlot* p)                      { ink_show(p); }

// ScatterPlot wrappers
void ink_sp_set_title(ScatterPlot* p, const char* t)  { ink_set_title(p, t); }
void ink_sp_set_xlabel(ScatterPlot* p, const char* l) { ink_set_xlabel(p, l); }
void ink_sp_set_ylabel(ScatterPlot* p, const char* l) { ink_set_ylabel(p, l); }
void ink_sp_set_color(ScatterPlot* p, const char* c)  { ink_set_color(p, c); }
void ink_sp_set_label(ScatterPlot* p, const char* l)  { ink_set_label(p, l); }
void ink_sp_set_grid(ScatterPlot* p, int8_t on)       { ink_set_grid(p, on); }
void ink_sp_add_line(ScatterPlot* p, MochaArray* x, MochaArray* y)    { ink_add_line_mocha(p, x, y); }
void ink_sp_add_scatter(ScatterPlot* p, MochaArray* x, MochaArray* y) { ink_add_scatter_mocha(p, x, y); }
void ink_sp_save(ScatterPlot* p, const char* path)    { ink_save(p, path); }
void ink_sp_show(ScatterPlot* p)                      { ink_show(p); }

/* ============================================================
 * mocha-ink — Bar Chart
 * ============================================================ */

#define INK_MAX_BARS     64
#define INK_MAX_BAR_SERIES 8
#define INK_BAR_GAP_RATIO  0.2  /* 20% of bar width as gap */

typedef struct {
    double  values[INK_MAX_BARS];
    int     n;
    char    color[32];
    char    label[64];
} InkBarSeries;

typedef struct {
    InkBarSeries series[INK_MAX_BAR_SERIES];
    int          n_series;
    char         labels[INK_MAX_BARS][64];  /* x axis category labels */
    int          n_labels;
    char         title[128];
    char         xlabel[64];
    char         ylabel[64];
    int          width;
    int          height;
    int          grid;
    int          horizontal;
    int          show_values;  /* auto: 1 if n_labels <= 8 */
} InkBarChart;

typedef InkBarChart BarChart;

static InkBarChart* ink_new_bar(char** labels, double* values, int n) {
    InkBarChart* p = (InkBarChart*)malloc(sizeof(InkBarChart));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkBarChart));
    p->width      = INK_WIDTH;
    p->height     = INK_HEIGHT;
    p->grid       = 1;
    p->horizontal = 0;
    p->show_values = (n <= 8) ? 1 : 0;

    int count = n < INK_MAX_BARS ? n : INK_MAX_BARS;
    for (int i = 0; i < count; i++) {
        p->series[0].values[i] = values[i];
        strncpy(p->labels[i], labels[i], 63);
    }
    p->series[0].n = count;
    p->n_labels    = count;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

InkBarChart* ink_new_bar_mocha(MochaArray* labels, MochaArray* values) {
    int n = labels->length < values->length ? labels->length : values->length;
    char** lbls = (char**)malloc(n * sizeof(char*));
    double* vals = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        char* lbl;
        mocha_array_get(labels, i, &lbl);
        lbls[i] = lbl;
        double v;
        mocha_array_get(values, i, &v);
        vals[i] = v;
    }
    InkBarChart* p = ink_new_bar(lbls, vals, n);
    free(lbls);
    free(vals);
    return p;
}

void ink_bar_add_series_mocha(InkBarChart* p, MochaArray* values) {
    if (p->n_series >= INK_MAX_BAR_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max bar series reached, ignoring\n");
        return;
    }
    InkBarSeries* s = &p->series[p->n_series];
    int n = values->length < INK_MAX_BARS ? values->length : INK_MAX_BARS;
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(values, i, &v);
        s->values[i] = v;
    }
    s->n = n;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── bar setters ── */
void ink_bar_set_title(InkBarChart* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_bar_set_xlabel(InkBarChart* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_bar_set_ylabel(InkBarChart* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_bar_set_grid(InkBarChart* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_bar_set_horizontal(InkBarChart* p)            { p->horizontal = 1;           }
void ink_bar_set_color(InkBarChart* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, ink_resolve_color(c), 31);
}
void ink_bar_set_label(InkBarChart* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── bar SVG generation ── */
void ink_bar_save(InkBarChart* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find value range */
    double vmin = 0.0;  /* bars always start at 0 */
    double vmax = 0.0;
    for (int s = 0; s < p->n_series; s++)
        for (int i = 0; i < p->series[s].n; i++)
            if (p->series[s].values[i] > vmax)
                vmax = p->series[s].values[i];

    double nv_min, nv_max, nv_step;
    ink_nice_range(vmin, vmax, &nv_min, &nv_max, &nv_step);
    nv_min = 0.0;  /* force zero baseline */

    /* bar geometry */
    int   n_cats    = p->n_labels;
    int   n_series  = p->n_series;
    double group_w  = (double)pw / n_cats;
    double gap      = group_w * INK_BAR_GAP_RATIO;
    double bar_area = group_w - gap;
    double bar_w    = bar_area / n_series;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-val    { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 10px; fill: #444; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* grid lines */
    if (p->grid && !p->horizontal) {
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
    }

    if (!p->horizontal) {
        /* ── vertical bars ── */

        /* y axis ticks */
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                ml - 5, gy, ml, gy
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
                "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
                ml - 8, gy, v
            );
        }

        /* bars */
        for (int i = 0; i < n_cats; i++) {
            double group_x = ml + i * group_w + gap / 2.0;
            double baseline = ink_map_y(0.0, nv_min, nv_max, mt, ph);

            for (int s = 0; s < n_series; s++) {
                double val  = p->series[s].values[i];
                double bx   = group_x + s * bar_w;
                double by   = ink_map_y(val, nv_min, nv_max, mt, ph);
                double bh   = baseline - by;
                const char* col = p->series[s].color;

                fprintf(f,
                    "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                    "fill=\"%s\" opacity=\"0.85\" rx=\"2\"/>\n",
                    bx, by, bar_w, bh, col
                );

                /* value label on top */
                if (p->show_values) {
                    fprintf(f,
                        "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                        "class=\"ink-val\">%g</text>\n",
                        bx + bar_w / 2.0, by - 4.0, val
                    );
                }
            }

            /* x axis category label */
            double label_x = group_x + bar_area / 2.0;
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                label_x, mt + ph, label_x, mt + ph + 5
            );
            fprintf(f,
                "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                "class=\"ink-tick\">%s</text>\n",
                label_x, mt + ph + 18, p->labels[i]
            );
        }

    } else {
        /* ── horizontal bars ── */
        double group_h  = (double)ph / n_cats;
        double h_gap    = group_h * INK_BAR_GAP_RATIO;
        double h_area   = group_h - h_gap;
        double h_bar_h  = h_area / n_series;

        /* x axis ticks */
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gx = ink_map_x(v, nv_min, nv_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                gx, mt + ph, gx, mt + ph + 5
            );
            fprintf(f,
                "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                "class=\"ink-tick\">%g</text>\n",
                gx, mt + ph + 18, v
            );
            if (p->grid) {
                fprintf(f,
                    "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                    "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                    gx, mt, gx, mt + ph
                );
            }
        }

        /* bars */
        for (int i = 0; i < n_cats; i++) {
            double group_y = mt + i * group_h + h_gap / 2.0;

            for (int s = 0; s < n_series; s++) {
                double val  = p->series[s].values[i];
                double by   = group_y + s * h_bar_h;
                double bw   = ink_map_x(val, nv_min, nv_max, 0, pw);
                const char* col = p->series[s].color;

                fprintf(f,
                    "<rect x=\"%d\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                    "fill=\"%s\" opacity=\"0.85\" rx=\"2\"/>\n",
                    ml, by, bw, h_bar_h, col
                );

                if (p->show_values) {
                    fprintf(f,
                        "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"start\" "
                        "dominant-baseline=\"middle\" class=\"ink-val\">%g</text>\n",
                        ml + bw + 4.0, by + h_bar_h / 2.0, val
                    );
                }
            }

            /* y axis category label */
            double label_y = group_y + h_area / 2.0;
            fprintf(f,
                "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
                "dominant-baseline=\"middle\" class=\"ink-tick\">%s</text>\n",
                ml - 8, label_y, p->labels[i]
            );
        }
    }

    /* axis border lines */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x axis label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y axis label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    /* legend */
    int show_legend = 0;
    for (int s = 0; s < p->n_series; s++)
        if (p->series[s].label[0]) { show_legend = 1; break; }
    if (p->n_series > 1) show_legend = 1;

    if (show_legend) {
        int lx = ml + pw - 10;
        int ly = mt + 10;
        int lw = 130;
        int lh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" rx=\"4\" opacity=\"0.9\"/>\n",
            lx - lw, ly, lw, lh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = ly + 10 + s * 22;
            fprintf(f,
                "<rect x=\"%d\" y=\"%d\" width=\"14\" height=\"14\" fill=\"%s\" rx=\"2\"/>\n",
                lx - lw + 8, iy, p->series[s].color
            );
            const char* lbl = p->series[s].label[0] ? p->series[s].label
                              : (s == 0 ? "Series 1" : s == 1 ? "Series 2" : "Series");
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx - lw + 28, iy + 11, lbl
            );
        }
    }

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_bar_show(InkBarChart* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_bar_save(p, tmp);
    #ifdef _WIN32
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "start %s", tmp);
        system(cmd);
    #elif defined(__APPLE__)
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "open %s", tmp);
        system(cmd);
    #else
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
        system(cmd);
    #endif
}

typedef InkBarChart BarChart;

void ink_bc_set_title(BarChart* p, const char* t)  { ink_bar_set_title(p, t);      }
void ink_bc_set_xlabel(BarChart* p, const char* l) { ink_bar_set_xlabel(p, l);     }
void ink_bc_set_ylabel(BarChart* p, const char* l) { ink_bar_set_ylabel(p, l);     }
void ink_bc_set_color(BarChart* p, const char* c)  { ink_bar_set_color(p, c);      }
void ink_bc_set_label(BarChart* p, const char* l)  { ink_bar_set_label(p, l);      }
void ink_bc_set_grid(BarChart* p, int8_t on)       { ink_bar_set_grid(p, on);      }
void ink_bc_set_horizontal(BarChart* p)            { ink_bar_set_horizontal(p);    }
void ink_bc_add_series(BarChart* p, MochaArray* v) { ink_bar_add_series_mocha(p, v); }
void ink_bc_save(BarChart* p, const char* path)    { ink_bar_save(p, path);        }
void ink_bc_show(BarChart* p)                      { ink_bar_show(p);              }

/* ============================================================
 * mocha-ink — Heatmap
 * ============================================================ */

#define INK_HEAT_MAX_ROWS 64
#define INK_HEAT_MAX_COLS 64

typedef struct {
    double  data[INK_HEAT_MAX_ROWS][INK_HEAT_MAX_COLS];
    int     rows;
    int     cols;
    char    row_labels[INK_HEAT_MAX_ROWS][64];
    char    col_labels[INK_HEAT_MAX_COLS][64];
    char    title[128];
    char    xlabel[64];
    char    ylabel[64];
    int     width;
    int     height;
    int     show_values;  /* auto: 1 if small matrix */
    /* color scheme: 0 = blue->red, 1 = white->blue, 2 = black->yellow */
    int     color_scheme;
} InkHeatmap;

typedef InkHeatmap Heatmap;

/* ── color interpolation ── */
static void ink_heat_color(double t, int scheme, char* out) {
    /* t in [0,1]: 0 = cool, 1 = hot */
    int r, g, b;
    if (scheme == 1) {
        /* white -> blue */
        r = (int)(255 * (1.0 - t));
        g = (int)(255 * (1.0 - t));
        b = 255;
    } else if (scheme == 2) {
        /* black -> yellow */
        r = (int)(255 * t);
        g = (int)(255 * t);
        b = 0;
    } else {
        /* blue -> red (default) */
        if (t < 0.25) {
            r = 0;
            g = (int)(255 * (t / 0.25));
            b = 255;
        } else if (t < 0.5) {
            r = 0;
            g = 255;
            b = (int)(255 * (1.0 - (t - 0.25) / 0.25));
        } else if (t < 0.75) {
            r = (int)(255 * ((t - 0.5) / 0.25));
            g = 255;
            b = 0;
        } else {
            r = 255;
            g = (int)(255 * (1.0 - (t - 0.75) / 0.25));
            b = 0;
        }
    }
    snprintf(out, 16, "#%02X%02X%02X", r, g, b);
}

static InkHeatmap* ink_new_heatmap(double data[][INK_HEAT_MAX_COLS],
                                    int rows, int cols) {
    InkHeatmap* p = (InkHeatmap*)malloc(sizeof(InkHeatmap));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkHeatmap));
    p->width        = INK_WIDTH;
    p->height       = INK_HEIGHT;
    p->rows         = rows;
    p->cols         = cols;
    p->show_values  = (rows <= 12 && cols <= 12) ? 1 : 0;
    p->color_scheme = 0;

    for (int i = 0; i < rows; i++)
        for (int j = 0; j < cols; j++)
            p->data[i][j] = data[i][j];

    /* default labels: 0,1,2... */
    for (int i = 0; i < rows; i++)
        snprintf(p->row_labels[i], 63, "%d", i);
    for (int j = 0; j < cols; j++)
        snprintf(p->col_labels[j], 63, "%d", j);

    return p;
}

InkHeatmap* ink_new_heatmap_mocha(MochaArray2D* mat) {
    int rows = mat->rows;
    int cols = mat->cols;
    if (rows > INK_HEAT_MAX_ROWS) rows = INK_HEAT_MAX_ROWS;
    if (cols > INK_HEAT_MAX_COLS) cols = INK_HEAT_MAX_COLS;

    /* temp 2D array */
    double data[INK_HEAT_MAX_ROWS][INK_HEAT_MAX_COLS];
    memset(data, 0, sizeof(data));

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            double v;
            mocha_array2d_get(mat, i, j, &v);
            data[i][j] = v;
        }
    }
    return ink_new_heatmap(data, rows, cols);
}

/* ── setters ── */
void ink_hm_set_title(InkHeatmap* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_hm_set_xlabel(InkHeatmap* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_hm_set_ylabel(InkHeatmap* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_hm_set_scheme_blue_red(InkHeatmap* p)       { p->color_scheme = 0; }
void ink_hm_set_scheme_white_blue(InkHeatmap* p)     { p->color_scheme = 1; }
void ink_hm_set_scheme_black_yellow(InkHeatmap* p)   { p->color_scheme = 2; }

void ink_hm_set_row_label(InkHeatmap* p, int i, const char* l) {
    if (i >= 0 && i < p->rows) strncpy(p->row_labels[i], l, 63);
}

void ink_hm_set_col_label(InkHeatmap* p, int j, const char* l) {
    if (j >= 0 && j < p->cols) strncpy(p->col_labels[j], l, 63);
}

/* ── SVG generation ── */
void ink_hm_save(InkHeatmap* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT + 60;  /* extra for colorbar */
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find min/max */
    double vmin = p->data[0][0];
    double vmax = p->data[0][0];
    for (int i = 0; i < p->rows; i++)
        for (int j = 0; j < p->cols; j++) {
            if (p->data[i][j] < vmin) vmin = p->data[i][j];
            if (p->data[i][j] > vmax) vmax = p->data[i][j];
        }
    double range = vmax - vmin;
    if (range == 0.0) range = 1.0;

    double cell_w = (double)pw / p->cols;
    double cell_h = (double)ph / p->rows;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-val    { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 9px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);

    /* cells */
    for (int i = 0; i < p->rows; i++) {
        for (int j = 0; j < p->cols; j++) {
            double val = p->data[i][j];
            double t   = (val - vmin) / range;
            char color[16];
            ink_heat_color(t, p->color_scheme, color);

            double cx = ml + j * cell_w;
            double cy = mt + i * cell_h;

            fprintf(f,
                "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                "fill=\"%s\" stroke=\"white\" stroke-width=\"1\"/>\n",
                cx, cy, cell_w, cell_h, color
            );

            /* value label */
            if (p->show_values) {
                /* choose white or black text based on brightness */
                double brightness = t;
                const char* txt_col = (brightness > 0.5 && p->color_scheme == 0)
                                      ? "white" : "#222";
                fprintf(f,
                    "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                    "dominant-baseline=\"middle\" fill=\"%s\" class=\"ink-val\">%.2f</text>\n",
                    cx + cell_w / 2.0, cy + cell_h / 2.0, txt_col, val
                );
            }
        }
    }

    /* row labels (y axis) */
    for (int i = 0; i < p->rows; i++) {
        double cy = mt + i * cell_h + cell_h / 2.0;
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%s</text>\n",
            ml - 5, cy, p->row_labels[i]
        );
    }

    /* col labels (x axis) */
    for (int j = 0; j < p->cols; j++) {
        double cx = ml + j * cell_w + cell_w / 2.0;
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-tick\">%s</text>\n",
            cx, mt + ph + 18, p->col_labels[j]
        );
    }

    /* colorbar */
    int cb_x  = ml + pw + 15;
    int cb_y  = mt;
    int cb_w  = 18;
    int cb_h  = ph;
    int cb_steps = 100;
    double step_h = (double)cb_h / cb_steps;

    for (int i = 0; i < cb_steps; i++) {
        double t = 1.0 - (double)i / cb_steps;  /* top = hot */
        char color[16];
        ink_heat_color(t, p->color_scheme, color);
        fprintf(f,
            "<rect x=\"%d\" y=\"%.2f\" width=\"%d\" height=\"%.2f\" "
            "fill=\"%s\"/>\n",
            cb_x, cb_y + i * step_h, cb_w, step_h + 0.5, color
        );
    }

    /* colorbar border */
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"none\" stroke=\"#999\" stroke-width=\"1\"/>\n",
        cb_x, cb_y, cb_w, cb_h
    );

    /* colorbar tick labels */
    int cb_ticks = 5;
    for (int i = 0; i <= cb_ticks; i++) {
        double t   = 1.0 - (double)i / cb_ticks;
        double val = vmin + t * range;
        double ty  = cb_y + (double)i / cb_ticks * cb_h;
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" dominant-baseline=\"middle\" "
            "class=\"ink-tick\">%.2f</text>\n",
            cb_x + cb_w + 4, ty, val
        );
    }

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x axis label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            ml + pw / 2, H - 10, p->xlabel
        );

    /* y axis label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_hm_show(InkHeatmap* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_hm_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ============================================================
 * mocha-ink — Pie Chart
 * ============================================================ */

#define INK_PIE_MAX_SLICES 32
#define INK_PIE_LABEL_THRESHOLD 0.03  /* slices < 3% go to legend only */

typedef struct {
    double  values[INK_PIE_MAX_SLICES];
    char    labels[INK_PIE_MAX_SLICES][64];
    char    colors[INK_PIE_MAX_SLICES][32];
    int     n;
    char    title[128];
    int     width;
    int     height;
    int     show_percent;
    int     show_values;
} InkPieChart;

typedef InkPieChart PieChart;

static InkPieChart* ink_new_pie(char** labels, double* values, int n) {
    InkPieChart* p = (InkPieChart*)malloc(sizeof(InkPieChart));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkPieChart));
    p->width        = INK_WIDTH;
    p->height       = INK_HEIGHT;
    p->show_percent = 1;  /* default: show percentage */
    p->show_values  = 0;

    int count = n < INK_PIE_MAX_SLICES ? n : INK_PIE_MAX_SLICES;
    for (int i = 0; i < count; i++) {
        p->values[i] = values[i];
        strncpy(p->labels[i], labels[i], 63);
        strncpy(p->colors[i], INK_PALETTE[i % INK_MAX_SERIES], 31);
    }
    p->n = count;
    return p;
}

InkPieChart* ink_new_pie_mocha(MochaArray* labels, MochaArray* values) {
    int n = labels->length < values->length ? labels->length : values->length;
    char** lbls  = (char**)malloc(n * sizeof(char*));
    double* vals = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        char* lbl;
        mocha_array_get(labels, i, &lbl);
        lbls[i] = lbl;
        double v;
        mocha_array_get(values, i, &v);
        vals[i] = v;
    }
    InkPieChart* p = ink_new_pie(lbls, vals, n);
    free(lbls);
    free(vals);
    return p;
}

/* ── setters ── */
void ink_pie_set_title(InkPieChart* p, const char* t) { strncpy(p->title, t, 127); }
void ink_pie_set_show_percent(InkPieChart* p)         { p->show_percent = 1;        }
void ink_pie_set_show_values(InkPieChart* p)          { p->show_values  = 1;        }
void ink_pie_set_color(InkPieChart* p, int i, const char* c) {
    if (i >= 0 && i < p->n)
        strncpy(p->colors[i], ink_resolve_color(c), 31);
}

/* ── SVG generation ── */
void ink_pie_save(InkPieChart* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;

    /* pie center and radius */
    double cx = W * 0.50;
    double cy = H / 2.0 + 15.0;
    double r  = (H < W ? H : W) * 0.32;

    /* total */
    double total = 0.0;
    for (int i = 0; i < p->n; i++) total += p->values[i];
    if (total == 0.0) total = 1.0;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #444; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);

    /* draw slices */
    /* start at 3 o'clock = angle 0, go clockwise */
    double angle = 0.0;
    double two_pi = 2.0 * 3.14159265358979323846;

    /* collect legend-only slices */
    int in_legend[INK_PIE_MAX_SLICES];
    memset(in_legend, 0, sizeof(in_legend));

    for (int i = 0; i < p->n; i++) {
        double pct     = p->values[i] / total;
        double sweep   = pct * two_pi;
        double mid_ang = angle + sweep / 2.0;

        double x1 = cx + r * cos(angle);
        double y1 = cy + r * sin(angle);
        double x2 = cx + r * cos(angle + sweep);
        double y2 = cy + r * sin(angle + sweep);
        int large = (sweep > 3.14159265) ? 1 : 0;

        /* slice path */
        fprintf(f,
            "<path d=\"M %.2f %.2f L %.2f %.2f "
            "A %.2f %.2f 0 %d 1 %.2f %.2f Z\" "
            "fill=\"%s\" stroke=\"white\" stroke-width=\"2\" opacity=\"0.9\"/>\n",
            cx, cy, x1, y1, r, r, large, x2, y2, p->colors[i]
        );

        /* label — outside with leader line if slice >= 3% */
        if (pct >= INK_PIE_LABEL_THRESHOLD) {
            /* leader line end point */
            double label_r  = r * 1.18;
            double label_r2 = r * 1.32;
            double lx1 = cx + label_r  * cos(mid_ang);
            double ly1 = cy + label_r  * sin(mid_ang);
            double lx2 = cx + label_r2 * cos(mid_ang);
            double ly2 = cy + label_r2 * sin(mid_ang);

            /* horizontal end of leader */
            double text_offset = (cos(mid_ang) >= 0) ? 8.0 : -8.0;
            double tx = lx2 + text_offset;
            double ty = ly2;
            const char* anchor = (cos(mid_ang) >= 0) ? "start" : "end";

            /* leader line */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                lx1, ly1, lx2, ly2
            );

            /* build label text */
            char label_text[128];
            if (p->show_percent && p->show_values) {
                snprintf(label_text, 127, "%s: %.1f (%.1f%%)",
                         p->labels[i], p->values[i], pct * 100.0);
            } else if (p->show_values) {
                snprintf(label_text, 127, "%s: %.1f",
                         p->labels[i], p->values[i]);
            } else {
                snprintf(label_text, 127, "%s: %.1f%%",
                         p->labels[i], pct * 100.0);
            }

            fprintf(f,
                "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"%s\" "
                "dominant-baseline=\"middle\" class=\"ink-tick\">%s</text>\n",
                tx, ty, anchor, label_text
            );
        } else {
            in_legend[i] = 1;
        }

        angle += sweep;
    }

    /* legend for small slices */
    int has_legend = 0;
    for (int i = 0; i < p->n; i++) if (in_legend[i]) { has_legend = 1; break; }

    if (has_legend) {
        int lx = (int)(cx + r + 20);
        int ly = H - 80;
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" class=\"ink-legend\" "
            "font-weight=\"bold\">Small slices:</text>\n",
            lx, ly
        );
        int row = 0;
        for (int i = 0; i < p->n; i++) {
            if (!in_legend[i]) continue;
            double pct = p->values[i] / total;
            int iy = ly + 18 + row * 18;
            fprintf(f,
                "<rect x=\"%d\" y=\"%d\" width=\"12\" height=\"12\" "
                "fill=\"%s\" rx=\"2\"/>\n",
                lx, iy - 10, p->colors[i]
            );
            char label_text[128];
            if (p->show_percent && p->show_values)
                snprintf(label_text, 127, "%s: %.1f (%.1f%%)",
                         p->labels[i], p->values[i], pct * 100.0);
            else if (p->show_values)
                snprintf(label_text, 127, "%s: %.1f", p->labels[i], p->values[i]);
            else
                snprintf(label_text, 127, "%s: %.1f%%", p->labels[i], pct * 100.0);
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx + 18, iy, label_text
            );
            row++;
        }
    }

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, 30, p->title
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_pie_show(InkPieChart* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_pie_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_pc_set_title(PieChart* p, const char* t) { ink_pie_set_title(p, t);        }
void ink_pc_set_show_percent(PieChart* p)         { ink_pie_set_show_percent(p);    }
void ink_pc_set_show_values(PieChart* p)          { ink_pie_set_show_values(p);     }
void ink_pc_set_color(PieChart* p, int i, const char* c) { ink_pie_set_color(p, i, c); }
void ink_pc_save(PieChart* p, const char* path)   { ink_pie_save(p, path);          }
void ink_pc_show(PieChart* p)                     { ink_pie_show(p);                }

/* ============================================================
 * mocha-ink — Histogram
 * ============================================================ */

#define INK_HIST_MAX_BINS    100
#define INK_HIST_MAX_SERIES  4
#define INK_HIST_MAX_POINTS  10000

typedef struct {
    double  data[INK_HIST_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
} InkHistSeries;

typedef struct {
    InkHistSeries series[INK_HIST_MAX_SERIES];
    int           n_series;
    char          title[128];
    char          xlabel[64];
    char          ylabel[64];
    int           width;
    int           height;
    int           bins;          /* 0 = auto via Sturges */
    int           density;       /* 0 = frequency, 1 = density */
    int           normal_curve;  /* 0 = off, 1 = on */
    int           grid;
} InkHistogram;

typedef InkHistogram Histogram;

/* ── Sturges' rule ── */
static int ink_sturges(int n) {
    if (n <= 1) return 1;
    int k = (int)ceil(log2((double)n) + 1.0);
    return k < 1 ? 1 : (k > INK_HIST_MAX_BINS ? INK_HIST_MAX_BINS : k);
}

static InkHistogram* ink_new_histogram(double* data, int n) {
    InkHistogram* p = (InkHistogram*)malloc(sizeof(InkHistogram));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkHistogram));
    p->width        = INK_WIDTH;
    p->height       = INK_HEIGHT;
    p->grid         = 1;
    p->bins         = 0;  /* auto */
    p->density      = 0;
    p->normal_curve = 0;

    int count = n < INK_HIST_MAX_POINTS ? n : INK_HIST_MAX_POINTS;
    for (int i = 0; i < count; i++)
        p->series[0].data[i] = data[i];
    p->series[0].n = count;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

InkHistogram* ink_new_histogram_mocha(MochaArray* arr) {
    int n = arr->length < INK_HIST_MAX_POINTS ? arr->length : INK_HIST_MAX_POINTS;
    double* data = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        data[i] = v;
    }
    InkHistogram* p = ink_new_histogram(data, n);
    free(data);
    return p;
}

void ink_hist_add_mocha(InkHistogram* p, MochaArray* arr) {
    if (p->n_series >= INK_HIST_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max histogram series reached\n");
        return;
    }
    int n = arr->length < INK_HIST_MAX_POINTS ? arr->length : INK_HIST_MAX_POINTS;
    InkHistSeries* s = &p->series[p->n_series];
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        s->data[i] = v;
    }
    s->n = n;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── setters ── */
void ink_hist_set_title(InkHistogram* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_hist_set_xlabel(InkHistogram* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_hist_set_ylabel(InkHistogram* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_hist_set_bins(InkHistogram* p, int32_t b)       { p->bins = b;                }
void ink_hist_set_density(InkHistogram* p)               { p->density = 1;             }
void ink_hist_set_normal_curve(InkHistogram* p)          { p->normal_curve = 1;        }
void ink_hist_set_grid(InkHistogram* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_hist_set_color(InkHistogram* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, ink_resolve_color(c), 31);
}
void ink_hist_set_label(InkHistogram* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── normal distribution PDF ── */
static double ink_normal_pdf(double x, double mean, double std) {
    if (std == 0.0) return 0.0;
    double z = (x - mean) / std;
    return exp(-0.5 * z * z) / (std * sqrt(2.0 * 3.14159265358979323846));
}

/* ── SVG generation ── */
void ink_hist_save(InkHistogram* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find global data range across all series */
    double dmin = p->series[0].data[0];
    double dmax = p->series[0].data[0];
    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double v = p->series[s].data[i];
            if (v < dmin) dmin = v;
            if (v > dmax) dmax = v;
        }
    }

    /* bin count — use first series for Sturges */
    int n_bins = p->bins > 0 ? p->bins : ink_sturges(p->series[0].n);
    double bin_w = (dmax - dmin) / n_bins;
    if (bin_w == 0.0) bin_w = 1.0;

    /* compute counts/density per series per bin */
    double counts[INK_HIST_MAX_SERIES][INK_HIST_MAX_BINS];
    memset(counts, 0, sizeof(counts));

    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            int b = (int)((p->series[s].data[i] - dmin) / bin_w);
            if (b >= n_bins) b = n_bins - 1;
            counts[s][b]++;
        }
        if (p->density) {
            double total = p->series[s].n * bin_w;
            for (int b = 0; b < n_bins; b++)
                counts[s][b] /= total;
        }
    }

    /* find max count across all series */
    double cmax = 0.0;
    for (int s = 0; s < p->n_series; s++)
        for (int b = 0; b < n_bins; b++)
            if (counts[s][b] > cmax) cmax = counts[s][b];

    /* also check normal curve peak if enabled */
    if (p->normal_curve) {
        /* compute mean and std of first series */
        double mean = 0.0;
        for (int i = 0; i < p->series[0].n; i++) mean += p->series[0].data[i];
        mean /= p->series[0].n;
        double var = 0.0;
        for (int i = 0; i < p->series[0].n; i++) {
            double d = p->series[0].data[i] - mean;
            var += d * d;
        }
        double std = sqrt(var / p->series[0].n);
        double peak = ink_normal_pdf(mean, mean, std);
        if (!p->density) peak *= p->series[0].n * bin_w;
        if (peak > cmax) cmax = peak;
    }

    double nv_min, nv_max, nv_step;
    ink_nice_range(0.0, cmax, &nv_min, &nv_max, &nv_step);
    nv_min = 0.0;

    /* bar width in pixels — split among series with small gap */
    double bar_pw  = (double)pw / n_bins;
    double bar_gap = bar_pw * 0.05;
    double bar_sw  = (bar_pw - bar_gap) / p->n_series;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* grid */
    if (p->grid) {
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
    }

    /* y axis ticks */
    for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
        double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            ml - 5, gy, ml, gy
        );
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
            ml - 8, gy, v
        );
    }

    /* bars */
    double baseline = ink_map_y(0.0, nv_min, nv_max, mt, ph);
    for (int b = 0; b < n_bins; b++) {
        double bx_start = ml + b * bar_pw + bar_gap / 2.0;

        for (int s = 0; s < p->n_series; s++) {
            double bx  = bx_start + s * bar_sw;
            double by  = ink_map_y(counts[s][b], nv_min, nv_max, mt, ph);
            double bh  = baseline - by;
            if (bh <= 0) continue;

            /* hex color with alpha for overlap visibility */
            fprintf(f,
                "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                "fill=\"%s\" opacity=\"0.75\" rx=\"1\"/>\n",
                bx, by, bar_sw, bh, p->series[s].color
            );
        }

        /* x tick — bin center */
        double tick_x = ml + b * bar_pw + bar_pw / 2.0;
        double bin_val = dmin + b * bin_w + bin_w / 2.0;
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-tick\">%.2g</text>\n",
            tick_x, mt + ph + 18, bin_val
        );
    }

    /* normal curve overlay */
    if (p->normal_curve) {
        double mean = 0.0;
        for (int i = 0; i < p->series[0].n; i++) mean += p->series[0].data[i];
        mean /= p->series[0].n;
        double var = 0.0;
        for (int i = 0; i < p->series[0].n; i++) {
            double d = p->series[0].data[i] - mean;
            var += d * d;
        }
        double std = sqrt(var / p->series[0].n);

        /* draw as polyline with 200 points */
        fprintf(f,
            "<polyline fill=\"none\" stroke=\"#E15759\" stroke-width=\"2\" "
            "stroke-dasharray=\"6,3\" points=\""
        );
        int curve_pts = 200;
        for (int i = 0; i <= curve_pts; i++) {
            double x   = dmin + (dmax - dmin) * i / curve_pts;
            double pdf = ink_normal_pdf(x, mean, std);
            double y_val = p->density ? pdf : pdf * p->series[0].n * bin_w;
            double px  = ink_map_x(x,     dmin,   dmax,   ml, pw);
            double py  = ink_map_y(y_val, nv_min, nv_max, mt, ph);
            fprintf(f, "%.2f,%.2f ", px, py);
        }
        fprintf(f, "\"/>\n");
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    /* legend */
    int show_legend = 0;
    for (int s = 0; s < p->n_series; s++)
        if (p->series[s].label[0]) { show_legend = 1; break; }
    if (p->n_series > 1) show_legend = 1;

    if (show_legend) {
        int lx = ml + pw - 10;
        int ly = mt + 10;
        int lw = 130;
        int lh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
            "rx=\"4\" opacity=\"0.9\"/>\n",
            lx - lw, ly, lw, lh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = ly + 10 + s * 22;
            const char* lbl = p->series[s].label[0] ? p->series[s].label
                              : (s == 0 ? "Series 1" : "Series 2");
            fprintf(f,
                "<rect x=\"%d\" y=\"%d\" width=\"14\" height=\"14\" "
                "fill=\"%s\" opacity=\"0.75\" rx=\"2\"/>\n",
                lx - lw + 8, iy, p->series[s].color
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx - lw + 28, iy + 11, lbl
            );
        }
    }

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_hist_show(InkHistogram* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_hist_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_hg_set_title(Histogram* p, const char* t)  { ink_hist_set_title(p, t);      }
void ink_hg_set_xlabel(Histogram* p, const char* l) { ink_hist_set_xlabel(p, l);     }
void ink_hg_set_ylabel(Histogram* p, const char* l) { ink_hist_set_ylabel(p, l);     }
void ink_hg_set_bins(Histogram* p, int32_t b)       { ink_hist_set_bins(p, b);       }
void ink_hg_set_density(Histogram* p)               { ink_hist_set_density(p);       }
void ink_hg_set_normal_curve(Histogram* p)          { ink_hist_set_normal_curve(p);  }
void ink_hg_set_grid(Histogram* p, int8_t on)       { ink_hist_set_grid(p, on);      }
void ink_hg_set_color(Histogram* p, const char* c)  { ink_hist_set_color(p, c);      }
void ink_hg_set_label(Histogram* p, const char* l)  { ink_hist_set_label(p, l);      }
void ink_hg_add(Histogram* p, MochaArray* arr)      { ink_hist_add_mocha(p, arr);    }
void ink_hg_save(Histogram* p, const char* path)    { ink_hist_save(p, path);        }
void ink_hg_show(Histogram* p)                      { ink_hist_show(p);              }

/* ============================================================
 * mocha-ink — Box Plot
 * ============================================================ */

#define INK_BOX_MAX_SERIES  8
#define INK_BOX_MAX_POINTS  10000

typedef struct {
    double  data[INK_BOX_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
} InkBoxSeries;

typedef struct {
    InkBoxSeries series[INK_BOX_MAX_SERIES];
    int          n_series;
    char         title[128];
    char         xlabel[64];
    char         ylabel[64];
    int          width;
    int          height;
    int          horizontal;
    int          confidence;
    int          grid;
} InkBoxPlot;

typedef InkBoxPlot BoxPlot;

/* ── comparison for qsort ── */
static int ink_double_cmp(const void* a, const void* b) {
    double da = *(const double*)a;
    double db = *(const double*)b;
    return (da > db) - (da < db);
}

/* ── five number summary ── */
typedef struct {
    double min, q1, median, q3, max;
    double iqr;
    double whisker_lo, whisker_hi;
    double ci_lo, ci_hi;  /* confidence interval around median */
} InkBoxStats;

static double ink_percentile(double* sorted, int n, double pct) {
    if (n == 0) return 0.0;
    double idx = pct / 100.0 * (n - 1);
    int lo = (int)idx;
    int hi = lo + 1;
    if (hi >= n) return sorted[n - 1];
    double frac = idx - lo;
    return sorted[lo] + frac * (sorted[hi] - sorted[lo]);
}

static InkBoxStats ink_compute_stats(double* data, int n) {
    InkBoxStats s;
    double* sorted = (double*)malloc(n * sizeof(double));
    memcpy(sorted, data, n * sizeof(double));
    qsort(sorted, n, sizeof(double), ink_double_cmp);

    s.min    = sorted[0];
    s.max    = sorted[n - 1];
    s.q1     = ink_percentile(sorted, n, 25.0);
    s.median = ink_percentile(sorted, n, 50.0);
    s.q3     = ink_percentile(sorted, n, 75.0);
    s.iqr    = s.q3 - s.q1;

    /* Tukey whiskers — 1.5 * IQR */
    double lo_fence = s.q1 - 1.5 * s.iqr;
    double hi_fence = s.q3 + 1.5 * s.iqr;

    s.whisker_lo = s.q1;
    s.whisker_hi = s.q3;
    for (int i = 0; i < n; i++) {
        if (sorted[i] >= lo_fence && sorted[i] < s.whisker_lo)
            s.whisker_lo = sorted[i];
        if (sorted[i] <= hi_fence && sorted[i] > s.whisker_hi)
            s.whisker_hi = sorted[i];
    }

    /* 95% confidence interval around median */
    s.ci_lo = s.median - 1.57 * s.iqr / sqrt((double)n);
    s.ci_hi = s.median + 1.57 * s.iqr / sqrt((double)n);

    free(sorted);
    return s;
}

static InkBoxPlot* ink_new_boxplot(double* data, int n) {
    InkBoxPlot* p = (InkBoxPlot*)malloc(sizeof(InkBoxPlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkBoxPlot));
    p->width      = INK_WIDTH;
    p->height     = INK_HEIGHT;
    p->grid       = 1;
    p->horizontal = 0;
    p->confidence = 0;

    int count = n < INK_BOX_MAX_POINTS ? n : INK_BOX_MAX_POINTS;
    for (int i = 0; i < count; i++)
        p->series[0].data[i] = data[i];
    p->series[0].n = count;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

InkBoxPlot* ink_new_boxplot_mocha(MochaArray* arr) {
    int n = arr->length < INK_BOX_MAX_POINTS ? arr->length : INK_BOX_MAX_POINTS;
    double* data = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        data[i] = v;
    }
    InkBoxPlot* p = ink_new_boxplot(data, n);
    free(data);
    return p;
}

void ink_box_add_mocha(InkBoxPlot* p, MochaArray* arr) {
    if (p->n_series >= INK_BOX_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max boxplot series reached\n");
        return;
    }
    int n = arr->length < INK_BOX_MAX_POINTS ? arr->length : INK_BOX_MAX_POINTS;
    InkBoxSeries* s = &p->series[p->n_series];
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        s->data[i] = v;
    }
    s->n = n;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── setters ── */
void ink_box_set_title(InkBoxPlot* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_box_set_xlabel(InkBoxPlot* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_box_set_ylabel(InkBoxPlot* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_box_set_grid(InkBoxPlot* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_box_set_horizontal(InkBoxPlot* p)            { p->horizontal = 1;           }
void ink_box_set_confidence(InkBoxPlot* p)            { p->confidence = 1;           }
void ink_box_set_color(InkBoxPlot* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, ink_resolve_color(c), 31);
}
void ink_box_set_label(InkBoxPlot* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── SVG generation ── */
void ink_box_save(InkBoxPlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* compute stats for all series */
    InkBoxStats stats[INK_BOX_MAX_SERIES];
    for (int s = 0; s < p->n_series; s++)
        stats[s] = ink_compute_stats(p->series[s].data, p->series[s].n);

    /* find global value range */
    double vmin = stats[0].min;
    double vmax = stats[0].max;
    for (int s = 0; s < p->n_series; s++) {
        if (stats[s].whisker_lo < vmin) vmin = stats[s].whisker_lo;
        if (stats[s].whisker_hi > vmax) vmax = stats[s].whisker_hi;
        /* include outliers */
        for (int i = 0; i < p->series[s].n; i++) {
            if (p->series[s].data[i] < vmin) vmin = p->series[s].data[i];
            if (p->series[s].data[i] > vmax) vmax = p->series[s].data[i];
        }
    }

    double nv_min, nv_max, nv_step;
    ink_nice_range(vmin, vmax, &nv_min, &nv_max, &nv_step);

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* grid and ticks */
    if (!p->horizontal) {
        /* vertical box plot — value axis is Y */
        if (p->grid) {
            for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
                double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
                fprintf(f,
                    "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                    "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                    ml, gy, ml + pw, gy
                );
            }
        }
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                ml - 5, gy, ml, gy
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
                "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
                ml - 8, gy, v
            );
        }

        /* draw each box */
        double slot_w  = (double)pw / p->n_series;
        double box_w   = slot_w * 0.5;
        double box_gap = (slot_w - box_w) / 2.0;

        for (int s = 0; s < p->n_series; s++) {
            InkBoxStats* st  = &stats[s];
            const char*  col = p->series[s].color;
            double cx = ml + s * slot_w + slot_w / 2.0;
            double bx = ml + s * slot_w + box_gap;

            double y_q1  = ink_map_y(st->q1,     nv_min, nv_max, mt, ph);
            double y_q3  = ink_map_y(st->q3,     nv_min, nv_max, mt, ph);
            double y_med = ink_map_y(st->median,  nv_min, nv_max, mt, ph);
            double y_wlo = ink_map_y(st->whisker_lo, nv_min, nv_max, mt, ph);
            double y_whi = ink_map_y(st->whisker_hi, nv_min, nv_max, mt, ph);
            double box_h = y_q1 - y_q3;

            /* whisker lines */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" stroke-dasharray=\"4,2\"/>\n",
                cx, y_whi, cx, y_q3, col
            );
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" stroke-dasharray=\"4,2\"/>\n",
                cx, y_q1, cx, y_wlo, col
            );

            /* whisker caps */
            double cap_w = box_w * 0.4;
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                cx - cap_w, y_whi, cx + cap_w, y_whi, col
            );
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                cx - cap_w, y_wlo, cx + cap_w, y_wlo, col
            );

            /* box body */
            if (p->confidence) {
                /* notched box */
                double y_cilo = ink_map_y(st->ci_lo, nv_min, nv_max, mt, ph);
                double y_cihi = ink_map_y(st->ci_hi, nv_min, nv_max, mt, ph);
                double notch_w = box_w * 0.4;
                fprintf(f,
                    "<polygon points=\""
                    "%.2f,%.2f %.2f,%.2f %.2f,%.2f %.2f,%.2f "
                    "%.2f,%.2f %.2f,%.2f %.2f,%.2f %.2f,%.2f\" "
                    "fill=\"%s\" opacity=\"0.7\" stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                    bx, y_q1,
                    bx + box_w, y_q1,
                    bx + box_w, y_cilo,
                    bx + box_w - notch_w, y_med,
                    bx + box_w, y_cihi,
                    bx + box_w, y_q3,
                    bx, y_q3,
                    bx + notch_w, y_med,
                    col, col
                );
            } else {
                /* plain box */
                fprintf(f,
                    "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                    "fill=\"%s\" opacity=\"0.7\" stroke=\"%s\" "
                    "stroke-width=\"1.5\" rx=\"2\"/>\n",
                    bx, y_q3, box_w, box_h, col, col
                );
            }

            /* median line */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"white\" stroke-width=\"2.5\"/>\n",
                bx, y_med, bx + box_w, y_med
            );

            /* outliers */
            double lo_fence = st->q1 - 1.5 * st->iqr;
            double hi_fence = st->q3 + 1.5 * st->iqr;
            for (int i = 0; i < p->series[s].n; i++) {
                double v = p->series[s].data[i];
                if (v < lo_fence || v > hi_fence) {
                    double oy = ink_map_y(v, nv_min, nv_max, mt, ph);
                    fprintf(f,
                        "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"4\" "
                        "fill=\"none\" stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                        cx, oy, col
                    );
                }
            }

            /* x axis label */
            const char* lbl = p->series[s].label[0]
                              ? p->series[s].label : p->series[s].label;
            if (p->series[s].label[0]) {
                fprintf(f,
                    "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                    "class=\"ink-tick\">%s</text>\n",
                    cx, mt + ph + 18, lbl
                );
            }
        }

    } else {
        /* ── horizontal box plot — value axis is X ── */
        if (p->grid) {
            for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
                double gx = ink_map_x(v, nv_min, nv_max, ml, pw);
                fprintf(f,
                    "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                    "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                    gx, mt, gx, mt + ph
                );
            }
        }
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gx = ink_map_x(v, nv_min, nv_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                gx, mt + ph, gx, mt + ph + 5
            );
            fprintf(f,
                "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                "class=\"ink-tick\">%g</text>\n",
                gx, mt + ph + 18, v
            );
        }

        double slot_h = (double)ph / p->n_series;
        double box_h  = slot_h * 0.5;
        double box_gap = (slot_h - box_h) / 2.0;

        for (int s = 0; s < p->n_series; s++) {
            InkBoxStats* st  = &stats[s];
            const char*  col = p->series[s].color;
            double cy = mt + s * slot_h + slot_h / 2.0;
            double by = mt + s * slot_h + box_gap;

            double x_q1  = ink_map_x(st->q1,        nv_min, nv_max, ml, pw);
            double x_q3  = ink_map_x(st->q3,        nv_min, nv_max, ml, pw);
            double x_med = ink_map_x(st->median,     nv_min, nv_max, ml, pw);
            double x_wlo = ink_map_x(st->whisker_lo, nv_min, nv_max, ml, pw);
            double x_whi = ink_map_x(st->whisker_hi, nv_min, nv_max, ml, pw);
            double bw    = x_q3 - x_q1;

            /* whisker lines */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" stroke-dasharray=\"4,2\"/>\n",
                x_wlo, cy, x_q1, cy, col
            );
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" stroke-dasharray=\"4,2\"/>\n",
                x_q3, cy, x_whi, cy, col
            );

            /* whisker caps */
            double cap_h = box_h * 0.4;
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                x_wlo, cy - cap_h, x_wlo, cy + cap_h, col
            );
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                x_whi, cy - cap_h, x_whi, cy + cap_h, col
            );

            /* box body */
            fprintf(f,
                "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                "fill=\"%s\" opacity=\"0.7\" stroke=\"%s\" "
                "stroke-width=\"1.5\" rx=\"2\"/>\n",
                x_q1, by, bw, box_h, col, col
            );

            /* median line */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"white\" stroke-width=\"2.5\"/>\n",
                x_med, by, x_med, by + box_h
            );

            /* outliers */
            double lo_fence = st->q1 - 1.5 * st->iqr;
            double hi_fence = st->q3 + 1.5 * st->iqr;
            for (int i = 0; i < p->series[s].n; i++) {
                double v = p->series[s].data[i];
                if (v < lo_fence || v > hi_fence) {
                    double ox = ink_map_x(v, nv_min, nv_max, ml, pw);
                    fprintf(f,
                        "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"4\" "
                        "fill=\"none\" stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                        ox, cy, col
                    );
                }
            }

            /* y axis label */
            if (p->series[s].label[0]) {
                fprintf(f,
                    "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
                    "dominant-baseline=\"middle\" class=\"ink-tick\">%s</text>\n",
                    ml - 8, cy, p->series[s].label
                );
            }
        }
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_box_show(InkBoxPlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_box_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_bp_set_title(BoxPlot* p, const char* t)  { ink_box_set_title(p, t);      }
void ink_bp_set_xlabel(BoxPlot* p, const char* l) { ink_box_set_xlabel(p, l);     }
void ink_bp_set_ylabel(BoxPlot* p, const char* l) { ink_box_set_ylabel(p, l);     }
void ink_bp_set_grid(BoxPlot* p, int8_t on)       { ink_box_set_grid(p, on);      }
void ink_bp_set_horizontal(BoxPlot* p)            { ink_box_set_horizontal(p);    }
void ink_bp_set_confidence(BoxPlot* p)            { ink_box_set_confidence(p);    }
void ink_bp_set_color(BoxPlot* p, const char* c)  { ink_box_set_color(p, c);      }
void ink_bp_set_label(BoxPlot* p, const char* l)  { ink_box_set_label(p, l);      }
void ink_bp_add(BoxPlot* p, MochaArray* arr)       { ink_box_add_mocha(p, arr);   }
void ink_bp_save(BoxPlot* p, const char* path)    { ink_box_save(p, path);        }
void ink_bp_show(BoxPlot* p)                      { ink_box_show(p);              }

/* ============================================================
 * mocha-ink — Violin Plot
 * ============================================================ */

#define INK_VIOLIN_MAX_SERIES  8
#define INK_VIOLIN_MAX_POINTS  10000
#define INK_VIOLIN_KDE_STEPS   200  /* smoothness of curve */

typedef struct {
    double  data[INK_VIOLIN_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
} InkViolinSeries;

typedef struct {
    InkViolinSeries series[INK_VIOLIN_MAX_SERIES];
    int             n_series;
    char            title[128];
    char            xlabel[64];
    char            ylabel[64];
    int             width;
    int             height;
    int             horizontal;
    int             show_box;   /* 1 = show inner box, 0 = hide */
    double          bandwidth;  /* 0 = auto Silverman */
    int             grid;
} InkViolinPlot;

typedef InkViolinPlot ViolinPlot;

/* ── Gaussian kernel ── */
static double ink_gaussian_kernel(double x) {
    return exp(-0.5 * x * x) / sqrt(2.0 * 3.14159265358979323846);
}

/* ── KDE at point x ── */
static double ink_kde(double x, double* data, int n, double h) {
    double sum = 0.0;
    for (int i = 0; i < n; i++)
        sum += ink_gaussian_kernel((x - data[i]) / h);
    return sum / (n * h);
}

/* ── Silverman bandwidth ── */
static double ink_silverman(double* data, int n) {
    if (n <= 1) return 1.0;
    double mean = 0.0;
    for (int i = 0; i < n; i++) mean += data[i];
    mean /= n;
    double var = 0.0;
    for (int i = 0; i < n; i++) {
        double d = data[i] - mean;
        var += d * d;
    }
    double std = sqrt(var / n);
    /* IQR-based robust estimate */
    double* sorted = (double*)malloc(n * sizeof(double));
    memcpy(sorted, data, n * sizeof(double));
    qsort(sorted, n, sizeof(double), ink_double_cmp);
    double q1  = ink_percentile(sorted, n, 25.0);
    double q3  = ink_percentile(sorted, n, 75.0);
    double iqr = (q3 - q1) / 1.34;
    free(sorted);
    double s = std < iqr ? std : iqr;
    if (s == 0.0) s = std;
    if (s == 0.0) s = 1.0;
    return 1.06 * s * pow((double)n, -0.2);
}

static InkViolinPlot* ink_new_violin(double* data, int n) {
    InkViolinPlot* p = (InkViolinPlot*)malloc(sizeof(InkViolinPlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkViolinPlot));
    p->width     = INK_WIDTH;
    p->height    = INK_HEIGHT;
    p->grid      = 1;
    p->show_box  = 1;
    p->bandwidth = 0.0;  /* auto */
    p->horizontal = 0;

    int count = n < INK_VIOLIN_MAX_POINTS ? n : INK_VIOLIN_MAX_POINTS;
    for (int i = 0; i < count; i++)
        p->series[0].data[i] = data[i];
    p->series[0].n = count;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

InkViolinPlot* ink_new_violin_mocha(MochaArray* arr) {
    int n = arr->length < INK_VIOLIN_MAX_POINTS ? arr->length : INK_VIOLIN_MAX_POINTS;
    double* data = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        data[i] = v;
    }
    InkViolinPlot* p = ink_new_violin(data, n);
    free(data);
    return p;
}

void ink_violin_add_mocha(InkViolinPlot* p, MochaArray* arr) {
    if (p->n_series >= INK_VIOLIN_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max violin series reached\n");
        return;
    }
    int n = arr->length < INK_VIOLIN_MAX_POINTS ? arr->length : INK_VIOLIN_MAX_POINTS;
    InkViolinSeries* s = &p->series[p->n_series];
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        s->data[i] = v;
    }
    s->n = n;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── setters ── */
void ink_vl_set_title(InkViolinPlot* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_vl_set_xlabel(InkViolinPlot* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_vl_set_ylabel(InkViolinPlot* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_vl_set_grid(InkViolinPlot* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_vl_set_horizontal(InkViolinPlot* p)            { p->horizontal = 1;           }
void ink_vl_set_no_box(InkViolinPlot* p)                { p->show_box = 0;             }
void ink_vl_set_bandwidth(InkViolinPlot* p, double h)   { p->bandwidth = h;            }
void ink_vl_set_color(InkViolinPlot* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, ink_resolve_color(c), 31);
}
void ink_vl_set_label(InkViolinPlot* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── SVG generation ── */
void ink_violin_save(InkViolinPlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find global data range */
    double vmin = p->series[0].data[0];
    double vmax = p->series[0].data[0];
    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double v = p->series[s].data[i];
            if (v < vmin) vmin = v;
            if (v > vmax) vmax = v;
        }
    }
    /* add padding for KDE tails */
    double range = vmax - vmin;
    vmin -= range * 0.1;
    vmax += range * 0.1;

    double nv_min, nv_max, nv_step;
    ink_nice_range(vmin, vmax, &nv_min, &nv_max, &nv_step);

    /* compute KDE for each series */
    double kde_vals[INK_VIOLIN_MAX_SERIES][INK_VIOLIN_KDE_STEPS];
    double kde_max_all = 0.0;

    for (int s = 0; s < p->n_series; s++) {
        double h = p->bandwidth > 0.0
                   ? p->bandwidth
                   : ink_silverman(p->series[s].data, p->series[s].n);
        for (int k = 0; k < INK_VIOLIN_KDE_STEPS; k++) {
            double x = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
            kde_vals[s][k] = ink_kde(x, p->series[s].data, p->series[s].n, h);
            if (kde_vals[s][k] > kde_max_all) kde_max_all = kde_vals[s][k];
        }
    }
    if (kde_max_all == 0.0) kde_max_all = 1.0;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* clip region */
    fprintf(f,
        "<clipPath id=\"ink-vclip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n",
        ml, mt, pw, ph
    );

    /* grid and value axis ticks */
    if (!p->horizontal) {
        if (p->grid) {
            for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
                double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
                fprintf(f,
                    "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                    "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                    ml, gy, ml + pw, gy
                );
            }
        }
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gy = ink_map_y(v, nv_min, nv_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                ml - 5, gy, ml, gy
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
                "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
                ml - 8, gy, v
            );
        }

        /* draw violins */
        double slot_w   = (double)pw / p->n_series;
        double violin_w = slot_w * 0.4;  /* half-width of violin */

        for (int s = 0; s < p->n_series; s++) {
            double cx = ml + s * slot_w + slot_w / 2.0;
            const char* col = p->series[s].color;

            /* build polygon points — right side then left side reversed */
            /* right side: kde mapped to x offset */
            fprintf(f, "<polygon fill=\"%s\" opacity=\"0.7\" "
                    "clip-path=\"url(#ink-vclip)\" points=\"", col);

            /* right side top to bottom */
            for (int k = 0; k < INK_VIOLIN_KDE_STEPS; k++) {
                double y_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double py    = ink_map_y(y_val, nv_min, nv_max, mt, ph);
                double kde_w = (kde_vals[s][k] / kde_max_all) * violin_w;
                fprintf(f, "%.2f,%.2f ", cx + kde_w, py);
            }
            /* left side bottom to top */
            for (int k = INK_VIOLIN_KDE_STEPS - 1; k >= 0; k--) {
                double y_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double py    = ink_map_y(y_val, nv_min, nv_max, mt, ph);
                double kde_w = (kde_vals[s][k] / kde_max_all) * violin_w;
                fprintf(f, "%.2f,%.2f ", cx - kde_w, py);
            }
            fprintf(f, "\"/>\n");

            /* outline */
            fprintf(f, "<polyline fill=\"none\" stroke=\"%s\" stroke-width=\"1.5\" "
                    "opacity=\"0.9\" clip-path=\"url(#ink-vclip)\" points=\"", col);
            for (int k = 0; k < INK_VIOLIN_KDE_STEPS; k++) {
                double y_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double py    = ink_map_y(y_val, nv_min, nv_max, mt, ph);
                double kde_w = (kde_vals[s][k] / kde_max_all) * violin_w;
                fprintf(f, "%.2f,%.2f ", cx + kde_w, py);
            }
            for (int k = INK_VIOLIN_KDE_STEPS - 1; k >= 0; k--) {
                double y_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double py    = ink_map_y(y_val, nv_min, nv_max, mt, ph);
                double kde_w = (kde_vals[s][k] / kde_max_all) * violin_w;
                fprintf(f, "%.2f,%.2f ", cx - kde_w, py);
            }
            fprintf(f, "\"/>\n");

            /* inner box plot */
            if (p->show_box) {
                InkBoxStats st = ink_compute_stats(
                    p->series[s].data, p->series[s].n);
                double y_q1  = ink_map_y(st.q1,     nv_min, nv_max, mt, ph);
                double y_q3  = ink_map_y(st.q3,     nv_min, nv_max, mt, ph);
                double y_med = ink_map_y(st.median,  nv_min, nv_max, mt, ph);
                double y_wlo = ink_map_y(st.whisker_lo, nv_min, nv_max, mt, ph);
                double y_whi = ink_map_y(st.whisker_hi, nv_min, nv_max, mt, ph);
                double iw    = violin_w * 0.15;  /* inner box half-width */

                /* whisker line */
                fprintf(f,
                    "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                    "stroke=\"#444\" stroke-width=\"1.5\"/>\n",
                    cx, y_whi, cx, y_wlo
                );
                /* IQR box */
                fprintf(f,
                    "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                    "fill=\"white\" stroke=\"#444\" stroke-width=\"1.5\" rx=\"1\"/>\n",
                    cx - iw, y_q3, iw * 2.0, y_q1 - y_q3
                );
                /* median dot */
                fprintf(f,
                    "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"3\" "
                    "fill=\"#444\"/>\n",
                    cx, y_med
                );
            }

            /* x axis label */
            if (p->series[s].label[0]) {
                fprintf(f,
                    "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                    "class=\"ink-tick\">%s</text>\n",
                    cx, mt + ph + 18, p->series[s].label
                );
            }
        }

    } else {
        /* ── horizontal violin ── */
        if (p->grid) {
            for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
                double gx = ink_map_x(v, nv_min, nv_max, ml, pw);
                fprintf(f,
                    "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                    "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                    gx, mt, gx, mt + ph
                );
            }
        }
        for (double v = nv_min; v <= nv_max + nv_step * 0.01; v += nv_step) {
            double gx = ink_map_x(v, nv_min, nv_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#999\" stroke-width=\"1\"/>\n",
                gx, mt + ph, gx, mt + ph + 5
            );
            fprintf(f,
                "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                "class=\"ink-tick\">%g</text>\n",
                gx, mt + ph + 18, v
            );
        }

        double slot_h   = (double)ph / p->n_series;
        double violin_h = slot_h * 0.4;

        for (int s = 0; s < p->n_series; s++) {
            double cy = mt + s * slot_h + slot_h / 2.0;
            const char* col = p->series[s].color;

            /* top half */
            fprintf(f, "<polygon fill=\"%s\" opacity=\"0.7\" "
                    "clip-path=\"url(#ink-vclip)\" points=\"", col);
            for (int k = 0; k < INK_VIOLIN_KDE_STEPS; k++) {
                double x_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double px    = ink_map_x(x_val, nv_min, nv_max, ml, pw);
                double kde_h = (kde_vals[s][k] / kde_max_all) * violin_h;
                fprintf(f, "%.2f,%.2f ", px, cy - kde_h);
            }
            for (int k = INK_VIOLIN_KDE_STEPS - 1; k >= 0; k--) {
                double x_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double px    = ink_map_x(x_val, nv_min, nv_max, ml, pw);
                double kde_h = (kde_vals[s][k] / kde_max_all) * violin_h;
                fprintf(f, "%.2f,%.2f ", px, cy + kde_h);
            }
            fprintf(f, "\"/>\n");

            /* outline */
            fprintf(f, "<polyline fill=\"none\" stroke=\"%s\" stroke-width=\"1.5\" "
                    "opacity=\"0.9\" clip-path=\"url(#ink-vclip)\" points=\"", col);
            for (int k = 0; k < INK_VIOLIN_KDE_STEPS; k++) {
                double x_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double px    = ink_map_x(x_val, nv_min, nv_max, ml, pw);
                double kde_h = (kde_vals[s][k] / kde_max_all) * violin_h;
                fprintf(f, "%.2f,%.2f ", px, cy - kde_h);
            }
            for (int k = INK_VIOLIN_KDE_STEPS - 1; k >= 0; k--) {
                double x_val = nv_min + (nv_max - nv_min) * k / (INK_VIOLIN_KDE_STEPS - 1);
                double px    = ink_map_x(x_val, nv_min, nv_max, ml, pw);
                double kde_h = (kde_vals[s][k] / kde_max_all) * violin_h;
                fprintf(f, "%.2f,%.2f ", px, cy + kde_h);
            }
            fprintf(f, "\"/>\n");

            /* inner box */
            if (p->show_box) {
                InkBoxStats st = ink_compute_stats(
                    p->series[s].data, p->series[s].n);
                double x_q1  = ink_map_x(st.q1,        nv_min, nv_max, ml, pw);
                double x_q3  = ink_map_x(st.q3,        nv_min, nv_max, ml, pw);
                double x_med = ink_map_x(st.median,     nv_min, nv_max, ml, pw);
                double x_wlo = ink_map_x(st.whisker_lo, nv_min, nv_max, ml, pw);
                double x_whi = ink_map_x(st.whisker_hi, nv_min, nv_max, ml, pw);
                double ih    = violin_h * 0.15;

                fprintf(f,
                    "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                    "stroke=\"#444\" stroke-width=\"1.5\"/>\n",
                    x_wlo, cy, x_whi, cy
                );
                fprintf(f,
                    "<rect x=\"%.2f\" y=\"%.2f\" width=\"%.2f\" height=\"%.2f\" "
                    "fill=\"white\" stroke=\"#444\" stroke-width=\"1.5\" rx=\"1\"/>\n",
                    x_q1, cy - ih, x_q3 - x_q1, ih * 2.0
                );
                fprintf(f,
                    "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"3\" fill=\"#444\"/>\n",
                    x_med, cy
                );
            }

            /* y axis label */
            if (p->series[s].label[0]) {
                fprintf(f,
                    "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
                    "dominant-baseline=\"middle\" class=\"ink-tick\">%s</text>\n",
                    ml - 8, cy, p->series[s].label
                );
            }
        }
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_violin_show(InkViolinPlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_violin_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_vn_set_title(ViolinPlot* p, const char* t)  { ink_vl_set_title(p, t);      }
void ink_vn_set_xlabel(ViolinPlot* p, const char* l) { ink_vl_set_xlabel(p, l);     }
void ink_vn_set_ylabel(ViolinPlot* p, const char* l) { ink_vl_set_ylabel(p, l);     }
void ink_vn_set_grid(ViolinPlot* p, int8_t on)       { ink_vl_set_grid(p, on);      }
void ink_vn_set_horizontal(ViolinPlot* p)            { ink_vl_set_horizontal(p);    }
void ink_vn_set_no_box(ViolinPlot* p)                { ink_vl_set_no_box(p);        }
void ink_vn_set_bandwidth(ViolinPlot* p, double h)   { ink_vl_set_bandwidth(p, h);  }
void ink_vn_set_color(ViolinPlot* p, const char* c)  { ink_vl_set_color(p, c);      }
void ink_vn_set_label(ViolinPlot* p, const char* l)  { ink_vl_set_label(p, l);      }
void ink_vn_add(ViolinPlot* p, MochaArray* arr)      { ink_violin_add_mocha(p, arr);}
void ink_vn_save(ViolinPlot* p, const char* path)    { ink_violin_save(p, path);    }
void ink_vn_show(ViolinPlot* p)                      { ink_violin_show(p);          }

//Area Chart
InkPlot* ink_new_area_mocha(MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    InkPlot* p = ink_new_line(xd, yd, n);
    p->series[0].is_area = 1;
    free(xd);
    free(yd);
    return p;
}

void ink_add_area_mocha(InkPlot* p, MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    ink_add_series(p, 0, xd, yd, n);
    p->series[p->n_series - 1].is_area = 1;
    free(xd);
    free(yd);
}
typedef InkPlot AreaChart;

AreaChart* ink_ac_new(MochaArray* x, MochaArray* y)          { return ink_new_area_mocha(x, y);      }
void ink_ac_set_title(AreaChart* p, const char* t)           { ink_lp_set_title(p, t);               }
void ink_ac_set_xlabel(AreaChart* p, const char* l)          { ink_lp_set_xlabel(p, l);              }
void ink_ac_set_ylabel(AreaChart* p, const char* l)          { ink_lp_set_ylabel(p, l);              }
void ink_ac_set_color(AreaChart* p, const char* c)           { ink_lp_set_color(p, c);               }
void ink_ac_set_label(AreaChart* p, const char* l)           { ink_lp_set_label(p, l);               }
void ink_ac_set_grid(AreaChart* p, int8_t on)                { ink_lp_set_grid(p, on);               }
void ink_ac_add_area(AreaChart* p, MochaArray* x, MochaArray* y) { ink_add_area_mocha(p, x, y);      }
void ink_ac_save(AreaChart* p, const char* path)             { ink_lp_save(p, path);                 }
void ink_ac_show(AreaChart* p)                               { ink_lp_show(p);                       }

/* ============================================================
 * mocha-ink — Bubble Chart
 * ============================================================ */

#define INK_BUBBLE_MAX_POINTS 512
#define INK_BUBBLE_MIN_R      4.0
#define INK_BUBBLE_MAX_R      40.0

typedef struct {
    double  x[INK_BUBBLE_MAX_POINTS];
    double  y[INK_BUBBLE_MAX_POINTS];
    double  z[INK_BUBBLE_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
} InkBubbleSeries;

typedef struct {
    InkBubbleSeries series[INK_MAX_SERIES];
    int             n_series;
    char            title[128];
    char            xlabel[64];
    char            ylabel[64];
    int             width;
    int             height;
    int             grid;
    double          min_r;
    double          max_r;
} InkBubbleChart;

typedef InkBubbleChart BubbleChart;

static InkBubbleChart* ink_new_bubble(double* x, double* y, double* z, int n) {
    InkBubbleChart* p = (InkBubbleChart*)malloc(sizeof(InkBubbleChart));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkBubbleChart));
    p->width    = INK_WIDTH;
    p->height   = INK_HEIGHT;
    p->grid     = 1;
    p->min_r    = INK_BUBBLE_MIN_R;
    p->max_r    = INK_BUBBLE_MAX_R;

    int count = n < INK_BUBBLE_MAX_POINTS ? n : INK_BUBBLE_MAX_POINTS;
    for (int i = 0; i < count; i++) {
        if (z[i] < 0.0) {
            fprintf(stderr,
                "MochaRuntimeError (mocha-ink): bubble size z[%d] = %.6g "
                "is negative. All z values must be >= 0.\n", i, z[i]);
            exit(2);
        }
        p->series[0].x[i] = x[i];
        p->series[0].y[i] = y[i];
        p->series[0].z[i] = z[i];
    }
    p->series[0].n = count;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

InkBubbleChart* ink_new_bubble_mocha(MochaArray* x, MochaArray* y, MochaArray* z) {
    int n = x->length;
    if (y->length < n) n = y->length;
    if (z->length < n) n = z->length;
    if (n > INK_BUBBLE_MAX_POINTS) n = INK_BUBBLE_MAX_POINTS;

    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    double* zd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        mocha_array_get(x, i, &xd[i]);
        mocha_array_get(y, i, &yd[i]);
        mocha_array_get(z, i, &zd[i]);
    }
    InkBubbleChart* p = ink_new_bubble(xd, yd, zd, n);
    free(xd); free(yd); free(zd);
    return p;
}

void ink_bubble_add_mocha(InkBubbleChart* p,
                          MochaArray* x, MochaArray* y, MochaArray* z) {
    if (p->n_series >= INK_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max bubble series reached\n");
        return;
    }
    int n = x->length;
    if (y->length < n) n = y->length;
    if (z->length < n) n = z->length;
    if (n > INK_BUBBLE_MAX_POINTS) n = INK_BUBBLE_MAX_POINTS;

    InkBubbleSeries* s = &p->series[p->n_series];
    for (int i = 0; i < n; i++) {
        mocha_array_get(x, i, &s->x[i]);
        mocha_array_get(y, i, &s->y[i]);
        double zv;
        mocha_array_get(z, i, &zv);
        if (zv < 0.0) {
            fprintf(stderr,
                "MochaRuntimeError (mocha-ink): bubble size z[%d] = %.6g "
                "is negative. All z values must be >= 0.\n", i, zv);
            exit(2);
        }
        s->z[i] = zv;
    }
    s->n = n;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── setters ── */
void ink_bb_set_title(InkBubbleChart* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_bb_set_xlabel(InkBubbleChart* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_bb_set_ylabel(InkBubbleChart* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_bb_set_grid(InkBubbleChart* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_bb_set_min_size(InkBubbleChart* p, double r)    { p->min_r = r;               }
void ink_bb_set_max_size(InkBubbleChart* p, double r)    { p->max_r = r;               }
void ink_bb_set_color(InkBubbleChart* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, ink_resolve_color(c), 31);
}
void ink_bb_set_label(InkBubbleChart* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── SVG generation ── */
void ink_bubble_save(InkBubbleChart* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find data range */
    double xmin = p->series[0].x[0], xmax = xmin;
    double ymin = p->series[0].y[0], ymax = ymin;
    double zmin = p->series[0].z[0], zmax = zmin;

    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double xi = p->series[s].x[i];
            double yi = p->series[s].y[i];
            double zi = p->series[s].z[i];
            if (xi < xmin) xmin = xi;
            if (xi > xmax) xmax = xi;
            if (yi < ymin) ymin = yi;
            if (yi > ymax) ymax = yi;
            if (zi < zmin) zmin = zi;
            if (zi > zmax) zmax = zi;
        }
    }

    double nx_min, nx_max, nx_step;
    double ny_min, ny_max, ny_step;
    ink_nice_range(xmin, xmax, &nx_min, &nx_max, &nx_step);
    ink_nice_range(ymin, ymax, &ny_min, &ny_max, &ny_step);

    double z_range = zmax - zmin;
    if (z_range == 0.0) z_range = 1.0;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-bval   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 9px; fill: white; font-weight: bold; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* clip */
    fprintf(f,
        "<clipPath id=\"ink-bclip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n",
        ml - (int)p->max_r, mt - (int)p->max_r,
        pw + (int)p->max_r * 2, ph + (int)p->max_r * 2
    );

    /* grid */
    if (p->grid) {
        for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
            double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
        for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
            double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                gx, mt, gx, mt + ph
            );
        }
    }

    /* x axis ticks */
    for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
        double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            gx, mt + ph, gx, mt + ph + 5
        );
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-tick\">%g</text>\n",
            gx, mt + ph + 18, v
        );
    }

    /* y axis ticks */
    for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
        double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            ml - 5, gy, ml, gy
        );
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
            ml - 8, gy, v
        );
    }

    /* draw bubbles — smallest z first so large don't cover small */
    /* simple sort by z descending per series */
    for (int s = 0; s < p->n_series; s++) {
        InkBubbleSeries* sr = &p->series[s];
        const char* col = sr->color;

        /* draw order: largest first so smallest visible on top */
        /* build index array sorted by z descending */
        int idx[INK_BUBBLE_MAX_POINTS];
        for (int i = 0; i < sr->n; i++) idx[i] = i;
        /* bubble sort by z descending — n is small enough */
        for (int i = 0; i < sr->n - 1; i++) {
            for (int j = i + 1; j < sr->n; j++) {
                if (sr->z[idx[j]] > sr->z[idx[i]]) {
                    int tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp;
                }
            }
        }

        for (int ii = 0; ii < sr->n; ii++) {
            int i = idx[ii];
            double cx = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
            double cy = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
            double t  = (sr->z[i] - zmin) / z_range;
            double r  = p->min_r + t * (p->max_r - p->min_r);

            fprintf(f,
                "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"%.2f\" "
                "fill=\"%s\" opacity=\"0.75\" stroke=\"%s\" "
                "stroke-width=\"1\" clip-path=\"url(#ink-bclip)\"/>\n",
                cx, cy, r, col, col
            );

            /* z value label inside large bubbles */
            if (r > 15.0) {
                fprintf(f,
                    "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                    "dominant-baseline=\"middle\" class=\"ink-bval\">%g</text>\n",
                    cx, cy, sr->z[i]
                );
            }
        }
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* size legend */
    int lx = ml + pw - 10;
    int ly = mt + ph - 100;
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"130\" height=\"90\" "
        "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
        "rx=\"4\" opacity=\"0.9\"/>\n",
        lx - 130, ly
    );
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
        "class=\"ink-legend\" font-weight=\"bold\">Size: z</text>\n",
        lx - 65, ly + 14
    );
    /* small bubble */
    fprintf(f,
        "<circle cx=\"%d\" cy=\"%d\" r=\"%.1f\" "
        "fill=\"#BAB0AC\" opacity=\"0.7\"/>\n",
        lx - 95, ly + 40, p->min_r
    );
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" dominant-baseline=\"middle\" "
        "class=\"ink-tick\">%g</text>\n",
        lx - 85, ly + 40, zmin
    );
    /* large bubble */
    fprintf(f,
        "<circle cx=\"%d\" cy=\"%d\" r=\"%.1f\" "
        "fill=\"#BAB0AC\" opacity=\"0.7\"/>\n",
        lx - 95, ly + 68, p->max_r * 0.5
    );
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" dominant-baseline=\"middle\" "
        "class=\"ink-tick\">%g</text>\n",
        lx - 85 + (int)(p->max_r * 0.5) - (int)p->min_r, ly + 68, zmax
    );

    /* series legend if multi */
    int show_legend = p->n_series > 1;
    for (int s = 0; s < p->n_series; s++)
        if (p->series[s].label[0]) { show_legend = 1; break; }

    if (show_legend) {
        int llx = ml + 10;
        int lly = mt + 10;
        int llw = 130;
        int llh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
            "rx=\"4\" opacity=\"0.9\"/>\n",
            llx, lly, llw, llh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = lly + 10 + s * 22;
            const char* lbl = p->series[s].label[0]
                              ? p->series[s].label
                              : (s == 0 ? "Series 1" : "Series 2");
            fprintf(f,
                "<circle cx=\"%d\" cy=\"%d\" r=\"7\" fill=\"%s\" opacity=\"0.75\"/>\n",
                llx + 14, iy + 7, p->series[s].color
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                llx + 28, iy + 11, lbl
            );
        }
    }

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_bubble_show(InkBubbleChart* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_bubble_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_bc2_set_title(BubbleChart* p, const char* t)  { ink_bb_set_title(p, t);     }
void ink_bc2_set_xlabel(BubbleChart* p, const char* l) { ink_bb_set_xlabel(p, l);    }
void ink_bc2_set_ylabel(BubbleChart* p, const char* l) { ink_bb_set_ylabel(p, l);    }
void ink_bc2_set_grid(BubbleChart* p, int8_t on)       { ink_bb_set_grid(p, on);     }
void ink_bc2_set_color(BubbleChart* p, const char* c)  { ink_bb_set_color(p, c);     }
void ink_bc2_set_label(BubbleChart* p, const char* l)  { ink_bb_set_label(p, l);     }
void ink_bc2_set_min_size(BubbleChart* p, double r)    { ink_bb_set_min_size(p, r);  }
void ink_bc2_set_max_size(BubbleChart* p, double r)    { ink_bb_set_max_size(p, r);  }
void ink_bc2_add(BubbleChart* p, MochaArray* x, MochaArray* y, MochaArray* z) {
    ink_bubble_add_mocha(p, x, y, z);
}
void ink_bc2_save(BubbleChart* p, const char* path)    { ink_bubble_save(p, path);   }
void ink_bc2_show(BubbleChart* p)                      { ink_bubble_show(p);         }

/* ============================================================
 * mocha-ink — Curve Plot (KDE density curve)
 * ============================================================ */

#define INK_CURVE_MAX_SERIES  6
#define INK_CURVE_MAX_POINTS  10000
#define INK_CURVE_KDE_STEPS   300

typedef struct {
    double  data[INK_CURVE_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
    int     filled;  /* fill area under curve */
} InkCurveSeries;

typedef struct {
    InkCurveSeries series[INK_CURVE_MAX_SERIES];
    int            n_series;
    char           title[128];
    char           xlabel[64];
    char           ylabel[64];
    int            width;
    int            height;
    int            grid;
    double         bandwidth;  /* 0 = auto Silverman */
} InkCurvePlot;

typedef InkCurvePlot CurvePlot;

static InkCurvePlot* ink_new_curve(double* data, int n) {
    InkCurvePlot* p = (InkCurvePlot*)malloc(sizeof(InkCurvePlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkCurvePlot));
    p->width     = INK_WIDTH;
    p->height    = INK_HEIGHT;
    p->grid      = 1;
    p->bandwidth = 0.0;

    int count = n < INK_CURVE_MAX_POINTS ? n : INK_CURVE_MAX_POINTS;
    for (int i = 0; i < count; i++)
        p->series[0].data[i] = data[i];
    p->series[0].n      = count;
    p->series[0].filled = 0;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

InkCurvePlot* ink_new_curve_mocha(MochaArray* arr) {
    int n = arr->length < INK_CURVE_MAX_POINTS ? arr->length : INK_CURVE_MAX_POINTS;
    double* data = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        data[i] = v;
    }
    InkCurvePlot* p = ink_new_curve(data, n);
    free(data);
    return p;
}

void ink_curve_add_mocha(InkCurvePlot* p, MochaArray* arr) {
    if (p->n_series >= INK_CURVE_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max curve series reached\n");
        return;
    }
    int n = arr->length < INK_CURVE_MAX_POINTS ? arr->length : INK_CURVE_MAX_POINTS;
    InkCurveSeries* s = &p->series[p->n_series];
    for (int i = 0; i < n; i++) {
        double v;
        mocha_array_get(arr, i, &v);
        s->data[i] = v;
    }
    s->n      = n;
    s->filled = 0;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── setters ── */
void ink_cv_set_title(InkCurvePlot* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_cv_set_xlabel(InkCurvePlot* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_cv_set_ylabel(InkCurvePlot* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_cv_set_grid(InkCurvePlot* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_cv_set_bandwidth(InkCurvePlot* p, double h)   { p->bandwidth = h;            }
void ink_cv_set_fill(InkCurvePlot* p)                  { p->series[p->n_series-1].filled = 1; }
void ink_cv_set_color(InkCurvePlot* p, const char* c) {
    strncpy(p->series[p->n_series-1].color, ink_resolve_color(c), 31);
}
void ink_cv_set_label(InkCurvePlot* p, const char* l) {
    strncpy(p->series[p->n_series-1].label, l, 63);
}

/* ── SVG generation ── */
void ink_curve_save(InkCurvePlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find global data range */
    double dmin = p->series[0].data[0];
    double dmax = p->series[0].data[0];
    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double v = p->series[s].data[i];
            if (v < dmin) dmin = v;
            if (v > dmax) dmax = v;
        }
    }
    double range = dmax - dmin;
    dmin -= range * 0.1;
    dmax += range * 0.1;

    double nx_min, nx_max, nx_step;
    ink_nice_range(dmin, dmax, &nx_min, &nx_max, &nx_step);

    /* compute KDE for all series */
    double kde_y[INK_CURVE_MAX_SERIES][INK_CURVE_KDE_STEPS];
    double kde_max = 0.0;

    for (int s = 0; s < p->n_series; s++) {
        double h = p->bandwidth > 0.0
                   ? p->bandwidth
                   : ink_silverman(p->series[s].data, p->series[s].n);
        for (int k = 0; k < INK_CURVE_KDE_STEPS; k++) {
            double x = nx_min + (nx_max - nx_min) * k / (INK_CURVE_KDE_STEPS - 1);
            kde_y[s][k] = ink_kde(x, p->series[s].data, p->series[s].n, h);
            if (kde_y[s][k] > kde_max) kde_max = kde_y[s][k];
        }
    }
    if (kde_max == 0.0) kde_max = 1.0;

    double ny_min, ny_max, ny_step;
    ink_nice_range(0.0, kde_max, &ny_min, &ny_max, &ny_step);
    ny_min = 0.0;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* clip */
    fprintf(f,
        "<clipPath id=\"ink-cvclip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n",
        ml, mt, pw, ph
    );

    /* grid */
    if (p->grid) {
        for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
            double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
        for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
            double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                gx, mt, gx, mt + ph
            );
        }
    }

    /* y axis ticks */
    for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
        double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            ml - 5, gy, ml, gy
        );
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%.3f</text>\n",
            ml - 8, gy, v
        );
    }

    /* x axis ticks */
    for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
        double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            gx, mt + ph, gx, mt + ph + 5
        );
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-tick\">%g</text>\n",
            gx, mt + ph + 18, v
        );
    }

    /* draw curves */
    double baseline = ink_map_y(0.0, ny_min, ny_max, mt, ph);

    for (int s = 0; s < p->n_series; s++) {
        const char* col = p->series[s].color;

        /* filled area under curve */
        if (p->series[s].filled) {
            fprintf(f,
                "<polygon fill=\"%s\" opacity=\"0.2\" "
                "clip-path=\"url(#ink-cvclip)\" points=\"",
                col
            );
            double px0 = ink_map_x(nx_min, nx_min, nx_max, ml, pw);
            fprintf(f, "%.2f,%.2f ", px0, baseline);
            for (int k = 0; k < INK_CURVE_KDE_STEPS; k++) {
                double x  = nx_min + (nx_max - nx_min) * k / (INK_CURVE_KDE_STEPS - 1);
                double px = ink_map_x(x,         nx_min, nx_max, ml, pw);
                double py = ink_map_y(kde_y[s][k], ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            double pxn = ink_map_x(nx_max, nx_min, nx_max, ml, pw);
            fprintf(f, "%.2f,%.2f ", pxn, baseline);
            fprintf(f, "\"/>\n");
        }

        /* curve line */
        fprintf(f,
            "<polyline fill=\"none\" stroke=\"%s\" stroke-width=\"2.5\" "
            "stroke-linejoin=\"round\" stroke-linecap=\"round\" "
            "clip-path=\"url(#ink-cvclip)\" points=\"",
            col
        );
        for (int k = 0; k < INK_CURVE_KDE_STEPS; k++) {
            double x  = nx_min + (nx_max - nx_min) * k / (INK_CURVE_KDE_STEPS - 1);
            double px = ink_map_x(x,           nx_min, nx_max, ml, pw);
            double py = ink_map_y(kde_y[s][k], ny_min, ny_max, mt, ph);
            fprintf(f, "%.2f,%.2f ", px, py);
        }
        fprintf(f, "\"/>\n");
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    /* legend */
    int show_legend = p->n_series > 1;
    for (int s = 0; s < p->n_series; s++)
        if (p->series[s].label[0]) { show_legend = 1; break; }

    if (show_legend) {
        int lx = ml + pw - 10;
        int ly = mt + 10;
        int lw = 130;
        int lh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
            "rx=\"4\" opacity=\"0.9\"/>\n",
            lx - lw, ly, lw, lh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = ly + 10 + s * 22;
            const char* lbl = p->series[s].label[0]
                              ? p->series[s].label
                              : (s == 0 ? "Series 1" : "Series 2");
            fprintf(f,
                "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
                "stroke=\"%s\" stroke-width=\"2.5\"/>\n",
                lx - lw + 8, iy + 7, lx - lw + 22, iy + 7,
                p->series[s].color
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx - lw + 28, iy + 11, lbl
            );
        }
    }

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_curve_show(InkCurvePlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_curve_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_cp_set_title(CurvePlot* p, const char* t)  { ink_cv_set_title(p, t);     }
void ink_cp_set_xlabel(CurvePlot* p, const char* l) { ink_cv_set_xlabel(p, l);    }
void ink_cp_set_ylabel(CurvePlot* p, const char* l) { ink_cv_set_ylabel(p, l);    }
void ink_cp_set_grid(CurvePlot* p, int8_t on)       { ink_cv_set_grid(p, on);     }
void ink_cp_set_bandwidth(CurvePlot* p, double h)   { ink_cv_set_bandwidth(p, h); }
void ink_cp_set_fill(CurvePlot* p)                  { ink_cv_set_fill(p);         }
void ink_cp_set_color(CurvePlot* p, const char* c)  { ink_cv_set_color(p, c);     }
void ink_cp_set_label(CurvePlot* p, const char* l)  { ink_cv_set_label(p, l);     }
void ink_cp_add(CurvePlot* p, MochaArray* arr)      { ink_curve_add_mocha(p, arr);}
void ink_cp_save(CurvePlot* p, const char* path)    { ink_curve_save(p, path);    }
void ink_cp_show(CurvePlot* p)                      { ink_curve_show(p);          }

/* ============================================================
 * mocha-ink — Error Bar Plot
 * ============================================================ */

#define INK_ERR_MAX_SERIES  6
#define INK_ERR_MAX_POINTS  1024
#define INK_ERR_CAP_SIZE    6.0

typedef struct {
    double  x[INK_ERR_MAX_POINTS];
    double  y[INK_ERR_MAX_POINTS];
    double  err_lo[INK_ERR_MAX_POINTS];
    double  err_hi[INK_ERR_MAX_POINTS];
    int     n;
    char    color[32];
    char    label[64];
    int     connect;  /* draw line between points */
} InkErrSeries;

typedef struct {
    InkErrSeries series[INK_ERR_MAX_SERIES];
    int          n_series;
    char         title[128];
    char         xlabel[64];
    char         ylabel[64];
    int          width;
    int          height;
    int          grid;
} InkErrorPlot;

typedef InkErrorPlot ErrorPlot;

static InkErrorPlot* ink_new_errorplot(double* x, double* y,
                                        double* err_lo, double* err_hi, int n) {
    InkErrorPlot* p = (InkErrorPlot*)malloc(sizeof(InkErrorPlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkErrorPlot));
    p->width  = INK_WIDTH;
    p->height = INK_HEIGHT;
    p->grid   = 1;

    int count = n < INK_ERR_MAX_POINTS ? n : INK_ERR_MAX_POINTS;
    for (int i = 0; i < count; i++) {
        p->series[0].x[i]      = x[i];
        p->series[0].y[i]      = y[i];
        p->series[0].err_lo[i] = err_lo[i];
        p->series[0].err_hi[i] = err_hi[i];
    }
    p->series[0].n       = count;
    p->series[0].connect = 0;
    strncpy(p->series[0].color, INK_PALETTE[0], 31);
    strncpy(p->series[0].label, "", 63);
    p->n_series = 1;
    return p;
}

/* symmetric error helper */
InkErrorPlot* ink_new_errorplot_mocha(MochaArray* x, MochaArray* y, MochaArray* err) {
    int n = x->length;
    if (y->length   < n) n = y->length;
    if (err->length < n) n = err->length;
    if (n > INK_ERR_MAX_POINTS) n = INK_ERR_MAX_POINTS;

    double* xd  = (double*)malloc(n * sizeof(double));
    double* yd  = (double*)malloc(n * sizeof(double));
    double* elo = (double*)malloc(n * sizeof(double));
    double* ehi = (double*)malloc(n * sizeof(double));

    for (int i = 0; i < n; i++) {
        mocha_array_get(x,   i, &xd[i]);
        mocha_array_get(y,   i, &yd[i]);
        double e;
        mocha_array_get(err, i, &e);
        elo[i] = e;
        ehi[i] = e;
    }
    InkErrorPlot* p = ink_new_errorplot(xd, yd, elo, ehi, n);
    free(xd); free(yd); free(elo); free(ehi);
    return p;
}

/* asymmetric error */
void ink_err_set_asymmetric_mocha(InkErrorPlot* p,
                                   MochaArray* err_lo, MochaArray* err_hi) {
    InkErrSeries* s = &p->series[p->n_series - 1];
    int n = s->n;
    for (int i = 0; i < n; i++) {
        if (i < (int)err_lo->length) mocha_array_get(err_lo, i, &s->err_lo[i]);
        if (i < (int)err_hi->length) mocha_array_get(err_hi, i, &s->err_hi[i]);
    }
}

void ink_err_add_mocha(InkErrorPlot* p,
                       MochaArray* x, MochaArray* y, MochaArray* err) {
    if (p->n_series >= INK_ERR_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max error series reached\n");
        return;
    }
    int n = x->length;
    if (y->length   < n) n = y->length;
    if (err->length < n) n = err->length;
    if (n > INK_ERR_MAX_POINTS) n = INK_ERR_MAX_POINTS;

    InkErrSeries* s = &p->series[p->n_series];
    for (int i = 0; i < n; i++) {
        mocha_array_get(x,   i, &s->x[i]);
        mocha_array_get(y,   i, &s->y[i]);
        double e;
        mocha_array_get(err, i, &e);
        s->err_lo[i] = e;
        s->err_hi[i] = e;
    }
    s->n       = n;
    s->connect = 0;
    strncpy(s->color, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label, "", 63);
    p->n_series++;
}

/* ── setters ── */
void ink_er_set_title(InkErrorPlot* p, const char* t)  { strncpy(p->title,  t, 127); }
void ink_er_set_xlabel(InkErrorPlot* p, const char* l) { strncpy(p->xlabel, l, 63);  }
void ink_er_set_ylabel(InkErrorPlot* p, const char* l) { strncpy(p->ylabel, l, 63);  }
void ink_er_set_grid(InkErrorPlot* p, int8_t on)       { p->grid = on ? 1 : 0;       }
void ink_er_set_connect(InkErrorPlot* p) {
    p->series[p->n_series - 1].connect = 1;
}
void ink_er_set_color(InkErrorPlot* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, ink_resolve_color(c), 31);
}
void ink_er_set_label(InkErrorPlot* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── SVG generation ── */
void ink_errorplot_save(InkErrorPlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find data range including error bars */
    double xmin = p->series[0].x[0], xmax = xmin;
    double ymin = p->series[0].y[0] - p->series[0].err_lo[0];
    double ymax = p->series[0].y[0] + p->series[0].err_hi[0];

    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double xi  = p->series[s].x[i];
            double yi  = p->series[s].y[i];
            double ylo = yi - p->series[s].err_lo[i];
            double yhi = yi + p->series[s].err_hi[i];
            if (xi   < xmin) xmin = xi;
            if (xi   > xmax) xmax = xi;
            if (ylo  < ymin) ymin = ylo;
            if (yhi  > ymax) ymax = yhi;
        }
    }

    double nx_min, nx_max, nx_step;
    double ny_min, ny_max, ny_step;
    ink_nice_range(xmin, xmax, &nx_min, &nx_max, &nx_step);
    ink_nice_range(ymin, ymax, &ny_min, &ny_max, &ny_step);

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* clip */
    fprintf(f,
        "<clipPath id=\"ink-erclip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n",
        ml, mt, pw, ph
    );

    /* grid */
    if (p->grid) {
        for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
            double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
        for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
            double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                gx, mt, gx, mt + ph
            );
        }
    }

    /* x axis ticks */
    for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
        double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            gx, mt + ph, gx, mt + ph + 5
        );
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-tick\">%g</text>\n",
            gx, mt + ph + 18, v
        );
    }

    /* y axis ticks */
    for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
        double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            ml - 5, gy, ml, gy
        );
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
            ml - 8, gy, v
        );
    }

    /* draw series */
    for (int s = 0; s < p->n_series; s++) {
        InkErrSeries* sr = &p->series[s];
        const char* col  = sr->color;

        /* connecting line first so it's behind error bars and dots */
        if (sr->connect) {
            fprintf(f,
                "<polyline fill=\"none\" stroke=\"%s\" stroke-width=\"1.5\" "
                "stroke-dasharray=\"6,3\" opacity=\"0.6\" "
                "clip-path=\"url(#ink-erclip)\" points=\"",
                col
            );
            for (int i = 0; i < sr->n; i++) {
                double px = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
                double py = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f, "\"/>\n");
        }

        /* error bars */
        for (int i = 0; i < sr->n; i++) {
            double px  = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
            double py  = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
            double plo = ink_map_y(sr->y[i] - sr->err_lo[i], ny_min, ny_max, mt, ph);
            double phi = ink_map_y(sr->y[i] + sr->err_hi[i], ny_min, ny_max, mt, ph);

            /* vertical error line */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" "
                "clip-path=\"url(#ink-erclip)\"/>\n",
                px, phi, px, plo, col
            );

            /* top cap */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" "
                "clip-path=\"url(#ink-erclip)\"/>\n",
                px - INK_ERR_CAP_SIZE, phi,
                px + INK_ERR_CAP_SIZE, phi, col
            );

            /* bottom cap */
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"1.5\" "
                "clip-path=\"url(#ink-erclip)\"/>\n",
                px - INK_ERR_CAP_SIZE, plo,
                px + INK_ERR_CAP_SIZE, plo, col
            );

            /* center dot */
            fprintf(f,
                "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"4\" "
                "fill=\"%s\" clip-path=\"url(#ink-erclip)\"/>\n",
                px, py, col
            );
        }
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    /* legend */
    int show_legend = p->n_series > 1;
    for (int s = 0; s < p->n_series; s++)
        if (p->series[s].label[0]) { show_legend = 1; break; }

    if (show_legend) {
        int lx = ml + pw - 10;
        int ly = mt + 10;
        int lw = 130;
        int lh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
            "rx=\"4\" opacity=\"0.9\"/>\n",
            lx - lw, ly, lw, lh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = ly + 10 + s * 22;
            const char* lbl = p->series[s].label[0]
                              ? p->series[s].label
                              : (s == 0 ? "Series 1" : "Series 2");
            /* error bar icon in legend */
            fprintf(f,
                "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                lx - lw + 14, iy + 2, lx - lw + 14, iy + 16,
                p->series[s].color
            );
            fprintf(f,
                "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                lx - lw + 10, iy + 2, lx - lw + 18, iy + 2,
                p->series[s].color
            );
            fprintf(f,
                "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
                "stroke=\"%s\" stroke-width=\"1.5\"/>\n",
                lx - lw + 10, iy + 16, lx - lw + 18, iy + 16,
                p->series[s].color
            );
            fprintf(f,
                "<circle cx=\"%d\" cy=\"%d\" r=\"3\" fill=\"%s\"/>\n",
                lx - lw + 14, iy + 9, p->series[s].color
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx - lw + 28, iy + 11, lbl
            );
        }
    }

    fprintf(f, "</svg>\n");
    fclose(f);
}

void ink_errorplot_show(InkErrorPlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_errorplot_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── wrappers ── */
void ink_ep_set_title(ErrorPlot* p, const char* t)  { ink_er_set_title(p, t);     }
void ink_ep_set_xlabel(ErrorPlot* p, const char* l) { ink_er_set_xlabel(p, l);    }
void ink_ep_set_ylabel(ErrorPlot* p, const char* l) { ink_er_set_ylabel(p, l);    }
void ink_ep_set_grid(ErrorPlot* p, int8_t on)       { ink_er_set_grid(p, on);     }
void ink_ep_set_connect(ErrorPlot* p)               { ink_er_set_connect(p);      }
void ink_ep_set_color(ErrorPlot* p, const char* c)  { ink_er_set_color(p, c);     }
void ink_ep_set_label(ErrorPlot* p, const char* l)  { ink_er_set_label(p, l);     }
void ink_ep_set_asymmetric(ErrorPlot* p, MochaArray* lo, MochaArray* hi) {
    ink_err_set_asymmetric_mocha(p, lo, hi);
}
void ink_ep_add(ErrorPlot* p, MochaArray* x, MochaArray* y, MochaArray* err) {
    ink_err_add_mocha(p, x, y, err);
}
void ink_ep_save(ErrorPlot* p, const char* path)    { ink_errorplot_save(p, path);}
void ink_ep_show(ErrorPlot* p)                      { ink_errorplot_show(p);      }

/* ════════════════════════════════════════════════════════════
   mocha-ink  —  LMPlot  (scatter + OLS line + confidence band)
   ════════════════════════════════════════════════════════════ */

/* ── Series ── */
typedef struct {
    double x[INK_MAX_POINTS];
    double y[INK_MAX_POINTS];
    int    n;
    char   color[32];
    char   linecolor[32];
    char   label[64];
} InkLMSeries;

/* ── Plot struct ── */
typedef struct {
    InkLMSeries series[INK_MAX_SERIES];
    int         n_series;
    char        title[128];
    char        xlabel[64];
    char        ylabel[64];
    int         width;
    int         height;
    int         grid;
    int         noband;
    double      ci_level;   /* default 0.95 */
} InkLMPlot;

/* ── OLS fit result ── */
typedef struct {
    double slope;
    double intercept;
    double se;        /* standard error of regression */
    double x_mean;
    double sxx;       /* sum of (xi - xmean)^2 */
    int    n;
} InkOLS;

/* ── Least squares fit ── */
static InkOLS ink_ols(const double* x, const double* y, int n) {
    InkOLS r = {0};
    r.n = n;
    double sx = 0, sy = 0, sxx = 0, sxy = 0;
    for (int i = 0; i < n; i++) {
        sx  += x[i];
        sy  += y[i];
        sxx += x[i] * x[i];
        sxy += x[i] * y[i];
    }
    double xm = sx / n;
    double ym = sy / n;
    double denom = sxx - n * xm * xm;
    if (denom == 0.0) denom = 1e-12;
    r.slope     = (sxy - n * xm * ym) / denom;
    r.intercept = ym - r.slope * xm;
    r.x_mean    = xm;
    r.sxx       = denom;

    /* residual standard error */
    double sse = 0;
    for (int i = 0; i < n; i++) {
        double res = y[i] - (r.slope * x[i] + r.intercept);
        sse += res * res;
    }
    r.se = (n > 2) ? sqrt(sse / (n - 2)) : 0.0;
    return r;
}

/* ── t-value lookup (approximate) for common CI levels ── */
static double ink_t_value(double ci_level, int df) {
    /* simple lookup for 90/95/99, fallback to 1.96 */
    (void)df; /* for large n t ≈ z */
    if (ci_level >= 0.99) return 2.576;
    if (ci_level >= 0.95) return 1.960;
    if (ci_level >= 0.90) return 1.645;
    return 1.960;
}

/* ── Constructor ── */
static InkLMPlot* ink_lm_new(double* x, double* y, int n) {
    InkLMPlot* p = (InkLMPlot*)malloc(sizeof(InkLMPlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkLMPlot));
    p->width    = INK_WIDTH;
    p->height   = INK_HEIGHT;
    p->grid     = 1;
    p->noband   = 0;
    p->ci_level = 0.95;

    InkLMSeries* s = &p->series[0];
    int count = n < INK_MAX_POINTS ? n : INK_MAX_POINTS;
    for (int i = 0; i < count; i++) {
        s->x[i] = x[i];
        s->y[i] = y[i];
    }
    s->n = count;
    strncpy(s->color,     INK_PALETTE[0], 31);
    strncpy(s->linecolor, INK_PALETTE[0], 31);
    strncpy(s->label,     "",             63);
    p->n_series = 1;
    return p;
}

/* ── Mocha-facing constructor ── */
InkLMPlot* ink_new_lmplot_mocha(MochaArray* x, MochaArray* y) {
    int n = x->length < y->length ? x->length : y->length;
    double* xd = (double*)malloc(n * sizeof(double));
    double* yd = (double*)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        xd[i] = xv;
        yd[i] = yv;
    }
    InkLMPlot* p = ink_lm_new(xd, yd, n);
    free(xd);
    free(yd);
    return p;
}

/* ── Setters ── */
void ink_lm_set_title(InkLMPlot* p, const char* t)     { strncpy(p->title,  t, 127); }
void ink_lm_set_xlabel(InkLMPlot* p, const char* l)    { strncpy(p->xlabel, l, 63);  }
void ink_lm_set_ylabel(InkLMPlot* p, const char* l)    { strncpy(p->ylabel, l, 63);  }
void ink_lm_set_grid(InkLMPlot* p, int8_t on)          { p->grid = on; }
void ink_lm_set_noband(InkLMPlot* p)                   { p->noband = 1; }
void ink_lm_set_ci(InkLMPlot* p, double level)         { p->ci_level = level; }

void ink_lm_set_color(InkLMPlot* p, const char* c) {
    strncpy(p->series[p->n_series - 1].color, c, 31);
}
void ink_lm_set_linecolor(InkLMPlot* p, const char* c) {
    strncpy(p->series[p->n_series - 1].linecolor, c, 31);
}
void ink_lm_set_label(InkLMPlot* p, const char* l) {
    strncpy(p->series[p->n_series - 1].label, l, 63);
}

/* ── Add series ── */
void ink_lm_add_series(InkLMPlot* p, MochaArray* x, MochaArray* y) {
    if (p->n_series >= INK_MAX_SERIES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max series reached, ignoring\n");
        return;
    }
    int n = x->length < y->length ? x->length : y->length;
    InkLMSeries* s = &p->series[p->n_series];
    int count = n < INK_MAX_POINTS ? n : INK_MAX_POINTS;
    for (int i = 0; i < count; i++) {
        double xv, yv;
        mocha_array_get(x, i, &xv);
        mocha_array_get(y, i, &yv);
        s->x[i] = xv;
        s->y[i] = yv;
    }
    s->n = count;
    strncpy(s->color,     INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->linecolor, INK_PALETTE[p->n_series % INK_MAX_SERIES], 31);
    strncpy(s->label,     "", 63);
    p->n_series++;
}

/* ── SVG save ── */
void ink_lm_save(InkLMPlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W  = p->width;
    int H  = p->height;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find data range across all series */
    double xmin = p->series[0].x[0], xmax = xmin;
    double ymin = p->series[0].y[0], ymax = ymin;

    for (int s = 0; s < p->n_series; s++) {
        for (int i = 0; i < p->series[s].n; i++) {
            double xi = p->series[s].x[i];
            double yi = p->series[s].y[i];
            if (xi < xmin) xmin = xi;
            if (xi > xmax) xmax = xi;
            if (yi < ymin) ymin = yi;
            if (yi > ymax) ymax = yi;
        }
    }

    /* extend y range to fit regression lines */
    for (int s = 0; s < p->n_series; s++) {
        InkOLS ols = ink_ols(p->series[s].x, p->series[s].y, p->series[s].n);
        double y0 = ols.slope * xmin + ols.intercept;
        double y1 = ols.slope * xmax + ols.intercept;
        if (y0 < ymin) ymin = y0;
        if (y0 > ymax) ymax = y0;
        if (y1 < ymin) ymin = y1;
        if (y1 > ymax) ymax = y1;
    }

    double nx_min, nx_max, nx_step;
    double ny_min, ny_max, ny_step;
    ink_nice_range(xmin, xmax, &nx_min, &nx_max, &nx_step);
    ink_nice_range(ymin, ymax, &ny_min, &ny_max, &ny_step);

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title  { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-label  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "  .ink-tick   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #555; }\n"
        "  .ink-legend { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f, "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n", W, H);
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph
    );

    /* clip */
    fprintf(f,
        "<clipPath id=\"ink-lmclip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n",
        ml, mt, pw, ph
    );

    /* grid */
    if (p->grid) {
        for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
            double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
            fprintf(f,
                "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                ml, gy, ml + pw, gy
            );
        }
        for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
            double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
                "stroke=\"#EEEEEE\" stroke-width=\"1\"/>\n",
                gx, mt, gx, mt + ph
            );
        }
    }

    /* per-series: band → line → dots (back to front) */
    for (int s = 0; s < p->n_series; s++) {
        InkLMSeries* sr  = &p->series[s];
        InkOLS        ols = ink_ols(sr->x, sr->y, sr->n);
        double        t   = ink_t_value(p->ci_level, ols.n - 2);

        /* confidence band — polygon built left to right then right to left */
        if (!p->noband) {
            int    steps  = 100;
            double x_step = (nx_max - nx_min) / steps;

            /* upper edge */
            fprintf(f, "<polygon points=\"");
            for (int i = 0; i <= steps; i++) {
                double xi  = nx_min + i * x_step;
                double yi  = ols.slope * xi + ols.intercept;
                double se_i = ols.se * sqrt(
                    1.0 / ols.n +
                    (xi - ols.x_mean) * (xi - ols.x_mean) / ols.sxx
                );
                double hi  = yi + t * se_i;
                double px  = ink_map_x(xi, nx_min, nx_max, ml, pw);
                double py  = ink_map_y(hi, ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            /* lower edge (reversed) */
            for (int i = steps; i >= 0; i--) {
                double xi  = nx_min + i * x_step;
                double yi  = ols.slope * xi + ols.intercept;
                double se_i = ols.se * sqrt(
                    1.0 / ols.n +
                    (xi - ols.x_mean) * (xi - ols.x_mean) / ols.sxx
                );
                double lo  = yi - t * se_i;
                double px  = ink_map_x(xi, nx_min, nx_max, ml, pw);
                double py  = ink_map_y(lo, ny_min, ny_max, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f,
                "\" fill=\"%s\" opacity=\"0.15\" "
                "clip-path=\"url(#ink-lmclip)\"/>\n",
                sr->linecolor
            );
        }

        /* regression line */
        {
            double x0 = nx_min, x1 = nx_max;
            double y0 = ols.slope * x0 + ols.intercept;
            double y1 = ols.slope * x1 + ols.intercept;
            double px0 = ink_map_x(x0, nx_min, nx_max, ml, pw);
            double py0 = ink_map_y(y0, ny_min, ny_max, mt, ph);
            double px1 = ink_map_x(x1, nx_min, nx_max, ml, pw);
            double py1 = ink_map_y(y1, ny_min, ny_max, mt, ph);
            fprintf(f,
                "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
                "stroke=\"%s\" stroke-width=\"2\" "
                "clip-path=\"url(#ink-lmclip)\"/>\n",
                px0, py0, px1, py1, sr->linecolor
            );
        }

        /* scatter dots */
        for (int i = 0; i < sr->n; i++) {
            double cx = ink_map_x(sr->x[i], nx_min, nx_max, ml, pw);
            double cy = ink_map_y(sr->y[i], ny_min, ny_max, mt, ph);
            fprintf(f,
                "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"%d\" "
                "fill=\"%s\" opacity=\"0.8\" "
                "clip-path=\"url(#ink-lmclip)\"/>\n",
                cx, cy, INK_DOT_RADIUS, sr->color
            );
        }
    }

    /* x axis ticks */
    for (double v = nx_min; v <= nx_max + nx_step * 0.01; v += nx_step) {
        double gx = ink_map_x(v, nx_min, nx_max, ml, pw);
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%d\" x2=\"%.2f\" y2=\"%d\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            gx, mt + ph, gx, mt + ph + 5
        );
        fprintf(f,
            "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-tick\">%g</text>\n",
            gx, mt + ph + 18, v
        );
    }

    /* y axis ticks */
    for (double v = ny_min; v <= ny_max + ny_step * 0.01; v += ny_step) {
        double gy = ink_map_y(v, ny_min, ny_max, mt, ph);
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#999\" stroke-width=\"1\"/>\n",
            ml - 5, gy, ml, gy
        );
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-tick\">%g</text>\n",
            ml - 8, gy, v
        );
    }

    /* axis border */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt + ph, ml + pw, mt + ph
    );
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, ml, mt + ph
    );

    /* legend */
    int show_legend = p->n_series > 1;
    for (int s = 0; s < p->n_series; s++)
        if (p->series[s].label[0]) { show_legend = 1; break; }

    if (show_legend) {
        int lx = ml + pw - 140;
        int ly = mt + 10;
        int lw = 130;
        int lh = p->n_series * 22 + 10;
        fprintf(f,
            "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
            "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
            "rx=\"4\" opacity=\"0.9\"/>\n",
            lx, ly, lw, lh
        );
        for (int s = 0; s < p->n_series; s++) {
            int iy = ly + 10 + s * 22;
            const char* lbl = p->series[s].label[0]
                              ? p->series[s].label
                              : (s == 0 ? "Series 1" : "Series 2");
            /* line swatch */
            fprintf(f,
                "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
                "stroke=\"%s\" stroke-width=\"2\"/>\n",
                lx + 6, iy + 7, lx + 22, iy + 7, p->series[s].linecolor
            );
            /* dot swatch */
            fprintf(f,
                "<circle cx=\"%d\" cy=\"%d\" r=\"3\" fill=\"%s\" opacity=\"0.8\"/>\n",
                lx + 14, iy + 7, p->series[s].color
            );
            fprintf(f,
                "<text x=\"%d\" y=\"%d\" class=\"ink-legend\">%s</text>\n",
                lx + 28, iy + 11, lbl
            );
        }
    }

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, mt - 15, p->title
        );

    /* x label */
    if (p->xlabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-label\">%s</text>\n",
            W / 2, H - 10, p->xlabel
        );

    /* y label */
    if (p->ylabel[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "transform=\"rotate(-90, %d, %d)\" class=\"ink-label\">%s</text>\n",
            ml - 55, mt + ph / 2,
            ml - 55, mt + ph / 2,
            p->ylabel
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

/* ── Show ── */
void ink_lm_show(InkLMPlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_lm_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* Wrappers */
void ink_lm_set_title_mocha(InkLMPlot* p, const char* t)     { ink_lm_set_title(p, t); }
void ink_lm_set_xlabel_mocha(InkLMPlot* p, const char* l)    { ink_lm_set_xlabel(p, l); }
void ink_lm_set_ylabel_mocha(InkLMPlot* p, const char* l)    { ink_lm_set_ylabel(p, l); }
void ink_lm_set_color_mocha(InkLMPlot* p, const char* c)     { ink_lm_set_color(p, c); }
void ink_lm_set_linecolor_mocha(InkLMPlot* p, const char* c) { ink_lm_set_linecolor(p, c); }
void ink_lm_set_label_mocha(InkLMPlot* p, const char* l)     { ink_lm_set_label(p, l); }
void ink_lm_set_grid_mocha(InkLMPlot* p, int8_t on)          { ink_lm_set_grid(p, on); }
void ink_lm_set_ci_mocha(InkLMPlot* p, double level)         { ink_lm_set_ci(p, level); }
void ink_lm_set_noband_mocha(InkLMPlot* p)                   { ink_lm_set_noband(p); }
void ink_lm_add_mocha(InkLMPlot* p, MochaArray* x, MochaArray* y) { ink_lm_add_series(p, x, y); }
void ink_lm_save_mocha(InkLMPlot* p, const char* path)       { ink_lm_save(p, path); }
void ink_lm_show_mocha(InkLMPlot* p)                         { ink_lm_show(p); }

/* ════════════════════════════════════════════════════════════
   mocha-ink  —  NetworkChart  (circular layout, nodes + edges)
   ════════════════════════════════════════════════════════════ */

#define INK_NET_MAX_NODES  64
#define INK_NET_MAX_EDGES  256
#define INK_NET_NODE_R     22.0
#define INK_NET_ARROW_SIZE 10.0
#define M_PI_NET           3.14159265358979323846

/* ── Node ── */
typedef struct {
    char   id[64];
    char   label[64];
    char   color[32];
    double size;   /* radius multiplier, default 1.0 */
    double cx;     /* computed SVG x */
    double cy;     /* computed SVG y */
} InkNetNode;

/* ── Edge ── */
typedef struct {
    char   from[64];
    char   to[64];
    double weight;    /* 0.0 = unweighted */
    char   color[32];
} InkNetEdge;

/* ── Chart ── */
typedef struct {
    InkNetNode nodes[INK_NET_MAX_NODES];
    int        n_nodes;
    InkNetEdge edges[INK_NET_MAX_EDGES];
    int        n_edges;
    char       title[128];
    int        directed;
    int        show_labels;
    int        width;
    int        height;
} InkNetChart;

/* ── Constructor ── */
static InkNetChart* ink_net_new_internal(void) {
    InkNetChart* p = (InkNetChart*)malloc(sizeof(InkNetChart));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkNetChart));
    p->width       = INK_WIDTH;
    p->height      = INK_HEIGHT;
    p->directed    = 0;
    p->show_labels = 1;
    return p;
}

InkNetChart* ink_new_network(void) {
    return ink_net_new_internal();
}

/* ── Node lookup ── */
static int ink_net_find_node(InkNetChart* p, const char* id) {
    for (int i = 0; i < p->n_nodes; i++)
        if (strcmp(p->nodes[i].id, id) == 0) return i;
    return -1;
}

/* ── Add node ── */
void ink_net_add_node(InkNetChart* p, const char* id, const char* label) {
    if (p->n_nodes >= INK_NET_MAX_NODES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max nodes (%d) reached\n",
                INK_NET_MAX_NODES);
        return;
    }
    if (ink_net_find_node(p, id) >= 0) return; /* already exists */
    InkNetNode* n = &p->nodes[p->n_nodes];
    strncpy(n->id,    id,    63);
    strncpy(n->label, label, 63);
    strncpy(n->color, INK_PALETTE[p->n_nodes % INK_MAX_SERIES], 31);
    n->size = 1.0;
    p->n_nodes++;
}

/* ── Add edge (unweighted) ── */
void ink_net_add_edge(InkNetChart* p, const char* from, const char* to) {
    if (p->n_edges >= INK_NET_MAX_EDGES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max edges (%d) reached\n",
                INK_NET_MAX_EDGES);
        return;
    }
    InkNetEdge* e = &p->edges[p->n_edges];
    strncpy(e->from,  from, 63);
    strncpy(e->to,    to,   63);
    e->weight = 0.0;
    strncpy(e->color, "#AAAAAA", 31);
    p->n_edges++;
}

/* ── Add edge (weighted) ── */
void ink_net_add_edge_weight(InkNetChart* p,
                             const char* from, const char* to,
                             double weight) {
    if (p->n_edges >= INK_NET_MAX_EDGES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max edges (%d) reached\n",
                INK_NET_MAX_EDGES);
        return;
    }
    InkNetEdge* e = &p->edges[p->n_edges];
    strncpy(e->from,  from, 63);
    strncpy(e->to,    to,   63);
    e->weight = weight;
    strncpy(e->color, "#AAAAAA", 31);
    p->n_edges++;
}

/* ── Setters ── */
void ink_net_set_title(InkNetChart* p, const char* t) {
    strncpy(p->title, t, 127);
}
void ink_net_set_directed(InkNetChart* p, int8_t on) {
    p->directed = on;
}
void ink_net_set_labels(InkNetChart* p, int8_t on) {
    p->show_labels = on;
}
void ink_net_set_node_color(InkNetChart* p,
                            const char* id, const char* color) {
    int i = ink_net_find_node(p, id);
    if (i >= 0) strncpy(p->nodes[i].color, color, 31);
}
void ink_net_set_node_size(InkNetChart* p,
                           const char* id, double size) {
    int i = ink_net_find_node(p, id);
    if (i >= 0) p->nodes[i].size = size;
}
void ink_net_set_edge_color(InkNetChart* p,
                            const char* from, const char* to,
                            const char* color) {
    for (int i = 0; i < p->n_edges; i++) {
        if (strcmp(p->edges[i].from, from) == 0 &&
            strcmp(p->edges[i].to,   to)   == 0) {
            strncpy(p->edges[i].color, color, 31);
            return;
        }
    }
}

/* ── Circular layout ── */
static void ink_net_layout(InkNetChart* p) {
    int    W  = p->width;
    int    H  = p->height;
    int    mt = INK_MARGIN_TOP;
    int    mb = INK_MARGIN_BOTTOM;
    int    ml = INK_MARGIN_LEFT;
    int    mr = INK_MARGIN_RIGHT;
    double cx = ml + (W - ml - mr) / 2.0;
    double cy = mt + (H - mt - mb) / 2.0;
    double r  = (W - ml - mr < H - mt - mb
                 ? W - ml - mr : H - mt - mb) * 0.38;

    if (p->n_nodes == 1) {
        p->nodes[0].cx = cx;
        p->nodes[0].cy = cy;
        return;
    }
    for (int i = 0; i < p->n_nodes; i++) {
        double angle = 2.0 * M_PI_NET * i / p->n_nodes - M_PI_NET / 2.0;
        p->nodes[i].cx = cx + r * cos(angle);
        p->nodes[i].cy = cy + r * sin(angle);
    }
}

/* ── Arrow head helper ── */
static void ink_net_arrow(FILE* f,
                          double x1, double y1,
                          double x2, double y2,
                          double node_r,
                          const char* color) {
    /* shorten end point to edge of target node */
    double dx  = x2 - x1;
    double dy  = y2 - y1;
    double len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return;
    double ux = dx / len;
    double uy = dy / len;
    double ex = x2 - ux * (node_r + INK_NET_ARROW_SIZE * 0.5);
    double ey = y2 - uy * (node_r + INK_NET_ARROW_SIZE * 0.5);

    /* arrow tip and base points */
    double ax  = ex - ux * INK_NET_ARROW_SIZE;
    double ay  = ey - uy * INK_NET_ARROW_SIZE;
    double px  = -uy * INK_NET_ARROW_SIZE * 0.4;
    double py  =  ux * INK_NET_ARROW_SIZE * 0.4;

    fprintf(f,
        "<polygon points=\"%.2f,%.2f %.2f,%.2f %.2f,%.2f\" "
        "fill=\"%s\"/>\n",
        ex, ey,
        ax + px, ay + py,
        ax - px, ay - py,
        color
    );
}

/* ── SVG save ── */
void ink_net_save(InkNetChart* p, const char* path) {
    ink_net_layout(p);

    /* find max weight for thickness scaling */
    double max_w = 0.0;
    for (int i = 0; i < p->n_edges; i++)
        if (p->edges[i].weight > max_w) max_w = p->edges[i].weight;
    int weighted = (max_w > 0.0);

    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n", path);
        exit(2);
    }

    int W = p->width;
    int H = p->height;

    /* SVG header */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title    { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-nodelbl  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; fill: white; font-weight: bold; }\n"
        "  .ink-edgelbl  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; fill: #333; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f,
        "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n",
        W, H
    );

    /* edges — drawn before nodes so nodes sit on top */
    for (int i = 0; i < p->n_edges; i++) {
        InkNetEdge* e  = &p->edges[i];
        int         fi = ink_net_find_node(p, e->from);
        int         ti = ink_net_find_node(p, e->to);
        if (fi < 0 || ti < 0) continue;

        InkNetNode* fn = &p->nodes[fi];
        InkNetNode* tn = &p->nodes[ti];

        /* stroke width: 1..5 scaled by weight */
        double sw = 1.5;
        if (weighted && max_w > 0.0)
            sw = 1.0 + (e->weight / max_w) * 4.0;

        /* shorten line so it doesn't overlap node circle */
        double dx  = tn->cx - fn->cx;
        double dy  = tn->cy - fn->cy;
        double len = sqrt(dx * dx + dy * dy);
        double ux  = (len > 1e-6) ? dx / len : 0;
        double uy  = (len > 1e-6) ? dy / len : 0;
        double r1  = INK_NET_NODE_R * fn->size;
        double r2  = INK_NET_NODE_R * tn->size;
        double x1  = fn->cx + ux * r1;
        double y1  = fn->cy + uy * r1;
        double x2  = tn->cx - ux * r2;
        double y2  = tn->cy - uy * r2;

        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
            "stroke=\"%s\" stroke-width=\"%.2f\" opacity=\"0.7\"/>\n",
            x1, y1, x2, y2, e->color, sw
        );

        /* arrowhead */
        if (p->directed)
            ink_net_arrow(f, fn->cx, fn->cy, tn->cx, tn->cy,
                          r2, e->color);

        /* edge weight label at midpoint */
        if (p->show_labels && weighted && e->weight > 0.0) {
            double mx = (fn->cx + tn->cx) / 2.0;
            double my = (fn->cy + tn->cy) / 2.0;
            /* white background rect */
            fprintf(f,
                "<rect x=\"%.2f\" y=\"%.2f\" width=\"28\" height=\"16\" "
                "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\" rx=\"3\"/>\n",
                mx - 14.0, my - 20.0
            );
            fprintf(f,
                "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                "dominant-baseline=\"middle\" class=\"ink-edgelbl\">%g</text>\n",
                mx, my - 12.0, e->weight
            );
        }
    }

    /* nodes */
    for (int i = 0; i < p->n_nodes; i++) {
        InkNetNode* n = &p->nodes[i];
        double r = INK_NET_NODE_R * n->size;

        /* circle */
        fprintf(f,
            "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"%.2f\" "
            "fill=\"%s\" stroke=\"white\" stroke-width=\"2\"/>\n",
            n->cx, n->cy, r, n->color
        );

        /* label inside node */
        fprintf(f,
            "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
            "dominant-baseline=\"middle\" class=\"ink-nodelbl\">%s</text>\n",
            n->cx, n->cy, n->label
        );
    }

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, INK_MARGIN_TOP - 15, p->title
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

/* ── Show ── */
void ink_net_show(InkNetChart* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_net_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── Mocha wrappers ── */
InkNetChart* ink_new_network_mocha(void)                              { return ink_new_network(); }
void ink_net_add_node_mocha(InkNetChart* p, const char* id, const char* label) { ink_net_add_node(p, id, label); }
void ink_net_add_edge_mocha(InkNetChart* p, const char* from, const char* to)  { ink_net_add_edge(p, from, to); }
void ink_net_add_edge_weight_mocha(InkNetChart* p, const char* from, const char* to, double w) { ink_net_add_edge_weight(p, from, to, w); }
void ink_net_set_node_color_mocha(InkNetChart* p, const char* id, const char* c)               { ink_net_set_node_color(p, id, c); }
void ink_net_set_node_size_mocha(InkNetChart* p, const char* id, double s)                     { ink_net_set_node_size(p, id, s); }
void ink_net_set_edge_color_mocha(InkNetChart* p, const char* from, const char* to, const char* c) { ink_net_set_edge_color(p, from, to, c); }
void ink_net_set_labels_mocha(InkNetChart* p, int8_t on)              { ink_net_set_labels(p, on); }
void ink_net_set_title_mocha(InkNetChart* p, const char* t)           { ink_net_set_title(p, t); }
void ink_net_set_directed_mocha(InkNetChart* p, int8_t on)            { ink_net_set_directed(p, on); }
void ink_net_save_mocha(InkNetChart* p, const char* path)             { ink_net_save(p, path); }
void ink_net_show_mocha(InkNetChart* p)                               { ink_net_show(p); }

/* ════════════════════════════════════════════════════════════
   mocha-ink  —  SankeyChart  (flow ribbons with Bezier curves)
   ════════════════════════════════════════════════════════════ */

#define INK_SK_MAX_NODES  64
#define INK_SK_MAX_FLOWS  256
#define INK_SK_NODE_W     15
#define INK_SK_PAD_X      120
#define INK_SK_PAD_Y      20

/* ── Flow ── */
typedef struct {
    char   src[64];
    char   dst[64];
    double value;
} InkSkFlow;

/* ── Node (computed) ── */
typedef struct {
    char   id[64];
    char   color[32];
    int    col;        /* assigned column */
    double total_in;
    double total_out;
    double x, y, h;   /* SVG position and height */
    double y_out_cur; /* current ribbon attachment cursor (out) */
    double y_in_cur;  /* current ribbon attachment cursor (in) */
} InkSkNode;

/* ── Chart ── */
typedef struct {
    InkSkNode nodes[INK_SK_MAX_NODES];
    int       n_nodes;
    InkSkFlow flows[INK_SK_MAX_FLOWS];
    int       n_flows;
    char      title[128];
    int       width;
    int       height;
} InkSkChart;

/* ── Constructor ── */
InkSkChart* ink_new_sankey(void) {
    InkSkChart* p = (InkSkChart*)malloc(sizeof(InkSkChart));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkSkChart));
    p->width  = INK_WIDTH;
    p->height = INK_HEIGHT;
    return p;
}

/* ── Node lookup / auto-create ── */
static int ink_sk_find_or_add(InkSkChart* p, const char* id) {
    for (int i = 0; i < p->n_nodes; i++)
        if (strcmp(p->nodes[i].id, id) == 0) return i;
    if (p->n_nodes >= INK_SK_MAX_NODES) {
        fprintf(stderr, "MochaWarning (mocha-ink): max sankey nodes reached\n");
        return 0;
    }
    int i = p->n_nodes++;
    strncpy(p->nodes[i].id,    id, 63);
    strncpy(p->nodes[i].color, INK_PALETTE[i % INK_MAX_SERIES], 31);
    p->nodes[i].col       = 0;
    p->nodes[i].total_in  = 0.0;
    p->nodes[i].total_out = 0.0;
    return i;
}

/* ── Add flow ── */
void ink_sk_add_flow(InkSkChart* p, const char* src,
                     const char* dst, double value) {
    if (p->n_flows >= INK_SK_MAX_FLOWS) {
        fprintf(stderr, "MochaWarning (mocha-ink): max flows reached\n");
        return;
    }
    ink_sk_find_or_add(p, src);
    ink_sk_find_or_add(p, dst);

    InkSkFlow* f = &p->flows[p->n_flows++];
    strncpy(f->src, src, 63);
    strncpy(f->dst, dst, 63);
    f->value = value;
}

/* ── Setters ── */
void ink_sk_set_title(InkSkChart* p, const char* t) {
    strncpy(p->title, t, 127);
}
void ink_sk_set_node_color(InkSkChart* p,
                           const char* id, const char* color) {
    int i = ink_sk_find_or_add(p, id);
    strncpy(p->nodes[i].color, color, 31);
}

/* ── Column layout (longest-path layering) ── */
static void ink_sk_assign_columns(InkSkChart* p) {
    /* iterative relaxation — repeat until stable */
    int changed = 1;
    while (changed) {
        changed = 0;
        for (int f = 0; f < p->n_flows; f++) {
            int si = -1, di = -1;
            for (int n = 0; n < p->n_nodes; n++) {
                if (strcmp(p->nodes[n].id, p->flows[f].src) == 0) si = n;
                if (strcmp(p->nodes[n].id, p->flows[f].dst) == 0) di = n;
            }
            if (si < 0 || di < 0) continue;
            if (p->nodes[di].col <= p->nodes[si].col) {
                p->nodes[di].col = p->nodes[si].col + 1;
                changed = 1;
            }
        }
    }
}

/* ── Compute node totals ── */
static void ink_sk_compute_totals(InkSkChart* p) {
    for (int f = 0; f < p->n_flows; f++) {
        for (int n = 0; n < p->n_nodes; n++) {
            if (strcmp(p->nodes[n].id, p->flows[f].src) == 0)
                p->nodes[n].total_out += p->flows[f].value;
            if (strcmp(p->nodes[n].id, p->flows[f].dst) == 0)
                p->nodes[n].total_in  += p->flows[f].value;
        }
    }
}

/* ── Assign SVG positions ── */
static void ink_sk_layout(InkSkChart* p) {
    int W  = p->width;
    int H  = p->height;
    int mt = INK_MARGIN_TOP;
    int mb = INK_MARGIN_BOTTOM;
    int ml = INK_MARGIN_LEFT;
    int mr = INK_MARGIN_RIGHT;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* find max column */
    int max_col = 0;
    for (int i = 0; i < p->n_nodes; i++)
        if (p->nodes[i].col > max_col) max_col = p->nodes[i].col;
    int n_cols = max_col + 1;

    /* find max total flow per column for height scaling */
    double col_total[INK_SK_MAX_NODES];
    memset(col_total, 0, sizeof(col_total));
    int    col_count[INK_SK_MAX_NODES];
    memset(col_count, 0, sizeof(col_count));

    for (int i = 0; i < p->n_nodes; i++) {
        int c = p->nodes[i].col;
        double flow = p->nodes[i].total_out > p->nodes[i].total_in
                      ? p->nodes[i].total_out : p->nodes[i].total_in;
        col_total[c] += flow;
        col_count[c]++;
    }

    /* find the column with the highest total for scale reference */
    double max_col_total = 0.0;
    for (int c = 0; c < n_cols; c++)
        if (col_total[c] > max_col_total) max_col_total = col_total[c];
    if (max_col_total == 0.0) max_col_total = 1.0;

    /* x position per column */
    double col_x[INK_SK_MAX_NODES];
    for (int c = 0; c < n_cols; c++)
        col_x[c] = ml + (n_cols == 1 ? pw / 2.0
                         : (double)c / (n_cols - 1) * pw);

    /* available height for nodes (subtract gaps) */
    double usable_h = (double)ph * 0.55;

    /* assign y and h per node within each column */
    for (int c = 0; c < n_cols; c++) {
        /* collect nodes in this column */
        int   idx[INK_SK_MAX_NODES];
        int   cnt = 0;
        for (int i = 0; i < p->n_nodes; i++)
            if (p->nodes[i].col == c) idx[cnt++] = i;
        if (cnt == 0) continue;

        /* max node height = 60% of available height divided by nodes in column */
        double scale = (usable_h * 0.5) / max_col_total;
        double gap   = (cnt > 1)
                       ? (ph - usable_h) / (cnt - 1)
                       : 0.0;
        if (gap < 30.0) gap = 30.0;

        double y_cur = mt;
        for (int k = 0; k < cnt; k++) {
            int    i    = idx[k];
            double flow = p->nodes[i].total_out > p->nodes[i].total_in
                          ? p->nodes[i].total_out : p->nodes[i].total_in;
            double h    = flow * scale;
            if (h < 12.0) h = 12.0;

            p->nodes[i].x        = col_x[c];
            p->nodes[i].y        = y_cur;
            p->nodes[i].h        = h;
            p->nodes[i].y_out_cur = y_cur;
            p->nodes[i].y_in_cur  = y_cur;
            y_cur += h + gap;
        }
    }
}

/* ── SVG save ── */
void ink_sk_save(InkSkChart* p, const char* path) {
    ink_sk_assign_columns(p);
    ink_sk_compute_totals(p);
    ink_sk_layout(p);

    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): cannot open '%s'\n", path);
        exit(2);
    }

    int W = p->width;
    int H = p->height;

    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title   { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 18px; font-weight: bold; }\n"
        "  .ink-sklbl   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 12px; fill: white; font-weight: bold; }\n"
        "  .ink-skval   { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #444; }\n"
        "  .ink-flowlbl { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 11px; fill: #333; }\n"
        "</style>\n",
        W, H
    );

    /* background */
    fprintf(f,
        "<rect width=\"%d\" height=\"%d\" fill=\"#FAFAFA\" rx=\"8\"/>\n",
        W, H
    );

    /* ── draw ribbons ── */
    for (int fi = 0; fi < p->n_flows; fi++) {
        InkSkFlow* fl = &p->flows[fi];

        /* find src and dst nodes */
        int si = -1, di = -1;
        for (int n = 0; n < p->n_nodes; n++) {
            if (strcmp(p->nodes[n].id, fl->src) == 0) si = n;
            if (strcmp(p->nodes[n].id, fl->dst) == 0) di = n;
        }
        if (si < 0 || di < 0) continue;

        InkSkNode* sn = &p->nodes[si];
        InkSkNode* dn = &p->nodes[di];

        /* flow max for scaling ribbon thickness */
        double sflow = sn->total_out > 0.0 ? sn->total_out : 1.0;
        double dflow = dn->total_in  > 0.0 ? dn->total_in  : 1.0;
        double sw    = (fl->value / sflow) * sn->h;
        double dw    = (fl->value / dflow) * dn->h;

        /* attachment points on src (right edge) and dst (left edge) */
        double x1  = sn->x + INK_SK_NODE_W;
        double y1t = sn->y_out_cur;
        double y1b = sn->y_out_cur + sw;
        double x2  = dn->x;
        double y2t = dn->y_in_cur;
        double y2b = dn->y_in_cur + dw;

        sn->y_out_cur += sw;
        dn->y_in_cur  += dw;

        /* Bezier control points (horizontal pull) */
        double cx1 = x1 + (x2 - x1) * 0.5;
        double cx2 = x2 - (x2 - x1) * 0.5;

        /* ribbon as a closed path: top curve + bottom curve */
        fprintf(f,
            "<path d=\""
            "M %.2f,%.2f "
            "C %.2f,%.2f %.2f,%.2f %.2f,%.2f "
            "L %.2f,%.2f "
            "C %.2f,%.2f %.2f,%.2f %.2f,%.2f "
            "Z\" "
            "fill=\"%s\" opacity=\"0.45\"/>\n",
            x1, y1t,
            cx1, y1t, cx2, y2t, x2, y2t,
            x2, y2b,
            cx2, y2b, cx1, y1b, x1, y1b,
            sn->color
        );

        /* flow value label above ribbon midpoint */
        double mx  = (x1 + x2) / 2.0;
        double myt = (y1t + y2t) / 2.0;
        fprintf(f,
            "<rect x=\"%.2f\" y=\"%.2f\" width=\"32\" height=\"16\" "
            "fill=\"white\" stroke=\"#DDDDDD\" stroke-width=\"1\" rx=\"3\"/>\n",
            mx - 16.0, myt - 18.0
        );
        fprintf(f,
            "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
            "dominant-baseline=\"middle\" class=\"ink-flowlbl\">%g</text>\n",
            mx, myt - 10.0, fl->value
        );
    }

    /* ── draw nodes ── */
    for (int i = 0; i < p->n_nodes; i++) {
        InkSkNode* n = &p->nodes[i];

        /* node rect */
        fprintf(f,
            "<rect x=\"%.2f\" y=\"%.2f\" width=\"%d\" height=\"%.2f\" "
            "fill=\"%s\" rx=\"4\"/>\n",
            n->x, n->y, INK_SK_NODE_W, n->h, n->color
        );

        /* label: inside if tall enough, below otherwise */
        double label_y;
        const char* cls;
        if (n->h >= 28.0) {
            label_y = n->y + n->h / 2.0;
            cls     = "ink-sklbl";
            /* id label */
            fprintf(f,
                "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                "dominant-baseline=\"middle\" class=\"%s\">%s</text>\n",
                n->x + INK_SK_NODE_W / 2.0, label_y - 7.0, cls, n->id
            );
            /* value label */
            fprintf(f,
                "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                "dominant-baseline=\"middle\" class=\"%s\" "
                "font-size=\"10px\">%g</text>\n",
                n->x + INK_SK_NODE_W / 2.0, label_y + 7.0,
                cls,
                n->total_in > n->total_out ? n->total_in : n->total_out
            );
        } else {
            /* below */
            fprintf(f,
                "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                "class=\"ink-skval\">%s</text>\n",
                n->x + INK_SK_NODE_W / 2.0, n->y + n->h + 13.0, n->id
            );
            fprintf(f,
                "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                "class=\"ink-skval\">%g</text>\n",
                n->x + INK_SK_NODE_W / 2.0, n->y + n->h + 26.0,
                n->total_in > n->total_out ? n->total_in : n->total_out
            );
        }
    }

    /* title */
    if (p->title[0])
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            W / 2, INK_MARGIN_TOP - 15, p->title
        );

    fprintf(f, "</svg>\n");
    fclose(f);
}

/* ── Show ── */
void ink_sk_show(InkSkChart* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_sk_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ── Mocha wrappers ── */
InkSkChart* ink_new_sankey_mocha(void)                                          { return ink_new_sankey(); }
void ink_sk_add_flow_mocha(InkSkChart* p, const char* src, const char* dst, double v) { ink_sk_add_flow(p, src, dst, v); }
void ink_sk_set_node_color_mocha(InkSkChart* p, const char* id, const char* c) { ink_sk_set_node_color(p, id, c); }
void ink_sk_set_title_mocha(InkSkChart* p, const char* t)                      { ink_sk_set_title(p, t); }
void ink_sk_save_mocha(InkSkChart* p, const char* path)                        { ink_sk_save(p, path); }
void ink_sk_show_mocha(InkSkChart* p)                                          { ink_sk_show(p); }

/* ════════════════════════════════════════════════════════════
   mocha-ink  —  SkewTPlot
   Skew-T Log-P diagram for atmospheric sounding visualization
   ════════════════════════════════════════════════════════════ */

/* ── Physical constants ── */
#define ST_RD       287.05    /* gas constant dry air J/kg/K       */
#define ST_CPD      1005.7    /* specific heat dry air J/kg/K      */
#define ST_LV       2.501e6   /* latent heat vaporization J/kg     */
#define ST_EPS      0.622     /* Rd/Rv                             */
#define ST_KAPPA    0.2857    /* Rd/Cpd                            */

/* ── Diagram bounds ── */
#define ST_P_BOT    1050.0    /* hPa — bottom of diagram           */
#define ST_P_TOP    100.0     /* hPa — top of diagram              */
#define ST_T_MIN   -60.0      /* °C  — left edge at 1000 hPa       */
#define ST_T_MAX    50.0      /* °C  — right edge at 1000 hPa      */
#define ST_SKEW     0.4       /* skew factor (1.0 = 45°)           */

/* ── Layout ── */
#define ST_WIDTH    900
#define ST_HEIGHT   800
#define ST_ML       80        /* margin left  (y-axis labels)      */
#define ST_MR       120       /* margin right (wind barbs)         */
#define ST_MT       50        /* margin top                        */
#define ST_MB       60        /* margin bottom                     */

#define ST_MAX_LEVELS  512

/* ── Sounding data ── */
typedef struct {
    double pressure[ST_MAX_LEVELS];   /* hPa                       */
    double temp[ST_MAX_LEVELS];       /* °C                        */
    double dewpoint[ST_MAX_LEVELS];   /* °C                        */
    double wind_speed[ST_MAX_LEVELS]; /* km/h — converted to knots */
    double wind_dir[ST_MAX_LEVELS];   /* degrees                   */
    int    n;
} InkSTSounding;

/* ── Plot struct ── */
typedef struct {
    InkSTSounding sounding;
    char  title[128];
    int   show_dry_adiabats;
    int   show_moist_adiabats;
    int   show_mixing_ratios;
    int   width;
    int   height;
} InkSTPlot;

/* ════════════════════════════════════════════════════════════
   Coordinate transforms
   ════════════════════════════════════════════════════════════ */

/* pressure → normalized y [0=bottom, 1=top] */
static double st_p_to_ynorm(double p) {
    return log(ST_P_BOT / p) / log(ST_P_BOT / ST_P_TOP);
}

/* normalized y → pixel y */
static double st_ynorm_to_px(double yn, int mt, int ph) {
    /* yn=0 is bottom (high pressure), yn=1 is top (low pressure) */
    return mt + ph * (1.0 - yn);
}

/* temperature + pressure → pixel x (with skew) */
static double st_t_to_px(double t_c, double p, int ml, int pw) {
    double t_range = ST_T_MAX - ST_T_MIN;
    double t_norm  = (t_c - ST_T_MIN) / t_range;
    double yn      = st_p_to_ynorm(p);
    /* skew: shift x rightward as pressure decreases (yn increases) */
    double x_norm  = t_norm + ST_SKEW * yn;
    return ml + x_norm * pw;
}

/* convenience: pressure → pixel y directly */
static double st_p_to_py(double p, int mt, int ph) {
    return st_ynorm_to_px(st_p_to_ynorm(p), mt, ph);
}

/* ════════════════════════════════════════════════════════════
   Constructor
   ════════════════════════════════════════════════════════════ */

static InkSTPlot* ink_st_new(
    double* pressure, double* temp, double* dewpoint,
    double* wind_speed, double* wind_dir, int n)
{
    InkSTPlot* p = (InkSTPlot*)malloc(sizeof(InkSTPlot));
    if (!p) {
        fprintf(stderr, "MochaRuntimeError (mocha-ink): out of memory\n");
        exit(2);
    }
    memset(p, 0, sizeof(InkSTPlot));
    p->width              = ST_WIDTH;
    p->height             = ST_HEIGHT;
    p->show_dry_adiabats  = 1;
    p->show_moist_adiabats = 1;
    p->show_mixing_ratios = 0;
    p->title[0]           = '\0';

    int count = n < ST_MAX_LEVELS ? n : ST_MAX_LEVELS;
    for (int i = 0; i < count; i++) {
        p->sounding.pressure[i]   = pressure[i];
        p->sounding.temp[i]       = temp[i];
        p->sounding.dewpoint[i]   = dewpoint[i];
        p->sounding.wind_speed[i] = wind_speed[i];
        p->sounding.wind_dir[i]   = wind_dir[i];
    }
    p->sounding.n = count;
    return p;
}

/* ── Mocha-facing constructor ── */
InkSTPlot* ink_new_skewt_mocha(
    MochaArray* pressure, MochaArray* temp, MochaArray* dewpoint,
    MochaArray* wind_speed, MochaArray* wind_dir)
{
    int n = pressure->length;
    if (temp->length       < n) n = temp->length;
    if (dewpoint->length   < n) n = dewpoint->length;
    if (wind_speed->length < n) n = wind_speed->length;
    if (wind_dir->length   < n) n = wind_dir->length;

    double* pr = (double*)malloc(n * sizeof(double));
    double* tc = (double*)malloc(n * sizeof(double));
    double* td = (double*)malloc(n * sizeof(double));
    double* ws = (double*)malloc(n * sizeof(double));
    double* wd = (double*)malloc(n * sizeof(double));

    for (int i = 0; i < n; i++) {
        mocha_array_get(pressure,   i, &pr[i]);
        mocha_array_get(temp,       i, &tc[i]);
        mocha_array_get(dewpoint,   i, &td[i]);
        mocha_array_get(wind_speed, i, &ws[i]);
        mocha_array_get(wind_dir,   i, &wd[i]);
    }

    InkSTPlot* p = ink_st_new(pr, tc, td, ws, wd, n);
    free(pr); free(tc); free(td); free(ws); free(wd);
    return p;
}

/* ── Setters ── */
void ink_st_set_title(InkSTPlot* p, const char* t) {
    strncpy(p->title, t, 127);
}
void ink_st_show_dry_adiabats(InkSTPlot* p)   { p->show_dry_adiabats   = 1; }
void ink_st_show_moist_adiabats(InkSTPlot* p) { p->show_moist_adiabats = 1; }
void ink_st_show_mixing_ratios(InkSTPlot* p)  { p->show_mixing_ratios  = 1; }

/* ════════════════════════════════════════════════════════════
   Thermodynamic helpers
   ════════════════════════════════════════════════════════════ */

/* saturation vapour pressure (hPa) — Bolton 1980 formula */
static double st_esat(double t_c) {
    return 6.112 * exp(17.67 * t_c / (t_c + 243.5));
}

/* saturation mixing ratio (kg/kg) */
static double st_rs(double t_c, double p_hpa) {
    double es = st_esat(t_c);
    return ST_EPS * es / (p_hpa - es);
}

/* dry adiabat: T at pressure p given potential temp theta (K) */
static double st_dry_adiabat_t(double theta_k, double p_hpa) {
    return theta_k * pow(p_hpa / 1000.0, ST_KAPPA) - 273.15;
}

/* moist adiabat: integrate dT/dP downward from (t0_c, p0_hpa)
   returns T in °C at pressure p_hpa
   uses MetPy-verified formula: dT/dP = (1/P)*(Rd*T + Lv*rs) / (Cpd + Lv²*rs*ε/(Rd*T²)) */
static double st_moist_adiabat_t(double t0_c, double p0_hpa, double p_hpa) {
    double t_k = t0_c + 273.15;
    double p   = p0_hpa;
    /* step size: negative when going up (decreasing p) */
    double dp  = (p_hpa > p0_hpa) ? 5.0 : -5.0;
    int    steps = (int)(fabs(p_hpa - p0_hpa) / fabs(dp)) + 1;

    for (int i = 0; i < steps; i++) {
        double p_next = p + dp;
        if (dp < 0 && p_next < p_hpa) p_next = p_hpa;
        if (dp > 0 && p_next > p_hpa) p_next = p_hpa;

        double rs     = st_rs(t_k - 273.15, p);
        double numer  = ST_RD * t_k + ST_LV * rs;
        double denom  = ST_CPD + (ST_LV * ST_LV * rs * ST_EPS) / (ST_RD * t_k * t_k);
        double dtdp   = (1.0 / p) * (numer / denom);
        t_k += dtdp * (p_next - p);
        p    = p_next;
        if (p == p_hpa) break;
    }
    return t_k - 273.15;
}

/* ════════════════════════════════════════════════════════════
   Background drawing
   ════════════════════════════════════════════════════════════ */

static void ink_st_draw_background(FILE* f, InkSTPlot* p,
                                   int ml, int mr, int mt, int mb)
{
    int W  = p->width;
    int H  = p->height;
    int pw = W - ml - mr;
    int ph = H - mt - mb;

    /* ── SVG header ── */
    fprintf(f,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg width=\"%d\" height=\"%d\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        "<style>\n"
        "  .ink-title { font-family: Consolas, Verdana, sans-serif; "
        "font-size: 16px; font-weight: bold; }\n"
        "  .ink-tick  { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 10px; fill: #555; }\n"
        "  .ink-plabel { font-family: Consolas, 'Courier New', monospace; "
        "font-size: 10px; fill: #333; }\n"
        "</style>\n", W, H);

    /* background rect */
    fprintf(f,
        "<rect width=\"%d\" height=\"%d\" fill=\"#F8F8F8\" rx=\"8\"/>\n", W, H);

    /* plot area */
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"white\" stroke=\"#CCCCCC\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph);

    /* clip path */
    fprintf(f,
        "<clipPath id=\"st-clip\">"
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\"/>"
        "</clipPath>\n", ml, mt, pw, ph);

    /* ── Isobars ── */
    double isobars[] = {1000.0, 925.0, 850.0, 700.0, 500.0,
                        400.0,  300.0, 200.0, 150.0, 100.0};
    int n_isobars = 10;
    for (int i = 0; i < n_isobars; i++) {
        double py = st_p_to_py(isobars[i], mt, ph);
        fprintf(f,
            "<line x1=\"%d\" y1=\"%.2f\" x2=\"%d\" y2=\"%.2f\" "
            "stroke=\"#BBBBBB\" stroke-width=\"0.8\" "
            "clip-path=\"url(#st-clip)\"/>\n",
            ml, py, ml + pw, py);
        /* pressure label on left */
        fprintf(f,
            "<text x=\"%d\" y=\"%.2f\" text-anchor=\"end\" "
            "dominant-baseline=\"middle\" class=\"ink-plabel\">%.0f</text>\n",
            ml - 5, py, isobars[i]);
    }

    /* ── Isotherms (skewed, every 10°C) ── */
    for (double t = -120.0; t <= 60.0; t += 10.0) {
        /* isotherm: same temperature at all pressures, skewed */
        double x_bot = st_t_to_px(t, ST_P_BOT, ml, pw);
        double y_bot = st_p_to_py(ST_P_BOT, mt, ph);
        double x_top = st_t_to_px(t, ST_P_TOP, ml, pw);
        double y_top = st_p_to_py(ST_P_TOP, mt, ph);

        /* highlight 0°C isotherm */
        const char* stroke = (t == 0.0) ? "#4444CC" : "#DDDDDD";
        double      width  = (t == 0.0) ? 1.2 : 0.7;

        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
            "stroke=\"%s\" stroke-width=\"%.1f\" "
            "clip-path=\"url(#st-clip)\"/>\n",
            x_bot, y_bot, x_top, y_top, stroke, width);

        /* temperature label at bottom */
        if (x_bot >= ml && x_bot <= ml + pw) {
            fprintf(f,
                "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
                "class=\"ink-tick\">%.0f</text>\n",
                x_bot, mt + ph + 14, t);
        }
    }

    /* ── Dry adiabats ── */
    if (p->show_dry_adiabats) {
        /* theta values in °C (= theta_K - 273.15), every 10°C */
        double thetas[] = {
            -30,-20,-10, 0, 10, 20, 30, 40, 50,
             60, 70, 80, 90,100,120,140,160,180
        };
        int n_theta = 18;
        int steps   = 80;
        double dp   = (ST_P_BOT - ST_P_TOP) / steps;

        for (int ti = 0; ti < n_theta; ti++) {
            double theta_k = thetas[ti] + 273.15;
            fprintf(f, "<polyline points=\"");
            for (int si = 0; si <= steps; si++) {
                double pr  = ST_P_BOT - si * dp;
                double t_c = st_dry_adiabat_t(theta_k, pr);
                double px  = st_t_to_px(t_c, pr, ml, pw);
                double py  = st_p_to_py(pr, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f,
                "\" fill=\"none\" stroke=\"#CC7722\" stroke-width=\"0.6\" "
                "opacity=\"0.5\" clip-path=\"url(#st-clip)\"/>\n");
        }
    }

    /* ── Moist adiabats ── */
    if (p->show_moist_adiabats) {
        /* starting temperatures at 1000 hPa, every 4°C */
        double t_starts[] = {
            -20,-16,-12,-8,-4, 0, 4, 8,
             12, 16, 20, 24, 28, 32, 36
        };
        int n_moist = 15;
        int steps   = 80;
        double dp   = (ST_P_BOT - ST_P_TOP) / steps;

        for (int mi = 0; mi < n_moist; mi++) {
            double t0 = t_starts[mi];
            fprintf(f, "<polyline points=\"");
            for (int si = 0; si <= steps; si++) {
                double pr  = ST_P_BOT - si * dp;
                double t_c = st_moist_adiabat_t(t0, ST_P_BOT, pr);
                double px  = st_t_to_px(t_c, pr, ml, pw);
                double py  = st_p_to_py(pr, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f,
                "\" fill=\"none\" stroke=\"#228844\" stroke-width=\"0.6\" "
                "opacity=\"0.5\" stroke-dasharray=\"4,3\" "
                "clip-path=\"url(#st-clip)\"/>\n");
        }
    }

    /* ── Mixing ratio lines ── */
    if (p->show_mixing_ratios) {
        /* g/kg values */
        double ws_lines[] = {0.4, 1.0, 2.0, 4.0, 7.0, 10.0, 16.0, 20.0};
        int    n_ws       = 8;
        int    steps      = 60;
        double dp         = (ST_P_BOT - 400.0) / steps; /* only below 400 hPa */

        for (int wi = 0; wi < n_ws; wi++) {
            double ws_kgkg = ws_lines[wi] / 1000.0;
            fprintf(f, "<polyline points=\"");
            for (int si = 0; si <= steps; si++) {
                double pr  = ST_P_BOT - si * dp;
                /* invert rs formula: es = ws*p/(eps+ws), then Bolton */
                double es  = ws_kgkg * pr / (ST_EPS + ws_kgkg);
                double t_c = 243.5 * log(es / 6.112) /
                             (17.67 - log(es / 6.112));
                double px  = st_t_to_px(t_c, pr, ml, pw);
                double py  = st_p_to_py(pr, mt, ph);
                fprintf(f, "%.2f,%.2f ", px, py);
            }
            fprintf(f,
                "\" fill=\"none\" stroke=\"#008888\" stroke-width=\"0.6\" "
                "opacity=\"0.6\" stroke-dasharray=\"2,4\" "
                "clip-path=\"url(#st-clip)\"/>\n");

            /* label at bottom */
            double pr_label = ST_P_BOT;
            double ws_kgkg_ = ws_lines[wi] / 1000.0;
            double es_l     = ws_kgkg_ * pr_label / (ST_EPS + ws_kgkg_);
            double t_label  = 243.5 * log(es_l / 6.112) /
                              (17.67 - log(es_l / 6.112));
            double px_label = st_t_to_px(t_label, pr_label, ml, pw);
            double py_label = st_p_to_py(pr_label, mt, ph);
            if (px_label >= ml && px_label <= ml + pw) {
                fprintf(f,
                    "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
                    "font-size=\"9\" fill=\"#008888\">%.1f</text>\n",
                    px_label, py_label - 4, ws_lines[wi]);
            }
        }
    }

    /* ── Axis border ── */
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" "
        "fill=\"none\" stroke=\"#999\" stroke-width=\"1\"/>\n",
        ml, mt, pw, ph);

    /* ── Title ── */
    if (p->title[0]) {
        fprintf(f,
            "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
            "class=\"ink-title\">%s</text>\n",
            ml + pw / 2, mt - 20, p->title);
    }

    /* ── Axis labels ── */
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
        "font-family=\"Consolas,sans-serif\" font-size=\"11\" fill=\"#444\">"
        "Temperature (°C)</text>\n",
        ml + pw / 2, mt + ph + 35);

    fprintf(f,
        "<text x=\"%d\" y=\"%d\" text-anchor=\"middle\" "
        "transform=\"rotate(-90,%d,%d)\" "
        "font-family=\"Consolas,sans-serif\" font-size=\"11\" fill=\"#444\">"
        "Pressure (hPa)</text>\n",
        ml - 55, mt + ph / 2,
        ml - 55, mt + ph / 2);
}

/* ════════════════════════════════════════════════════════════
   Sounding drawing
   ════════════════════════════════════════════════════════════ */

static void ink_st_draw_sounding(FILE* f, InkSTPlot* p,
                                  int ml, int mr, int mt, int mb)
{
    int W  = p->width;
    int H  = p->height;
    int pw = W - ml - mr;
    int ph = H - mt - mb;
    InkSTSounding* s = &p->sounding;

    /* ── Temperature profile (red) ── */
    fprintf(f, "<polyline points=\"");
    for (int i = 0; i < s->n; i++) {
        if (s->pressure[i] < ST_P_TOP || s->pressure[i] > ST_P_BOT) continue;
        double px = st_t_to_px(s->temp[i], s->pressure[i], ml, pw);
        double py = st_p_to_py(s->pressure[i], mt, ph);
        fprintf(f, "%.2f,%.2f ", px, py);
    }
    fprintf(f,
        "\" fill=\"none\" stroke=\"#CC2222\" stroke-width=\"2.5\" "
        "stroke-linejoin=\"round\" clip-path=\"url(#st-clip)\"/>\n");

    /* ── Dewpoint profile (green) ── */
    fprintf(f, "<polyline points=\"");
    for (int i = 0; i < s->n; i++) {
        if (s->pressure[i] < ST_P_TOP || s->pressure[i] > ST_P_BOT) continue;
        double px = st_t_to_px(s->dewpoint[i], s->pressure[i], ml, pw);
        double py = st_p_to_py(s->pressure[i], mt, ph);
        fprintf(f, "%.2f,%.2f ", px, py);
    }
    fprintf(f,
        "\" fill=\"none\" stroke=\"#228822\" stroke-width=\"2.5\" "
        "stroke-linejoin=\"round\" clip-path=\"url(#st-clip)\"/>\n");

    /* ── LCL marker ── */
    /* find approximate LCL: where temp ~ dewpoint along dry adiabat
       use simple approximation: LCL pressure from surface values */
    double t_sfc  = s->temp[0];
    double td_sfc = s->dewpoint[0];
    double p_sfc  = s->pressure[0];

    /* Bolton 1980 LCL approximation:
       T_lcl = 1 / (1/(Td - 56) + ln(T/Td)/800) + 56  (K)
       where T, Td in Kelvin */
    double T_k  = t_sfc  + 273.15;
    double Td_k = td_sfc + 273.15;
    double T_lcl_k = 1.0 / (1.0 / (Td_k - 56.0) +
                     log(T_k / Td_k) / 800.0) + 56.0;
    /* LCL pressure: p_lcl = p_sfc * (T_lcl/T)^(Cp/Rd) */
    double p_lcl = p_sfc * pow(T_lcl_k / T_k, ST_CPD / ST_RD);
    double t_lcl = T_lcl_k - 273.15;

    if (p_lcl >= ST_P_TOP && p_lcl <= ST_P_BOT) {
        double lcl_px = st_t_to_px(t_lcl, p_lcl, ml, pw);
        double lcl_py = st_p_to_py(p_lcl, mt, ph);
        /* diamond marker */
        fprintf(f,
            "<polygon points=\"%.2f,%.2f %.2f,%.2f %.2f,%.2f %.2f,%.2f\" "
            "fill=\"#8800CC\" opacity=\"0.85\" "
            "clip-path=\"url(#st-clip)\"/>\n",
            lcl_px,     lcl_py - 6,
            lcl_px + 5, lcl_py,
            lcl_px,     lcl_py + 6,
            lcl_px - 5, lcl_py);
        fprintf(f,
            "<text x=\"%.2f\" y=\"%.2f\" font-size=\"9\" "
            "fill=\"#8800CC\" clip-path=\"url(#st-clip)\">LCL</text>\n",
            lcl_px + 8, lcl_py + 3);
    }

    /* ── Legend ── */
    int lx = ml + pw - 110;
    int ly = mt + 12;
    fprintf(f,
        "<rect x=\"%d\" y=\"%d\" width=\"105\" height=\"52\" "
        "fill=\"white\" stroke=\"#DDD\" stroke-width=\"1\" "
        "rx=\"3\" opacity=\"0.9\"/>\n", lx, ly);
    /* temp swatch */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#CC2222\" stroke-width=\"2.5\"/>\n",
        lx + 6, ly + 14, lx + 22, ly + 14);
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" font-size=\"11\" "
        "font-family=\"Consolas,sans-serif\" fill=\"#333\">Temp</text>\n",
        lx + 28, ly + 18);
    /* dewpoint swatch */
    fprintf(f,
        "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" "
        "stroke=\"#228822\" stroke-width=\"2.5\"/>\n",
        lx + 6, ly + 32, lx + 22, ly + 32);
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" font-size=\"11\" "
        "font-family=\"Consolas,sans-serif\" fill=\"#333\">Dewpoint</text>\n",
        lx + 28, ly + 36);
    /* LCL swatch */
    fprintf(f,
        "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" fill=\"#8800CC\"/>\n",
        lx + 14, ly + 44,
        lx + 19, ly + 49,
        lx + 14, ly + 54,
        lx + 9,  ly + 49);
    fprintf(f,
        "<text x=\"%d\" y=\"%d\" font-size=\"11\" "
        "font-family=\"Consolas,sans-serif\" fill=\"#333\">LCL</text>\n",
        lx + 28, ly + 53);
}

/* ════════════════════════════════════════════════════════════
   Wind barb drawing
   ════════════════════════════════════════════════════════════ */

/* draw one wind barb at pixel position (cx, cy)
   speed_knots: wind speed in knots
   dir_deg: meteorological direction (from, clockwise from north) */
static void ink_st_draw_barb(FILE* f, double cx, double cy,
                              double speed_knots, double dir_deg)
{
    /* calm: draw circle only */
    if (speed_knots < 2.5) {
        fprintf(f,
            "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"4\" "
            "fill=\"none\" stroke=\"#333\" stroke-width=\"1\"/>\n",
            cx, cy);
        return;
    }

    /* meteorological convention: dir is where wind comes FROM
       stem points INTO the wind (toward origin)
       in SVG: north=up, angle 0=north, clockwise
       convert to SVG angle: SVG 0=right, so subtract 90 */
    double angle_rad = (dir_deg - 180.0) * M_PI_NET / 180.0;
    double stem_len  = 22.0;
    double barb_len  = 10.0;
    double barb_gap  = 4.0;

    /* stem end point (tip of barbs) */
    double sx = cx + stem_len * sin(angle_rad);
    double sy = cy - stem_len * cos(angle_rad);

    /* draw stem */
    fprintf(f,
        "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
        "stroke=\"#333\" stroke-width=\"1.2\"/>\n",
        cx, cy, sx, sy);

    /* perpendicular direction for barbs (to the left of stem) */
    double perp_rad = angle_rad - M_PI_NET / 2.0;
    double pbx = barb_len * sin(perp_rad);
    double pby = -barb_len * cos(perp_rad);

    /* round to nearest 5 knots */
    int spd = (int)(speed_knots + 2.5);

    int pennants  = spd / 50;  spd %= 50;
    int full_barbs = spd / 10; spd %= 10;
    int half_barbs = spd / 5;

    /* position along stem from tip outward */
    double pos = 0.0;

    /* ── Pennants (filled triangles, 50 kt each) ── */
    for (int i = 0; i < pennants; i++) {
        double b1x = sx - pos       * sin(angle_rad);
        double b1y = sy + pos       * cos(angle_rad);
        double b2x = sx - (pos + barb_gap * 1.5) * sin(angle_rad);
        double b2y = sy + (pos + barb_gap * 1.5) * cos(angle_rad);
        fprintf(f,
            "<polygon points=\"%.2f,%.2f %.2f,%.2f %.2f,%.2f\" "
            "fill=\"#333\" stroke=\"#333\" stroke-width=\"0.5\"/>\n",
            b1x, b1y,
            b2x, b2y,
            b1x + pbx, b1y + pby);
        pos += barb_gap * 1.5 + 1.0;
    }

    /* ── Full barbs (10 kt each) ── */
    for (int i = 0; i < full_barbs; i++) {
        double bx = sx - pos * sin(angle_rad);
        double by = sy + pos * cos(angle_rad);
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
            "stroke=\"#333\" stroke-width=\"1.2\"/>\n",
            bx, by, bx + pbx, by + pby);
        pos += barb_gap;
    }

    /* ── Half barbs (5 kt each) ── */
    for (int i = 0; i < half_barbs; i++) {
        double bx = sx - pos * sin(angle_rad);
        double by = sy + pos * cos(angle_rad);
        fprintf(f,
            "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" "
            "stroke=\"#333\" stroke-width=\"1.2\"/>\n",
            bx, by, bx + pbx * 0.5, by + pby * 0.5);
        pos += barb_gap;
    }
}

static void ink_st_draw_barbs(FILE* f, InkSTPlot* p,
                               int ml, int mr, int mt, int mb)
{
    int W  = p->width;
    int H  = p->height;
    int ph = H - mt - mb;

    /* barbs drawn in right margin, centered */
    double barb_x = W - mr + mr / 2.0;

    /* km/h to knots */
    double kmh_to_kt = 0.539957;

    /* draw at standard pressure levels only to avoid crowding */
    double levels[] = {1000,925,850,700,500,400,300,250,200,150,100};
    int    n_levels = 11;

    InkSTSounding* s = &p->sounding;

    for (int li = 0; li < n_levels; li++) {
        double target_p = levels[li];
        if (target_p < ST_P_TOP || target_p > ST_P_BOT) continue;

        /* find closest sounding level */
        int    best_idx  = -1;
        double best_dist = 999.0;
        for (int i = 0; i < s->n; i++) {
            double dist = fabs(s->pressure[i] - target_p);
            if (dist < best_dist) {
                best_dist = dist;
                best_idx  = i;
            }
        }

        /* only draw if close enough to the standard level */
        if (best_idx < 0 || best_dist > 30.0) continue;

        double barb_y     = st_p_to_py(s->pressure[best_idx], mt, ph);
        double spd_knots  = s->wind_speed[best_idx] * kmh_to_kt;
        double dir        = s->wind_dir[best_idx];

        ink_st_draw_barb(f, barb_x, barb_y, spd_knots, dir);

        /* pressure label next to barb */
        fprintf(f,
            "<text x=\"%.2f\" y=\"%.2f\" text-anchor=\"middle\" "
            "font-size=\"8\" font-family=\"Consolas,sans-serif\" "
            "fill=\"#888\">%.0f</text>\n",
            barb_x, barb_y + 14, target_p);
    }

    /* column header */
    fprintf(f,
        "<text x=\"%.2f\" y=\"%d\" text-anchor=\"middle\" "
        "font-size=\"9\" font-family=\"Consolas,sans-serif\" "
        "fill=\"#555\">Wind</text>\n",
        barb_x, mt - 8);
}

/* ════════════════════════════════════════════════════════════
   Save — assembles background + sounding + barbs
   ════════════════════════════════════════════════════════════ */

void ink_st_save(InkSTPlot* p, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) {
        fprintf(stderr,
            "MochaRuntimeError (mocha-ink): cannot open '%s' for writing\n",
            path);
        exit(2);
    }

    int ml = ST_ML;
    int mr = ST_MR;
    int mt = ST_MT;
    int mb = ST_MB;

    ink_st_draw_background(f, p, ml, mr, mt, mb);
    ink_st_draw_sounding(f, p, ml, mr, mt, mb);
    ink_st_draw_barbs(f, p, ml, mr, mt, mb);

    fprintf(f, "</svg>\n");
    fclose(f);
}

/* ════════════════════════════════════════════════════════════
   Show — save to temp file and open
   ════════════════════════════════════════════════════════════ */

void ink_st_show(InkSTPlot* p) {
    const char* tmp = "mocha_ink_preview.svg";
    ink_st_save(p, tmp);
#ifdef _WIN32
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "start %s", tmp);
    system(cmd);
#elif defined(__APPLE__)
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "open %s", tmp);
    system(cmd);
#else
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xdg-open %s", tmp);
    system(cmd);
#endif
}

/* ════════════════════════════════════════════════════════════
   Mocha wrappers
   ════════════════════════════════════════════════════════════ */

void ink_st_save_mocha(InkSTPlot* p, const char* path) { ink_st_save(p, path); }
void ink_st_show_mocha(InkSTPlot* p)                   { ink_st_show(p); }


/*!!MOCHA - INK END!!*/
//Default Params
void mocha_missing_arg(const char* name, const char* type) {
    fprintf(stderr, "MochaRuntimeError: required argument '%s: %s' was not provided.\n", name, type);
    exit(1);
}

//For Mocha-ds, Bloom Filters
uint32_t ht_djb2(const char *key) {
    uint32_t hash = 5381u;
    while (*key) {
        hash = hash * 33u + (uint8_t)*key++;
    }
    return hash;
}

/* ============================================================
 * mocha-metero C helpers — Thermodynamics
 * All temperatures in Celsius, pressure in mb, speed in km/h
 * Calls into mocha runtime for precision-safe arithmetic
 * ============================================================ */

/* Forward declarations of runtime functions we use */
extern double mocha_float_add(double a, double b);
extern double mocha_float_sub(double a, double b);
extern double mocha_float_mul(double a, double b);
extern double mocha_float_div(double a, double b);
extern double mocha_ext_float_sin(double x, int32_t mes);
extern double mocha_ext_float_cos(double x, int32_t mes);
extern double mocha_ext_float_inv_tan(double x);
extern MochaComplex* mocha_ext_float_log(double x);
extern MochaComplex* mocha_ext_float_sqrt(double x);

/* Saturation vapour pressure — Buck equation, returns mb */
double metero_sat_vp(double t_c) {
    /* 6.1121 * exp((18.678 - t/234.5) * (t/(257.14 + t))) */
    double a = mocha_float_sub(18.678, mocha_float_div(t_c, 234.5));
    double b = mocha_float_div(t_c, mocha_float_add(257.14, t_c));
    return mocha_float_mul(6.1121, exp(mocha_float_mul(a, b)));
}

/* Dew point from temp and relative humidity — Magnus inverse */
double metero_dewpoint(double t_c, double rh) {
    double a     = 17.625;
    double b     = 243.04;
    double log_rh = mocha_ext_float_log(mocha_float_div(rh, 100.0))->real;
    double num   = mocha_float_mul(a, t_c);
    double den   = mocha_float_add(b, t_c);
    double alpha = mocha_float_add(log_rh, mocha_float_div(num, den));
    return mocha_float_div(
        mocha_float_mul(b, alpha),
        mocha_float_sub(a, alpha)
    );
}

/* Wet bulb — Stull 2011 empirical */
double metero_wetbulb(double t_c, double rh) {
    double a1 = mocha_ext_float_inv_tan(
                    mocha_float_mul(0.151977,
                        mocha_ext_float_sqrt(mocha_float_add(rh, 8.313659))->real));
    double a2 = mocha_ext_float_inv_tan(mocha_float_add(t_c, rh));
    double a3 = mocha_ext_float_inv_tan(mocha_float_sub(rh, 1.676331));
    double a4 = mocha_float_mul(
                    mocha_float_mul(0.00391838, pow(rh, 1.5)),
                    mocha_ext_float_inv_tan(mocha_float_mul(0.023101, rh)));

    /* sum terms with fixed-point add */
    double s = mocha_float_mul(t_c, a1);
    s = mocha_float_add(s, a2);
    s = mocha_float_sub(s, a3);
    s = mocha_float_add(s, a4);
    s = mocha_float_sub(s, 4.686035);
    return s;
}

/* Heat index — Rothfusz NWS regression, fixed-point polynomial */
double metero_heat_index(double t_c, double rh) {
    double t_f = mocha_float_add(mocha_float_mul(t_c, 1.8), 32.0);
    double t2  = mocha_float_mul(t_f, t_f);
    double r2  = mocha_float_mul(rh, rh);
    double tr  = mocha_float_mul(t_f, rh);

    /* Nine Rothfusz terms accumulated with fixed-point add */
    double terms[9] = {
        -42.379,
        mocha_float_mul( 2.04901523,  t_f),
        mocha_float_mul(10.14333127,  rh),
        mocha_float_mul(-0.22475541,  tr),
        mocha_float_mul(-0.00683783,  t2),
        mocha_float_mul(-0.05481717,  r2),
        mocha_float_mul( 0.00122874,  mocha_float_mul(t2, rh)),
        mocha_float_mul( 0.00085282,  mocha_float_mul(t_f, r2)),
        mocha_float_mul(-0.00000199,  mocha_float_mul(t2, r2)),
    };

    double hi_f = terms[0];
    for (int i = 1; i < 9; i++)
        hi_f = mocha_float_add(hi_f, terms[i]);

    return mocha_float_div(mocha_float_sub(hi_f, 32.0), 1.8);
}

/* Wind chill — NWS 2001, input km/h */
double metero_wind_chill(double t_c, double speed_kmh) {
    double t_f     = mocha_float_add(mocha_float_mul(t_c, 1.8), 32.0);
    double mph     = mocha_float_mul(speed_kmh, 0.621371);
    double mph016  = pow(mph, 0.16);  /* pow fine here — single call, correctly rounded */
    double wc_f    = mocha_float_add(35.74,
                     mocha_float_add(mocha_float_mul(0.6215,  t_f),
                     mocha_float_add(mocha_float_mul(-35.75,  mph016),
                                     mocha_float_mul(mocha_float_mul(0.4275, t_f), mph016))));
    return mocha_float_div(mocha_float_sub(wc_f, 32.0), 1.8);
}

/* Feels-like — heat index above 27°C, wind chill below 10°C, else actual */
double metero_feels_like(double t_c, double rh, double speed_kmh) {
    if (t_c >= 27.0)  return metero_heat_index(t_c, rh);
    if (t_c <= 10.0)  return metero_wind_chill(t_c, speed_kmh);
    return t_c;
}

/* Potential temperature theta — kelvin, then back to C */
double metero_potential_temp(double t_c, double pressure_mb) {
    double t_k    = mocha_float_add(t_c, 273.15);
    double ratio  = mocha_float_div(1000.0, pressure_mb);
    double theta_k = mocha_float_mul(t_k, exp(mocha_float_mul(0.2854, mocha_ext_float_log(ratio)->real)));
    return mocha_float_sub(theta_k, 273.15);
}

/* Virtual temperature — moisture correction */
double metero_virtual_temp(double t_c, double mixing_ratio_gkg) {
    double t_k = mocha_float_add(t_c, 273.15);
    double w   = mocha_float_div(mixing_ratio_gkg, 1000.0);
    double tv_k = mocha_float_mul(t_k, mocha_float_add(1.0, mocha_float_mul(1.6078, w)));
    return mocha_float_sub(tv_k, 273.15);
}

/* Equivalent potential temperature — Bolton 1980 */
/* Returns KELVIN — do NOT convert to Celsius */
double metero_equiv_potential_temp(double t_c, double dewpoint_c, double pressure_mb) {
    double t_k  = mocha_float_add(t_c, 273.15);
    double td_k = mocha_float_add(dewpoint_c, 273.15);
    double e    = metero_sat_vp(dewpoint_c);
    double w    = mocha_float_div(mocha_float_mul(0.622, e),
                                   mocha_float_sub(pressure_mb, e));
    double tl   = mocha_float_add(
                    mocha_float_div(1.0,
                        mocha_float_add(
                            mocha_float_div(1.0, mocha_float_sub(td_k, 56.0)),
                            mocha_float_div(mocha_ext_float_log(mocha_float_div(t_k, td_k))->real, 800.0)
                        )),
                    56.0);
    double exp1 = mocha_float_mul(0.2854, mocha_float_sub(1.0, mocha_float_mul(0.28, w)));
    double exp2 = mocha_float_sub(mocha_float_div(3.376, tl), 0.00254);
    
    double theta_e_k = mocha_float_mul(
        mocha_float_mul(t_k, exp(mocha_float_mul(exp1, mocha_ext_float_log(mocha_float_div(1000.0, pressure_mb))->real))),
        exp(mocha_float_mul(exp2, mocha_float_mul(w, mocha_float_add(1.0, mocha_float_mul(0.81, w)))))
    );
    
    return theta_e_k;  // KELVIN — DO NOT convert to Celsius
}

/* Lifting condensation level temperature */
double metero_lcl_temp(double t_c, double dewpoint_c) {
    /* Bolton 1980: Tl = 1/(1/(Td-56) + ln(T/Td)/800) + 56 */
    double t_k  = mocha_float_add(t_c, 273.15);
    double td_k = mocha_float_add(dewpoint_c, 273.15);
    return mocha_float_sub(
        mocha_float_div(1.0,
            mocha_float_add(
                mocha_float_div(1.0, mocha_float_sub(td_k, 56.0)),
                mocha_float_div(mocha_ext_float_log(mocha_float_div(t_k, td_k))->real, 800.0)
            )),
        273.15 - 56.0);
}

/* LCL pressure */
double metero_lcl_pressure(double t_c, double dewpoint_c, double pressure_mb) {
    double t_k   = mocha_float_add(t_c, 273.15);
    double tl_k  = mocha_float_add(metero_lcl_temp(t_c, dewpoint_c), 273.15);
    return mocha_float_mul(pressure_mb, exp(mocha_float_mul(3.5, mocha_ext_float_log(mocha_float_div(tl_k, t_k))->real)));
}

/* ============================================================
 * mocha-metero C helpers — Humidity
 * ============================================================ */

/* Absolute humidity (g/m³) from temp and relative humidity */
double metero_absolute_humidity(double t_c, double rh) {
    double svp = metero_sat_vp(t_c);
    double vp  = mocha_float_mul(mocha_float_div(rh, 100.0), svp);
    /* Clausius-Clapeyron: AH = 216.7 * vp / (t_k) */
    double t_k = mocha_float_add(t_c, 273.15);
    return mocha_float_div(mocha_float_mul(216.7, vp), t_k);
}

/* Specific humidity (g/kg) from vapour pressure and total pressure */
double metero_specific_humidity(double vp_mb, double pressure_mb) {
    return mocha_float_div(
        mocha_float_mul(621.97, vp_mb),
        mocha_float_sub(pressure_mb, mocha_float_mul(0.378, vp_mb))
    );
}

/* Mixing ratio (g/kg) */
double metero_mixing_ratio(double vp_mb, double pressure_mb) {
    return mocha_float_div(
        mocha_float_mul(621.97, vp_mb),
        mocha_float_sub(pressure_mb, vp_mb)
    );
}

/* Relative humidity from temp and dew point */
double metero_rh_from_dewpoint(double t_c, double dewpoint_c) {
    double svp = metero_sat_vp(t_c);
    double dp  = metero_sat_vp(dewpoint_c);
    return mocha_float_mul(100.0, mocha_float_div(dp, svp));
}

/* Vapour pressure from temp and relative humidity */
double metero_vapour_pressure(double t_c, double rh) {
    return mocha_float_mul(
        mocha_float_div(rh, 100.0),
        metero_sat_vp(t_c)
    );
}

/* Vapour pressure deficit (mb) — how far from saturation */
double metero_vpd(double t_c, double rh) {
    double svp = metero_sat_vp(t_c);
    double vp  = mocha_float_mul(mocha_float_div(rh, 100.0), svp);
    return mocha_float_sub(svp, vp);
}

/* Precipitable water (mm) from surface to top
   Takes arrays of specific humidity (g/kg) and pressure levels (mb)
   Integrates using trapezoidal rule */
double metero_precipitable_water(double* q_gkg, double* p_mb, int32_t n) {
    if (n < 2) return 0.0;
    double sum = 0.0;
    for (int32_t i = 0; i < n - 1; i++) {
        double q_avg = mocha_float_div(
            mocha_float_add(q_gkg[i], q_gkg[i+1]), 2.0);
        double dp = mocha_float_sub(p_mb[i], p_mb[i+1]); /* pressure decreases upward */
        /* PW contribution: q * dp / (g * rho_w) — simplified to q*dp*0.1 in mm */
        sum = mocha_float_add(sum,
            mocha_float_mul(mocha_float_mul(q_avg, dp), 0.1));
    }
    return sum;
}

/* Humidex — Canadian apparent temperature */
double metero_humidex(double t_c, double dewpoint_c) {
    double vp = metero_sat_vp(dewpoint_c);
    return mocha_float_add(t_c,
        mocha_float_mul(0.5555,
            mocha_float_sub(vp, 10.0)));
}

/* Wet bulb globe temperature — simplified outdoor WBGT */
double metero_wbgt_outdoor(double t_c, double rh, double solar_wm2) {
    double wb = metero_wetbulb(t_c, rh);
    /* WBGT = 0.7*Twb + 0.2*Tg + 0.1*Tdb */
    /* Globe temp estimate: Tg ≈ Tdb + 0.012 * solar */
    double tg = mocha_float_add(t_c, mocha_float_mul(0.012, solar_wm2));
    return mocha_float_add(
        mocha_float_add(
            mocha_float_mul(0.7, wb),
            mocha_float_mul(0.2, tg)),
        mocha_float_mul(0.1, t_c));
}

/* ============================================================
 * mocha-metero C helpers — Pressure & Altitude
 * ============================================================ */

/* Barometric formula — pressure at altitude from sea level pressure */
double metero_pressure_at_altitude(double pressure_sl_mb, double altitude_m, double temp_c) {
    double t_k = mocha_float_add(temp_c, 273.15);
    /* P = P0 * exp(-M*g*h / R*T) — simplified with scale height */
    /* Using hypsometric with standard lapse rate */
    double exp_arg = mocha_float_div(
        mocha_float_mul(-0.0341631, altitude_m), t_k);
    return mocha_float_mul(pressure_sl_mb, exp(exp_arg));
}

/* Altitude from pressure — hypsometric equation */
double metero_altitude_from_pressure(double pressure_mb, double pressure_sl_mb, double temp_c) {
    double t_k   = mocha_float_add(temp_c, 273.15);
    double ratio = mocha_float_div(pressure_sl_mb, pressure_mb);
    return mocha_float_mul(
        mocha_float_mul(t_k, 29.271),
        mocha_ext_float_log(ratio)->real
    );
}

/* Pressure altitude (m) — altitude in ISA where pressure equals observed */
double metero_pressure_altitude(double pressure_mb) {
    /* PA = 44330 * (1 - (P/1013.25)^0.1903) */
    double ratio = mocha_float_div(pressure_mb, 1013.25);
    return mocha_float_mul(44330.0,
        mocha_float_sub(1.0, exp(mocha_float_mul(0.1903,
            mocha_ext_float_log(ratio)->real))));
}

/* Density altitude (m) — pressure altitude corrected for temp */
double metero_density_altitude(double pressure_mb, double temp_c) {
    double pa   = metero_pressure_altitude(pressure_mb);
    double isa  = mocha_float_sub(15.0, mocha_float_mul(0.0065, pa));
    return mocha_float_add(pa,
        mocha_float_mul(118.8, mocha_float_sub(temp_c, isa)));
}

/* QNH from QFE — aerodrome pressure to sea level */
double metero_qnh_from_qfe(double qfe_mb, double elevation_m, double temp_c) {
    double t_k = mocha_float_add(temp_c, 273.15);
    double exp_arg = mocha_float_div(
        mocha_float_mul(0.0341631, elevation_m), t_k);
    return mocha_float_mul(qfe_mb, exp(exp_arg));
}

/* QFE from QNH */
double metero_qfe_from_qnh(double qnh_mb, double elevation_m, double temp_c) {
    double t_k = mocha_float_add(temp_c, 273.15);
    double exp_arg = mocha_float_div(
        mocha_float_mul(-0.0341631, elevation_m), t_k);
    return mocha_float_mul(qnh_mb, exp(exp_arg));
}

/* ISA temperature at altitude */
double metero_isa_temp(double altitude_m) {
    /* Troposphere: 15 - 6.5*h/1000 C up to 11000m */
    /* Stratosphere: -56.5 C from 11000 to 20000m */
    if (altitude_m <= 11000.0)
        return mocha_float_sub(15.0, mocha_float_mul(0.0065, altitude_m));
    return -56.5;  // stratosphere
}

/* ============================================================
 * mocha-metero C helpers — Wind
 * ============================================================ */

/* U component (east-west) from speed and direction */
double metero_wind_u(double speed_kmh, double direction_deg) {
    double dir_rad = mocha_float_mul(direction_deg, 0.017453293);
    return mocha_float_mul(-speed_kmh, mocha_ext_float_sin(dir_rad, 0));
}

/* V component (north-south) from speed and direction */
double metero_wind_v(double speed_kmh, double direction_deg) {
    double dir_rad = mocha_float_mul(direction_deg, 0.017453293);
    return mocha_float_mul(-speed_kmh, mocha_ext_float_cos(dir_rad, 0));
}

/* Wind speed from u/v components */
double metero_wind_speed_from_uv(double u, double v) {
    return mocha_ext_float_sqrt(
        mocha_float_add(mocha_float_mul(u, u),
                        mocha_float_mul(v, v)))->real;
}

/* Wind direction from u/v components (degrees, meteorological) */
double metero_wind_dir_from_uv(double u, double v) {
    double dir = mocha_float_mul(
        atan2(-u, -v) * 180.0 / 3.14159265358979323846, 1.0);
    if (dir < 0.0) dir = mocha_float_add(dir, 360.0);
    return dir;
}

/* Crosswind component for runway — angle between wind and runway */
double metero_crosswind(double speed_kmh, double wind_dir_deg, double runway_dir_deg) {
    double angle_rad = mocha_float_mul(
        mocha_float_sub(wind_dir_deg, runway_dir_deg),
        0.017453293);
    return mocha_float_mul(speed_kmh,
        fabs(mocha_ext_float_sin(angle_rad, 0)));
}

/* Headwind component — along runway axis */
double metero_headwind(double speed_kmh, double wind_dir_deg, double runway_dir_deg) {
    double angle_rad = mocha_float_mul(
        mocha_float_sub(wind_dir_deg, runway_dir_deg),
        0.017453293);
    return mocha_float_mul(speed_kmh, mocha_ext_float_cos(angle_rad, 0));
}

/* Wind power density (W/m²) — energy available per unit area */
double metero_wind_power_density(double speed_ms, double air_density_kgm3) {
    return mocha_float_mul(
        mocha_float_mul(0.5, air_density_kgm3),
        mocha_float_mul(speed_ms, mocha_float_mul(speed_ms, speed_ms)));
}

/* Gust factor — ratio of gust to mean wind */
double metero_gust_factor(double gust_kmh, double mean_kmh) {
    if (mean_kmh == 0.0) return 1.0;
    return mocha_float_div(gust_kmh, mean_kmh);
}

/* Wind rose sector (0-15) from direction — 16-point compass */
int32_t metero_wind_rose_sector(double direction_deg) {
    double sector = mocha_float_div(
        mocha_float_add(direction_deg, 11.25), 22.5);
    return (int32_t)sector % 16;
}

/* Beaufort number from speed in km/h */
int32_t metero_beaufort(double speed_kmh) {
    if (speed_kmh < 1.0)   return 0;
    if (speed_kmh < 5.5)   return 1;
    if (speed_kmh < 11.0)  return 2;
    if (speed_kmh < 19.0)  return 3;
    if (speed_kmh < 28.0)  return 4;
    if (speed_kmh < 38.0)  return 5;
    if (speed_kmh < 49.0)  return 6;
    if (speed_kmh < 61.0)  return 7;
    if (speed_kmh < 74.0)  return 8;
    if (speed_kmh < 88.0)  return 9;
    if (speed_kmh < 102.0) return 10;
    if (speed_kmh < 117.0) return 11;
    return 12;
}

/* Mean wind from vector average of u/v arrays */
double metero_mean_wind_speed(double* speeds, double* dirs_deg, int32_t n) {
    double u_sum = 0.0, v_sum = 0.0;
    for (int32_t i = 0; i < n; i++) {
        u_sum = mocha_float_add(u_sum, metero_wind_u(speeds[i], dirs_deg[i]));
        v_sum = mocha_float_add(v_sum, metero_wind_v(speeds[i], dirs_deg[i]));
    }
    double u_mean = mocha_float_div(u_sum, (double)n);
    double v_mean = mocha_float_div(v_sum, (double)n);
    return metero_wind_speed_from_uv(u_mean, v_mean);
}

/* Mean wind direction from vector average */
double metero_mean_wind_dir(double* speeds, double* dirs_deg, int32_t n) {
    double u_sum = 0.0, v_sum = 0.0;
    for (int32_t i = 0; i < n; i++) {
        u_sum = mocha_float_add(u_sum, metero_wind_u(speeds[i], dirs_deg[i]));
        v_sum = mocha_float_add(v_sum, metero_wind_v(speeds[i], dirs_deg[i]));
    }
    return metero_wind_dir_from_uv(
        mocha_float_div(u_sum, (double)n),
        mocha_float_div(v_sum, (double)n));
}

/* Wind shear magnitude between two levels */
double metero_wind_shear(double spd1_kmh, double dir1_deg,
                          double spd2_kmh, double dir2_deg,
                          double dz_m) {
    double du = mocha_float_sub(metero_wind_u(spd2_kmh, dir2_deg),
                                 metero_wind_u(spd1_kmh, dir1_deg));
    double dv = mocha_float_sub(metero_wind_v(spd2_kmh, dir2_deg),
                                 metero_wind_v(spd1_kmh, dir1_deg));
    double shear_vec = metero_wind_speed_from_uv(du, dv);
    return mocha_float_div(shear_vec, dz_m);
}

/* ============================================================
 * mocha-metero C helpers — Precipitation
 * ============================================================ */

/* Z-R relationship — radar reflectivity (dBZ) to rain rate (mm/hr)
   Marshall-Palmer: Z = 200 * R^1.6 → R = (Z/200)^(1/1.6) */
double metero_dbz_to_rainrate(double dbz) {
    double z = exp(mocha_float_mul(mocha_float_mul(dbz, 0.1),
                   mocha_ext_float_log(10.0)->real));
    return exp(mocha_float_mul(
        mocha_float_div(1.0, 1.6),
        mocha_ext_float_log(mocha_float_div(z, 200.0))->real));
}

/* Rain rate to dBZ */
double metero_rainrate_to_dbz(double rain_rate_mmhr) {
    double z = mocha_float_mul(200.0,
        exp(mocha_float_mul(1.6,
            mocha_ext_float_log(rain_rate_mmhr)->real)));
    return mocha_float_div(
        mocha_ext_float_log(z)->real,
        mocha_float_mul(0.1, mocha_ext_float_log(10.0)->real));
}

/* Snow water equivalent — density-based */
double metero_snow_water_equivalent(double snow_depth_cm, double snow_density_kgm3) {
    /* SWE (mm) = depth (cm) * density (kg/m³) / 100 */
    return mocha_float_div(
        mocha_float_mul(snow_depth_cm, snow_density_kgm3),
        100.0);
}

/* Snow density estimate from temperature */
double metero_snow_density(double temp_c) {
    /* Hedstrom & Pomeroy 1998 */
    if (temp_c <= -15.0) return 50.0;
    if (temp_c <= -5.0)
        return mocha_float_add(50.0,
            mocha_float_mul(3.0, mocha_float_add(temp_c, 15.0)));
    /* Wet snow near 0C */
    return mocha_float_add(100.0,
        mocha_float_mul(10.0, mocha_float_add(temp_c, 5.0)));
}

/* Snowfall rate from rain equivalent */
double metero_rain_to_snowfall(double rain_mm, double temp_c) {
    double density = metero_snow_density(temp_c);
    /* snow depth (cm) = rain (mm) * 100 / density */
    return mocha_float_div(
        mocha_float_mul(rain_mm, 100.0),
        density);
}

/* Hail size category — returns mm diameter estimate from dBZ */
double metero_hail_size_from_dbz(double dbz) {
    /* Empirical: D (mm) = 0.1 * (dbz - 40)^1.5 for dbz > 40 */
    if (dbz <= 40.0) return 0.0;
    double diff = mocha_float_sub(dbz, 40.0);
    return mocha_float_mul(0.1,
        exp(mocha_float_mul(1.5,
            mocha_ext_float_log(diff)->real)));
}

/* Accumulated precipitation from rate array and time steps */
double metero_accumulate_precip(double* rates_mmhr, double* dt_hr, int32_t n) {
    double total = 0.0;
    for (int32_t i = 0; i < n; i++)
        total = mocha_float_add(total,
            mocha_float_mul(rates_mmhr[i], dt_hr[i]));
    return total;
}

/* Antecedent precipitation index — weighted sum of past rainfall */
/* weights decay exponentially: w_i = k^i, k typically 0.85-0.98 */
double metero_api(double* daily_rain_mm, int32_t n, double k) {
    double api = 0.0;
    double weight = 1.0;
    for (int32_t i = 0; i < n; i++) {
        api = mocha_float_add(api,
            mocha_float_mul(daily_rain_mm[i], weight));
        weight = mocha_float_mul(weight, k);
    }
    return api;
}

/* Runoff estimation — SCS curve number method */
double metero_runoff_cn(double rainfall_mm, double curve_number) {
    /* S = 25400/CN - 254 (mm) */
    double s = mocha_float_sub(
        mocha_float_div(25400.0, curve_number), 254.0);
    double ia = mocha_float_mul(0.2, s);  /* initial abstraction */
    if (rainfall_mm <= ia) return 0.0;
    double num = mocha_float_mul(
        mocha_float_sub(rainfall_mm, ia),
        mocha_float_sub(rainfall_mm, ia));
    double den = mocha_float_add(
        mocha_float_sub(rainfall_mm, ia), s);
    return mocha_float_div(num, den);
}

/* Evapotranspiration — Hargreaves simplified */
double metero_et_hargreaves(double t_max_c, double t_min_c,
                             double t_mean_c, double ra_mj_m2_day) {
    double td = mocha_float_sub(t_max_c, t_min_c);
    return mocha_float_mul(
        mocha_float_mul(0.0023, ra_mj_m2_day),
        mocha_float_mul(
            mocha_float_add(t_mean_c, 17.8),
            mocha_ext_float_sqrt(td)->real));
}

/* ============================================================
 * mocha-metero C helpers — Severe Weather Indices
 * Full parcel theory CAPE/CIN with sounding arrays
 * ============================================================ */

/* Parcel temperature after dry adiabatic lift to pressure level */
double metero_parcel_temp_dry(double t_surface_c, double p_surface_mb,
                               double p_level_mb) {
    double t_k = mocha_float_add(t_surface_c, 273.15);
    double ratio = mocha_float_div(p_level_mb, p_surface_mb);
    return mocha_float_sub(
        mocha_float_mul(t_k,
            exp(mocha_float_mul(0.2854,
                mocha_ext_float_log(ratio)->real))),
        273.15);
}

/* Parcel temperature after moist adiabatic lift above LCL
   Uses iterative pseudo-adiabatic approximation — Betts 1982 */
double metero_parcel_temp_moist(double t_lcl_c, double p_lcl_mb,
                                 double p_level_mb) {
    double t_k  = mocha_float_add(t_lcl_c, 273.15);
    double p    = p_lcl_mb;
    double dp   = -10.0;  /* 10mb steps downward in pressure */
    double lv   = 2.5e6;  /* latent heat of vaporization J/kg */
    double rd   = 287.05; /* gas constant dry air */
    double rv   = 461.5;  /* gas constant water vapour */
    double cpd  = 1005.7; /* specific heat dry air */

    while (p > p_level_mb) {
        double svp   = metero_sat_vp(mocha_float_sub(t_k, 273.15));
        double ws    = mocha_float_div(
                        mocha_float_mul(0.622, svp),
                        mocha_float_sub(p, svp));
        double num   = mocha_float_add(1.0,
                        mocha_float_div(
                            mocha_float_mul(lv, ws),
                            mocha_float_mul(rd, t_k)));
        double den   = mocha_float_add(1.0,
                        mocha_float_div(
                            mocha_float_mul(
                                mocha_float_mul(lv, lv),
                                mocha_float_mul(ws,
                                    mocha_float_add(1.0,
                                        mocha_float_div(ws, 0.622)))),
                            mocha_float_mul(cpd,
                                mocha_float_mul(rv,
                                    mocha_float_mul(t_k, t_k)))));
        double gamma_m = mocha_float_mul(
                            mocha_float_div(rd * t_k, mocha_float_mul(cpd, p)),
                            mocha_float_div(num, den));
        t_k = mocha_float_add(t_k, mocha_float_mul(gamma_m, dp));
        p   = mocha_float_add(p, dp);
        if (p < p_level_mb) p = p_level_mb;
    }
    return mocha_float_sub(t_k, 273.15);
}

/* Full CAPE/CIN computation from sounding
   p_mb:    pressure levels (mb), surface first, decreasing
   t_c:     temperature at each level (C)
   td_c:    dew point at each level (C)
   n:       number of levels
   returns: [CAPE, CIN, LFC_mb, EL_mb] as 4-element array */
MochaArray* metero_cape_cin(double* p_mb, double* t_c, double* td_c, int32_t n) {
    double cape = 0.0, cin = 0.0, lfc = -1.0, el = -1.0;

    if (n >= 2) {
        double t_sfc   = t_c[0];
        double td_sfc  = td_c[0];
        double p_sfc   = p_mb[0];

        double p_lcl = metero_lcl_pressure(t_sfc, td_sfc, p_sfc);
        double t_lcl = metero_lcl_temp(t_sfc, td_sfc);

        int lfc_found = 0;
        int el_found  = 0;

        for (int32_t i = 1; i < n; i++) {
            double p_lev = p_mb[i];
            double t_env = t_c[i];
            double t_parcel;

            if (p_lev >= p_lcl) {
                t_parcel = metero_parcel_temp_dry(t_sfc, p_sfc, p_lev);
            } else {
                t_parcel = metero_parcel_temp_moist(t_lcl, p_lcl, p_lev);
            }

            double buoy = mocha_float_sub(t_parcel, t_env);
            double tv_parcel = mocha_float_add(t_parcel, 273.15);
            double tv_env    = mocha_float_add(t_env, 273.15);

            double buoy_acc = mocha_float_div(
                mocha_float_mul(9.80665,
                    mocha_float_sub(tv_parcel, tv_env)),
                tv_env);

            double dz = mocha_float_mul(
                mocha_float_mul(287.05 / 9.80665,
                    mocha_float_div(mocha_float_add(tv_parcel, tv_env), 2.0)),
                mocha_ext_float_log(
                    mocha_float_div(p_mb[i-1], p_lev))->real);

            if (!lfc_found && p_lev < p_lcl && buoy > 0.0) {
                lfc = p_lev;
                lfc_found = 1;
            }

            if (lfc_found && !el_found && buoy < 0.0 && p_lev < lfc) {
                el = p_lev;
                el_found = 1;
            }

            if (lfc_found && !el_found && buoy > 0.0)
                cape = mocha_float_add(cape, mocha_float_mul(buoy_acc, dz));

            if (!lfc_found && buoy < 0.0 && p_lev < p_sfc)
                cin = mocha_float_add(cin, mocha_float_mul(buoy_acc, dz));
        }

        if (cin > 0.0) cin = -cin;
    }

    /* Build MochaArray with 4 float values */
    MochaArray* result = mocha_array_new(4, 8, 0);
    mocha_array_init_set(result, 0, &cape);
    mocha_array_init_set(result, 1, &cin);
    mocha_array_init_set(result, 2, &lfc);
    mocha_array_init_set(result, 3, &el);
    return result;
}

/* K-Index — thunderstorm potential from sounding */
double metero_k_index(double t_850_c, double t_700_c, double t_500_c,
                       double td_850_c, double td_700_c) {
    return mocha_float_add(
        mocha_float_sub(
            mocha_float_add(
                mocha_float_sub(t_850_c, t_500_c),
                td_850_c),
            mocha_float_sub(t_700_c, td_700_c)),
        0.0);
}

/* Showalter Index — lifted index variant */
double metero_showalter(double t_850_c, double td_850_c, double t_500_c) {
    double t_parcel = metero_parcel_temp_moist(
        metero_lcl_temp(t_850_c, td_850_c),
        metero_lcl_pressure(t_850_c, td_850_c, 850.0),
        500.0);
    return mocha_float_sub(t_500_c, t_parcel);
}

/* Lifted Index — surface parcel lifted to 500mb */
double metero_lifted_index(double t_sfc_c, double td_sfc_c,
                            double p_sfc_mb, double t_500_c) {
    double t_parcel = metero_parcel_temp_moist(
        metero_lcl_temp(t_sfc_c, td_sfc_c),
        metero_lcl_pressure(t_sfc_c, td_sfc_c, p_sfc_mb),
        500.0);
    return mocha_float_sub(t_500_c, t_parcel);
}

/* Total-Totals Index */
double metero_total_totals(double t_850_c, double td_850_c, double t_500_c) {
    /* VT = T850 - T500, CT = Td850 - T500, TT = VT + CT */
    double vt = mocha_float_sub(t_850_c, t_500_c);
    double ct = mocha_float_sub(td_850_c, t_500_c);
    return mocha_float_add(vt, ct);
}

/* SWEAT Index — severe weather threat */
double metero_sweat(double td_850_c, double tt,
                    double spd_850_kmh, double spd_500_kmh,
                    double dir_850_deg, double dir_500_deg) {
    double term1 = mocha_float_mul(12.0, td_850_c);
    double term2 = mocha_float_mul(20.0, mocha_float_sub(tt, 49.0));
    double term3 = mocha_float_mul(2.0, mocha_float_div(spd_850_kmh, 1.852));
    double term4 = mocha_float_div(spd_500_kmh, 1.852);
    double sin_dd = mocha_ext_float_sin(
        mocha_float_mul(
            mocha_float_sub(dir_500_deg, dir_850_deg),
            0.017453293), 0);
    double term5 = mocha_float_mul(125.0,
        mocha_float_add(sin_dd, 0.2));
    double sum = mocha_float_add(term1,
                 mocha_float_add(term2,
                 mocha_float_add(term3,
                 mocha_float_add(term4, term5))));
    return sum < 0.0 ? 0.0 : sum;
}

/* Storm Relative Helicity (SRH) from sounding
   u/v arrays in m/s, storm motion um/vm in m/s */
double metero_srh(double* u_ms, double* v_ms,
                   double* p_mb, int32_t n,
                   double storm_u, double storm_v) {
    double srh = 0.0;
    for (int32_t i = 0; i < n - 1; i++) {
        double u1 = mocha_float_sub(u_ms[i],   storm_u);
        double v1 = mocha_float_sub(v_ms[i],   storm_v);
        double u2 = mocha_float_sub(u_ms[i+1], storm_u);
        double v2 = mocha_float_sub(v_ms[i+1], storm_v);
        /* Cross product: (u1*v2 - u2*v1) */
        srh = mocha_float_add(srh,
            mocha_float_sub(
                mocha_float_mul(u1, v2),
                mocha_float_mul(u2, v1)));
    }
    return srh;
}

/* Energy Helicity Index */
double metero_ehi(double cape, double srh) {
    return mocha_float_div(
        mocha_float_mul(cape, srh),
        160000.0);
}

/* Supercell composite parameter */
double metero_scp(double cape, double srh, double bulk_shear_ms) {
    double cape_term  = mocha_float_div(cape, 1000.0);
    double srh_term   = mocha_float_div(srh, 50.0);
    double shear_term = mocha_float_div(bulk_shear_ms, 20.0);
    return mocha_float_mul(cape_term,
           mocha_float_mul(srh_term, shear_term));
}

/* Bulk Richardson Number — storm type indicator */
double metero_brn(double cape, double bulk_shear_ms) {
    if (bulk_shear_ms == 0.0) return 9999.0;
    double shear_sq = mocha_float_mul(
        mocha_float_mul(0.5, bulk_shear_ms), bulk_shear_ms);
    return mocha_float_div(cape, shear_sq);
}

/* ============================================================
 * mocha-metero C helpers — Visibility & Fog
 * ============================================================ */

/* Visibility from extinction coefficient (Koschmieder's law) */
double metero_visibility_from_extinction(double extinction_coeff_per_km) {
    if (extinction_coeff_per_km <= 0.0) return 99.0;
    return mocha_float_div(3.912, extinction_coeff_per_km);
}

/* Extinction coefficient from visibility */
double metero_extinction_from_visibility(double visibility_km) {
    if (visibility_km <= 0.0) return 999.0;
    return mocha_float_div(3.912, visibility_km);
}

/* Fog formation probability — RH threshold method */
double metero_fog_probability(double t_c, double td_c, double wind_kmh) {
    double spread = mocha_float_sub(t_c, td_c);
    double rh     = metero_rh_from_dewpoint(t_c, td_c);
    /* Base probability from RH */
    double prob = 0.0;
    if (rh >= 100.0) prob = 1.0;
    else if (rh >= 95.0) prob = 0.8;
    else if (rh >= 90.0) prob = 0.5;
    else if (rh >= 85.0) prob = 0.2;
    else prob = 0.0;
    /* Wind reduces fog probability */
    if (wind_kmh > 15.0)
        prob = mocha_float_mul(prob, 0.3);
    else if (wind_kmh > 8.0)
        prob = mocha_float_mul(prob, 0.6);
    return prob;
}

/* Lifted fog ceiling estimate (m) from LCL */
double metero_fog_ceiling(double t_c, double td_c) {
    double spread = mocha_float_sub(t_c, td_c);
    /* Empirical: ceiling (m) = spread * 125 */
    return mocha_float_mul(spread, 125.0);
}

/* Fosberg Fire Weather Index */
double metero_ffwi(double t_c, double rh, double wind_kmh) {
    double t_f   = mocha_float_add(mocha_float_mul(t_c, 1.8), 32.0);
    double wind_mph = mocha_float_mul(wind_kmh, 0.621371);
    /* eta = EMC (equilibrium moisture content) */
    double eta;
    if (rh < 10.0)
        eta = mocha_float_add(0.03229,
              mocha_float_add(
                  mocha_float_mul(0.281073, rh),
                  mocha_float_mul(-0.000578, mocha_float_mul(rh, t_f))));
    else if (rh < 50.0)
        eta = mocha_float_add(2.22749,
              mocha_float_add(
                  mocha_float_mul(0.160107, rh),
                  mocha_float_mul(-0.014784, t_f)));
    else
        eta = mocha_float_add(21.0606,
              mocha_float_add(
                  mocha_float_mul(0.005565, mocha_float_mul(rh, rh)),
                  mocha_float_add(
                      mocha_float_mul(-0.00035, mocha_float_mul(rh, t_f)),
                      mocha_float_mul(-0.483199, rh))));

    double m = mocha_float_mul(eta, 100.0);
    double nm = mocha_float_div(
        mocha_float_sub(m, 30.0),
        mocha_float_sub(250.0, 30.0));
    if (nm < 0.0) nm = 0.0;
    if (nm > 1.0) nm = 1.0;
    double b = mocha_float_add(
        mocha_float_mul(nm, nm),
        mocha_float_mul(
            mocha_float_mul(nm, nm),
            mocha_float_mul(nm, nm)));
    return mocha_float_mul(
        mocha_float_div(
            mocha_float_mul(1.0,
                mocha_ext_float_sqrt(1.0 + mocha_float_mul(0.3, b))->real),
            0.3002),
        wind_mph);
}

/* Runway Visual Range from visibility and lighting */
double metero_rvr(double visibility_m, int32_t has_lights) {
    /* RVR ≈ visibility * transmissometer factor */
    double factor = has_lights ? 1.5 : 1.0;
    return mocha_float_mul(visibility_m, factor);
}

/* Ceiling height from cloud base temp differential */
double metero_cloud_base(double t_c, double td_c) {
    /* Standard: (T - Td) / 2.5 * 1000 feet → convert to meters */
    double spread = mocha_float_sub(t_c, td_c);
    double feet   = mocha_float_mul(
        mocha_float_div(spread, 2.5), 1000.0);
    return mocha_float_mul(feet, 0.3048);
}

/* Mixing layer depth (m) — inverse lapse rate relationship */
/* Mixing layer depth — parcel rise to inversion level */
double metero_mixing_depth(double t_sfc_c, double t_inversion_c,
                            double inversion_height_m) {
    double delta_t = mocha_float_sub(t_sfc_c, t_inversion_c);
    if (delta_t <= 0.0) return 0.0;  /* No inversion */
    /* Dry adiabatic lapse rate: 0.0098 K/m = 9.8 K/km */
    /* Mixing depth where parcel cools to inversion temp:
       MD = delta_T / 0.0098  (in meters) */
    double md = mocha_float_div(delta_t, 0.0098);
    /* Cap at inversion height (can't rise above inversion) */
    if (md > inversion_height_m) {
        md = inversion_height_m;
    }
    return md;
}

/* ============================================================
 * mocha-metero C helpers — Air Quality (Indian AQI)
 * ============================================================ */

/* Sub-index for PM2.5 (µg/m³) — Indian AQI */
double metero_aqi_pm25_subindex(double pm25_ugm3) {
    if (pm25_ugm3 <= 30.0)
        return mocha_float_mul(pm25_ugm3, 50.0 / 30.0);
    if (pm25_ugm3 <= 60.0)
        return mocha_float_add(50.0,
            mocha_float_mul(mocha_float_sub(pm25_ugm3, 30.0), 50.0 / 30.0));
    if (pm25_ugm3 <= 90.0)
        return mocha_float_add(100.0,
            mocha_float_mul(mocha_float_sub(pm25_ugm3, 60.0), 100.0 / 30.0));
    if (pm25_ugm3 <= 120.0)
        return mocha_float_add(200.0,
            mocha_float_mul(mocha_float_sub(pm25_ugm3, 90.0), 100.0 / 30.0));
    if (pm25_ugm3 <= 250.0)
        return mocha_float_add(300.0,
            mocha_float_mul(mocha_float_sub(pm25_ugm3, 120.0), 100.0 / 130.0));
    return mocha_float_add(400.0,
        mocha_float_mul(mocha_float_sub(pm25_ugm3, 250.0), 400.0 / 250.0));
}

/* Sub-index for PM10 (µg/m³) */
double metero_aqi_pm10_subindex(double pm10_ugm3) {
    if (pm10_ugm3 <= 50.0)
        return mocha_float_mul(pm10_ugm3, 50.0 / 50.0);
    if (pm10_ugm3 <= 100.0)
        return mocha_float_add(50.0,
            mocha_float_mul(mocha_float_sub(pm10_ugm3, 50.0), 50.0 / 50.0));
    if (pm10_ugm3 <= 250.0)
        return mocha_float_add(100.0,
            mocha_float_mul(mocha_float_sub(pm10_ugm3, 100.0), 100.0 / 150.0));
    if (pm10_ugm3 <= 350.0)
        return mocha_float_add(200.0,
            mocha_float_mul(mocha_float_sub(pm10_ugm3, 250.0), 100.0 / 100.0));
    if (pm10_ugm3 <= 430.0)
        return mocha_float_add(300.0,
            mocha_float_mul(mocha_float_sub(pm10_ugm3, 350.0), 100.0 / 80.0));
    return mocha_float_add(400.0,
        mocha_float_mul(mocha_float_sub(pm10_ugm3, 430.0), 400.0 / 570.0));
}

/* Sub-index for NO2 (µg/m³) */
double metero_aqi_no2_subindex(double no2_ugm3) {
    if (no2_ugm3 <= 40.0)
        return mocha_float_mul(no2_ugm3, 50.0 / 40.0);
    if (no2_ugm3 <= 80.0)
        return mocha_float_add(50.0,
            mocha_float_mul(mocha_float_sub(no2_ugm3, 40.0), 50.0 / 40.0));
    if (no2_ugm3 <= 180.0)
        return mocha_float_add(100.0,
            mocha_float_mul(mocha_float_sub(no2_ugm3, 80.0), 100.0 / 100.0));
    if (no2_ugm3 <= 280.0)
        return mocha_float_add(200.0,
            mocha_float_mul(mocha_float_sub(no2_ugm3, 180.0), 100.0 / 100.0));
    if (no2_ugm3 <= 400.0)
        return mocha_float_add(300.0,
            mocha_float_mul(mocha_float_sub(no2_ugm3, 280.0), 100.0 / 120.0));
    return mocha_float_add(400.0,
        mocha_float_mul(mocha_float_sub(no2_ugm3, 400.0), 400.0 / 200.0));
}

/* Sub-index for SO2 (µg/m³) */
double metero_aqi_so2_subindex(double so2_ugm3) {
    if (so2_ugm3 <= 40.0)
        return mocha_float_mul(so2_ugm3, 50.0 / 40.0);
    if (so2_ugm3 <= 80.0)
        return mocha_float_add(50.0,
            mocha_float_mul(mocha_float_sub(so2_ugm3, 40.0), 50.0 / 40.0));
    if (so2_ugm3 <= 380.0)
        return mocha_float_add(100.0,
            mocha_float_mul(mocha_float_sub(so2_ugm3, 80.0), 100.0 / 300.0));
    if (so2_ugm3 <= 800.0)
        return mocha_float_add(200.0,
            mocha_float_mul(mocha_float_sub(so2_ugm3, 380.0), 100.0 / 420.0));
    if (so2_ugm3 <= 1600.0)
        return mocha_float_add(300.0,
            mocha_float_mul(mocha_float_sub(so2_ugm3, 800.0), 100.0 / 800.0));
    return mocha_float_add(400.0,
        mocha_float_mul(mocha_float_sub(so2_ugm3, 1600.0), 400.0 / 800.0));
}

/* Sub-index for O3 (µg/m³) */
double metero_aqi_o3_subindex(double o3_ugm3) {
    if (o3_ugm3 <= 50.0)
        return mocha_float_mul(o3_ugm3, 50.0 / 50.0);
    if (o3_ugm3 <= 100.0)
        return mocha_float_add(50.0,
            mocha_float_mul(mocha_float_sub(o3_ugm3, 50.0), 50.0 / 50.0));
    if (o3_ugm3 <= 168.0)
        return mocha_float_add(100.0,
            mocha_float_mul(mocha_float_sub(o3_ugm3, 100.0), 100.0 / 68.0));
    if (o3_ugm3 <= 208.0)
        return mocha_float_add(200.0,
            mocha_float_mul(mocha_float_sub(o3_ugm3, 168.0), 100.0 / 40.0));
    if (o3_ugm3 <= 748.0)
        return mocha_float_add(300.0,
            mocha_float_mul(mocha_float_sub(o3_ugm3, 208.0), 100.0 / 540.0));
    return mocha_float_add(400.0,
        mocha_float_mul(mocha_float_sub(o3_ugm3, 748.0), 400.0 / 752.0));
}

/* Sub-index for CO (mg/m³) */
double metero_aqi_co_subindex(double co_mgm3) {
    if (co_mgm3 <= 1.0)
        return mocha_float_mul(co_mgm3, 50.0 / 1.0);
    if (co_mgm3 <= 2.0)
        return mocha_float_add(50.0,
            mocha_float_mul(mocha_float_sub(co_mgm3, 1.0), 50.0 / 1.0));
    if (co_mgm3 <= 10.0)
        return mocha_float_add(100.0,
            mocha_float_mul(mocha_float_sub(co_mgm3, 2.0), 100.0 / 8.0));
    if (co_mgm3 <= 17.0)
        return mocha_float_add(200.0,
            mocha_float_mul(mocha_float_sub(co_mgm3, 10.0), 100.0 / 7.0));
    if (co_mgm3 <= 34.0)
        return mocha_float_add(300.0,
            mocha_float_mul(mocha_float_sub(co_mgm3, 17.0), 100.0 / 17.0));
    return mocha_float_add(400.0,
        mocha_float_mul(mocha_float_sub(co_mgm3, 34.0), 400.0 / 66.0));
}

/* Maximum sub-index becomes AQI */
double metero_aqi_from_subindices(double pm25, double pm10,
                                   double no2, double so2,
                                   double o3, double co) {
    double max_idx = pm25;
    if (pm10 > max_idx) max_idx = pm10;
    if (no2 > max_idx) max_idx = no2;
    if (so2 > max_idx) max_idx = so2;
    if (o3 > max_idx) max_idx = o3;
    if (co > max_idx) max_idx = co;
    return max_idx;
}

/* ============================================================
 * mocha-metero C helpers — Solar & Radiation
 * ============================================================ */

#define METERO_PI 3.14159265358979323846
#define METERO_DEG2RAD 0.017453293
#define METERO_RAD2DEG 57.295779513

/* Solar declination (degrees) from day of year */
double metero_solar_declination(int32_t day_of_year) {
    double d = (double)day_of_year;
    /* Spencer 1971 Fourier series */
    double b = mocha_float_mul(
        mocha_float_mul(2.0, METERO_PI),
        mocha_float_div(mocha_float_sub(d, 1.0), 365.0));
    return mocha_float_mul(METERO_RAD2DEG,
        mocha_float_add(0.006918,
        mocha_float_add(mocha_float_mul(-0.399912, mocha_ext_float_cos(b, 0)),
        mocha_float_add(mocha_float_mul( 0.070257, mocha_ext_float_sin(b, 0)),
        mocha_float_add(mocha_float_mul(-0.006758, mocha_ext_float_cos(mocha_float_mul(2.0, b), 0)),
        mocha_float_add(mocha_float_mul( 0.000907, mocha_ext_float_sin(mocha_float_mul(2.0, b), 0)),
        mocha_float_add(mocha_float_mul(-0.002697, mocha_ext_float_cos(mocha_float_mul(3.0, b), 0)),
                        mocha_float_mul( 0.001480, mocha_ext_float_sin(mocha_float_mul(3.0, b), 0)))))))));
}

/* Equation of time (minutes) from day of year */
double metero_equation_of_time(int32_t day_of_year) {
    double b = mocha_float_mul(
        mocha_float_mul(2.0, METERO_PI),
        mocha_float_div((double)(day_of_year - 1), 365.0));
    return mocha_float_mul(229.18,
        mocha_float_add(0.000075,
        mocha_float_add(mocha_float_mul( 0.001868, mocha_ext_float_cos(b, 0)),
        mocha_float_add(mocha_float_mul(-0.032077, mocha_ext_float_sin(b, 0)),
        mocha_float_add(mocha_float_mul(-0.014615, mocha_ext_float_cos(mocha_float_mul(2.0, b), 0)),
                        mocha_float_mul(-0.04089,  mocha_ext_float_sin(mocha_float_mul(2.0, b), 0)))))));
}

/* Hour angle (degrees) from solar time */
double metero_hour_angle(double solar_time_hr) {
    return mocha_float_mul(15.0, mocha_float_sub(solar_time_hr, 12.0));
}

/* Solar elevation angle (degrees) */
double metero_solar_elevation(double lat_deg, double decl_deg, double hour_angle_deg) {
    double lat_r  = mocha_float_mul(lat_deg,       METERO_DEG2RAD);
    double decl_r = mocha_float_mul(decl_deg,      METERO_DEG2RAD);
    double ha_r   = mocha_float_mul(hour_angle_deg, METERO_DEG2RAD);
    double sin_elev = mocha_float_add(
        mocha_float_mul(mocha_ext_float_sin(lat_r,  0),
                        mocha_ext_float_sin(decl_r, 0)),
        mocha_float_mul(mocha_ext_float_cos(lat_r,  0),
            mocha_float_mul(mocha_ext_float_cos(decl_r, 0),
                            mocha_ext_float_cos(ha_r, 0))));
    return mocha_float_mul(METERO_RAD2DEG,
        mocha_ext_float_inv_sin(sin_elev)->real);
}

/* Solar azimuth angle (degrees from North) */
double metero_solar_azimuth(double lat_deg, double decl_deg,
                             double hour_angle_deg, double elev_deg) {
    double lat_r  = mocha_float_mul(lat_deg,  METERO_DEG2RAD);
    double decl_r = mocha_float_mul(decl_deg, METERO_DEG2RAD);
    double elev_r = mocha_float_mul(elev_deg, METERO_DEG2RAD);
    double cos_az = mocha_float_div(
        mocha_float_sub(
            mocha_ext_float_sin(decl_r, 0),
            mocha_float_mul(mocha_ext_float_sin(elev_r, 0),
                            mocha_ext_float_sin(lat_r, 0))),
        mocha_float_mul(mocha_ext_float_cos(elev_r, 0),
                        mocha_ext_float_cos(lat_r, 0)));
    double az = mocha_float_mul(METERO_RAD2DEG,
        mocha_ext_float_inv_cos(cos_az)->real);
    if (hour_angle_deg > 0.0)
        az = mocha_float_sub(360.0, az);
    return az;
}

/* Sunrise/sunset hour angle (degrees) */
double metero_sunrise_hour_angle(double lat_deg, double decl_deg) {
    double lat_r  = mocha_float_mul(lat_deg,  METERO_DEG2RAD);
    double decl_r = mocha_float_mul(decl_deg, METERO_DEG2RAD);
    double cos_ha = mocha_float_div(
        mocha_float_mul(-1.0,
            mocha_float_mul(mocha_ext_float_tan(lat_r, 0),
                            mocha_ext_float_tan(decl_r, 0))),
        1.0);
    /* Clamp to [-1,1] for polar regions */
    if (cos_ha < -1.0) return 180.0;
    if (cos_ha >  1.0) return 0.0;
    return mocha_float_mul(METERO_RAD2DEG,
        mocha_ext_float_inv_cos(cos_ha)->real);
}

/* Sunrise time (decimal hours UTC) */
double metero_sunrise_utc(double lat_deg, double lon_deg,
                           int32_t day_of_year) {
    double decl  = metero_solar_declination(day_of_year);
    double eot   = metero_equation_of_time(day_of_year);
    double ha    = metero_sunrise_hour_angle(lat_deg, decl);
    double noon  = mocha_float_sub(12.0,
        mocha_float_add(
            mocha_float_div(lon_deg, 15.0),
            mocha_float_div(eot, 60.0)));
    return mocha_float_sub(noon,
        mocha_float_div(ha, 15.0));
}

/* Sunset time (decimal hours UTC) */
double metero_sunset_utc(double lat_deg, double lon_deg,
                          int32_t day_of_year) {
    double decl  = metero_solar_declination(day_of_year);
    double eot   = metero_equation_of_time(day_of_year);
    double ha    = metero_sunrise_hour_angle(lat_deg, decl);
    double noon  = mocha_float_sub(12.0,
        mocha_float_add(
            mocha_float_div(lon_deg, 15.0),
            mocha_float_div(eot, 60.0)));
    return mocha_float_add(noon,
        mocha_float_div(ha, 15.0));
}

/* Daylight hours */
double metero_daylight_hours(double lat_deg, int32_t day_of_year) {
    double decl = metero_solar_declination(day_of_year);
    double ha   = metero_sunrise_hour_angle(lat_deg, decl);
    return mocha_float_div(mocha_float_mul(2.0, ha), 15.0);
}

/* Extraterrestrial radiation (MJ/m²/day) — top of atmosphere */
double metero_extraterrestrial_radiation(double lat_deg, int32_t day_of_year) {
    double lat_r = mocha_float_mul(lat_deg, METERO_DEG2RAD);
    double decl  = metero_solar_declination(day_of_year);
    double decl_r = mocha_float_mul(decl, METERO_DEG2RAD);
    double ha    = metero_sunrise_hour_angle(lat_deg, decl);
    double ha_r  = mocha_float_mul(ha, METERO_DEG2RAD);
    /* Dr — relative earth-sun distance */
    double b     = mocha_float_mul(
        mocha_float_mul(2.0, METERO_PI),
        mocha_float_div((double)day_of_year, 365.0));
    double dr    = mocha_float_add(1.0,
        mocha_float_mul(0.033,
            mocha_ext_float_cos(b, 0)));
    /* Ra = (24*60/pi) * Gsc * dr * (ws*sin(lat)*sin(decl) + cos(lat)*cos(decl)*sin(ws)) */
    double gsc   = 0.0820; /* MJ/m²/min */
    double term1 = mocha_float_mul(ha_r,
        mocha_float_mul(mocha_ext_float_sin(lat_r, 0),
                        mocha_ext_float_sin(decl_r, 0)));
    double term2 = mocha_float_mul(mocha_ext_float_cos(lat_r, 0),
        mocha_float_mul(mocha_ext_float_cos(decl_r, 0),
                        mocha_ext_float_sin(ha_r, 0)));
    return mocha_float_mul(
        mocha_float_mul(
            mocha_float_div(mocha_float_mul(24.0, 60.0), METERO_PI),
            mocha_float_mul(gsc, dr)),
        mocha_float_add(term1, term2));
}

/* Clear sky solar radiation (MJ/m²/day) — Hargreaves */
double metero_clear_sky_radiation(double lat_deg, int32_t day_of_year,
                                   double elevation_m) {
    double ra  = metero_extraterrestrial_radiation(lat_deg, day_of_year);
    double krs = mocha_float_add(0.75,
        mocha_float_mul(2.0E-5, elevation_m));
    return mocha_float_mul(krs, ra);
}

/* UV Index from solar elevation and ozone column */
double metero_uv_index(double solar_elev_deg, double ozone_du) {
    if (solar_elev_deg <= 0.0) return 0.0;
    /* Simplified: UVI = 0.4 * (elev/90)^1.5 * (300/ozone) * 11 */
    double elev_norm = mocha_float_div(solar_elev_deg, 90.0);
    double ozone_factor = mocha_float_div(300.0, ozone_du);
    return mocha_float_mul(
        mocha_float_mul(0.4,
            exp(mocha_float_mul(1.5,
                mocha_ext_float_log(elev_norm)->real))),
        mocha_float_mul(ozone_factor, 11.0));
}

/* Photosynthetically Active Radiation (PAR) from global radiation */
double metero_par(double global_radiation_wm2) {
    /* PAR ≈ 45% of global solar radiation */
    return mocha_float_mul(global_radiation_wm2, 0.45);
}

/* Net radiation estimate */
double metero_net_radiation(double rs_mj_m2_day, double t_max_c,
                             double t_min_c, double rh_mean,
                             double ra_mj_m2_day, double elevation_m) {
    /* Rns — net shortwave */
    double alpha = 0.23; /* albedo grass reference */
    double rns   = mocha_float_mul(mocha_float_sub(1.0, alpha), rs_mj_m2_day);
    /* Rnl — net longwave (FAO-56) */
    double t_max_k = mocha_float_add(t_max_c, 273.15);
    double t_min_k = mocha_float_add(t_min_c, 273.15);
    double sigma   = 4.903E-9; /* Stefan-Boltzmann MJ/m²/day/K⁴ */
    double ea      = metero_sat_vp(mocha_float_div(
        mocha_float_add(t_max_c, t_min_c), 2.0));
    ea = mocha_float_mul(ea, mocha_float_div(rh_mean, 100.0));
    double rso     = metero_clear_sky_radiation(0.0, 182, elevation_m);
    double rs_rso  = mocha_float_div(rs_mj_m2_day, rso);
    if (rs_rso > 1.0) rs_rso = 1.0;
    double cloud_f = mocha_float_sub(
        mocha_float_mul(1.35, rs_rso), 0.35);
    double humid_f = mocha_float_sub(0.34,
        mocha_float_mul(0.14, mocha_ext_float_sqrt(ea)->real));
    double t4_mean = mocha_float_div(
        mocha_float_add(
            mocha_float_mul(mocha_float_mul(t_max_k, t_max_k),
                            mocha_float_mul(t_max_k, t_max_k)),
            mocha_float_mul(mocha_float_mul(t_min_k, t_min_k),
                            mocha_float_mul(t_min_k, t_min_k))),
        2.0);
    double rnl = mocha_float_mul(
        mocha_float_mul(sigma, t4_mean),
        mocha_float_mul(humid_f, cloud_f));
    return mocha_float_sub(rns, rnl);
}

/* ============================================================
 * mocha-metero C helpers — Climate Statistics
 * ============================================================ */

/* Heating Degree Days — base temp default 18C */
double metero_hdd(double t_mean_c, double base_c) {
    double diff = mocha_float_sub(base_c, t_mean_c);
    return diff > 0.0 ? diff : 0.0;
}

/* Cooling Degree Days */
double metero_cdd(double t_mean_c, double base_c) {
    double diff = mocha_float_sub(t_mean_c, base_c);
    return diff > 0.0 ? diff : 0.0;
}

/* Growing Degree Days */
double metero_gdd(double t_max_c, double t_min_c,
                   double base_c, double cap_c) {
    double t_max_cap = t_max_c > cap_c ? cap_c : t_max_c;
    double t_min_cap = t_min_c < base_c ? base_c : t_min_c;
    double mean = mocha_float_div(
        mocha_float_add(t_max_cap, t_min_cap), 2.0);
    double gdd = mocha_float_sub(mean, base_c);
    return gdd > 0.0 ? gdd : 0.0;
}

/* Temperature anomaly from climatological mean */
double metero_temp_anomaly(double observed_c, double climatology_c) {
    return mocha_float_sub(observed_c, climatology_c);
}

/* Standardised anomaly (z-score) */
double metero_standardised_anomaly(double observed,
                                    double mean, double std_dev) {
    if (std_dev == 0.0) return 0.0;
    return mocha_float_div(
        mocha_float_sub(observed, mean), std_dev);
}

/* Percentile rank of value in sorted climatology array */
double metero_percentile_rank(double value, double* clim,
                               int32_t n) {
    int32_t below = 0;
    for (int32_t i = 0; i < n; i++)
        if (clim[i] < value) below++;
    return mocha_float_mul(
        mocha_float_div((double)below, (double)n), 100.0);
}

/* Running mean — n-day moving average */
double metero_running_mean(double* values, int32_t n,
                            int32_t window) {
    if (n < window) return 0.0;
    double sum = 0.0;
    for (int32_t i = n - window; i < n; i++)
        sum = mocha_float_add(sum, values[i]);
    return mocha_float_div(sum, (double)window);
}

/* Frost days count in array */
int32_t metero_frost_days(double* t_min_arr, int32_t n) {
    int32_t count = 0;
    for (int32_t i = 0; i < n; i++)
        if (t_min_arr[i] < 0.0) count++;
    return count;
}

/* Summer days count — t_max > 25C */
int32_t metero_summer_days(double* t_max_arr, int32_t n) {
    int32_t count = 0;
    for (int32_t i = 0; i < n; i++)
        if (t_max_arr[i] > 25.0) count++;
    return count;
}

/* Tropical nights count — t_min > 20C */
int32_t metero_tropical_nights(double* t_min_arr, int32_t n) {
    int32_t count = 0;
    for (int32_t i = 0; i < n; i++)
        if (t_min_arr[i] > 20.0) count++;
    return count;
}

/* Consecutive dry days — longest run without rain */
int32_t metero_consecutive_dry_days(double* precip_arr,
                                     int32_t n, double threshold_mm) {
    int32_t max_run = 0, current = 0;
    for (int32_t i = 0; i < n; i++) {
        if (precip_arr[i] < threshold_mm) {
            current++;
            if (current > max_run) max_run = current;
        } else {
            current = 0;
        }
    }
    return max_run;
}

/* Consecutive wet days */
int32_t metero_consecutive_wet_days(double* precip_arr,
                                     int32_t n, double threshold_mm) {
    int32_t max_run = 0, current = 0;
    for (int32_t i = 0; i < n; i++) {
        if (precip_arr[i] >= threshold_mm) {
            current++;
            if (current > max_run) max_run = current;
        } else {
            current = 0;
        }
    }
    return max_run;
}

/* Simple drought index — SPI approximation from z-score */
double metero_spi(double precip, double mean_precip,
                   double std_precip) {
    if (std_precip == 0.0) return 0.0;
    return mocha_float_div(
        mocha_float_sub(precip, mean_precip), std_precip);
}

/* Thornthwaite PET (mm/month) */
double metero_pet_thornthwaite(double t_mean_c, double heat_index,
                                double daylight_hr, int32_t days_in_month) {
    if (t_mean_c <= 0.0) return 0.0;
    double alpha = mocha_float_add(
        mocha_float_add(
            mocha_float_mul(6.75E-7, mocha_float_mul(heat_index,
                mocha_float_mul(heat_index, heat_index))),
            mocha_float_mul(-7.71E-5,
                mocha_float_mul(heat_index, heat_index))),
        mocha_float_add(
            mocha_float_mul(1.792E-2, heat_index),
            0.49239));
    double et0 = mocha_float_mul(16.0,
        exp(mocha_float_mul(alpha,
            mocha_ext_float_log(
                mocha_float_div(
                    mocha_float_mul(10.0, t_mean_c),
                    heat_index))->real)));
    return mocha_float_mul(et0,
        mocha_float_mul(
            mocha_float_div(daylight_hr, 12.0),
            mocha_float_div((double)days_in_month, 30.0)));
}

/* ============================================================
 * mocha-metero C helpers — Large-Scale Climate Indices & Cyclones
 * ============================================================ */

/* Cyclone category from max sustained wind speed (km/h) */
int32_t metero_saffir_simpson_category(double wind_kmh) {
    if (wind_kmh < 63.0)   return 0; /* TD/TS */
    if (wind_kmh < 119.0)  return 1;
    if (wind_kmh < 154.0)  return 2;
    if (wind_kmh < 177.0)  return 3;
    if (wind_kmh < 209.0)  return 4;
    return 5;
}

/* JMA Typhoon scale (Western Pacific) */
int32_t metero_jma_category(double wind_kmh) {
    if (wind_kmh < 63.0)   return 0; /* TD */
    if (wind_kmh < 88.0)   return 1; /* Tropical Storm */
    if (wind_kmh < 118.0)  return 2; /* Strong TS */
    if (wind_kmh < 150.0)  return 3; /* Typhoon */
    if (wind_kmh < 180.0)  return 4; /* Strong Typhoon */
    return 5; /* Very Strong Typhoon */
}

/* IMD Scale (Indian Ocean cyclones) */
int32_t metero_imd_category(double wind_kmh) {
    if (wind_kmh < 63.0)   return 0; /* Depression */
    if (wind_kmh < 89.0)   return 1; /* Deep Depression */
    if (wind_kmh < 119.0)  return 2; /* Cyclonic Storm */
    if (wind_kmh < 150.0)  return 3; /* Severe Cyclonic Storm */
    if (wind_kmh < 180.0)  return 4; /* Very Severe Cyclonic Storm */
    return 5; /* Super Cyclonic Storm */
}

/* ENSO phase from ONI value */
int32_t metero_enso_phase(double oni) {
    if (oni >= 0.5)   return 1;  /* El Niño */
    if (oni <= -0.5)  return -1; /* La Niña */
    return 0; /* Neutral */
}

/* IOD phase from DMI value */
int32_t metero_iod_phase(double dmi) {
    if (dmi >= 0.4)   return 1;  /* Positive IOD */
    if (dmi <= -0.4)  return -1; /* Negative IOD */
    return 0; /* Neutral */
}

/* NAO/SAM phase */
int32_t metero_ao_phase(double ao_index) {
    if (ao_index >= 0.5)   return 1;  /* Positive */
    if (ao_index <= -0.5)  return -1; /* Negative */
    return 0; /* Neutral */
}

//Stragglers from Section 3. Got left out
/* ISA pressure at altitude */
double metero_isa_pressure(double altitude_m) {
    if (altitude_m <= 11000.0) {
        double ratio = mocha_float_div(
            mocha_float_add(288.15, mocha_float_mul(-0.0065, altitude_m)),
            288.15);
        return mocha_float_mul(1013.25,
            exp(mocha_float_mul(5.2561,
                mocha_ext_float_log(ratio)->real)));
    }
    /* Isothermal stratosphere */
    double p11 = 226.32;
    double exp_arg = mocha_float_div(
        mocha_float_mul(-0.0341631, mocha_float_sub(altitude_m, 11000.0)),
        216.65);
    return mocha_float_mul(p11, exp(exp_arg));
}

/* ISA density (kg/m³) at altitude */
double metero_isa_density(double altitude_m) {
    double p  = metero_isa_pressure(altitude_m);
    double t_k = mocha_float_add(metero_isa_temp(altitude_m), 273.15);
    return mocha_float_div(
        mocha_float_mul(p, 100.0),
        mocha_float_mul(287.05, t_k));
}

/* Altimeter setting (mb) from station pressure and elevation */
double metero_altimeter_setting(double station_pressure_mb, double elevation_m) {
    double isa_sl  = 1013.25;
    double exp_arg = mocha_float_mul(0.190284,
        mocha_ext_float_log(mocha_float_div(isa_sl, station_pressure_mb))->real);
    double ratio   = mocha_float_add(1.0,
        mocha_float_mul(
            mocha_float_div(0.0065, 288.15),
            mocha_float_mul(elevation_m, exp(exp_arg))));
    return mocha_float_mul(station_pressure_mb,
        exp(mocha_float_mul(5.2561,
            mocha_ext_float_log(ratio)->real)));
}

/* Thickness (m) between two pressure levels */
double metero_thickness(double p_upper_mb, double p_lower_mb, double mean_temp_c) {
    double t_k = mocha_float_add(mean_temp_c, 273.15);
    return mocha_float_mul(
        mocha_float_mul(287.05 / 9.80665, t_k),
        mocha_ext_float_log(mocha_float_div(p_lower_mb, p_upper_mb))->real);
}

/* For Mocha-space */
//Bypasses fixed-point decimal scaling entirely. Use ONLY for values outside
//safe fixed-point range (~1e13+). No drift protection — raw IEEE 754.

double mocha_unsafe_mul(double a, double b) { return a * b; }
double mocha_unsafe_div(double a, double b) {
    if (b == 0.0) { fprintf(stderr, "MochaRuntimeError: Division by zero!\n"); exit(2); }
    return a / b;
}
double mocha_unsafe_add(double a, double b) { return a + b; }
double mocha_unsafe_sub(double a, double b) { return a - b; }
double mocha_unsafe_mod(double a, double b) { return fmod(a, b); }