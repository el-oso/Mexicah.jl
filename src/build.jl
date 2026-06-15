"""
    build_mex(f;
        input_types,
        output_types,
        name        = nothing,
        output      = ".",
        trim        = true,
        bundle      = true,
        juliac_bin  = "juliac",
    )

Compile Julia function `f` into a MATLAB MEX extension in `output/`.

# Arguments
- `f` — any Julia function. Must have a single method matching `input_types`.
- `input_types` — `Vector{Type}` of concrete argument types.
- `output_types` — `Vector{Type}` of concrete return types.
- `name` — MATLAB-visible name (default: `nameof(f)`).
- `output` — directory where the `.mex*` file and bundle land.
- `trim` — pass `--trim=safe` to juliac (recommended; much smaller binaries).
- `bundle` — pass `--bundle output` to juliac so `libjulia.so` is co-located.
- `juliac_bin` — path or name of the juliac executable.

# Output
Writes `output/<name>.<mex_ext>` and, when `bundle=true`, `libjulia.so` and
friends into `output/`. Also writes `output/mexicah_setup.m` which the MATLAB
user runs once per session to put the bundle directory on `LD_LIBRARY_PATH`.
"""
function build_mex(
        f;
        input_types::Vector{<:Type},
        output_types::Vector{<:Type},
        name::Union{Symbol, Nothing} = nothing,
        output::String = ".",
        trim::Bool = true,
        bundle::Bool = true,
        juliac_bin::String = "juliac",
        project::String = _active_project_dir(),
    )::String
    func_name = name === nothing ? nameof(f) : name
    func_module = parentmodule(f)

    _validate_method(f, input_types)

    mkpath(output)

    src = generate_mex_source(
        func_module,
        func_name,
        Vector{Type}(input_types),
        Vector{Type}(output_types),
        func_name,
    )

    return _compile_generated_source(
        src, func_name, output;
        trim = trim, bundle = bundle, juliac_bin = juliac_bin, project = project,
    )
end

# The project juliac should compile against must contain BOTH Mexicah and the
# module that defines `f` (so the generated `using Mexicah` / `import <Module>`
# both resolve). The caller's active project satisfies this — the user adds
# Mexicah as a dependency of the package where their @mexfunction lives.
function _active_project_dir()::String
    p = Base.active_project()
    return p === nothing ? pkgdir(@__MODULE__) : dirname(p)
end

"""
    _compile_generated_source(src, func_name, output; trim, bundle, juliac_bin) -> String

Write generated Julia `src` to `output/<func_name>_mexgen.jl`, format it, and run
juliac to produce `output/<func_name>.<mex_ext>`. Shared by the CPU `build_mex`
path and the GPU `MexicahCUDAExt` path so the juliac invocation lives in one place.
"""
function _compile_generated_source(
        src::String,
        func_name::Symbol,
        output::String;
        trim::Bool = true,
        bundle::Bool = true,
        juliac_bin::String = "juliac",
        project::String = pkgdir(@__MODULE__),
    )::String
    mkpath(output)

    generated_jl = joinpath(output, "$(func_name)_mexgen.jl")
    write(generated_jl, src)

    _format_file(generated_jl)

    ext = mex_ext()
    out_mex = joinpath(output, "$(func_name).$ext")
    tmp_lib = joinpath(output, "$(func_name)_tmp.so")

    # juliac runs as a separate process and resolves `using Mexicah` / the user's
    # `import <Module>` from `project`. For the CPU build_mex path this is the
    # caller's active project (has Mexicah + the user module); the GPU path leaves
    # the default = Mexicah's own project (CUDA/KernelAbstractions are weak deps
    # there, so the PTX-embedding wrapper never drags a Julia GPU stack into the
    # trimmed MEX).
    args = String[juliac_bin, "--project", project, "--output-lib", tmp_lib]
    trim && push!(args, "--trim=safe")
    bundle && append!(args, ["--bundle", output])
    # macOS linker rejects undefined symbols by default; tell it to resolve them
    # at load time from the MATLAB process image (same as ELF lazy binding on Linux).
    Sys.isapple() && append!(args, ["-C", "link-arg=-undefined", "-C", "link-arg=dynamic_lookup"])
    push!(args, generated_jl)

    @info "Mexicah: compiling $(func_name) with juliac…"
    run(Cmd(args))

    # With `--bundle`, juliac (≥0.3) nests the output library under `<output>/lib/`
    # alongside the bundled libjulia; without it the lib lands flat in `<output>/`.
    bundled_lib = joinpath(output, "lib", "$(func_name)_tmp.so")
    produced_lib = isfile(bundled_lib) ? bundled_lib : tmp_lib
    isfile(produced_lib) ||
        error("Mexicah: juliac did not produce a library at $(tmp_lib) or $(bundled_lib).")

    if Sys.iswindows()
        # Windows gateway not implemented yet; ship the juliac lib directly.
        mv(produced_lib, out_mex; force = true)
    else
        # MATLAB will not cleanly load a raw juliac library as a MEX. Ship a tiny
        # C gateway as the .mex* file: MATLAB loads it as a normal MEX, and on the
        # first call it dlopens the juliac library (RTLD_GLOBAL, so its runtime
        # initializes and libjulia symbols are visible) and forwards the call.
        impl_ext = Sys.isapple() ? "dylib" : "so"
        impl_name = "$(func_name)_impl.$(impl_ext)"
        mv(produced_lib, joinpath(output, impl_name); force = true)
        _build_mex_gateway(output, out_mex, impl_name)
    end
    @info "Mexicah: wrote $out_mex"

    _write_setup_m(output, func_name)

    return out_mex
