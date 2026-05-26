/*
 * ============================================================
 * Mocha Language Runtime
 * mocha_runtime.c
 *
 * Implements:
 *   - Mark and Sweep Garbage Collector (ORPHANED — scheduled
 *     for replacement with reference counting; currently unused
 *     by codegen)
 *
 *   - String operations (alloc, concat, copy, case, search)
 *   - Complex number arithmetic (MochaComplex)
 *   - Print functions (int, float, str, bool, vast, newline variants)
 *   - Type conversions (int↔float↔str↔vast↔bool)
 *   - Fixed-point arithmetic (scaled by 10^12, __int128 overflow guard)
 *
 *   - 1D Array runtime (MochaArray)
 *   - 2D Array runtime (MochaArray2D)
 *   - Tuple runtime (MochaTuple)
 *   - Dict runtime (MochaDict, string keys, typed values,
 *                   Levenshtein fuzzy key suggestions)
 *   - Set runtime (MochaSet, unique ordered values,
 *                  union/intersect/xor/rel_diff)
 *   - HashTable runtime (MochaHashTable, open-addressed,
 *                        FNV-1a hash, quadratic probing)
 *   - StringBuilder runtime (MochaStringBuilder)
 *
 *   - Sorting (hybrid selection+merge, typed + comparator variants)
 *   - Math extensions (trig, log, roots, pow, derivative,
 *                      integral, limit, MochaComplex domain handling)
 *
 *   - File I/O runtime (MochaFile, read/write/append/readline)
 *   - tell() — blocking stdin input with optional prompt
 *
 *   - FFI wrappers — SQLite3, Lua, ctype, system
 *   - Straggler lib wrappers — mocha-processing (mocha_map_float),
 *                              mocha-matvec (mocha_wrap_sqrt_f),
 *                              mocha-SymCha (mocha_wrap_sin/cos/log)
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
#include <windows.h>
#include <setjmp.h>

//RANDOM NUMBER
#include <bcrypt.h>
#pragma comment(lib, "bcrypt.lib")

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
} GcNode;

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
    if (!(ptr)) { fprintf(stderr, "MochaRuntimeError: Out of memory!\n"); exit(1); }

#define MOCHA_EPSILON        1e-13
#define MOCHA_SORT_THRESHOLD 16

double mocha_call_lambda_float(MochaClosureBundle *b, void *a, void *c);

/* ---- Garbage Collector (orphaned) ---- */
#define GC_THRESHOLD  1024
#define MAX_ROOTS     4096

/* ---- Bounds Checking ---- */

#define MOCHA_BOUNDS_CHECK_ROW(arr, row) \
    if ((row) < 0 || (row) >= (arr)->rows) { \
        fprintf(stderr, "Index_Out_Of_Bounds Error: row %d out of range [0, %d)\n", row, (arr)->rows); \
        exit(1); \
    }

#define MOCHA_BOUNDS_CHECK_COL(arr, col) \
    if ((col) < 0 || (col) >= (arr)->cols) { \
        fprintf(stderr, "Index_Out_Of_Bounds Error: col %d out of range [0, %d)\n", col, (arr)->cols); \
        exit(1); \
    }

/* ---- Fixed-Point Arithmetic ---- */
#define MOCHA_DECIMAL_SCALE 1000000000000LL

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
        _Exit(1);                                                             \
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
        _Exit(1);                                                             \
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
        _Exit(1);                                                             \
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
        _Exit(1);                                                             \
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
    gc_head = NULL; gc_alloc_count = 0; gc_root_count = 0;
}

