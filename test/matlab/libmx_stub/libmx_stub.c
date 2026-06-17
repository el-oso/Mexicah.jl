/*
 * libmx_stub.c — Minimal libmx/libmex stub for testing Mexicah marshalers
 * without a MATLAB installation.
 *
 * When preloaded with RTLD_GLOBAL on Linux, bare ccall(:mxFoo, ...) resolves
 * to these implementations, enabling the :matlab-tagged test items to run
 * against the stub (no MATLAB license required).
 *
 * Only Linux bare names are needed: @mxccall730 on Linux still expands to bare
 * names (the _730 suffix is Windows-only via _ccall_with_lib win_suffix="").
 *
 * The stub is intentionally simple: it allocates heap memory, stores metadata
 * in a flat struct, and returns raw pointers that the marshalers read/write.
 * It is NOT thread-safe and does NOT implement the full MATLAB C API — only
 * the ~50 functions exercised by marshaling.jl.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ── mxClassID constants (match MATLAB's enum) ──────────────────────────── */
#define MX_UNKNOWN_CLASS   0
#define MX_CELL_CLASS      1
#define MX_STRUCT_CLASS    2
#define MX_LOGICAL_CLASS   3
#define MX_CHAR_CLASS      4
#define MX_DOUBLE_CLASS    6
#define MX_SINGLE_CLASS    7
#define MX_INT8_CLASS      8
#define MX_UINT8_CLASS     9
#define MX_INT16_CLASS     10
#define MX_UINT16_CLASS    11
#define MX_INT32_CLASS     12
#define MX_UINT32_CLASS    13
#define MX_INT64_CLASS     14
#define MX_UINT64_CLASS    15

/* ── Complexity flags ────────────────────────────────────────────────────── */
#define MX_REAL    0
#define MX_COMPLEX 1

/* ── Internal mxArray representation ────────────────────────────────────── */
typedef struct _mx_stub {
    int classid;
    int is_complex;
    int is_sparse;
    /* dimensions */
    size_t m, n;       /* 2-D extents (also used for 1-D: m=nelems, n=1) */
    size_t ndim;
    size_t *dims;      /* copy of the full dims array */
    size_t nelems;     /* product of dims */
    /* numeric / logical / char data */
    void *pr;          /* real data (or char bytes) */
    void *pi;          /* imaginary data (NULL if real) */
    /* sparse indices */
    size_t nzmax;
    size_t *ir;        /* row indices, 0-based */
    size_t *jc;        /* column pointers, 0-based */
    /* struct fields */
    int nfields;
    char **fieldnames; /* nfields null-terminated strings */
    struct _mx_stub **fields; /* [nfields × nelems] row-major: fields[f*nelems+e] */
    /* cell elements */
    struct _mx_stub **cells;  /* [nelems] */
} mx_stub_t;

typedef mx_stub_t *mxArray;

/* ── Helpers ─────────────────────────────────────────────────────────────── */
static size_t element_size(int classid) {
    switch (classid) {
        case MX_LOGICAL_CLASS: return 1;
        case MX_CHAR_CLASS:    return 2;  /* mxChar = uint16_t */
        case MX_INT8_CLASS:    return 1;
        case MX_UINT8_CLASS:   return 1;
        case MX_INT16_CLASS:   return 2;
        case MX_UINT16_CLASS:  return 2;
        case MX_INT32_CLASS:   return 4;
        case MX_UINT32_CLASS:  return 4;
        case MX_SINGLE_CLASS:  return 4;
        case MX_INT64_CLASS:   return 8;
        case MX_UINT64_CLASS:  return 8;
        case MX_DOUBLE_CLASS:  return 8;
        default:               return 8;
    }
}

static mx_stub_t *alloc_stub(void) {
    mx_stub_t *p = (mx_stub_t *)calloc(1, sizeof(mx_stub_t));
    if (!p) { perror("libmx_stub: calloc"); abort(); }
    return p;
}

static size_t prod(size_t ndim, const size_t *dims) {
    size_t n = 1;
    for (size_t i = 0; i < ndim; i++) n *= dims[i];
    return n;
}

static mx_stub_t *make_numeric(size_t m, size_t n, int classid, int complex) {
    mx_stub_t *p = alloc_stub();
    p->classid    = classid;
    p->is_complex = complex;
    p->m          = m;
    p->n          = n;
    p->ndim       = 2;
    p->dims       = (size_t *)malloc(2 * sizeof(size_t));
    p->dims[0]    = m;
    p->dims[1]    = n;
    p->nelems     = m * n;
    size_t esz    = element_size(classid);
    p->pr         = calloc(p->nelems, esz);
    if (complex)
        p->pi     = calloc(p->nelems, esz);
    return p;
}

