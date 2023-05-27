"Abstract type for substitutions"
abstract type AbstractSubstitution end

"""
A substitution is a function from variables (``\\Sigma_v``) to non-empty sentences without special symbols (``\\Sigma_{-s}^{+}``).

# Fields
* `mapping::Dict{Variable,Sentence}`
"""
struct Substitution <: AbstractSubstitution
    mapping::Dict{Variable,Sentence}

    function Substitution(mapping::Dict{Variable,Sentence})
        @assert all(has_no_special_symbol(sent) for (_, sent) in mapping)
        return new(mapping)
    end
end

"""
    A special type of substitution with only one variable.

# Example
```jldoctest
julia> VariableBinding(variable"A", sent"hello world")
VariableBinding([A], hello world)
```
"""
struct VariableBinding <: AbstractSubstitution
    variable::Variable
    sentence::Sentence

    function VariableBinding(var::Variable, sent::Sentence)
        @assert has_no_special_symbol(sent)
        return new(var, sent)
    end
end

"An alpha-conversion is a special type of substitution that only renames variables."
struct AlphaConversion <: AbstractSubstitution
    mapping::Bijection{Variable,Variable}
end

function AlphaConversion()
    return AlphaConversion(Bijection{Variable,Variable}())
end

"""
    Substitution()

Create an empty substitution.

# Example
```jldoctest
julia> subst = Substitution()
{}

julia> isempty(subst)
true
```
"""
function Substitution()
    return Substitution(Dict{Variable,Sentence}())
end

"""
    Substitution(pairs::Pair{Variable,Sentence}...)

Create a substitution from pairs of variables and sentences.

# Example
```jldoctest
julia> Substitution(variable"A" => sent"hello world")
{[A] -> hello world, }
```
"""
function Substitution(pairs::Pair{Variable,Sentence}...)
    return Substitution(Dict(pairs...))
end

"""
    Substitution(pairs::Pair{<:AbstractString,<:AbstractString}...)

Create a substitution from pairs of strings.

# Example
```jldoctest
julia> Substitution("A" => "hello world")
{[A] -> hello world, }
```
"""
function Substitution(pairs::Pair{<:AbstractString,<:AbstractString}...)
    return Substitution((create_variable(v) => Sentence(s) for (v, s) in pairs)...)
end

"""
    Substitution(pairs::Base.Generator)

Create a substitution from pairs of variables and sentences.

# Example
```jldoctest
julia> a = [(variable"A", sent"hello world")];

julia> Substitution(var => sent for (var, sent) in a)
{[A] -> hello world, }
```
"""
function Substitution(pairs::Base.Generator)
    return Substitution(Dict{Variable,Sentence}(pairs))
end

"""
    Substitution(subst::VariableBinding)

Create a substitution from a variable binding.

# Example
```jldoctest
julia> Substitution(VariableBinding(variable"A", sent"hello world"))
{[A] -> hello world, }
```
"""
function Substitution(subst::VariableBinding)
    return Substitution(subst.variable => subst.sentence)
end

"""
    VariableBinding(subst::Substitution)

Create a variable binding from a substitution.

# Example
```jldoctest
julia> VariableBinding(Substitution("A" => "hello world"))
VariableBinding([A], hello world)

julia> VariableBinding(Substitution("A" => "hello world", "B" => "hi !"))
ERROR: AssertionError
```
"""
function VariableBinding(subst::Substitution)
    @assert length(subst) == 1
    return VariableBinding(first(subst)...)
end

function Base.copy(subst::Substitution)
    return Substitution(copy(subst.mapping))
end

"""
    Base.haskey(subst::AbstractSubstitution, key)

Test if `key` is in `subst`.

# Example
```jldoctest
julia> haskey(Substitution("A" => "hello world"), variable"A")
true

julia> haskey(VariableBinding(variable"A", sent"hello world"), variable"A")
true
```
"""
function Base.haskey(::AbstractSubstitution, key)
    error("Not implemented")
end

function Base.haskey(subst::Union{Substitution,AlphaConversion}, key::Variable)
    return haskey(subst.mapping, key)
end

function Base.haskey(subst::Union{Substitution,AlphaConversion}, key::AbstractString)
    return haskey(subst.mapping, create_variable(key))
end

function Base.haskey(subst::VariableBinding, key::Variable)
    return subst.variable == key
end

function Base.haskey(subst::VariableBinding, key::AbstractString)
    return get_name(subst.variable) == key
end

function Base.length(::AbstractSubstitution)
    error("Not implemented")
end

function Base.length(subst::Substitution)
    return length(subst.mapping)
end

function Base.length(::VariableBinding)
    return 1
end

function Base.iterate(subst::AbstractSubstitution)
    error("Not implemented")
end

function Base.iterate(subst::AbstractSubstitution, state)
    error("Not implemented")
end

function Base.iterate(subst::Substitution)
    return iterate(subst.mapping)
end

function Base.iterate(subst::Substitution, state)
    return iterate(subst.mapping, state)
end

function Base.getindex(subst::Union{Substitution,AlphaConversion}, var::Variable)
    return subst.mapping[var]
end

function Base.getindex(subst::Union{Substitution,AlphaConversion}, var_name::AbstractString)
    return subst.mapping[create_variable(var_name)]
end

function Base.setindex!(subst::Substitution, to::AbstractSentence, from::Variable)
    @assert has_no_special_symbol(to)
    subst.mapping[from] = to
    return subst
end