void mocha_gc_shutdown() {
    GcNode *node = gc_head;
    while (node) { GcNode *next = node->next; free(node); node = next; }
    gc_head = NULL; gc_alloc_count = 0;
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
    if (!node) { fprintf(stderr, "MochaRuntimeError: Out of memory!\n"); exit(1); }
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
        exit(1);
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
                "[Mocha] format error: positional format string contains named "
                "placeholder '$%c...'. Do not mix positional and named placeholders.\n",
                *(p+1));
            exit(1);
        } else if (*p == '$' && !isdigit(*(p+1))) {
            fprintf(stderr,
                "MochaRuntimeError (.format): invalid placeholder '$%c': "
                "'$' must be followed by a digit (positional) or letter/underscore (named)\n",
                *(p+1));
            exit(1);
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
                exit(1);
            }
            if (idx >= argc) {
                fprintf(stderr,
                    "MochaRuntimeError (.format): index $%d out of range "
                    "(%d argument%s provided)\n",
                    idx, argc, argc == 1 ? "" : "s");
                exit(1);
            }
            // check for pipe specifier
            if (*p == '|') {
                p++;
                int decimals = 0;
                if (!mocha_parse_pipe_spec(p, &decimals)) {
                    fprintf(stderr,
                        "MochaRuntimeError (.format): invalid format specifier after '|'. "
                        "Expected format: Nf (e.g. |2f)\n");
                    exit(1);
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
                    exit(1);
                }
                fprintf(stderr,
                    "MochaRuntimeError (.format): named format string contains positional "
                    "placeholder '$%d'. Do not mix positional and named placeholders.\n",
                    idx);
                exit(1);
            } else if (isalpha(*p) || *p == '_') {
                char name[256]; int ni = 0;
                while (isalnum(*p) || *p == '_') {
                    if (ni >= 255) {
                        fprintf(stderr, "MochaRuntimeError (.format): placeholder name too long.\n");
                        exit(1);
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
                        exit(1);
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
                    exit(1);
                }
            } else {
                fprintf(stderr,
                    "MochaRuntimeError (.format): invalid placeholder '$%c': "
                    "'$' must be followed by a digit (positional) or letter/underscore (named)\n",
                    *p);
                exit(1);
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
        exit(1);
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
 * NEED SO MANY BECAUSE C DOES NOT HAVE GENERICS (PATTERN SAME IN ALL FROM NOW ON)
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
        printf("%s", f > 0 ? "Inf" : "-Inf");
    } else if (isnan(f)) {
        printf("NaN");
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

typedef __int128 mocha_decimal;

static mocha_decimal decimal_from(double x) { 
    return (mocha_decimal)llround(x * (double)MOCHA_DECIMAL_SCALE); 
}

static double decimal_to(mocha_decimal f) { 
    mocha_decimal int_part  = f / MOCHA_DECIMAL_SCALE;
    mocha_decimal frac_part = f % MOCHA_DECIMAL_SCALE;
    return (double)int_part + (double)frac_part / (double)MOCHA_DECIMAL_SCALE;
}

double mocha_float_add(double a, double b) { 
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to(a_s + b_s);
}

double mocha_float_sub(double a, double b) { 
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to(a_s - b_s);
}

double mocha_float_mul(double a, double b) {
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to((a_s * b_s) / (mocha_decimal)MOCHA_DECIMAL_SCALE);
}

double mocha_float_div(double a, double b) {
    if (b == 0.0) { fprintf(stderr, "MochaRuntimeError: Division by zero!\n"); exit(1); }
    mocha_decimal a_s = decimal_from(a);
    mocha_decimal b_s = decimal_from(b);
    return decimal_to((a_s * (mocha_decimal)MOCHA_DECIMAL_SCALE) / b_s);
}

double mocha_float_mod(double a, double b) {
    if (b == 0.0) { fprintf(stderr, "MochaRuntimeError: Division by zero!\n"); exit(1); }
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
        exit(1);
    }
}

static void fixed_check(MochaArray *arr, const char *op) {
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot %s a fixed-size array\n", op);
        exit(1);
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
    // Static arrays cannot be pushed to
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot push to static array (created with 'alloc'). Use indexing instead.");
        exit(1);
    }
    ensure_capacity(arr);
    memcpy((char *)arr->data + arr->length * arr->elem_size, value, arr->elem_size);
    arr->length++;
}

void mocha_array_push_front(MochaArray *arr, void *value) {
    // Static arrays cannot be pushed to
    if (arr->fixed) {
        fprintf(stderr, "MochaRuntimeError: Cannot push_front to static array (created with 'alloc'). Use indexing instead.");
        exit(1);
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
        exit(1);
    }
    if (arr->length == 0) {
        fprintf(stderr, "MochaRuntimeError: Cannot pop from empty array\n");
        exit(1);
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
        _Exit(1);
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
        _Exit(1);
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
        exit(1);
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
        exit(1);
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

/* ---- Resize — grow only, never shrink ---- */
void mocha_array2d_resize(MochaArray2D *arr, int32_t new_rows,
                           int32_t new_cols, int32_t elem_size) {
    if (new_rows < arr->rows || new_cols < arr->cols) {
        fprintf(stderr, "MochaRuntimeError: resize() can only grow a 2D array, not shrink it.\n");
        exit(1);
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
        exit(1);
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
        exit(1);
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
        exit(1);
    }
    return 1.0 / tanh(x);
}

/* ── Inverse Reciprocal Hyperbolic ── */

double mocha_ext_float_inv_cosech_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (inv_cosech): argument is 0, inv_cosech is undefined at 0.\n");
        exit(1);
    }
    // inv_cosech(x) = asinh(1/x) — defined for all x != 0
    return asinh(1.0 / x);
}