/* ── Creation ────────────────────────────────────────────────────────────── */

mxArray mxCreateDoubleMatrix(size_t m, size_t n, int complex_flag) {
    return make_numeric(m, n, MX_DOUBLE_CLASS, complex_flag);
}

mxArray mxCreateDoubleScalar(double v) {
    mx_stub_t *p = make_numeric(1, 1, MX_DOUBLE_CLASS, 0);
    *(double *)p->pr = v;
    return p;
}

mxArray mxCreateNumericMatrix(size_t m, size_t n, int classid, int complex_flag) {
    return make_numeric(m, n, classid, complex_flag);
}

mxArray mxCreateNumericArray(size_t ndim, const size_t *dims, int classid, int complex_flag) {
    mx_stub_t *p = alloc_stub();
    p->classid    = classid;
    p->is_complex = complex_flag;
    p->ndim       = ndim;
    p->dims       = (size_t *)malloc(ndim * sizeof(size_t));
    memcpy(p->dims, dims, ndim * sizeof(size_t));
    p->m          = ndim >= 1 ? dims[0] : 1;
    p->n          = ndim >= 2 ? dims[1] : 1;
    p->nelems     = prod(ndim, dims);
    size_t esz    = element_size(classid);
    p->pr         = calloc(p->nelems, esz);
    if (complex_flag)
        p->pi     = calloc(p->nelems, esz);
    return p;
}

mxArray mxCreateLogicalMatrix(size_t m, size_t n) {
    return make_numeric(m, n, MX_LOGICAL_CLASS, 0);
}

/* 2-D logical alias used by LogicalArrayMarshaler for rank-1/2 */
mxArray mxCreateLogicalArray(size_t ndim, const size_t *dims) {
    return mxCreateNumericArray(ndim, dims, MX_LOGICAL_CLASS, 0);
}

mxArray mxCreateSparse(size_t m, size_t n, size_t nzmax, int complex_flag) {
    mx_stub_t *p = alloc_stub();
    p->classid    = MX_DOUBLE_CLASS;
    p->is_sparse  = 1;
    p->is_complex = complex_flag;
    p->m          = m;
    p->n          = n;
    p->ndim       = 2;
    p->dims       = (size_t *)malloc(2 * sizeof(size_t));
    p->dims[0]    = m; p->dims[1] = n;
    p->nelems     = m * n;
    p->nzmax      = nzmax > 0 ? nzmax : 1;
    p->ir         = (size_t *)calloc(p->nzmax, sizeof(size_t));
    p->jc         = (size_t *)calloc(n + 1,    sizeof(size_t));
    p->pr         = calloc(p->nzmax, sizeof(double));
    if (complex_flag)
        p->pi     = calloc(p->nzmax, sizeof(double));
    return p;
}

mxArray mxCreateSparseLogicalMatrix(size_t m, size_t n, size_t nzmax) {
    mx_stub_t *p = alloc_stub();
    p->classid    = MX_LOGICAL_CLASS;
    p->is_sparse  = 1;
    p->m          = m;
    p->n          = n;
    p->ndim       = 2;
    p->dims       = (size_t *)malloc(2 * sizeof(size_t));
    p->dims[0]    = m; p->dims[1] = n;
    p->nelems     = m * n;
    p->nzmax      = nzmax > 0 ? nzmax : 1;
    p->ir         = (size_t *)calloc(p->nzmax, sizeof(size_t));
    p->jc         = (size_t *)calloc(n + 1,    sizeof(size_t));
    p->pr         = calloc(p->nzmax, 1);   /* mxLogical = uint8 */
    return p;
}

mxArray mxCreateStructMatrix(size_t m, size_t n, int nfields, const char **fieldnames) {
    mx_stub_t *p = alloc_stub();
    p->classid   = MX_STRUCT_CLASS;
    p->m         = m;
    p->n         = n;
    p->ndim      = 2;
    p->dims      = (size_t *)malloc(2 * sizeof(size_t));
    p->dims[0]   = m; p->dims[1] = n;
    p->nelems    = m * n;
    p->nfields   = nfields;
    p->fieldnames = (char **)malloc(nfields * sizeof(char *));
    for (int i = 0; i < nfields; i++)
        p->fieldnames[i] = strdup(fieldnames[i]);
    p->fields = (mx_stub_t **)calloc((size_t)nfields * p->nelems, sizeof(mx_stub_t *));
    return p;
}

