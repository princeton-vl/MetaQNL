import Z3
import Julog

abstract type MaxSatSolver end

abstract type MaxSatExpr end

function bool_const(::MaxSatSolver, name)::MaxSatExpr
    error("Not implemented")
end

function mk_and(::MaxSatSolver, exprs)::MaxSatExpr
    error("Not implemented")
end

function mk_or(::MaxSatSolver, exprs)::MaxSatExpr
    error("Not implemented")
end

function mk_not(::MaxSatSolver, expr)::MaxSatExpr
    error("Not implemented")
end

function mk_equal(::MaxSatSolver, expr)::MaxSatExpr
    error("Not implemented")
end

function mk_imply(solver::MaxSatSolver, expr_1, expr_2)::MaxSatExpr
    return mk_or(solver, [mk_not(solver, expr_1), expr_2])
end

function get_model(::MaxSatSolver)::Dict{Symbol,Bool}
    error("Not implemented")
end

function add!(::MaxSatSolver, ::MaxSatExpr, ::Real)
    error("Not implemented")
end

struct Z3Expr <: MaxSatExpr
    z3expr::Z3.ExprAllocated
end

struct Z3Solver <: MaxSatSolver
    context::Z3.ContextAllocated
    optimizer::Z3.OptimizeAllocated
end

function Z3Solver()
    ctx = Z3.Context()
    opt = Z3.Optimize(ctx)
    return Z3Solver(ctx, opt)
end

function bool_const(solver::Z3Solver, name::AbstractString)
    return Z3Expr(Z3.bool_const(solver.context, name))
end

function bool_const(solver::Z3Solver, name::Symbol)
    return Z3Expr(Z3.bool_const(solver.context, string(name)))
end

function mk_and(solver::Z3Solver, exprs)
    return Z3Expr(Z3.mk_and(Z3.ExprVector(solver.context, [e.z3expr for e in exprs])))
end

function mk_or(solver::Z3Solver, exprs)
    return Z3Expr(Z3.mk_or(Z3.ExprVector(solver.context, [e.z3expr for e in exprs])))
end

function mk_not(::Z3Solver, expr)
    return Z3Expr(Z3.not(expr.z3expr))
end

function mk_equal(::Z3Solver, expr_1, expr_2)
    return Z3Expr(expr_1.z3expr == expr_2.z3expr)
end

function get_model(solver::Z3Solver)::Dict{Symbol,Bool}
    @info "Solving MAX-SAT..."
    @assert Z3.check(solver.optimizer) == Z3.sat
    z3_model = Z3.get_model(solver.optimizer)
    return Dict(Symbol(k) => Z3.is_true(v) for (k, v) in Z3.consts(z3_model))
end

function add!(solver::Z3Solver, expr::Z3Expr, weight::Real)
    z3expr = Z3.simplify(expr.z3expr)
    @assert weight >= 0
    if weight == 0
        return solver
    elseif weight == Inf
        Z3.add(solver.optimizer, z3expr)
    else
        w = round(weight)
        if !isapprox(w, weight)
            @warn "Z3 supports only integer weights"
        end
        Z3.add(solver.optimizer, z3expr, convert(Int, w))
    end
    return solver
end

function Base.show(io::IO, expr::Z3Expr)
    print(io, expr.z3expr)
end

function Base.show(io::IO, solver::Z3Solver)
    print(io, Z3.assertions(solver.optimizer))
end

abstract type OpenWboExpr <: MaxSatExpr end

struct OpenWboBoolValueExpr <: OpenWboExpr
    value::Bool
end

struct OpenWboBoolConstExpr <: OpenWboExpr
    name::Symbol
end

struct OpenWboAndExpr <: OpenWboExpr
    subexprs::Vector{OpenWboExpr}
end

struct OpenWboOrExpr <: OpenWboExpr
    subexprs::Vector{OpenWboExpr}
end

struct OpenWboNotExpr <: OpenWboExpr
    subexpr::OpenWboExpr
end

