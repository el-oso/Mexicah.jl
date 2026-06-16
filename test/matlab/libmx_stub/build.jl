src = joinpath(@__DIR__, "libmx_stub.c")
out = joinpath(@__DIR__, "libmx_stub.so")
run(`cc -O2 -shared -fPIC -o $out $src`)
println("libmx_stub built → $out")