/* N-D struct array; field storage stays [nfields × nelems], same as the 2-D form. */
mxArray mxCreateStructArray(size_t ndim, const size_t *dims, int nfields, const char **fieldnames) {
    mx_stub_t *p = alloc_stub();
    p->classid   = MX_STRUCT_CLASS;
    p->ndim      = ndim;
    p->dims      = (size_t *)malloc(ndim * sizeof(size_t));
    memcpy(p->dims, dims, ndim * sizeof(size_t));
    p->m         = ndim >= 1 ? dims[0] : 1;
    p->n         = ndim >= 2 ? dims[1] : 1;
    p->nelems    = prod(ndim, dims);
    p->nfields   = nfields;
    p->fieldnames = (char **)malloc(nfields * sizeof(char *));
    for (int i = 0; i < nfields; i++)
        p->fieldnames[i] = strdup(fieldnames[i]);
    p->fields = (mx_stub_t **)calloc((size_t)nfields * p->nelems, sizeof(mx_stub_t *));
    return p;
}

mxArray mxCreateCellMatrix(size_t m, size_t n) {
    mx_stub_t *p = alloc_stub();
    p->classid   = MX_CELL_CLASS;
    p->m         = m;
    p->n         = n;
    p->ndim      = 2;
    p->dims      = (size_t *)malloc(2 * sizeof(size_t));
    p->dims[0]   = m; p->dims[1] = n;
    p->nelems    = m * n;
    p->cells     = (mx_stub_t **)calloc(p->nelems, sizeof(mx_stub_t *));
    return p;
}

/* M×N char array; elements are uint16_t (mxChar) stored column-major in pr. */
mxArray mxCreateCharArray(size_t ndim, const size_t *dims) {
    mx_stub_t *p = alloc_stub();
    p->classid = MX_CHAR_CLASS;
    p->ndim    = ndim;
    p->dims    = (size_t *)malloc(ndim * sizeof(size_t));
    memcpy(p->dims, dims, ndim * sizeof(size_t));
    p->m       = ndim >= 1 ? dims[0] : 1;
    p->n       = ndim >= 2 ? dims[1] : 1;
    p->nelems  = prod(ndim, dims);
    p->pr      = calloc(p->nelems, 2);  /* uint16_t per element */
    return p;
}

uint16_t *mxGetChars(mxArray pa) {
    return (uint16_t *)pa->pr;
}

mxArray mxCreateString(const char *str) {
    size_t len = str ? strlen(str) : 0;
    mx_stub_t *p = alloc_stub();
    p->classid = MX_CHAR_CLASS;
    p->m       = 1;
    p->n       = len;
    p->ndim    = 2;
    p->dims    = (size_t *)malloc(2 * sizeof(size_t));
    p->dims[0] = 1; p->dims[1] = len;
    p->nelems  = len;
    p->pr      = malloc(len + 1);
    if (str) memcpy(p->pr, str, len + 1);
    else ((char *)p->pr)[0] = '\0';
    return p;
}

/* ── Lifecycle ───────────────────────────────────────────────────────────── */

void mxDestroyArray(mxArray pa) {
    if (!pa) return;
    free(pa->pr);
    free(pa->pi);
    free(pa->ir);
    free(pa->jc);
    free(pa->dims);
    for (int i = 0; i < pa->nfields; i++) free(pa->fieldnames[i]);
    free(pa->fieldnames);
    if (pa->fields) {
        size_t total = (size_t)pa->nfields * pa->nelems;
        for (size_t i = 0; i < total; i++) mxDestroyArray(pa->fields[i]);
        free(pa->fields);
    }
    if (pa->cells) {
        for (size_t i = 0; i < pa->nelems; i++) mxDestroyArray(pa->cells[i]);
        free(pa->cells);
    }
    free(pa);
}

static mx_stub_t *deep_copy(const mx_stub_t *src);

mxArray mxDuplicateArray(mxArray pa) {
    return pa ? deep_copy(pa) : NULL;
}