struct OpenWboEqualExpr <: OpenWboExpr
    subexpr_1::OpenWboExpr
    subexpr_2::OpenWboExpr
end

struct OpenWboSolver <: MaxSatSolver
    constraints::Vector{Tuple{OpenWboExpr,Float64}}
end

function OpenWboSolver()
    return OpenWboSolver(Tuple{OpenWboSolver,Float64}[])
end

function bool_value(::OpenWboSolver, value::Bool)
    return OpenWboBoolValueExpr(value)
end

function bool_const(::OpenWboSolver, name::AbstractString)
    return OpenWboBoolConstExpr(Symbol(name))
end

function bool_const(::OpenWboSolver, name::Symbol)
    return OpenWboBoolConstExpr(name)
end

function has_opposite_literals(exprs)
    literals = Dict{}
end

function mk_and(solver::OpenWboSolver, exprs)
    t = bool_value(solver, true)
    f = bool_value(solver, false)

    if isempty(exprs)
        return t
    elseif length(exprs) == 1
        return first(exprs)
    end

    filtered_exprs = OpenWboExpr[]
    literals = Dict{OpenWboBoolConstExpr,Bool}()

    for e in exprs
        if e == f
            return f
        elseif e == t
            continue
        end
        if is_literal(e)
            if e isa OpenWboNotExpr
                if haskey(literals, e.subexpr) && literals[e.subexpr] == true
                    return f
                end
                literals[e.subexpr] = false
            else
                if haskey(literals, e) && literals[e] == false
                    return f
                end
                literals[e] = true
            end
        end
        push!(filtered_exprs, e)
    end

    return OpenWboAndExpr(filtered_exprs)
end

function mk_or(solver::OpenWboSolver, exprs)
    t = bool_value(solver, true)
    f = bool_value(solver, false)

    if isempty(exprs)
        return f
    elseif length(exprs) == 1
        return first(exprs)
    end

    filtered_exprs = OpenWboExpr[]
    literals = Dict{OpenWboBoolConstExpr,Bool}()

    for e in exprs
        if e == f
            continue
        elseif e == t
            return t
        end
        if is_literal(e)
            if e isa OpenWboNotExpr
                if haskey(literals, e.subexpr) && literals[e.subexpr] == true
                    return t
                end
                literals[e.subexpr] = false
            else
                if haskey(literals, e) && literals[e] == false
                    return t
                end
                literals[e] = true
            end
        end
        push!(filtered_exprs, e)
    end

    return OpenWboOrExpr(filtered_exprs)
end

function mk_not(::OpenWboSolver, expr)
    return OpenWboNotExpr(expr)
end

function mk_not(solver::OpenWboSolver, expr::OpenWboBoolValueExpr)
    return bool_value(solver, !expr.value)
end

function mk_equal(solver::OpenWboSolver, expr_1, expr_2)::OpenWboExpr
    return OpenWboEqualExpr(expr_1, expr_2)
end

function is_clause(expr::OpenWboExpr)
    return is_literal(expr)
end

function is_clause(expr::OpenWboOrExpr)
    return all(is_literal(e) for e in expr.subexprs)
end

function get_literals(expr::OpenWboExpr)
    error("Not implemented")
end

function get_literals(expr::OpenWboOrExpr)
    lits = OpenWboExpr[]
    for e in expr.subexprs
        @assert is_literal(e)
        push!(lits, e)
    end
    return lits
end

function get_literals(expr::OpenWboBoolValueExpr)
    return [expr]
end

function get_literals(expr::OpenWboBoolConstExpr)
    return [expr]
end

function get_literals(expr::OpenWboNotExpr)
    @assert is_literal(expr)
    return [expr]
end

function is_literal(expr::OpenWboExpr)
    return false
end

function is_literal(expr::OpenWboBoolValueExpr)
    return true
end

function is_literal(expr::OpenWboBoolConstExpr)
    return true
end

function is_literal(expr::OpenWboNotExpr)
    return is_literal(expr.subexpr)
