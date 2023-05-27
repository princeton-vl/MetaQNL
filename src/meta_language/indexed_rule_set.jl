function Base.show(io::IO, template::RuleTemplate)
    for p in template.premises
        print(io, p, '\n')
    end
    print(io, "---\n", template.conclusion)
end

struct IndexedRuleSet
    rules::Vector{Rule}
    subsets::Dict{RuleTemplate,Vector{Tuple{Int,Rule}}}
    rule_idxs::Dict{Rule,Int}
    graph::SimpleDiGraph{Int}
    isvalid::Function
end

function IndexedRuleSet(isvalid::Function = Base.isvalid)
    return IndexedRuleSet(
        Rule[],
        Dict{RuleTemplate,Vector{Rule}}(),
        Dict{Rule,Int}(),
        SimpleDiGraph{Int}(),
        isvalid,
    )
end

function IndexedRuleSet(rules::AbstractVector, isvalid::Function = Base.isvalid)
    rule_set = IndexedRuleSet(isvalid)
    union!(rule_set, rules)
    return rule_set
end

function Base.iterate(rule_set::IndexedRuleSet)
    return iterate(rule_set.rules)
end

function Base.iterate(rule_set::IndexedRuleSet, state)
    return iterate(rule_set.rules, state)
end

function Base.length(rule_set::IndexedRuleSet)
    return length(rule_set.rules)
end

function Base.in(r::Rule, rule_set::IndexedRuleSet)
    return haskey(rule_set.rule_idxs, r)
end

function Base.firstindex(rule_set::IndexedRuleSet)
    return firstindex(rule_set.rules)
end

function Base.lastindex(rule_set::IndexedRuleSet)
    return lastindex(rule_set.rules)
end

function Base.getindex(rule_set::IndexedRuleSet, idx::Integer)
    return rule_set.rules[idx]
end

function Base.getindex(rule_set::IndexedRuleSet, r::Rule)
    return get(rule_set.rule_idxs, r, nothing)
end

function Base.union!(rule_set::IndexedRuleSet, rules)
    for r in rules
        push!(rule_set, r)
    end
end

function Base.push!(
    rule_set::IndexedRuleSet,
    r,
    check_existing::Bool = true,
    propagate::Bool = true,
)

    if check_existing && r in rule_set
        return rule_set
    end

    push!(rule_set.rules, r)
    num_rules = length(rule_set.rules)
    rule_set.rule_idxs[r] = num_rules
    add_vertex!(rule_set.graph)

    new = [(num_rules, r, RuleTemplate(r))]

    while !isempty(new)
        new_next = Tuple{Int,Rule,RuleTemplate}[]

        for (i, r_1, tpl) in new
            rules = get(rule_set.subsets, tpl, nothing)
            if rules === nothing
                rule_set.subsets[tpl] = [(i, r_1)]
                continue
            end

            for (j, r_2) in rule_set.subsets[tpl]

                if !is_concrete(r_1) && is_more_general(r_1, r_2)
                    add_edge!(rule_set.graph, j, i)
                    continue
                elseif !is_concrete(r_2) && is_more_general(r_2, r_1)
                    add_edge!(rule_set.graph, i, j)
                    continue
                end

                if !propagate
                    continue
                end

                for g in anti_unify(r_1, r_2)
                    if !rule_set.isvalid(g)
                        continue
                    end
                    k = rule_set[g]
                    if k === nothing
                        push!(rule_set.rules, g)
                        k = length(rule_set.rules)
                        rule_set.rule_idxs[g] = k
                        add_vertex!(rule_set.graph)
                        push!(new_next, (k, g, tpl))
                    end
                    add_edge!(rule_set.graph, i, k)
                    add_edge!(rule_set.graph, j, k)
                end
            end

            push!(rule_set.subsets[tpl], (i, r_1))
        end

        new = new_next
    end

    return rule_set
end

function get_ancestor_indexes(rule_set::IndexedRuleSet, idx::Integer)
    return [v for (v, d) in enumerate(gdistances(rule_set.graph, idx)) if d < typemax(Int)]
end

function get_descendant_indexes(rule_set::IndexedRuleSet, idx::Integer)
    reverse!(rule_set.graph)
    descendants =
        [v for (v, d) in enumerate(gdistances(rule_set.graph, idx)) if d < typemax(Int)]
    reverse!(rule_set.graph)
    return descendants
end

export IndexedRuleSet, get_ancestor_indexes, get_descendant_indexes
