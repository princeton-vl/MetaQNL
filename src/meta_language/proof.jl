using Bijections: Bijection

struct Proof
    graph::SimpleDiGraph{Int}
    vertex_map::Bijection{Int,Union{Sentence,Rule}}
end

"""
    Proof()

Create an empty proof.

# Example
```jldoctest
julia> proof = Proof();

julia> isempty(proof)
true
```
"""
function Proof()
    return Proof(SimpleDiGraph{Int}(), Bijection{Int,Union{Sentence,Rule}}())
end

"""
    Proof(sents::Sentence...)

Create a proof with only `sents`.
"""
function Proof(sents::Sentence...)
    proof = Proof()
    for s in sents
        create_vertex!(proof, s)
    end
    return proof
end

function create_vertex!(proof::Proof, x)::Int
    @assert add_vertex!(proof.graph)
    idx = nv(proof.graph)
    proof.vertex_map[idx] = x
    return idx
end

"""
    isvalid(proof)

Test if `proof` is a valid proof.
"""
function Base.isvalid(proof::Proof)
    if is_cyclic(proof.graph)
        return false
    end

    goals = Sentence[]

    for v in vertices(proof.graph)
        u = proof.vertex_map[v]
        if !is_concrete(u)
            return false
        end

        if u isa Rule
            if Set(u.premises) !=
               Set(proof.vertex_map[p] for p in inneighbors(proof.graph, v)) ||
               Set([u.conclusion]) !=
               Set(proof.vertex_map[c] for c in outneighbors(proof.graph, v))
                return false
            end
        else
            for rv in inneighbors(proof.graph, v)
                r = proof.vertex_map[rv]
                if !(r isa Rule) || !is_identical(r.conclusion, u)
                    return false
                end
            end
            successors = outneighbors(proof.graph, v)
            for rv in successors
                r = proof.vertex_map[rv]
                if !(r isa Rule) || !contains_premise(r, u)
                    return false
                end
            end
            if isempty(successors)
                push!(goals, u)
            end
        end
    end

    @assert !isempty(goals)
    if length(goals) > 1
        return false
    end

    return true
end

function Base.getindex(proof::Proof, idx)
    return proof.vertex_map[idx]
end

"""
    x::Union{Sentence,Rule} in proof

Check if a formula or rule is in `proof`.
"""
function Base.in(x, proof::Proof)
    try
        proof.vertex_map(x)
        return true
    catch ex
        if ex isa KeyError
            return false
        else
            rethrow()
        end
    end
end

function Base.isempty(proof::Proof)
    return nv(proof.graph) == 0
end

function get_or_create_vertex!(proof::Proof, x)
    try
        return proof.vertex_map(x)
    catch ex
        if ex isa KeyError
            return create_vertex!(proof, x)
        else
            rethrow()
        end
    end
end

function Base.merge!(proof_1::Proof, proof_2::Proof)
    for v2 in topological_sort_by_dfs(proof_2.graph)
        sent = proof_2[v2]
        if sent isa Rule || sent in proof_1
            continue
        end
        v1 = create_vertex!(proof_1, sent)
        for u2 in inneighbors(proof_2.graph, v2)
            rule = proof_2[u2]
            @assert rule isa Rule && !(rule in proof_1)
            u1 = create_vertex!(proof_1, rule)
            for w2 in inneighbors(proof_2.graph, u2)
                sent_pred = proof_2[w2]
                add_edge!(proof_1.graph, proof_1.vertex_map(sent_pred), u1)
            end
            add_edge!(proof_1.graph, u1, v1)
        end
    end
    @assert !is_cyclic(proof_1.graph)
    return proof_1
end

function Base.merge(proof_1::Proof, proof_2::Proof)
    proof = Proof()
    merge!(proof, proof_1)
    merge!(proof, proof_2)
    return proof
end

"Expand the proof by applying a concrete rule."
function apply!(proof::Proof, rule::Rule)
    @assert is_concrete(rule)
    if rule in proof
        return proof
    end

    rule_v = create_vertex!(proof, rule)

    conclusion_v = get_or_create_vertex!(proof, rule.conclusion)
    add_edge!(proof.graph, rule_v, conclusion_v)

    if isempty(rule.premises)
        add_edge!(proof.graph, 1, rule_v)
    else
        # Find all premise vertices
        for premise in rule.premises
            premise_v = proof.vertex_map(premise)
            add_edge!(proof.graph, premise_v, rule_v)
        end
    end

    @assert !is_cyclic(proof.graph)
    return proof
end

function get_rule(proof, sent)
    v = proof.vertex_map(sent)
    predecessors = inneighbors(proof.graph, v)
    if isempty(predecessors)
        return nothing
    else
        @assert length(predecessors) == 1
        return proof[predecessors[1]]
    end
end

function trim(proof::Proof, goal)
    subproof = Proof(goal)
    q = Queue{Int}()
    enqueue!(q, 1)

    while !isempty(q)
        v = dequeue!(q)
        sent = subproof[v]
        rule = get_rule(proof, sent)

        if rule !== nothing && !(rule in subproof)
            u = create_vertex!(subproof, rule)
            add_edge!(subproof.graph, u, v)
            for p in rule.premises
                if !(p in subproof)
                    idx = create_vertex!(subproof, p)
                    enqueue!(q, idx)
                else
                    idx = subproof.vertex_map(p)
                end
                add_edge!(subproof.graph, idx, u)
            end
        end
    end

    return subproof
end

function get_assumptions(proof::Proof)::Vector{Sentence}
    assumptions = Sentence[]
    for v in vertices(proof.graph)
        if isempty(inneighbors(proof.graph, v))
            push!(assumptions, proof[v])
        end
    end
    return assumptions
end

function get_rules(proof::Proof)::Vector{Rule}
    return [r for r in values(proof.vertex_map) if r isa Rule]
end

function get_goal(proof::Proof)::Sentence
    goals = Sentence[]
    for v in vertices(proof.graph)
        if isempty(outneighbors(proof.graph, v))
            push!(goals, proof[v])
        end
    end
    @assert length(goals) == 1
    return goals[1]
end

export Proof,
    get_or_create_vertex!, merge!, apply!, trim, get_assumptions, get_goal, get_rules