end

function get_bool_consts(expr::OpenWboExpr)
    error("Not implemented")
end

function get_bool_consts(expr::OpenWboBoolValueExpr)
    return Symbol[]
end

function get_bool_consts(expr::OpenWboBoolConstExpr)
    return [expr.name]
end

function get_bool_consts(expr::OpenWboAndExpr)
    return vcat((get_bool_consts(e) for e in expr.subexprs)...)
end

function get_bool_consts(expr::OpenWboOrExpr)
    return vcat((get_bool_consts(e) for e in expr.subexprs)...)
end

function get_bool_consts(expr::OpenWboNotExpr)
    return get_bool_consts(expr.subexpr)
end

function get_bool_consts(expr::OpenWboEqualExpr)
    return [get_bool_consts(expr.subexpr_1); get_bool_consts(expr.subexpr_2)]
end

function to_julog(expr::OpenWboExpr)
    error("Not implemented")
end

function to_julog(expr::OpenWboBoolValueExpr)
    return Julog.Const(expr.value)
end

function to_julog(expr::OpenWboBoolConstExpr)
    return Julog.Const(expr.name)
end

function to_julog(expr::OpenWboAndExpr)
    return Julog.Compound(:and, to_julog.(expr.subexprs))
end

function to_julog(expr::OpenWboOrExpr)
    return Julog.Compound(:or, to_julog.(expr.subexprs))
end

function to_julog(expr::OpenWboNotExpr)
    return Julog.Compound(:not, [to_julog(expr.subexpr)])
end

function to_julog(expr::OpenWboEqualExpr)
    subexpr_1 = to_julog(expr.subexpr_1)
    subexpr_2 = to_julog(expr.subexpr_2)
    return Julog.Compound(
        :or,
        [
            Julog.Compound(:and, [subexpr_1, subexpr_2]),
            Julog.Compound(
                :and,
                [Julog.Compound(:not, [subexpr_1]), Julog.Compound(:not, [subexpr_2])],
            ),
        ],
    )
end

function to_expr(solver, julog_formula)::OpenWboExpr
    if julog_formula.name == :and
        return mk_and(solver, [to_expr(solver, arg) for arg in julog_formula.args])
    elseif julog_formula.name == :or
        return mk_or(solver, [to_expr(solver, arg) for arg in julog_formula.args])
    elseif julog_formula.name == :not
        return mk_not(solver, to_expr(solver, julog_formula.args[1]))
    else
        @assert julog_formula isa Julog.Const
        if julog_formula.name isa Symbol
            return bool_const(solver, julog_formula.name)
        else
            @info dump(julog_formula)
            return bool_value(solver, julog_formula.name)
        end
    end
end

"""
    to_cnf(expr::OpenWboExpr)::Vector{OpenWboExpr}

Convert `expr` to conjunctive normal form (CNF).

Return a vector of clauses.
"""
function to_cnf(solver, expr::OpenWboExpr)::Vector{OpenWboExpr}
    cnf_expr = to_expr(solver, Julog.to_cnf(to_julog(expr)))
    if is_clause(cnf_expr)
        return [cnf_expr]
    else
        @assert cnf_expr isa OpenWboAndExpr
        return cnf_expr.subexprs
    end
end

