@testitem "handle store and retrieve" begin
    using Mexicah: _handle_store!, _handle_get, _handle_delete!, _handle_count

    obj = [1.0, 2.0, 3.0]
    id = _handle_store!(obj)
    @test id isa UInt64
    @test id > 0

    retrieved = _handle_get(id)
    @test retrieved === obj
end

@testitem "handle delete returns true once, false after" begin
    using Mexicah: _handle_store!, _handle_get, _handle_delete!

    id = _handle_store!("hello")
    @test _handle_delete!(id) == true
    @test _handle_delete!(id) == false
    @test _handle_get(id) === nothing
end

@testitem "handle IDs are unique across calls" begin
    using Mexicah: _handle_store!, _handle_delete!

    ids = [_handle_store!(i) for i in 1:100]
    @test length(unique(ids)) == 100
    foreach(_handle_delete!, ids)
end

@testitem "handle count tracks live handles" begin
    using Mexicah: _handle_store!, _handle_delete!, _handle_count

    before = _handle_count()
    id1 = _handle_store!(42)
    id2 = _handle_store!(:foo)
    @test _handle_count() == before + 2
    _handle_delete!(id1)
    @test _handle_count() == before + 1
    _handle_delete!(id2)
    @test _handle_count() == before
end

@testitem "handle stores arbitrary Julia types" begin
    using Mexicah: _handle_store!, _handle_get, _handle_delete!

    # struct
    struct MyStruct
        x::Float64
        y::Int
    end
    s = MyStruct(3.14, 42)
    id = _handle_store!(s)
    retrieved = _handle_get(id)::MyStruct
    @test retrieved.x == s.x && retrieved.y == s.y
    _handle_delete!(id)

    # Dict
    d = Dict("a" => 1, "b" => 2)
    id2 = _handle_store!(d)
    @test _handle_get(id2) === d
    _handle_delete!(id2)
end

@testitem "handle missing key returns nothing" begin
    using Mexicah: _handle_get

    @test _handle_get(UInt64(0)) === nothing
    @test _handle_get(typemax(UInt64)) === nothing
end
