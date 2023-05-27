using Serialization

"Abstract type for nodes in the Rete network."
abstract type ReteNode end


"""
An ``\\alpha`` node represents a single premise with possibly multiple instantiations.

# Fields
* `condition::Sentence`: the premise.
* `instantiations::Dict{Vector{Sentence},Float64}`: concrete sentences instantiating the premise, each with a weight. Each `Vector{Sentence}` is a substitution of variables in `condition`.
* `children::Vector{<:ReteNode}`: a list of ``\\beta`` nodes.
"""
struct AlphaNode <: ReteNode
    condition::Sentence
    instantiations::Dict{Vector{Sentence},Float64}
    children::Vector{<:ReteNode}
end

"""
A ``\\beta`` node represents a conjunction of `n` premises.

# Fields
* `conditions::Vector{Sentence}`: premises `1` to `n`.
* `de_bruijn_indexes::Union{Vector{Int},Nothing}`: De Bruijn indexes of variables in premise `n`.
* `instantiations::Dict{Vector{Sentence},Float64}``: concrete instantiations of the conjunction of premises, each with a weight. Each `Vector{Sentence}` is a substitution of variables in `conditions`.
* `rules::Vector{Rule}`: rules whose premises are premises `1` to `n`.
* `rule_weights::Vector{Float64}`
* `left_parent::Union{BetaNode,Nothing}`: another ``\\beta`` representing the conjunction of premises `1` to `n-1`; `nothing` if `n == 0`.
* `right_parent::Union{AlphaNode,Nothing}`: an `\\alpha`` node representing premise `n`; `nothing` if `n == 0`.
* `children::Vector{BetaNode}`: a list of ``\\beta`` nodes.
"""
struct BetaNode <: ReteNode
    conditions::Vector{Sentence}
    de_bruijn_indexes::Union{Vector{Int},Nothing}
    instantiations::Dict{Vector{Sentence},Float64}
    rules::Vector{Rule}
    rule_weights::Vector{Float64}
    left_parent::Union{BetaNode,Nothing}
    right_parent::Union{AlphaNode,Nothing}
    children::Vector{BetaNode}

    function BetaNode(
        conditions = Sentence[],
        left_parent = nothing,
        right_parent = nothing,
        children = BetaNode[],
    )
        if isempty(conditions)
            de_bruijn_indexes = nothing
            instantiations = Dict(Sentence[] => Inf)
        else
            _, vars = get_de_bruijn(conditions[end])
            de_bruijn_indexes = [v.idx for v in vars]
            instantiations = Dict{Vector{Sentence},Float64}()
        end
        return new(
            conditions,
            de_bruijn_indexes,
            instantiations,
            Rule[],
            Float64[],
            left_parent,
            right_parent,
            children,
        )
    end
end

function Base.isempty(node::BetaNode)
    return isempty(node.conditions)
end

function AlphaNode(condition::Sentence)
    return AlphaNode(condition, Dict{Vector{Sentence},Float64}(), BetaNode[])
end

"""
Rete algorithm for efficient forward chaining.

Reference: Doorenbos, "Production Matching for Large Learning Systems", 1995.

# Fields
* `alpha_nodes::Vector{AlphaNode}`: ``\\alpha`` nodes in the Rete network.
* `beta_nodes::Vector{BetaNode}`: ``\\beta`` nodes in the Rete network.
* `working_memory::Dict{Sentence,Float64}`: proved sentences, each with a weight.
* `activated_concrete_rules::Dict{Rule,Float64}`: concrete rules whose premises have been satisfied.
"""
struct ReteNetwork
    alpha_nodes::Vector{AlphaNode}
    beta_nodes::Vector{BetaNode}
    working_memory::Dict{Sentence,Float64}
    activated_concrete_rules::Dict{Rule,Float64}
end