function get_model(solver::OpenWboSolver)::Dict{Symbol,Bool}
    if isempty(solver.constraints)
        return Dict{Symbol,Bool}()
    end

    @info "Converting to CNF..."
    top = 1 + sum(convert(Int, w) for (_, w) in solver.constraints if !isinf(w))
    vars = Symbol[]
    vars_idx = Dict{Symbol,Int}()
    num_dummy_vars = 0
    clauses = Tuple{OpenWboExpr,Int}[]

    for (i, (expr, weight)) in enumerate(solver.constraints)
        if isinf(weight)
            weight = top
        end

        for v in get_bool_consts(expr)
            if !haskey(vars_idx, v)
                @assert !startswith(string(v), "d_")
                push!(vars, v)
                vars_idx[v] = length(vars)
            end
        end

        if expr isa OpenWboBoolValueExpr  # true and false do not affect the model
            if expr.value == false
                @assert weight != top
            end
            continue
        end

        if is_clause(expr)
            push!(clauses, (expr, weight))
        elseif weight == top  # non-clausal hard constraint
            for cl in to_cnf(solver, expr)
                push!(clauses, (cl, top))
            end
        else  # non-clausal soft constraint
            num_dummy_vars += 1
            name = Symbol("d_$num_dummy_vars")
            d = bool_const(solver, name)
            push!(vars, name)
            vars_idx[name] = length(vars)
            push!(clauses, (d, weight))
            for cl in to_cnf(solver, mk_equal(solver, d, expr))
                push!(clauses, (cl, top))
            end
        end
    end

    model = Dict{Symbol,Bool}()

    mktemp() do path, io
        # Write the MAX-SAT problem to a temporary file
        write(io, "p wcnf $(length(vars)) $(length(clauses)) $top \n")
        for (cl, w) in clauses
            write(io, "$w ")
            for lit in get_literals(cl)
                if lit isa OpenWboNotExpr
                    idx = -vars_idx[lit.subexpr.name]
                else
                    @assert lit isa OpenWboBoolConstExpr
                    idx = vars_idx[lit.name]
                end
                write(io, "$idx ")
            end
            write(io, "0\n")
        end
        flush(io)
        # cp(path, "./tmp.maxsat", force = true)
        # @info "MAX-SAT problem exported to ./tmp.maxsat"

        # Run Open-WBO
        @info "Solving MAX-SAT..."
        output = readchomp(ignorestatus(`open-wbo $path`))
        for line in split(output, r"\n|\r\n")
            if startswith(line, 'c')
                continue
            elseif startswith(line, 's')
                @assert (line != "s UNSATISFIABLE") line
                if line == "s SATISFIABLE"
                    @warn "A solution was found by Open-WBO but its optimality was not proven."
                else
                    @assert (line == "s OPTIMUM FOUND") line
                end
            elseif startswith(line, 'v')
                for s in split(line[begin+1:end])
                    idx = parse(Int, s)
                    if idx > 0
                        name = vars[idx]
                        if !startswith(string(name), "d_")
                            model[name] = true
                        end
                    else
                        name = vars[-idx]
                        if !startswith(string(name), "d_")
                            model[name] = false
                        end
                    end
                end
            end
        end
    end

    return model
end

function add!(solver::OpenWboSolver, expr::OpenWboExpr, weight::Real)
    @assert weight >= 0
    if weight == 0
        return solver
    elseif weight == Inf
        w = weight
    else
        w = round(weight)
        if !isapprox(w, weight)
            @warn "Open-WBO supports only integer weights"
        end
    end
    push!(solver.constraints, (expr, w))
    return solver
end

function Base.show(io::IO, expr::OpenWboBoolValueExpr)
    print(io, expr.value)
end

function Base.show(io::IO, expr::OpenWboBoolConstExpr)
    print(io, expr.name)
end

function Base.show(io::IO, expr::OpenWboAndExpr)
    print(io, "(and")
    for e in expr.subexprs
        print(io, ' ', e)
    end
    print(io, ')')
end

function Base.show(io::IO, expr::OpenWboOrExpr)
    print(io, "(or")
    for e in expr.subexprs
        print(io, ' ', e)
    end
    print(io, ')')
end

function Base.show(io::IO, expr::OpenWboNotExpr)
    print(io, "(not ", expr.subexpr, ')')
end

function Base.show(io::IO, expr::OpenWboEqualExpr)
    print(io, "(= ", expr.subexpr_1, ' ', expr.subexpr_2, ')')
end

function Base.show(io::IO, solver::OpenWboSolver)
    for (expr, weight) in solver.constraints
        print(io, weight, ": ", expr, '\n')
    end
end

export Z3Solver, OpenWboSolver