MochaComplex* mocha_ext_float_inv_sech_c(double x) {
    if (x == 0.0) {
        fprintf(stderr, "MochaRuntimeError (inv_sech): argument is 0, inv_sech is undefined at 0.\n");
        exit(1);
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
        exit(1);
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
    if (base < 0.0) { fprintf(stderr, "MochaMathError: c_pow requires positive base\n"); exit(1); }
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
 * BCryptGenRandom — Cryptographic RNG
 * Much better than rand() — uses OS entropy source
 * ============================================================ */

/* Random int between min and max inclusive */
int mocha_bcrypt_rand_int(int min, int max) {
    if (min >= max) return min;
    unsigned int range = (unsigned int)(max - min + 1);
    unsigned int limit = UINT_MAX - (UINT_MAX % range); // largest multiple of range
    unsigned int raw;
    do {
        BCryptGenRandom(NULL, (PUCHAR)&raw, sizeof(raw), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    } while (raw >= limit); // reject the biased tail
    return min + (int)(raw % range);
}

/* Random float between min and max */
double mocha_bcrypt_rand_float(double min, double max) {
    unsigned int raw = 0;
    BCryptGenRandom(NULL, (PUCHAR)&raw, sizeof(raw), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    double normalized = (double)raw / (double)UINT_MAX;
    return min + normalized * (max - min);
}

/* Random float between 0.0 and 1.0 */
double mocha_bcrypt_rand_unit() {
    unsigned int raw = 0;
    BCryptGenRandom(NULL, (PUCHAR)&raw, sizeof(raw), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    return (double)raw / (double)UINT_MAX;
}

/* Fill a buffer with n random ints */
/* Returns them as a pipe-separated string "42|17|99|..." */
/* Mocha can split on | to get the array */
const char* mocha_bcrypt_rand_ints(int min, int max, int count) {
    if (count <= 0 || count > 10000) return "";
    static char buf[131072];  // 128KB — enough for 10000 ints
    buf[0] = '\0';
    int pos = 0;
    for (int i = 0; i < count; i++) {
        unsigned int raw = 0;
        BCryptGenRandom(NULL, (PUCHAR)&raw, sizeof(raw), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
        int range = max - min + 1;
        int val = min + (int)(raw % (unsigned int)range);
        pos += snprintf(buf + pos, sizeof(buf) - pos, 
                       i < count-1 ? "%d|" : "%d", val);
    }
    return buf;
}

/* Random bool — cryptographically fair coin flip */
int mocha_bcrypt_rand_bool() {
    unsigned char raw = 0;
    BCryptGenRandom(NULL, &raw, sizeof(raw), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    return raw % 2;
}

/* Random seed — get a good seed for other RNGs */
int mocha_bcrypt_rand_seed() {
    unsigned int raw = 0;
    BCryptGenRandom(NULL, (PUCHAR)&raw, sizeof(raw), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    return (int)(raw & 0x7FFFFFFF);  // positive int
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
 * Hash map (not so real one LoL) with string keys and typed values.
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
        exit(1);
    }
    if (d->entries[idx].value_type != MOCHA_DICT_DICT) {
        fprintf(stderr, "MochaRuntimeError: Key '%s' is not a dict.\n", key);
        exit(1);
    }
    return (MochaDict*)d->entries[idx].value;
}

void* mocha_dict_get_typed(MochaDict *d, char *key, int32_t expected) {
    void *val = mocha_dict_get(d, key);  // existing fuzzy lookup
    int idx = mocha_dict_find(d, key);
    if (idx < 0) return val;  // already errored in mocha_dict_get
    int actual = d->entries[idx].value_type;
    // Allow object type to pass through (FFI handles)
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
        exit(1);
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
    if (idx < 0) { fprintf(stderr, "MochaRuntimeError: Cannot remove key '%s' — not found.\n", key); exit(1); }
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
                exit(1);
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
    if (idx < 0) { fprintf(stderr, "MochaRuntimeError: Key '%s' not found.\n", key); exit(1); }
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
        exit(1);
    }
    /* Shift elements left to fill the gap */
    for (int32_t i = idx; i < s->size - 1; i++) {
        void *curr = (char *)s->data + i       * s->elem_size;
        void *next = (char *)s->data + (i + 1) * s->elem_size;
        memcpy(curr, next, s->elem_size);
    }
    s->size--;
}

void mocha_set_retype(MochaSet *s, int32_t new_type) {
    if (s->elem_type != new_type)
        fprintf(stderr, "### WARNING: Set type changed — previous data cleared.\n");
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
        exit(1);
    }
}

/* ---- Utility ---- */
void mocha_set_get(MochaSet *s, int32_t index, void *out) {
    if (index < 0 || index >= s->size) {
        fprintf(stderr, "MochaRuntimeError: Set index %d out of bounds [0, %d).\n",
                index, s->size);
        exit(1);
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
        _Exit(1);
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
        _Exit(1);
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

/* ============================================================
 * STOPWATCH / TIME FFI
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
    LARGE_INTEGER freq, count;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&count);
    double ms = (double)count.QuadPart / (double)freq.QuadPart * 1000.0;
    if (mocha_wall_start == 0.0) { mocha_wall_start = ms; }
    return ms - mocha_wall_start;
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
double mocha_wrap_hypot(double x, double y) { return _hypot(x, y); }
double mocha_wrap_fmod(double x, double y)  { return fmod(x, y);   }
double mocha_wrap_erf(double x)    { return erf(x);    }
double mocha_wrap_tgamma(double x) { return tgamma(x); }
double mocha_wrap_lgamma(double x) { return lgamma(x); }
double mocha_wrap_exp(double x)    { return exp(x);    }

/* ---- system wrappers ---- */
int mocha_wrap_system(const char *cmd) { return system(cmd); }

/* ---- RUNTIME CONTROL ---- */

//Flush stdout before writing — prevents interleaved output on error
void* mocha_print_stderr(const char *msg) {
    fflush(stdout);
    fprintf(stderr, "%s\n", msg);
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

/* ============================================================
 * WREN FFI
 * ============================================================ */

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

/* INSERT HERE NEXT FFI*/

// ============================================================
// STRING BUILDER
// ============================================================

MochaStringBuilder* mocha_sb_new() {
    MochaStringBuilder *sb = (MochaStringBuilder*)malloc(sizeof(MochaStringBuilder));
    MOCHA_OOM_CHECK(sb);
    sb->capacity = 64;
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
    exit(1);
}

/* ---- Construction ---- */ 
MochaFile* mocha_file_open(char *path, char *mode) {
    const char *c_mode = resolve_mode(mode);
    FILE *handle = fopen(path, c_mode);
    if (!handle) {
        fprintf(stderr, "MochaRuntimeError: Could not open file '%s' in mode \"%s\".\n"
                        "    Check the path exists and permissions are correct.\n",
                        path, mode);
        exit(1);
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
        exit(1);
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
        exit(1);
    }
    return buf;
}

//Read one line — returns "" at EOF
char* mocha_file_readline(MochaFile *f) {
    if (!f->is_open) {
        fprintf(stderr, "MochaRuntimeError: Cannot read from closed file '%s'.\n", f->path);
        exit(1);
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

    buf[len] = '\0';
    return buf;
}

/* ---- Write operation ---- */ 
void mocha_file_write(MochaFile *f, char *content) {
    if (!f->is_open) {
        fprintf(stderr, "MochaRuntimeError: Cannot write to closed file '%s'.\n", f->path);
        exit(1);
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
static uint32_t ht_fnv1a(const char *key) {
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
    exit(1);
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
        exit(1);
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
        exit(1);
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
        exit(1);
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
        exit(1);
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
        exit(1);
    }
    const char* msg = ((MochaExFrame*)mocha_ex_top)->message;
    mocha_ex_top = ((MochaExFrame*)mocha_ex_top)->prev;
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Unhandled exception: %s\n", msg);
        exit(1);
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
        exit(1);
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
        exit(1);
    }
    MochaExFrame* frame = (MochaExFrame*)mocha_ex_top;
    frame->message = msg;
    frame->active  = 1;
    longjmp(frame->env, 1);
}

void mocha_ex_rethrow(void) {
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): rethrow with no active exception.\n");
        exit(1);
    }
    const char* msg = ((MochaExFrame*)mocha_ex_top)->message;
    mocha_ex_top = ((MochaExFrame*)mocha_ex_top)->prev;
    if (!mocha_ex_top) {
        fprintf(stderr, "MochaRuntimeError (try/rescue): Unhandled exception: %s\n", msg);
        exit(1);
    }
    MocrafFrame* frame = (MochaExFrame*)mocha_ex_top;
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
        exit(1);
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