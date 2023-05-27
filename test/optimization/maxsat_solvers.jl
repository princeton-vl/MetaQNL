import Z3

@testset "Z3" begin
    ctx = Z3.Context()
    x = Z3.real_const(ctx, "x")
    y = Z3.real_const(ctx, "y")
    s = Z3.Solver(ctx, "QF_NRA")
    Z3.add(s, x == y^2)
    Z3.add(s, x > 1)
    Z3.to_smt2(s, "unknown")
    @test Z3.check(s) == Z3.sat
end
