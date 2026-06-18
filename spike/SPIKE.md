# SPIKE: ErrorTypes.jl (Rust-style `Result`) in Mexicah — `spike/errortypes`

**Status: prototype, do NOT merge.** Companion to ParselTongue's `spike/errortypes`.
Goal: assess whether `Result`/`Option` (ErrorTypes.jl) can replace the runtime
`try/finally` guards in the marshaling layer and move error handling toward a
compile-time-checked style.

## What was converted

The three composite `store!` methods each inlined an identical per-child block:

```julia
let fv = getfield(s, i)
    fpa = create(FM(), fdims)
    attached = false
    try
        store!(FM(), fpa, fv)
        mx_set_field!(pa, ..., fpa)   # or mx_set_cell!
        attached = true
    finally
        attached || mx_destroy_array(fpa)   # free temporary if store! threw
    end
end
```

Replaced by a single shared helper (`src/marshaling.jl`, `_marshal_child`) returning
`Result{MxArray,Symbol}`, consumed at each of the three call sites
(`StructMarshaler`, `StructArrayMarshaler`, `CellArrayMarshaler`):

```julia
function _marshal_child(m::M, fv)::Result{MxArray, Symbol} where {M}
    fdims = fv isa AbstractArray ? size(fv) : ()
    fpa = create(m, fdims)
    try
        store!(m, fpa, fv)
        return Result{MxArray, Symbol}(Ok{MxArray}(fpa))
    catch
        mx_destroy_array(fpa)
        return Result{MxArray, Symbol}(Err(:child_store))
    end
end
# call site:
let r = _marshal_child(FM(), getfield(s, i))
    is_error(r) && error("Mexicah: failed to marshal struct field ...")
    mx_set_field!(pa, Csize_t(0), nm, unwrap(r))
end
```

## Results

| Question | Finding |
|---|---|
| **Trim-safe?** (`juliac --trim=safe`) | **Yes.** Built `make_stats` (StructMarshaler), `scale_stats` (StructArray/VectorMarshaler), `tuple_passthrough` (CellArrayMarshaler) — all three converted paths — into `.mexa64` with Result in the image. |
| **Behavior preserved?** | Yes — full suite 382/382 (struct/struct-array/cell round-trips via the libmx stub). |
| **Type-stable?** | Yes — required explicit `Result{MxArray,Symbol}(Ok{MxArray}(...))` / `(Err(...))` construction (same trim lesson as ParselTongue: bare `Ok(x)`/`Err(x)` infer to the non-concrete `ResultConstructor` union and trip `--trim=safe`). |
| **DRY win?** | Yes, partial — three identical try/finally blocks collapse to one helper. This is the only genuine upside, and it is equally achievable with a plain helper function (no Result needed). |
| **Removes the runtime guard?** | **No — it makes it worse (see below).** |
| **Compile-time check?** | No. ErrorTypes is runtime-checked; Julia has no `#[must_use]`/exhaustiveness. |

## The decisive finding: returning vs throwing primitives

This is where Mexicah diverges sharply from ParselTongue, and it is the core input to
the cross-repo assessment.

- **ParselTongue's `_pycall`** wraps CPython C-API calls that **signal failure by return
  value** — `PyTuple_New` → NULL, `PyObject_Call` → NULL, `PyErr_Occurred` → non-NULL.
  Mapping those to `Err(:sym)` is *natural*: `ptr == C_NULL && return Err(...)`. No
  `try/catch` is introduced; Result fits the grain of the code.

- **Mexicah's fallible primitive is `store!`, which signals failure by THROWING** a Julia
  exception (`error()` on a dimension mismatch, `mxCreateString`'s `Cstring` conversion
  on an embedded NUL, etc.). To produce an `Err`, the helper **must `try/catch` the
  throw**. So `Result` does not *replace* the guard — it **requires one** (`catch`), then
  the caller `unwrap`s and re-`error`s at the boundary. We added a guard and a round-trip.

- **Worse, the `catch` discards the original exception.** The pre-spike `try/finally`
  (no `catch`) cleaned up *and* let the real exception — with its specific message —
  propagate untouched. The Result version swallows it into `Err(:child_store)` and
  re-raises a generic `"failed to marshal ..."`. To preserve fidelity you'd need to
  capture the exception object, which `Symbol` can't hold — pushing toward
  `Result{MxArray, Exception}`, i.e. reinventing exceptions on top of exceptions.

- **Cleanup is still `try`-based and is MATLAB's job anyway.** `Result` propagates values;
  it is not `Drop`. The temporary-mxArray cleanup remains, and MATLAB already auto-frees
  un-attached temporaries at MEX return/error — so the guard was peak-memory hygiene, not
  a leak fix, before *and* after.

## Verdict (Mexicah)

**Net-negative. Do not adopt.** Because Mexicah's fallible operations throw rather than
return sentinels, `Result` adds the very `try/catch` it was meant to remove and degrades
error messages. The one real benefit (collapsing three duplicated blocks) is a plain
refactor that needs no new dependency. ErrorTypes *is* trim-safe and type-stable here —
the problem is architectural fit, not the package. See `../parseltongue` `spike/errortypes`
for the contrasting (mildly positive) case and the joined recommendation.