static mx_stub_t *deep_copy(const mx_stub_t *src) {
    mx_stub_t *dst = (mx_stub_t *)malloc(sizeof(mx_stub_t));
    *dst = *src;
    if (src->dims) {
        dst->dims = (size_t *)malloc(src->ndim * sizeof(size_t));
        memcpy(dst->dims, src->dims, src->ndim * sizeof(size_t));
    }
    size_t esz = element_size(src->classid);
    if (src->pr) {
        size_t nb = src->is_sparse ? src->nzmax * esz : src->nelems * esz;
        dst->pr = malloc(nb);
        memcpy(dst->pr, src->pr, nb);
    }
    if (src->pi) {
        size_t nb = src->is_sparse ? src->nzmax * esz : src->nelems * esz;
        dst->pi = malloc(nb);
        memcpy(dst->pi, src->pi, nb);
    }
    if (src->ir) {
        dst->ir = (size_t *)malloc(src->nzmax * sizeof(size_t));
        memcpy(dst->ir, src->ir, src->nzmax * sizeof(size_t));
    }
    if (src->jc) {
        dst->jc = (size_t *)malloc((src->n + 1) * sizeof(size_t));
        memcpy(dst->jc, src->jc, (src->n + 1) * sizeof(size_t));
    }
    if (src->fieldnames) {
        dst->fieldnames = (char **)malloc(src->nfields * sizeof(char *));
        for (int i = 0; i < src->nfields; i++)
            dst->fieldnames[i] = strdup(src->fieldnames[i]);
    }
    if (src->fields) {
        size_t total = (size_t)src->nfields * src->nelems;
        dst->fields = (mx_stub_t **)calloc(total, sizeof(mx_stub_t *));
        for (size_t i = 0; i < total; i++)
            if (src->fields[i]) dst->fields[i] = deep_copy(src->fields[i]);
    }
    if (src->cells) {
        dst->cells = (mx_stub_t **)calloc(src->nelems, sizeof(mx_stub_t *));
        for (size_t i = 0; i < src->nelems; i++)
            if (src->cells[i]) dst->cells[i] = deep_copy(src->cells[i]);
    }
    return dst;
}

/* ── Dimension accessors ─────────────────────────────────────────────────── */

size_t mxGetM(const mxArray pa) { return pa->m; }
size_t mxGetN(const mxArray pa) { return pa->n; }
size_t mxGetNumberOfElements(const mxArray pa) { return pa->nelems; }
size_t mxGetNumberOfDimensions(const mxArray pa) { return pa->ndim; }
const size_t *mxGetDimensions(const mxArray pa) { return pa->dims; }

/* ── Type queries ────────────────────────────────────────────────────────── */

int mxGetClassID(const mxArray pa)  { return pa->classid; }
int mxIsDouble(const mxArray pa)    { return pa->classid == MX_DOUBLE_CLASS  && !pa->is_sparse; }
int mxIsSingle(const mxArray pa)    { return pa->classid == MX_SINGLE_CLASS; }
int mxIsInt8(const mxArray pa)      { return pa->classid == MX_INT8_CLASS;   }
int mxIsInt16(const mxArray pa)     { return pa->classid == MX_INT16_CLASS;  }
int mxIsInt32(const mxArray pa)     { return pa->classid == MX_INT32_CLASS;  }
int mxIsInt64(const mxArray pa)     { return pa->classid == MX_INT64_CLASS;  }
int mxIsUint8(const mxArray pa)     { return pa->classid == MX_UINT8_CLASS;  }
int mxIsUint16(const mxArray pa)    { return pa->classid == MX_UINT16_CLASS; }
int mxIsUint32(const mxArray pa)    { return pa->classid == MX_UINT32_CLASS; }
int mxIsUint64(const mxArray pa)    { return pa->classid == MX_UINT64_CLASS; }
int mxIsLogical(const mxArray pa)   { return pa->classid == MX_LOGICAL_CLASS; }
int mxIsComplex(const mxArray pa)   { return pa->is_complex; }
int mxIsSparse(const mxArray pa)    { return pa->is_sparse; }
int mxIsNumeric(const mxArray pa)   { return pa->classid >= MX_DOUBLE_CLASS; }
int mxIsStruct(const mxArray pa)    { return pa->classid == MX_STRUCT_CLASS; }
int mxIsChar(const mxArray pa)      { return pa->classid == MX_CHAR_CLASS;   }
int mxIsCell(const mxArray pa)      { return pa->classid == MX_CELL_CLASS;   }

/* ── Data accessors ──────────────────────────────────────────────────────── */

double *mxGetPr(const mxArray pa)       { return (double *)pa->pr; }
double *mxGetPi(const mxArray pa)       { return (double *)pa->pi; }
/* Faithful to MATLAB: read the first element per its class and return as double
 * (NOT a raw double reinterpret — int/logical/char data is not double-encoded). */