"""
    ReteNetwork(rules, rule_weights)

Create a Rete network.
"""
function ReteNetwork(rules::AbstractVector{Rule}, rule_weights::AbstractVector{<:Real})
    all_alpha_nodes = Dict{Sentence,AlphaNode}()
    dummy_beta_node = BetaNode()
    all_beta_nodes = [dummy_beta_node]

    for (r, w) in zip(rules, rule_weights)
        # Find the best beta node to start
        all_premises, _ = get_de_bruijn(r.premises)
        num_premises = length(all_premises)
        beta_node = dummy_beta_node
        for node in all_beta_nodes
            n = length(node.conditions)
            if length(beta_node.conditions) < n <= num_premises &&
               node.conditions == all_premises[1:n]
                beta_node = node
            end
        end

        for i = (length(beta_node.conditions)+1):num_premises
            condition, _ = get_de_bruijn(all_premises[i])
            # Create alpha nodes
            alpha_node = get(all_alpha_nodes, condition, nothing)
            if alpha_node === nothing
                alpha_node = AlphaNode(condition)
                all_alpha_nodes[condition] = alpha_node
            end
            # Create beta nodes
            premises_prefix = all_premises[1:i]
            j = findfirst(
                node -> is_equivalent(node.conditions, premises_prefix),
                beta_node.children,
            )
            if j === nothing
                beta_node_next = BetaNode(premises_prefix, beta_node, alpha_node)
                push!(beta_node.children, beta_node_next)
                push!(alpha_node.children, beta_node_next)
                push!(all_beta_nodes, beta_node_next)
                beta_node = beta_node_next
            else
                beta_node = beta_node.children[j]
            end
        end

        push!(beta_node.rules, r)
        push!(beta_node.rule_weights, w)
    end

    return ReteNetwork(
        collect(values(all_alpha_nodes)),
        collect(values(all_beta_nodes)),
        Dict{Sentence,Float64}(),
        Dict{Rule,Float64}(),
    )
end

function Base.show(io::IO, node::AlphaNode)
    print(io, "AlphaNode \"")
    print(io, node.condition)
    print(io, "\" with $(length(node.instantiations)) instantiations")
end

function Base.show(io::IO, node::BetaNode)
    print(io, "BetaNode \"")
    print(io, node.conditions)
end

function Base.show(io::IO, rete::ReteNetwork)
    print(
        io,
        "ReteNetwork with $(length(rete.alpha_nodes)) alpha nodes and $(length(rete.beta_nodes)) beta models",
    )
end

"""
    add_wme!(rete::ReteNetwork, fact, weight)

Add a working memory entry (WME) `fact` to `rete`.
"""
function add_wme!(rete::ReteNetwork, fact, weight)
    @assert !haskey(rete.working_memory, fact)
    rete.working_memory[fact] = weight

    for node in rete.alpha_nodes
        for subst in match(flip_variables(node.condition), fact)
            num_vars = length(subst)
            inst = [subst[create_variable(i)] for i = 1:num_vars]
            node.instantiations[inst] = weight
            for child in Iterators.reverse(node.children)  # descendents before ancestors
                right_activate(rete, child, inst, weight)
            end
        end
    end

    return rete
end

"""
    clear!(rete::ReteNetwork)

Clear the WMEs and instantiations in `rete`.
"""
function clear!(rete::ReteNetwork)
    for node in rete.alpha_nodes
        empty!(node.instantiations)
    end
    for node in rete.beta_nodes
        empty!(node.instantiations)
        if isempty(node.conditions)  # dummy
            node.instantiations[Sentence[]] = Inf
        end
    end
    empty!(rete.working_memory)
    empty!(rete.activated_concrete_rules)
    return rete
end

function merge_instantiations(left_inst, right_inst, de_bruijn_indexes)
    if isempty(right_inst)
        return left_inst
    end
    new_inst = nothing
    len = length(left_inst)

    for (idx, sent) in zip(de_bruijn_indexes, right_inst)
        if -idx <= len
            if sent != left_inst[-idx]  # conflict
                return nothing
            end
        else
            if new_inst === nothing
                new_inst = copy(left_inst)
            end
            @assert -idx == length(new_inst) + 1
            push!(new_inst, sent)
        end
    end
    if new_inst === nothing
        return left_inst
    else
        return new_inst
    end
