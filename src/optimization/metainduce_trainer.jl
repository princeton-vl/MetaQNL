include("maxsat_solvers.jl")

"""
MetaInduceTrainer learn rules from data using MetaInduce.

# Fields
* `num_epochs::Int`: the number of training epochs
* `rule_proposer::RuleProposer`
* `prover_type::Type{<:Prover}`: the type of prover, e.g. [`NaiveForwardChaining`](@ref) or [`NaiveBackwardChaining`](@ref) 
* `weight_existing::Float64`: weight of existing rules in the model in theorem proving
* `weight_candidate::Float64`: weight of candidate rules in theorem proving
* `maxsat_solver::Symbol`: MAX-SAT solver to use, currently either `:Z3` or `:OpenWBO` 
* `lambda_provable::Float64`: MAX-SAT weights for provable examples
* `lambda_unprovable::Float64`: MAX-SAT weights for unprovable examples
* `on_the_fly_proposal::Bool`: whether to propose rules on-the-fly in backward chaining
* `log_dir::String`: directory for saving logs
* `ds_val::Union{Dataset,Nothing}`: validation data
* `all_rules::IndexedRuleSet`: concrete rules and their generalizations (``\\Gamma'``)
* `all_provable_paths::Vector{Dict{Substitution,Set{ProofPath}}}`: proof paths of correct reasoning
* `all_unprovable_paths::Vector{DefaultDict{Substitution,Set{ProofPath}}}`: proof paths of incorrect reasoning
"""
struct MetaInduceTrainer <: Trainer
    num_epochs::Int
    rule_proposer::RuleProposer
    prover_type::Type{<:Prover}
    weight_existing::Float64
    weight_candidate::Float64
    maxsat_solver::Symbol
    lambda_provable::Float64
    lambda_unprovable::Float64
    on_the_fly_proposal::Bool
    log_dir::String
    ds_val::Union{Dataset,Nothing}
    all_rules::IndexedRuleSet
    all_provable_paths::Vector{Dict{Substitution,Set{ProofPath}}}
    all_unprovable_paths::Vector{DefaultDict{Substitution,Set{ProofPath}}}

    function MetaInduceTrainer(
        num_epochs,
        rule_proposer,
        prover_type,
        weight_existing,
        weight_candidate,
        maxsat_solver,
        lambda_provable,
        lambda_unprovable,
        on_the_fly_proposal,
        log_dir,
        ds_val = nothing,
    )
        @assert num_epochs >= 0
        @assert maxsat_solver in (:Z3, :OpenWBO)
        @assert 0.0 <= weight_existing <= 1.0
        @assert 0.0 <= weight_candidate <= 1.0
        @assert 0.0 <= lambda_provable && 0.0 <= lambda_unprovable
        for lambda in (lambda_provable, lambda_unprovable)
            if !isinf(lambda) && isapprox(lambda, round(lambda))
                @warn "Integer lambda ($lambda) may lead to unstable results"
            end
        end

        all_rules = IndexedRuleSet(r -> isvalid(rule_proposer, r))

        return new(
            num_epochs,
            rule_proposer,
            prover_type,
            weight_existing,
            weight_candidate,
            maxsat_solver,
            lambda_provable,
            lambda_unprovable,
            on_the_fly_proposal,
            log_dir,
            ds_val,
            all_rules,
            Dict{Substitution,Set{ProofPath}}[],
            DefaultDict{Substitution,Set{ProofPath}}[],
        )
    end
end

"""
    MetaInduceTrainer(; num_epochs, rule_proposer, prover_type, weight_existing, weight_candidate, maxsat_solver, lambda_provable, lambda_unprovable, on_the_fly_proposal, log_dir, ds_val = nothing)

Create a MetaInduceTrainer.
"""
function MetaInduceTrainer(;
    num_epochs,
    rule_proposer,
    prover_type,
    weight_existing,
    weight_candidate,
    maxsat_solver,
    lambda_provable,
    lambda_unprovable,
    on_the_fly_proposal,
    log_dir,
    ds_val = nothing,
)
    return MetaInduceTrainer(
        num_epochs,
        rule_proposer,
        prover_type,
        weight_existing,
        weight_candidate,
        maxsat_solver,
        lambda_provable,
        lambda_unprovable,
        on_the_fly_proposal,
        log_dir,
        ds_val,
    )
