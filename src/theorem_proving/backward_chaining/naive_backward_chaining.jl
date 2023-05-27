const ProofPath = Set{Rule}

"""
Naive implementation of backward chaining

See: Russell, Stuart, and Peter Norvig. "Artificial intelligence: a modern approach." (2002).

# Fields
* `rules::Vector{Rule}`
* `rule_weights::Vector{Float64}`
"""
struct NaiveBackwardChaining <: BackwardChaining
    rules::Vector{Rule}
    rule_weights::Vector{Float64}

    function NaiveBackwardChaining(rules, rule_weights = zeros(length(rules)))
        @assert length(rules) == length(rule_weights)
        @assert all(0.0 <= w <= 1.0 for w in rule_weights)
        return new(rules, rule_weights)
    end
end

function (prover::NaiveBackwardChaining)(
    assumptions::AbstractVector{Sentence},
    goal::Sentence,
    on_the_fly_proposal::Bool = false,
)
    @assert all(is_concrete(a) for a in assumptions)
    return backward_or(prover, assumptions, goal, 1.0, on_the_fly_proposal)
end

function disjoint_rename(goal, rule)::Tuple{AlphaConversion,Sentence}
    vars = union(get_variables(goal), get_variables(rule))
    alpha_conv = AlphaConversion()
    tokens = Token[]

    for t in goal
        if !is_variable(t)
            push!(tokens, t)
        elseif haskey(alpha_conv, t)
            push!(tokens, alpha_conv[t])
        else
            unused_var = fresh_variable(vars)
            alpha_conv[t] = unused_var
            push!(vars, unused_var)
            push!(tokens, unused_var)
        end
    end

    return alpha_conv, Sentence(tokens)
end

function backward_or(
    prover::Prover,
    assumptions::AbstractVector{Sentence},
    goal::Sentence,
    weight_limit::Real,
    on_the_fly_proposal::Bool,
)
    proof_paths = OrderedDict{Substitution,Tuple{Int,Set{ProofPath}}}()
    if is_concrete(goal) && on_the_fly_proposal
        proof_paths[Substitution()] = (1, Set([Set([Rule(Sentence[], goal)])]))
    end

    if weight_limit < 0
        return proof_paths
    end

    satisfied = false
    for a in assumptions
        for subst in match(goal, a)
            proof_paths[subst] = (0, Set([ProofPath()]))
            satisfied = true
        end
    end
    if satisfied
        return proof_paths
    end

    for (rule, weight) in zip(prover.rules, prover.rule_weights)
        new_weight = weight_limit - weight
        if new_weight < 0
            continue
        end

        alpha_conv, transformed_goal = disjoint_rename(goal, rule)
        vars_in_transformed_goal = get_variables(transformed_goal)
        @assert isempty(
            intersect(get_variables(rule.conclusion), get_variables(transformed_goal)),
        )

        for subst_c in unify(rule.conclusion, transformed_goal)
            transformed_premises = subst_c.(rule.premises)
            for (subst_p, (d, premises_paths)) in backward_and(
                prover,
                assumptions,
                transformed_premises,
                new_weight,
                on_the_fly_proposal,
            )
                @assert !isempty(premises_paths)
                subst = subst_c ∘ subst_p
                cr = subst(rule)
                @assert is_concrete(cr)  # Since variables in the conclusion must also appear in premises.

                subst = Substitution(
                    alpha_conv.mapping(var) => sent for
                    (var, sent) in subst if var in vars_in_transformed_goal
                )
                if !haskey(proof_paths, subst)
                    proof_paths[subst] = (d + 1, Set{ProofPath}())
                end
                for path in premises_paths
                    push!(path, cr)
                    push!(proof_paths[subst][2], path)
                end
            end
        end
    end

    vars_in_goal = get_variables(goal)
    for (subst, _) in proof_paths
        @assert get_variables(subst) == vars_in_goal
    end
    return proof_paths
end

function backward_and(
    prover::Prover,
    assumptions::AbstractVector{Sentence},
    goals::AbstractVector{Sentence},
    weight_limit::Real,
    on_the_fly_proposal::Bool,
)
    @assert weight_limit >= 0

    if isempty(goals)
        return OrderedDict(Substitution() => (0, Set([ProofPath()])))
    elseif length(goals) == 1
        return backward_or(prover, assumptions, goals[1], weight_limit, on_the_fly_proposal)
    end

    # Prove the first goal, then prove remaining goals recursively
    proof_paths = OrderedDict{Substitution,Tuple{Int,Set{ProofPath}}}()

    for (subst_first, (d_first, paths_first)) in
        backward_or(prover, assumptions, goals[1], weight_limit, on_the_fly_proposal)
        remaining_goals = [subst_first(g) for g in (@view goals[2:end])]
        for (subst_others, (d_others, paths_others)) in backward_and(
            prover,
            assumptions,
            remaining_goals,
            weight_limit,
            on_the_fly_proposal,
        )
            subst = subst_first ∘ subst_others
            if !haskey(proof_paths, subst)
                proof_paths[subst] = (max(d_first, d_others), Set{ProofPath}())
            end
            for (p_f, p_o) in Iterators.product(paths_first, paths_others)
                push!(proof_paths[subst][2], union(p_f, p_o))
            end
        end
    end

    return proof_paths
end

export NaiveBackwardChaining, ProofPath