double mxGetScalar(const mxArray pa) {
    if (!pa || !pa->pr) return 0.0;
    switch (pa->classid) {
        case MX_DOUBLE_CLASS:  return *(double *)pa->pr;
        case MX_SINGLE_CLASS:  return (double)*(float *)pa->pr;
        case MX_INT8_CLASS:    return (double)*(int8_t *)pa->pr;
        case MX_UINT8_CLASS:   return (double)*(uint8_t *)pa->pr;
        case MX_INT16_CLASS:   return (double)*(int16_t *)pa->pr;
        case MX_UINT16_CLASS:  return (double)*(uint16_t *)pa->pr;
        case MX_INT32_CLASS:   return (double)*(int32_t *)pa->pr;
        case MX_UINT32_CLASS:  return (double)*(uint32_t *)pa->pr;
        case MX_INT64_CLASS:   return (double)*(int64_t *)pa->pr;
        case MX_UINT64_CLASS:  return (double)*(uint64_t *)pa->pr;
        case MX_LOGICAL_CLASS: return (double)*(uint8_t *)pa->pr;
        case MX_CHAR_CLASS:    return (double)*(uint16_t *)pa->pr;
        default:               return *(double *)pa->pr;
    }
}
void   *mxGetData(const mxArray pa)     { return pa->pr; }
void   *mxGetImagData(const mxArray pa) { return pa->pi; }
unsigned char *mxGetLogicals(const mxArray pa) { return (unsigned char *)pa->pr; }

/* These are aliases required by mxGetComplexDoubles in api.jl (unused in
   split-Pr/Pi marshalers, but the symbol must exist for dlopen). */
double *mxGetComplexDoubles(const mxArray pa) { return (double *)pa->pr; }

/* ── Sparse accessors ────────────────────────────────────────────────────── */

size_t  mxGetNzmax(const mxArray pa)    { return pa->nzmax; }
size_t *mxGetIr(const mxArray pa)       { return pa->ir; }
size_t *mxGetJc(const mxArray pa)       { return pa->jc; }

/* ── String accessor ─────────────────────────────────────────────────────── */

int mxGetString(const mxArray pa, char *buf, size_t buflen) {
    if (!pa || !buf || buflen == 0) return 1;
    size_t len = pa->nelems;
    if (len >= buflen) len = buflen - 1;
    if (pa->pr) memcpy(buf, pa->pr, len);
    buf[len] = '\0';
    return 0;
}

/* ── Struct accessors ────────────────────────────────────────────────────── */

int mxGetNumberOfFields(const mxArray pa) { return pa->nfields; }

const char *mxGetFieldNameByNumber(const mxArray pa, int n) {
    if (n < 0 || n >= pa->nfields) return NULL;
    return pa->fieldnames[n];
}

mxArray mxGetField(const mxArray pa, size_t index, const char *fieldname) {
    for (int f = 0; f < pa->nfields; f++) {
        if (strcmp(pa->fieldnames[f], fieldname) == 0)
            return pa->fields[(size_t)f * pa->nelems + index];
    }
    return NULL;
}

void mxSetField(mxArray pa, size_t index, const char *fieldname, mxArray value) {
    for (int f = 0; f < pa->nfields; f++) {
        if (strcmp(pa->fieldnames[f], fieldname) == 0) {
            mxDestroyArray(pa->fields[(size_t)f * pa->nelems + index]);
            pa->fields[(size_t)f * pa->nelems + index] = value;
            return;
        }
    }
}

int mxAddField(mxArray pa, const char *fieldname) {
    int idx = pa->nfields;
    pa->nfields++;
    pa->fieldnames = (char **)realloc(pa->fieldnames, (size_t)pa->nfields * sizeof(char *));
    pa->fieldnames[idx] = strdup(fieldname);
    size_t new_total = (size_t)pa->nfields * pa->nelems;
    pa->fields = (mx_stub_t **)realloc(pa->fields, new_total * sizeof(mx_stub_t *));
    for (size_t e = 0; e < pa->nelems; e++)
        pa->fields[(size_t)idx * pa->nelems + e] = NULL;
    return idx;
}

/* ── Cell accessors ──────────────────────────────────────────────────────── */

mxArray mxGetCell(const mxArray pa, size_t index) {
    if (!pa->cells || index >= pa->nelems) return NULL;
    return pa->cells[index];
}

void mxSetCell(mxArray pa, size_t index, mxArray value) {
    if (!pa->cells || index >= pa->nelems) return;
    mxDestroyArray(pa->cells[index]);
    pa->cells[index] = value;
}

/* ── MEX error (abort in the stub — not reached in unit tests) ───────────── */

void mexErrMsgIdAndTxt(const char *id, const char *msg, ...) {
    fprintf(stderr, "libmx_stub mexErrMsgIdAndTxt: [%s] %s\n", id ? id : "", msg ? msg : "");
    abort();
}