end

# ── Helpers ───────────────────────────────────────────────────────────────────

"""
    _infer_vector_input(f) -> Type or nothing

Return `Vector{Float64}` if `f` has a method accepting a single `Vector{Float64}`
argument, otherwise `nothing`. Used by `@mexgradient` to validate gradient targets.
"""
function _infer_vector_input(f)::Union{Type, Nothing}
    hasmethod(f, Tuple{Vector{Float64}}) && return Vector{Float64}
    return nothing
end

function _validate_method(f, input_types::Vector{<:Type})
    sig = Tuple{typeof(f), input_types...}
    if !hasmethod(f, Tuple{input_types...})
        error(
            "Mexicah: no method found for $(nameof(f)) with types $(join(input_types, ", ")). " *
                "Ensure the function has a concrete method matching these argument types.",
        )
    end
    # Check that inference produces a concrete result (not Any) to warn early.
    rt = only(Base.return_types(f, Tuple{input_types...}))
    return if rt === Any || rt === Union{}
        @warn "Mexicah: return type inferred as $rt for $(nameof(f)). " *
            "juliac --trim=safe may fail. Add explicit return type annotations."
    end
end

function _format_file(path::String)::Cvoid
    # runic is a dev convenience, not a build requirement — skip cleanly when it
    # is not installed (CI runners, end-user machines). `ignorestatus` only
    # suppresses a nonzero exit, not a spawn failure when the binary is absent.
    if Sys.which("runic") === nothing
        @warn "Mexicah: `runic` not found on PATH; skipping formatting of $path"
        return
    end
    result = run(ignorestatus(`runic -i $path`))
    result.exitcode != 0 && @warn "Mexicah: runic formatting failed for $path (exit $(result.exitcode))"
    return
end

# Compile the POSIX C gateway MEX (`out_mex`) that, on first call, dlopens the
# juliac implementation library `impl_name` (a sibling file) and forwards the
# MEX call to it. Uses only libc/libdl — no MATLAB headers — so the build stays
# toolchain-light (just a C compiler).
function _build_mex_gateway(output::String, out_mex::String, impl_name::String)::Cvoid
    cc = something(Sys.which("cc"), Sys.which("gcc"), "cc")
    csrc = joinpath(output, "mexicah_gateway.c")
    write(csrc, _gateway_c_source(impl_name))
    cmd = String[cc, "-shared", "-fPIC", "-O2", "-o", out_mex, csrc]
    Sys.isapple() || push!(cmd, "-ldl")   # dl* live in libc on macOS
    @info "Mexicah: compiling MEX gateway with $cc…"
    run(Cmd(cmd))
    return
end

function _gateway_c_source(impl_name::String)::String
    return """
    /* AUTO-GENERATED by Mexicah.jl — thin MEX gateway. */
    #define _GNU_SOURCE
    #include <dlfcn.h>
    #include <string.h>
    #include <stdio.h>
    #include <stddef.h>

    typedef void (*mexfn_t)(int, void **, int, void **);
    static mexfn_t g_impl = NULL;

    static void mexicah_load(void) {
        Dl_info info;
        char path[8192];
        if (!dladdr((void *)mexicah_load, &info) || !info.dli_fname) return;
        const char *self = info.dli_fname;
        const char *slash = strrchr(self, '/');
        size_t dl = slash ? (size_t)(slash - self) + 1 : 0;
        snprintf(path, sizeof(path), "%.*s%s", (int)dl, self, "$(impl_name)");
        void *h = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
        if (!h) { fprintf(stderr, "Mexicah gateway: dlopen(%s): %s\\n", path, dlerror()); return; }
        g_impl = (mexfn_t)dlsym(h, "mexFunction");
        if (!g_impl) fprintf(stderr, "Mexicah gateway: mexFunction missing in %s\\n", path);
    }

    void mexFunction(int nlhs, void **plhs, int nrhs, void **prhs) {
        if (!g_impl) mexicah_load();
        if (g_impl) g_impl(nlhs, plhs, nrhs, prhs);
    }
    """
end

function _write_setup_m(output_dir::String, func_name::Symbol)::Cvoid
    # MATLAB single-quoted strings take backslashes literally (good for Windows
    # paths); the only character needing escaping is the single quote, doubled.
    # `escape_string` would wrongly double backslashes.
    abs_dir = replace(abspath(output_dir), "'" => "''")
    content = """
    % mexicah_setup.m — run this once per MATLAB session before calling MEX functions.
    % Generated by Mexicah.jl for: $func_name

    bundle_dir = '$(abs_dir)';
    % juliac --bundle places libjulia and the Julia runtime libraries under
    % lib/ and lib/julia/; the MEX needs all three on the library search path.
    lib_dirs = {bundle_dir, fullfile(bundle_dir, 'lib'), fullfile(bundle_dir, 'lib', 'julia')};
    prefix = strjoin(lib_dirs, ':');
    if ismac
        var = 'DYLD_LIBRARY_PATH';
    else
        var = 'LD_LIBRARY_PATH';
    end
    if isunix || ismac
        cur = getenv(var);
        if isempty(cur)
            setenv(var, prefix);
        elseif ~contains(cur, lib_dirs{2})
            setenv(var, [prefix ':' cur]);
        end
    end
    addpath(bundle_dir);
    """
    write(joinpath(output_dir, "mexicah_setup.m"), content)
    return
end
