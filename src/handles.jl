# Opaque object handle registry — the bridge between Julia heap objects and MATLAB.
#
# Julia structs and GC-managed objects cannot be shared directly with MATLAB:
# MATLAB only understands mxArray types, and Julia's GC heap is invisible to it.
# The handle pattern stores Julia objects here and gives MATLAB a UInt64 key.
# MATLAB passes the key back on subsequent calls; Julia retrieves the object.
# The object stays GC-rooted (alive) until _handle_delete! is called.
#
# Lifecycle (from MATLAB's perspective):
#   id = create_foo(...)      — MEX wrapping Julia that calls _handle_store!
#   use_foo(id, ...)          — MEX looks up object via _handle_get
#   destroy_foo(id)           — MEX calls _handle_delete! to allow GC
#
# The counter is monotonically increasing and never reused, so stale IDs
# from deleted handles will be detected as missing rather than aliasing.

const _HANDLE_REGISTRY = Dict{UInt64, Any}()
const _HANDLE_LOCK = ReentrantLock()
const _HANDLE_COUNTER = Threads.Atomic{UInt64}(UInt64(0))

"""
    _handle_store!(obj) → UInt64

Store `obj` in the handle registry and return a unique opaque identifier.
The object is GC-rooted until `_handle_delete!` is called with the same id.
"""
function _handle_store!(obj)::UInt64
    id = Threads.atomic_add!(_HANDLE_COUNTER, UInt64(1)) + UInt64(1)
    lock(_HANDLE_LOCK) do
        _HANDLE_REGISTRY[id] = obj
    end
    return id
end

"""
    _handle_get(id) → Any

Retrieve the object stored under `id`, or `nothing` if the handle does not exist.
"""
function _handle_get(id::UInt64)
    return lock(_HANDLE_LOCK) do
        return get(_HANDLE_REGISTRY, id, nothing)
    end
end

"""
    _handle_delete!(id) → Bool

Remove the handle `id` from the registry, allowing the associated object to be
garbage-collected. Returns `true` if the handle existed and was removed, `false`
if it was not found (already deleted or never created).
"""
function _handle_delete!(id::UInt64)::Bool
    return lock(_HANDLE_LOCK) do
        haskey(_HANDLE_REGISTRY, id) || return false
        delete!(_HANDLE_REGISTRY, id)
        return true
    end
end

"""
    _handle_count() → Int

Return the number of live (not yet deleted) handles. Useful for leak detection.
"""
function _handle_count()::Int
    return lock(_HANDLE_LOCK) do
        return length(_HANDLE_REGISTRY)
    end
end
