"""
Two possible labels of a data example:
* `PROVABLE`: The goal is provable from the assumptions.
* `UNPROVABLE`: The goal is not provable from the assumptions.
"""
@enum Label begin
    PROVABLE
    UNPROVABLE
end

"""
Data example

# Fields
* `assumptions::Vector{Sentence}`: concrete sentences
* `goal::Sentence`: a sentence that may have variables
* `label::Label`: PROVABLE or UNPROVABLE
* `substitutions::Substitution`: substitutions of the variables in `goal`
* `is_complete::Bool`: whether `substitutions` contains everything that make `label` hold
* `metadata::Dict{Symbol,Any}`: additional dataset-dependent information
"""
struct Example
    assumptions::Vector{Sentence}
    goal::Sentence
    label::Label
    substitutions::Vector{Substitution}
    is_complete::Bool  # Everything else is unprovable (for provable examples) or provable (for unprovable examples).
    metadata::Dict{Symbol,<:Any}

    """
        Example(assumptions::AbstractVector{<:AbstractSentence}, goal::AbstractSentence, label::Label, substitutions::AbstractVector{<:AbstractSubstitution} = [Substitution()], is_complete::Bool = false, metadata::Dict{Symbol,<:Any} = Dict{Symbol,Any}())

    Create a data example.
    """
    function Example(
        assumptions::AbstractVector{<:AbstractSentence},
        goal::AbstractSentence,
        label::Label,
        substitutions::AbstractVector{<:AbstractSubstitution} = [Substitution()],
        is_complete::Bool = false,
        metadata::Dict{Symbol,<:Any} = Dict{Symbol,Any}(),
    )
        @assert all(is_concrete.(substitutions))
        @assert all(get_variables(goal) == get_variables(subst) for subst in substitutions)
        return new(assumptions, goal, label, substitutions, is_complete, metadata)
    end
end

"""
    concrete_goals(ex::Example)::Vector{Sentence}

Get the concrete goals of `ex` by applying `ex.substitutions` to `ex.goal`.
"""
function concrete_goals(ex::Example)::Vector{Sentence}
    return [subst(ex.goal) for subst in ex.substitutions]
end

function Base.show(io::IO, ex::Example)
    for x in ex.assumptions
        print(io, x, "\n")
    end
    print(io, "---", ex.label, "---\n")
    print(io, ex.goal, "\n")
    print(io, ex.substitutions, "\n")
end

export Label, PROVABLE, UNPROVABLE, Example, concrete_goals