end

function train(trainer::MetaInduceTrainer, ds::Dataset)::ReasoningModel
    model = ReasoningModel(trainer.prover_type)
    initialize!(trainer, ds)

    for epoch = 1:trainer.num_epochs
        @info "Epoch #$epoch"
        @info "Proving.."

        @showprogress for (n, ex) in enumerate(ds)
            candidate_rules = propose(trainer.rule_proposer, ds, n)
            prove!(trainer, n, ex, model, candidate_rules)
        end

        @info "Abstracting rules.."
        abstract_rules!(trainer, epoch)

        @info "Pruning rules.."
        rules = prune_rules!(
            trainer,
            ds,
            trainer.maxsat_solver == :Z3 ? Z3Solver() : OpenWboSolver(),
            epoch,
        )

        save_vocabs(joinpath(trainer.log_dir, "vocabs_$epoch.bin"))
        serialize(joinpath(trainer.log_dir, "rules_$epoch.bin"), rules)

        update!(model, rules, trainer.weight_existing)

        for r in model.rules
            @info r
        end
        @info "$(length(model)) rules in the model"

        if trainer.ds_val !== nothing
            @info "Validating.."
            preds_val = predict(model, trainer.ds_val)
            @info evaluate(trainer.ds_val, preds_val)
        end
    end

    return model
end


function initialize!(trainer, ds)
    # Initialize the `trainer` using the dataset `ds`.
    for ex in ds
        # `trainer` contains no proof path initially.
        push!(
            trainer.all_provable_paths,
            Dict(subst => Set{ProofPath}() for subst in ex.substitutions),
        )
        push!(
            trainer.all_unprovable_paths,
            DefaultDict{Substitution,Set{ProofPath}}(Set{ProofPath}),
        )
    end
end

function prove!(trainer, n, ex, model, candidate_rules)
    # Run the prover to update proof paths in `trainer`.

    setdiff!(candidate_rules, model.rules)
    rules = [model.rules; candidate_rules]
    rule_weights = [
        fill(trainer.weight_existing, length(model.rules))
        fill(trainer.weight_candidate, length(candidate_rules))
    ]

    if model.prover isa ForwardChaining
        forward_prove!(trainer, n, ex, rules, rule_weights)
    else
        backward_prove!(trainer, n, ex, rules, rule_weights, trainer.on_the_fly_proposal)
    end
end

function forward_prove!(trainer, n, ex, rules::AbstractVector{Rule}, rule_weights)
    # Prove `ex` using forward chaining.
    proof_paths = DefaultDict{Sentence,Set{ProofPath}}(Set{ProofPath})

    function record_path(concl, cr)
        if cr === nothing
            push!(proof_paths[concl], ProofPath())
        else
            premise_paths = Set{ProofPath}[]
            for premise in cr.premises
                paths = proof_paths[premise]
                @assert !isempty(paths)
                push!(premise_paths, paths)
            end
            for paths in Iterators.product(premise_paths...)
                combined_path = union!(Set([cr]), paths...)
                push!(proof_paths[concl], combined_path)
            end
        end
        return true
    end

    prover = trainer.prover_type(rules, rule_weights)
    prover(ex.assumptions, callback = record_path)

    for (fact, paths) in proof_paths
        substs = match(ex.goal, fact)
        @assert length(substs) <= 1
        if isempty(substs)
            continue
        end
        subst = first(substs)
        if ex.label == PROVABLE
            if subst in ex.substitutions
                union!(trainer.all_provable_paths[n][subst], paths)
            elseif ex.is_complete
                union!(trainer.all_unprovable_paths[n][subst], paths)
            end
        else
            @assert ex.label == UNPROVABLE
            if subst in ex.substitutions
                union!(trainer.all_unprovable_paths[n][subst], paths)
            elseif ex.is_complete
                union!(trainer.all_provable_paths[n][subst], paths)
            end
        end
    end