end

function activate_beta(
    rete::ReteNetwork,
    node::BetaNode,
    new_inst::AbstractVector,
    new_weight::Real,
)
    node.instantiations[new_inst] = new_weight

    for (r, w) in zip(node.rules, node.rule_weights)
        _, vars = get_de_bruijn(r.premises)
        subst = Substitution(Dict(v => sent for (v, sent) in zip(vars, new_inst)))
        cr = subst(r)
        @assert is_concrete(cr)
        concl_weight = new_weight - w

        if concl_weight >= 0 && !haskey(rete.working_memory, cr.conclusion)
            rete.activated_concrete_rules[cr] = concl_weight
        end
    end

    for child in node.children
        left_activate(rete, child, new_inst, new_weight)
    end
end

function right_activate(
    rete::ReteNetwork,
    node::BetaNode,
    right_inst::AbstractVector,
    right_weight::Real,
)
    for (left_inst, left_weight) in node.left_parent.instantiations
        new_inst = merge_instantiations(left_inst, right_inst, node.de_bruijn_indexes)
        if new_inst !== nothing
            new_weight = min(left_weight, right_weight)
            activate_beta(rete, node, new_inst, new_weight)
        end
    end
end

function left_activate(
    rete::ReteNetwork,
    node::BetaNode,
    left_inst::AbstractVector,
    left_weight::Real,
)
    for (right_inst, right_weight) in node.right_parent.instantiations
        new_inst = merge_instantiations(left_inst, right_inst, node.de_bruijn_indexes)
        if new_inst !== nothing
            new_weight = min(left_weight, right_weight)
            activate_beta(rete, node, new_inst, new_weight)
        end
    end
end

"""
Efficient forward chaining with Rete algorithm.

Reference: Doorenbos, "Production Matching for Large Learning Systems", 1995.

# Fields
* `rules::Vector{Rule}`
* `rule_weights::Vector{Float64}`
* `rete::ReteNetwork`: the Rete network.
"""
struct ReteForwardChaining <: ForwardChaining
    rules::Vector{Rule}
    rule_weights::Vector{Float64}
    rete::ReteNetwork

    function ReteForwardChaining(rules, rule_weights = zeros(length(rules)))
        # Sorting the premises empirically improves the speed.
        rete = ReteNetwork(
            [
                Rule(sort(r.premises, by = p -> string(p), rev = true), r.conclusion)
                for r in rules
            ],
            rule_weights,
        )
        return new(rules, rule_weights, rete)
    end
end

function (prover::ReteForwardChaining)(
    assumptions::AbstractVector{Sentence};
    callback::Function = ((_, _) -> true),
)
    clear!(prover.rete)

    for (r, w) in zip(prover.rules, prover.rule_weights)
        if isempty(r.premises)
            @assert is_concrete(r)
            prover.rete.activated_concrete_rules[r] = 1.0 - w
        end
    end

    for fact in assumptions
        @assert is_concrete(fact)
        if haskey(prover.rete.working_memory, fact)
            continue
        end
        if !callback(fact, nothing)
            return
        end
        add_wme!(prover.rete, fact, 1.0)
    end

    applied_crs = Set{Rule}()
    while true
        updated = false

        for (cr, weight) in prover.rete.activated_concrete_rules
            if cr in applied_crs
                continue
            end
            push!(applied_crs, cr)
            updated = true
            if !callback(cr.conclusion, cr)
                return
            end
            if !haskey(prover.rete.working_memory, cr.conclusion)
                add_wme!(prover.rete, cr.conclusion, weight)
            end
        end

        if !updated
            break
        end
    end
end

export ReteForwardChaining
