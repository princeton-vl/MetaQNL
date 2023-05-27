"""
Naive implementation of forward chaining

See: Russell, Stuart, and Peter Norvig. "Artificial intelligence: a modern approach." (2002).

# Fields
* `rules::Vector{Rule}`
* `rule_weights::Vector{Float64}`
"""
struct NaiveForwardChaining <: ForwardChaining
    rules::Vector{Rule}
    rule_weights::Vector{Float64}

    function NaiveForwardChaining(rules, rule_weights = zeros(length(rules)))
        @assert length(rules) == length(rule_weights)
        @assert all(w >= 0 for w in rule_weights)
        return new(rules, rule_weights)
    end
end

function update!(prover::NaiveForwardChaining, rules, rule_weights)
    n = length(rules)
    @assert n == length(rule_weights)
    resize!(prover.rules, n)
    copyto!(prover.rules, rules)
    resize(prover.rule_weights, n)
    copyto!(prover.rule_weights, rule_weights)
end

function (prover::NaiveForwardChaining)(
    assumptions::AbstractVector;
    callback::Function = ((_, _) -> true),
)
    weight_limit = 1.0

    proved_facts = Dict{Sentence,Float64}()
    for a in assumptions
        if !callback(a, nothing)
            return
        end
        proved_facts[a] = weight_limit
    end
    applied_crs = Set{Rule}()

    while true
        should_exit = true

        for (rule, weight) in zip(prover.rules, prover.rule_weights)

            for subst in match_pattern(rule.premises, keys(proved_facts))
                cr = subst(rule)
                @assert is_concrete(cr)
                concl = cr.conclusion
                if isempty(cr.premises)
                    new_weight = weight_limit - weight
                else
                    new_weight = minimum(proved_facts[p] for p in cr.premises) - weight
                end
                #if (haskey(proved_facts, concl) && proved_facts[concl] >= new_weight) ||
                if new_weight < 0 ||
                   (cr in applied_crs && new_weight <= proved_facts[concl])
                    continue
                end
                if !callback(concl, cr)
                    return
                end
                proved_facts[concl] = new_weight
                push!(applied_crs, cr)
                should_exit = false
            end
        end

        if should_exit
            break
        end
    end
end

function match_pattern(
    premises::AbstractVector{Sentence},
    proved_facts::AbstractSet{Sentence},
)::Vector{Substitution}
    if issubset(premises, proved_facts)
        return [Substitution()]
    end

    result = Substitution[]
    first_premise = premises[1]
    other_premises = premises[2:end]

    for fact in proved_facts
        for first_subst in match(first_premise, fact)
            transformed_premises = first_subst.(other_premises)
            for other_subst in match_pattern(transformed_premises, proved_facts)
                push!(result, first_subst + other_subst)
            end
        end
    end

    return result
end

export NaiveForwardChaining