end

function backward_prove!(trainer, n, ex, rules, rule_weights, on_the_fly_proposal)
    # Prove `ex` using backward chaining.
    prover = trainer.prover_type(rules, rule_weights)

    for (subst, (_, proof_paths)) in prover(ex.assumptions, ex.goal, on_the_fly_proposal)
        @assert !isempty(proof_paths)
        if ex.label == PROVABLE
            if subst in ex.substitutions
                union!(trainer.all_provable_paths[n][subst], proof_paths)
            elseif ex.is_complete
                union!(trainer.all_unprovable_paths[n][subst], paths)
            end
        else
            @assert ex.label == UNPROVABLE
            if subst in ex.substitutions
                union!(trainer.all_unprovable_paths[n][subst], paths)
            elseif ex.is_complete
                union!(trainer.all_provable_paths[n][subst], paths)
            end
        end
    end
end

function abstract_rules!(trainer, epoch)
    save_vocabs(joinpath(trainer.log_dir, "vocabs_$epoch.bin"))
    serialize(joinpath(trainer.log_dir, "trainer_$epoch.bin"), trainer)

    @showprogress for proof_paths in trainer.all_provable_paths
        for (_, paths) in proof_paths
            for path in paths
                for cr in path
                    @assert is_concrete(cr)
                    push!(trainer.all_rules, cr)
                end
            end
        end
    end

    @showprogress for proof_paths in trainer.all_unprovable_paths
        for (_, paths) in proof_paths
            for path in paths
                for cr in path
                    @assert is_concrete(cr)
                    push!(trainer.all_rules, cr, true, false)
                end
            end
        end
    end
end


function prune_rules!(trainer, ds, solver, epoch)::Vector{Rule}
    save_vocabs(joinpath(trainer.log_dir, "vocabs_$epoch.bin"))
    serialize(joinpath(trainer.log_dir, "trainer_$epoch.bin"), trainer)

    lambda_provable = 100.0 * trainer.lambda_provable
    lambda_unprovable = 100.0 * trainer.lambda_unprovable

    crs = Dict{Int,MaxSatExpr}()

    function get_cr_expr(cr)
        i = trainer.all_rules[cr]
        @assert i !== nothing
        return get!(crs, i, bool_const(solver, "cr_$i"))
    end

    function encode_paths(solver, paths)
        return mk_or(
            solver,
            mk_and(solver, get_cr_expr(cr) for cr in path) for path in paths
        )
    end

    # Data consistency constraints
    for (ex, provable_paths) in zip(ds, trainer.all_provable_paths)
        if ex.label == PROVABLE
            for (_, paths) in provable_paths
                add!(solver, encode_paths(solver, paths), lambda_provable)
            end
        end
    end

    for (ex, unprovable_paths) in zip(ds, trainer.all_unprovable_paths)
        for (_, paths) in unprovable_paths
            add!(solver, mk_not(solver, encode_paths(solver, paths)), lambda_unprovable)
        end
    end

    rs = Dict{Int,MaxSatExpr}()
    for (i, cr) in crs
        rule_exprs = []
        for j in get_ancestor_indexes(trainer.all_rules, i)
            if !haskey(rs, j)
                rj = bool_const(solver, "r_$j")
                rs[j] = rj
                add!(solver, mk_not(solver, rj), 100)  # Model complexity constraints
            end
            push!(rule_exprs, rs[j])
        end
        # Rule instantiation constraints
        add!(solver, mk_equal(solver, cr, mk_or(solver, rule_exprs)), Inf)
    end

    @time m = get_model(solver)
    return get_rules_from_model(m, trainer.all_rules)
end

function get_rules_from_model(model, all_rules)
    rules = Rule[]
    for (name, value) in model
        s = string(name)
        if startswith(s, "r_") && value == true
            j = parse(Int, s[3:end])
            push!(rules, all_rules[j])
        end
    end
    return rules
end

export MetaInduceTrainer