function Base.setindex!(subst::AlphaConversion, to::Variable, from::Variable)
    subst.mapping[from] = to
    return subst
end

function Base.delete!(subst::Substitution, var::Variable)
    delete!(subst.mapping, var)
    return subst
end

function Base.get(subst::Substitution, var::Variable, default)
    return get(subst.mapping, var, default)
end

function Base.get(subst::Substitution, var_name::AbstractString, default)
    return get(subst.mapping, create_variable(var_name), default)
end

"""
    (subst::AbstractSubstitution)(sent::AbstractSentence)::Sentence

Apply `subst` to `sent`.
"""
function (::AbstractSubstitution)(::AbstractSentence)::Sentence
    error("Not implemented")
end

function (subst::Substitution)(sent::AbstractSentence)::Sentence
    tokens = Token[]
    for t in sent
        if is_variable(t)
            target = get(subst, t, nothing)
            if target === nothing
                push!(tokens, t)
            else
                append!(tokens, target)
            end
        else
            push!(tokens, t)
        end
    end
    return Sentence(tokens)
end

function (subst::VariableBinding)(sent::AbstractSentence)::Sentence
    if !(subst.variable in sent)
        return sent
    end
    tokens = Token[]
    for t in sent
        if t == subst.variable
            append!(tokens, subst.sentence)
        else
            push!(tokens, t)
        end
    end
    return Sentence(tokens)
end

function (subst::AbstractSubstitution)(rule::Rule)::Rule
    return Rule([subst(p) for p in rule.premises], subst(rule.conclusion))
end

function is_concrete(subst::Substitution)
    return all(is_concrete(sent) for sent in values(subst.mapping))
end

function get_variables(subst::Substitution)::Set{Variable}
    return keys(subst.mapping)
end

function Base.show(io::IO, subst::Substitution)
    print(io, "{")
    for (var, sent) in subst
        print(io, var, " -> ", sent, ", ")
    end
    print(io, "}")
end

function composite(::AbstractSubstitution, ::AbstractSubstitution)
    error("Not implemented")
end

function composite(subst_1::Substitution, subst_2::Substitution)::Substitution
    result = copy(subst_2)
    for (from, to) in subst_1
        result[from] = subst_2(to)
    end
    return result
end

function composite(subst_1::Substitution, subst_2::VariableBinding)::Substitution
    result = Substitution(subst_2)
    for (from, to) in subst_1
        result[from] = subst_2(to)
    end
    return result
end

"""
    (subst_1::AbstractSubstitution) ∘ (subst_2::AbstractSubstitution)

Composite two substitutions.

# Example
```jldoctest
julia> subst = Substitution("A" => "hello [B] world") ∘ Substitution("B" => "!");

julia> subst(sent"[A]")
hello ! world
```
"""
function Base.:∘(subst_1::AbstractSubstitution, subst_2::AbstractSubstitution)
    return composite(subst_1, subst_2)
end

function Base.merge(::AbstractSubstitution, ::AbstractSubstitution)
    error("Not implemented")
end

function Base.merge(subst_1::Substitution, subst_2::Substitution)::Substitution
    @assert is_compatible(subst_1, subst_2)
    return Substitution(merge(subst_1.mapping, subst_2.mapping))
end

function is_compatible(substs::Substitution...)
    intersection = Dict{Variable,Sentence}()
    for subst in substs
        for (var, sent) in subst
            s = get(intersection, var, nothing)
            if s === nothing
                intersection[var] = sent
            elseif !is_identical(s::Sentence, sent)
                return false
            end
        end
    end
    return true
end

function Base.merge(subst_1::Substitution, subst_2::VariableBinding)::Substitution
    subst = copy(subst_1)
    var, sent = subst_2.variable, subst_2.sentence
    s = get(subst_1, var, nothing)
    if s != sent
        @assert s === nothing
        subst[var] = sent
    end
    return subst
end

"""
    (subst_1::AbstractSubstitution) + (subst_2::AbstractSubstitution)

Merge two disjoint substitutions.

# Example
```jldoctest
julia> subst = Substitution("A" => "hello [B] world") + Substitution("C" => "!");

julia> subst(sent"[A]")
hello [B] world

julia> subst(sent"[C]")
!
```
"""
function Base.:+(subst_1::AbstractSubstitution, subst_2::AbstractSubstitution)
    return merge(subst_1, subst_2)
end

function Base.:(==)(subst_1::Substitution, subst_2::Substitution)
    return subst_1.mapping == subst_2.mapping
    # Distinguish sentences that are alpha-equivalent but not identical
    #=
    if length(subst_1) != length(subst_2)
        return false
    end
    for (var, sent_1) in subst_1
        sent_2 = get(subst_2, var, nothing)
        if sent_2 === nothing || !is_identical(sent_1, sent_2)
            return false
        end
    end
    return true
    =#
end

function Base.hash(subst::Substitution, h::UInt)::UInt
    return hash(subst.mapping, h)
    #=
    for (var, sent) in subst.mapping
        h = hash(var, h)
        for t in sent
            h = hash(t, h)
        end
    end
    return h
    =#
end

"""
    restrict(subst::Substitution, vars)::Substitution

Restrict `subst` to a subset of variables `vars`.
"""
function restrict(subst::Substitution, vars)::Substitution
    return Substitution(Dict(v => sent for (v, sent) in subst if v in vars))
end

export AbstractSubstitution,
    Substitution, VariableBinding, AlphaConversion, is_concrete, restrict
