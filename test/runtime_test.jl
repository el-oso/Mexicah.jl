@testitem "init_once runs exactly once per session" tags = [:matlab] begin
    using Mexicah, Test

    # The atomic guard is process-global; reset it so this test is order-independent
    # (other testitems may have already tripped it).
    Mexicah._initialized[] = 0

    # First call sets the flag and would print the banner; subsequent calls no-op.
    Mexicah._mexicah_init_once("")
    @test Mexicah._initialized[] == 1
    # Calling again must not throw and must leave the flag set.
    Mexicah._mexicah_init_once("")
    @test Mexicah._initialized[] == 1
end

@testitem "logo + banner print through mexPrintf without error" tags = [:matlab] begin
    using Mexicah, Test

    # Each helper ends in `mex_printf` ccalls into the (stub) libmx. We only assert
    # they execute cleanly and return Cvoid — the visible output goes to stdout.
    @test Mexicah._mexicah_print_logo() === nothing
    @test Mexicah._mexicah_print_banner("") === nothing
    @test Mexicah._mexicah_print_banner("a user-defined message") === nothing

    # mex_printf returns the libmx Cint result; a '%' in the text is safe because
    # the call routes through a literal "%s" format (no conversion-specifier parse).
    @test Mexicah.mex_printf("100% safe") isa Cint
end
