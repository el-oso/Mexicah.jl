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
- `message` — optional banner printed (after the Julia logo, which always prints)
  the first time the MEX runs in a MATLAB session.

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
        verbose::Bool = false,
        message::AbstractString = "",
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
        func_name;
        message = message,
    )

    return _compile_generated_source(
        src, func_name, output;
        trim = trim, bundle = bundle, juliac_bin = juliac_bin, project = project,
        verbose = verbose,
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

# Shared-library extension for the juliac implementation library per OS. MATLAB
# loads the thin gateway (with the .mex* extension); the gateway dlopens this.
_impl_ext()::String = Sys.iswindows() ? "dll" : Sys.isapple() ? "dylib" : "so"

"""
    _run_juliac(src, lib_base, output; trim, bundle, juliac_bin, project) -> String

Write generated Julia `src` to `output/<lib_base>_mexgen.jl`, format it, run
juliac, and return the path to the produced shared library. Shared by the
single-function, shared, and GPU build paths so the juliac invocation lives in
one place. `project` must contain both Mexicah and the user's module(s).
"""
function _run_juliac(
        src::String,
        lib_base::String,
        output::String;
        trim::Bool = true,
        bundle::Bool = true,
        juliac_bin::String = "juliac",
        project::String = pkgdir(@__MODULE__),
        verbose::Bool = false,
    )::String
    mkpath(output)
    generated_jl = joinpath(output, "$(lib_base)_mexgen.jl")
    write(generated_jl, src)
    _format_file(generated_jl)

    # juliac requires the platform's native library extension (.dll/.dylib/.so).
    tmp_lib = joinpath(output, "$(lib_base)_tmp.$(_impl_ext())")
    args = String[juliac_bin, "--project", project, "--output-lib", tmp_lib]
    trim && push!(args, "--trim=safe")
    if bundle
        append!(args, ["--bundle", output])
        # Privatize the bundled libjulia symbols (Unix) so the Julia runtime does
        # not collide with libraries already loaded in the host process — MATLAB
        # ships its own LLVM/libuv/libstdc++, and the symbol clash crashes it.
        Sys.iswindows() || push!(args, "--privatize")
    end
    push!(args, generated_jl)

    verbose && @info "Mexicah: compiling $(lib_base) with juliac…"
    # Capture juliac output so --trim=safe failures can be translated into
    # readable, source-mapped diagnostics (TypeContracts.TrimDiagnostics).
    # On Windows route through `cmd /c` so PATHEXT resolves the .cmd launcher.
    base_cmd = Sys.iswindows() ? Cmd(vcat(["cmd", "/c"], args)) : Cmd(args)
    logf = tempname()
    proc = open(logf, "w") do io
        run(pipeline(ignorestatus(base_cmd); stdout = io, stderr = io))
    end
    captured = isfile(logf) ? read(logf, String) : ""
    rm(logf; force = true)
    if !success(proc)
        verbose && print(stderr, captured)
        throw(explain_trim_failure(captured; entry_path = abspath(generated_jl)))
    end
    verbose && print(captured)

    # With `--bundle`, juliac (≥0.3) nests the output library next to the bundled
    # libjulia: under `<output>/lib/` on Unix, `<output>/bin/` on Windows. Without
    # it the lib lands flat in `<output>/`.
    libname = "$(lib_base)_tmp.$(_impl_ext())"
    candidates = [
        joinpath(output, "lib", libname),
        joinpath(output, "bin", libname),
        tmp_lib,
    ]
    idx = findfirst(isfile, candidates)
    idx === nothing &&
        error("Mexicah: juliac did not produce a library; looked in: $(join(candidates, ", ")).")
    return candidates[idx]
end

"""
    _compile_generated_source(src, func_name, output; trim, bundle, juliac_bin, project) -> String

Compile a single-`mexFunction` source into `output/<func_name>.<mex_ext>`: build
the juliac implementation library, then a thin C gateway that MATLAB loads.
Shared by the CPU `build_mex` path and the GPU `MexicahCUDAExt` path.
"""
function _compile_generated_source(
        src::String,
        func_name::Symbol,
        output::String;
        trim::Bool = true,
        bundle::Bool = true,
        juliac_bin::String = "juliac",
        project::String = pkgdir(@__MODULE__),
        verbose::Bool = false,
    )::String
    produced_lib = _run_juliac(
        src, string(func_name), output;
        trim = trim, bundle = bundle, juliac_bin = juliac_bin, project = project,
        verbose = verbose,
    )
    out_mex = joinpath(output, "$(func_name).$(mex_ext())")
    impl_name = "$(func_name)_impl.$(_impl_ext())"
    impl_path = joinpath(output, impl_name)
    mv(produced_lib, impl_path; force = true)
    _fix_impl_rpath(impl_path)
    _build_mex_gateway(output, out_mex, impl_name, "mexFunction")
    @info "Mexicah: wrote $out_mex"
    _write_setup_m(output, func_name)
    return out_mex
end

"""
    build_shared_mex(funcs; output, name, trim, juliac_bin, project) -> String

Compile several functions into ONE juliac library exporting a separate entry per
function, plus one thin gateway MEX per function. All gateways dlopen the single
shared library, so the Julia runtime initializes exactly once — which lets the
resulting MEX files be called together in one MATLAB session (unlike one
juliac library per function, where each would start its own runtime and conflict).

`funcs` is a vector of `(f, input_types, output_types)` tuples. Writes
`output/<name>_impl.<ext>`, `output/<fname>.<mex_ext>` for each function, and
`output/mexicah_setup.m`.
"""
function build_shared_mex(
        funcs::Vector;
        output::String = ".",
        name::Symbol = :mexicah_shared,
        trim::Bool = true,
        juliac_bin::String = "juliac",
        project::String = _active_project_dir(),
        verbose::Bool = false,
        message::AbstractString = "",
    )::String
    entries = Tuple{Module, Symbol, Vector{Type}, Vector{Type}}[]
    for (f, intypes, outtypes) in funcs
        it = Vector{Type}(intypes)
        _validate_method(f, it)
        push!(entries, (parentmodule(f), nameof(f), it, Vector{Type}(outtypes)))
    end

    src = generate_shared_mex_source(entries; message = message)
    produced_lib = _run_juliac(
        src, string(name), output;
        trim = trim, bundle = true, juliac_bin = juliac_bin, project = project,
        verbose = verbose,
    )
    impl_name = "$(name)_impl.$(_impl_ext())"
    impl_path = joinpath(output, impl_name)
    mv(produced_lib, impl_path; force = true)
    _fix_impl_rpath(impl_path)

    ext = mex_ext()
    for (_, fname, _, _) in entries
        out_mex = joinpath(output, "$(fname).$ext")
        _build_mex_gateway(output, out_mex, impl_name, string(_entry_symbol(fname)))
        @info "Mexicah: wrote $out_mex"
    end
    _write_setup_m(output, name)
    return output
end

# ── Helpers ───────────────────────────────────────────────────────────────────

"""
    _fix_impl_rpath(impl_path) -> nothing

Make the relocated impl library find its bundled `libjulia`.

`juliac --bundle` lays out `<bundle>/lib/<lib>` and `<bundle>/lib/julia/<deps>`,
and stamps the lib with rpaths relative to `<bundle>/lib`. We relocate the impl to
`<bundle>/` next to the gateways, so those rpaths point one directory too high.

- **macOS:** rewrite the rpaths to `@loader_path/lib[/julia]`. SIP strips
  `DYLD_LIBRARY_PATH` from the signed MATLAB process, so the rpath *must* be right.
  `install_name_tool` invalidates the ad-hoc signature (arm64 then refuses to
  load), so strip + re-sign around the edit.
- **Linux:** set an `\$ORIGIN`-relative RUNPATH via `patchelf` so the MEX is
  self-contained. If `patchelf` is unavailable we leave juliac's rpath and fall
  back to `LD_LIBRARY_PATH` (set by `mexicah_setup.m` / CI), as before.
"""
function _fix_impl_rpath(impl_path::String)::Nothing
    if Sys.isapple()
        # Rewrite (not add) the existing rpaths in place: the dylib has no header
        # padding so adding load commands fails, but the corrected paths are
        # *shorter* than the originals and fit.
        edit() = for (old, new) in (
                "@loader_path/../lib" => "@loader_path/lib",
                "@loader_path/../lib/julia" => "@loader_path/lib/julia",
            )
            run(`install_name_tool -rpath $old $new $impl_path`)
        end
        try
            # Modern `install_name_tool` (Xcode 16 / macOS-15 runners) edits the
            # ad-hoc-signed binary in place, invalidating the signature — and avoids
            # the `__LINKEDIT` gap that `codesign --remove-signature` leaves behind,
            # which newer install_name_tool rejects ("link edit information does not
            # fill the __LINKEDIT segment").
            edit()
        catch
            # Older toolchains (Xcode ≤ 15) refuse to edit a *signed* binary — strip
            # the ad-hoc signature first, then rewrite the rpaths.
            run(ignorestatus(`codesign --remove-signature $impl_path`))
            edit()
        end
        # (Re-)apply an ad-hoc signature: editing invalidated juliac's, and arm64
        # refuses to load an unsigned/badly-signed dylib.
        run(`codesign -s - -f $impl_path`)
    elseif Sys.islinux()
        patchelf = Sys.which("patchelf")
        if patchelf !== nothing
            rpath = "\$ORIGIN/lib:\$ORIGIN/lib/julia"   # literal $ORIGIN for ld.so
            run(ignorestatus(`$patchelf --set-rpath $rpath $impl_path`))
        end
    end
    return nothing
end

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
    # (`first`, not `only`: a signature can match >1 method, where `only` throws.)
    rts = Base.return_types(f, Tuple{input_types...})
    rt = isempty(rts) ? Any : first(rts)
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

# Compile the thin C gateway MEX (`out_mex`) that, on first call, loads the juliac
# implementation library `impl_name` (a sibling file) and forwards the MEX call to
# its `entry` export. Uses only libc/libdl (POSIX) or kernel32 (Windows) — no
# MATLAB headers — so the build stays toolchain-light (just a C compiler).
function _build_mex_gateway(
        output::String, out_mex::String, impl_name::String, entry::String,
    )::Cvoid
    base = splitext(basename(out_mex))[1]
    csrc = joinpath(output, "$(base)_gateway.c")
    write(csrc, _gateway_c_source(impl_name, entry))
    if Sys.iswindows()
        cc = something(Sys.which("gcc"), Sys.which("clang"), Sys.which("cc"), "gcc")
        cmd = String[cc, "-shared", "-O2", "-o", out_mex, csrc]
    else
        cc = something(Sys.which("cc"), Sys.which("gcc"), Sys.which("clang"), "cc")
        cmd = String[cc, "-shared", "-fPIC", "-O2", "-o", out_mex, csrc]
        Sys.isapple() || push!(cmd, "-ldl")   # dl* live in libc on macOS
    end
    @info "Mexicah: compiling MEX gateway $(base) ($entry) with $cc…"
    run(Cmd(cmd))
    return
end

function _gateway_c_source(impl_name::String, entry::String)::String
    return """
    /* AUTO-GENERATED by Mexicah.jl — thin MEX gateway. */
    #ifndef _WIN32
    #define _GNU_SOURCE
    #endif
    #include <stdio.h>
    #include <string.h>
    #include <stddef.h>
    #ifdef _WIN32
    #include <windows.h>
    #else
    #include <dlfcn.h>
    #endif

    typedef void (*mexfn_t)(int, void **, int, void **);
    static mexfn_t g_impl = 0;

    #ifdef _WIN32
    static void mexicah_load(void) {
        char path[32768];
        HMODULE self = 0;
        GetModuleHandleExA(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            (LPCSTR)(void *)&mexicah_load, &self);
        DWORD n = GetModuleFileNameA(self, path, (DWORD)sizeof(path));
        if (n == 0 || n >= sizeof(path)) return;
        char *bs = strrchr(path, '\\\\');
        size_t dl = bs ? (size_t)(bs - path) + 1 : 0;
        snprintf(path + dl, sizeof(path) - dl, "%s", "$(impl_name)");
        HMODULE h = LoadLibraryA(path);
        if (!h) { fprintf(stderr, "Mexicah gateway: LoadLibrary(%s) failed\\n", path); return; }
        g_impl = (mexfn_t)(void *)GetProcAddress(h, "$(entry)");
        if (!g_impl) fprintf(stderr, "Mexicah gateway: $(entry) missing in %s\\n", path);
    }
    #else
    static void mexicah_load(void) {
        Dl_info info;
        char path[8192];
        if (!dladdr((void *)mexicah_load, &info) || !info.dli_fname) return;
        const char *self = info.dli_fname;
        const char *slash = strrchr(self, '/');
        size_t dl = slash ? (size_t)(slash - self) + 1 : 0;
        snprintf(path, sizeof(path), "%.*s%s", (int)dl, self, "$(impl_name)");
        void *h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (!h) { fprintf(stderr, "Mexicah gateway: dlopen(%s): %s\\n", path, dlerror()); return; }
        g_impl = (mexfn_t)dlsym(h, "$(entry)");
        if (!g_impl) fprintf(stderr, "Mexicah gateway: $(entry) missing in %s\\n", path);
    }
    #endif

    /* Raise a MATLAB error if the implementation library can't be loaded, instead
       of silently returning with no output. mexErrMsgIdAndTxt is resolved from the
       already-loaded libmex (MATLAB), so the gateway still links no MATLAB libs. */
    typedef void (*mexerr_t)(const char *, const char *);
    static void mexicah_fail(void) {
    #ifdef _WIN32
        HMODULE m = GetModuleHandleA("libmex.dll");
        mexerr_t f = m ? (mexerr_t)(void *)GetProcAddress(m, "mexErrMsgIdAndTxt") : 0;
    #else
        mexerr_t f = (mexerr_t)dlsym(RTLD_DEFAULT, "mexErrMsgIdAndTxt");
    #endif
        if (f) f("Mexicah:gatewayLoadFailed",
            "Mexicah gateway could not load $(impl_name) or its $(entry) entry; see stderr.");
    }

    #ifdef _WIN32
    __declspec(dllexport)
    #endif
    void mexFunction(int nlhs, void **plhs, int nrhs, void **prhs) {
        if (!g_impl) mexicah_load();
        if (!g_impl) { mexicah_fail(); return; }
        g_impl(nlhs, plhs, nrhs, prhs);
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
    % lib/ and lib/julia/. On macOS the implementation library finds them via its
    % @loader_path/lib rpaths (and SIP strips DYLD_LIBRARY_PATH anyway), so only
    % addpath is needed. On Linux the loader path still helps locate libjulia.
    if isunix && ~ismac
        lib_dirs = {bundle_dir, fullfile(bundle_dir, 'lib'), fullfile(bundle_dir, 'lib', 'julia')};
        prefix = strjoin(lib_dirs, ':');
        cur = getenv('LD_LIBRARY_PATH');
        if isempty(cur)
            setenv('LD_LIBRARY_PATH', prefix);
        elseif ~contains(cur, lib_dirs{2})
            setenv('LD_LIBRARY_PATH', [prefix ':' cur]);
        end
    end
    addpath(bundle_dir);
    """
    write(joinpath(output_dir, "mexicah_setup.m"), content)
    return
end
