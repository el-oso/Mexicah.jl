# Raw CUDA Driver API bindings for the GPU MEX runtime.
#
# These ccall the NVIDIA driver library directly — NOT CUDA.jl. A MEX built with
# Mexicah's GPU path embeds PTX (generated at build time on a developer machine
# that *does* have CUDA.jl) and loads it through these wrappers at runtime. The
# end-user machine therefore needs only the NVIDIA driver (`libcuda.so.1` on
# Linux, `nvcuda.dll` on Windows), never CUDA.jl or a Julia GPU stack.
#
# The driver C ABI is stable across CUDA versions, so these signatures are fixed.
# All entry points are `_cu_*` and are intended to be called only from generated
# MEX wrappers (see cuda_codegen.jl).

const _LIBCUDA = Sys.iswindows() ? "nvcuda" : "libcuda.so.1"

const CUDA_SUCCESS = Cint(0)

# One context per process, created lazily on the first GPU MEX call. Multiple MEX
# files loaded into the same MATLAB session share it.
const _cuda_initialized = Threads.Atomic{Int}(0)
const _cu_context = Ref{Ptr{Cvoid}}(C_NULL)

# Raise a MATLAB error carrying the CUresult code. mexErrMsgIdAndTxt does not
# return (it longjmps back into MATLAB), but we keep the Cvoid signature so the
# generated wrapper stays inference-friendly for juliac --trim=safe.
function _cu_check(rc::Cint, op::String)::Cvoid
    rc == CUDA_SUCCESS && return
    mex_errorf("Mexicah:cuda", "CUDA driver call '" * op * "' failed with code " * string(Int(rc)))
    return
end

function _cuda_init_once!()::Cvoid
    Threads.atomic_cas!(_cuda_initialized, 0, 1) == 0 || return

    rc = ccall((:cuInit, _LIBCUDA), Cint, (Cuint,), 0)
    _cu_check(rc, "cuInit")

    dev = Ref{Cint}(0)
    rc = ccall((:cuDeviceGet, _LIBCUDA), Cint, (Ptr{Cint}, Cint), dev, 0)
    _cu_check(rc, "cuDeviceGet")

    ctx = Ref{Ptr{Cvoid}}(C_NULL)
    rc = ccall((:cuCtxCreate_v2, _LIBCUDA), Cint, (Ptr{Ptr{Cvoid}}, Cuint, Cint), ctx, 0, dev[])
    _cu_check(rc, "cuCtxCreate")
    _cu_context[] = ctx[]
    return
end

# Load a PTX image (null-terminated ASCII) and return the resulting CUmodule.
function _cu_module_load(ptx::String)::Ptr{Cvoid}
    mod = Ref{Ptr{Cvoid}}(C_NULL)
    GC.@preserve ptx begin
        rc = ccall(
            (:cuModuleLoadDataEx, _LIBCUDA),
            Cint,
            (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Cuint, Ptr{Cint}, Ptr{Ptr{Cvoid}}),
            mod, pointer(ptx), 0, C_NULL, C_NULL,
        )
    end
    _cu_check(rc, "cuModuleLoadDataEx")
    return mod[]
end

function _cu_fn(mod::Ptr{Cvoid}, name::String)::Ptr{Cvoid}
    fn = Ref{Ptr{Cvoid}}(C_NULL)
    rc = ccall(
        (:cuModuleGetFunction, _LIBCUDA),
        Cint,
        (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Cstring),
        fn, mod, name,
    )
    _cu_check(rc, "cuModuleGetFunction")
    return fn[]
end

# Device memory. CUdeviceptr is a 64-bit integer handle in the driver ABI.
function _cu_alloc(nbytes::Int)::UInt64
    dptr = Ref{UInt64}(0)
    rc = ccall((:cuMemAlloc_v2, _LIBCUDA), Cint, (Ptr{UInt64}, Csize_t), dptr, Csize_t(nbytes))
    _cu_check(rc, "cuMemAlloc")
    return dptr[]
end

function _cu_free(dptr::UInt64)::Cvoid
    rc = ccall((:cuMemFree_v2, _LIBCUDA), Cint, (UInt64,), dptr)
    _cu_check(rc, "cuMemFree")
    return
end

function _cu_h2d(dst::UInt64, src::Ptr{Cvoid}, nbytes::Int)::Cvoid
    rc = ccall(
        (:cuMemcpyHtoD_v2, _LIBCUDA),
        Cint,
        (UInt64, Ptr{Cvoid}, Csize_t),
        dst, src, Csize_t(nbytes),
    )
    _cu_check(rc, "cuMemcpyHtoD")
    return
end

function _cu_d2h(dst::Ptr{Cvoid}, src::UInt64, nbytes::Int)::Cvoid
    rc = ccall(
        (:cuMemcpyDtoH_v2, _LIBCUDA),
        Cint,
        (Ptr{Cvoid}, UInt64, Csize_t),
        dst, src, Csize_t(nbytes),
    )
    _cu_check(rc, "cuMemcpyDtoH")
    return
end

# Launch with an explicit 3D grid/block. `kparams` is the kernelParams array:
# one pointer per kernel argument, each pointing at that argument's bytes.
function _cu_launch(
        fn::Ptr{Cvoid},
        gx::Int, gy::Int, gz::Int,
        bx::Int, by::Int, bz::Int,
        shmem::Int,
        kparams::Ptr{Ptr{Cvoid}},
    )::Cvoid
    rc = ccall(
        (:cuLaunchKernel, _LIBCUDA),
        Cint,
        (
            Ptr{Cvoid},
            Cuint, Cuint, Cuint,
            Cuint, Cuint, Cuint,
            Cuint, Ptr{Cvoid},
            Ptr{Ptr{Cvoid}}, Ptr{Ptr{Cvoid}},
        ),
        fn,
        Cuint(gx), Cuint(gy), Cuint(gz),
        Cuint(bx), Cuint(by), Cuint(bz),
        Cuint(shmem), C_NULL,
        kparams, C_NULL,
    )
    _cu_check(rc, "cuLaunchKernel")
    return
end

# Block until all work on the context's default stream has finished.
function _cu_sync()::Cvoid
    rc = ccall((:cuCtxSynchronize, _LIBCUDA), Cint, ())
    _cu_check(rc, "cuCtxSynchronize")
    return
end
