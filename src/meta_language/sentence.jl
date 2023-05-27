"Abstract type for sentences."
abstract type AbstractSentence end

"""
A sequence of tokens (``\\Sigma^{*}``).

# Fields
* `tokens::Vector{Token}`
"""
struct Sentence <: AbstractSentence
    tokens::Vector{Token}
end

"""
    Sentence()

Create an empty sentence.

# Example
```jldoctest
julia> sent = Sentence()


julia> isempty(sent)
true
```
"""
function Sentence()
    return Sentence(Token[])
end

"""
    Sentence(str::AbstractString)

Create a sentence from `str`.

# Example
```jldoctest
julia> Sentence("hello [X] world")
hello [X] world
```
"""
function Sentence(str::AbstractString)
    return Sentence([create_token(s) for s in split(str)])
end

"""
    macro sent_str(str::AbstractString)

Create a sentence from `str`.

# Example
julia> sent_1 = sent"the test may come today ."
the test may come today .

julia> typeof(sent_1)
Sentence
```
"""
macro sent_str(str::AbstractString)
    return Sentence(str)
end

"A view to tokens without owning the underlying storage."
struct SentenceView <: AbstractSentence
    tokens::SubArray{Token,1,Vector{Token},Tuple{UnitRange{Int}},true}
end

"""
    convert(::Type{Sentence}, sent::SentenceView)

Create a new sentence from a sentence view `sent`.
"""
function Base.convert(::Type{Sentence}, sent::SentenceView)
    return sent[begin:end]
end

"""
    convert(::Type{SentenceView}, sent::Sentence)

Create a view of `sent`.
"""
function Base.convert(::Type{SentenceView}, sent::Sentence)
    return @view sent[begin:end]
end

"""
    length(sent::AbstractSentence)::Int

Return the number of tokens in `sent`.

# Example
```jldoctest
julia> length(sent"hello [X] world")
3
```
"""
function Base.length(sent::AbstractSentence)
    return length(sent.tokens)
end

"""
    iterate(sent::AbstractSentence)

Iterate through `sent`.

# Example
```jldoctest
julia> sent = sent"hello [X] world";

julia> for t in sent println(t) end
hello
[X]
world
```
"""
function Base.iterate(sent::AbstractSentence)
    return iterate(sent.tokens)
end

function Base.iterate(sent::AbstractSentence, state)
    return iterate(sent.tokens, state)
end

function Base.keys(sent::AbstractSentence)
    return keys(sent.tokens)
end

function Base.firstindex(sent::AbstractSentence)
    return firstindex(sent.tokens)
end

function Base.lastindex(sent::AbstractSentence)
    return lastindex(sent.tokens)
end

function Base.getindex(sent::AbstractSentence, idx::Integer)::Token
    return sent.tokens[idx]
end

function Base.getindex(sent::AbstractSentence, range::AbstractRange)::Sentence
    return Sentence(sent.tokens[range])
end

function Base.setindex!(sent::AbstractSentence, t::Token, idx::Integer)
    sent.tokens[idx] = t
    return sent
end

function Base.view(sent::AbstractSentence, range::UnitRange)::SentenceView
    return SentenceView(view(sent.tokens, range))
end

"""
    push!(sent::Sentence, t::Token)

Append a new token `t` to the end of `sent`.

# Example
```jldoctest
julia> sent = Sentence("hello world")
hello world

julia> push!(sent, word"!")
hello world !
```
"""
function Base.push!(sent::Sentence, t::Token)
    push!(sent.tokens, t)
    return sent
end

"""
    pushfirst!(sent::Sentence, t::Token)

Prepend a new token `t` to the begining of `sent`.

# Example
```jldoctest
julia> sent = sent"hello world"
hello world

julia> pushfirst!(sent, word"!")
! hello world
```
"""
function Base.pushfirst!(sent::Sentence, t::Token)
    pushfirst!(sent.tokens, t)
    return sent
end

"""
    append!(sent_1::Sentence, sent_2::AbstractSentence)

Append the tokens from `sent_2` to the end of `sent_1`.

# Example
```jldoctest
julia> sent = sent"how are"
how are

julia> append!(sent, sent"you ?")
how are you ?
```
"""
function Base.append!(sent_1::Sentence, sent_2::AbstractSentence)
    append!(sent_1.tokens, sent_2.tokens)
    return sent_1
end

function Base.string(sent::AbstractSentence)
    len = length(sent.tokens)
    buf = IOBuffer(write = true)
    for (i, t) in enumerate(sent.tokens)
        write(buf, string(t))
        if i < len
            write(buf, " ")
        end
    end
    return String(take!(buf))
end

function Base.show(io::IO, sent::AbstractSentence)
    print(io, string(sent))
end

"""
    get_variables(sent::AbstractSentence)::Set{Variable}

Return the set of variables in `sent`.

# Example
```jldoctest
julia> get_variables(Sentence("hello [X] world"))
Set{Token} with 1 element:
  [X]

julia> get_variables(Sentence("hello world"))
Set{Token}()
```
"""
function get_variables(sent::AbstractSentence)::Set{Variable}
    vars = Set{Variable}()
    return get_variables!(sent, vars)
end

function get_variables!(sent::AbstractSentence, vars::AbstractSet{Variable})::Set{Variable}
    for t in sent
        if is_variable(t) && !(t in vars)
            push!(vars, t)
        end
    end
    return vars
end

function get_variables(sents::AbstractVector{<:AbstractSentence})::Set{Variable}
    vars = Set{Variable}()
    for s in sents
        get_variables!(s, vars)
    end
    return vars
end

"""
    is_identical(x::AbstractSentence, y::AbstractSentence)

Test if `x` and `y` are identical (equal without considering ``\\alpha``-conversion).
"""
function is_identical(sent_1::AbstractSentence, sent_2::AbstractSentence)
    return sent_1.tokens == sent_2.tokens
end

function is_identical(
    sents_1::AbstractVector{<:AbstractSentence},
    sents_2::AbstractVector{<:AbstractSentence},
)
    return length(sents_1) == length(sents_2) &&
           all(is_identical(s1, s2) for (s1, s2) in zip(sents_1, sents_2))
end

function Base.:(==)(sent_1::AbstractSentence, sent_2::AbstractSentence)
    return is_identical(sent_1, sent_2)
end

function Base.isless(sent_1::AbstractSentence, sent_2::AbstractSentence)
    return sent_1.tokens < sent_2.tokens
end

"""
    Base.hash(sent::AbstractSentence, h)

Compute the hash code of `sent` without considering ``\\alpha``-conversion.
"""
function Base.hash(sent::AbstractSentence, h::UInt)::UInt
    for t in sent.tokens
        h = hash(t.idx, h)
    end
    return h
end

"""
    alpha_invariant_hash(sent::AbstractSentence, h)

Compute the hash code of `sent` modulo ``\\alpha``-conversion.

# Example
```jldoctest
julia> h1 = alpha_invariant_hash(Sentence("how [Y] are [X] you [Y] ?"));

julia> h2 = alpha_invariant_hash(Sentence("how [Q] are [X] you [Q] ?"));

julia> h1 == h2
true

julia> h3 = alpha_invariant_hash(Sentence("how [Q] are [X] you [Z] ?"));

julia> h1 == h3
false
```
"""
function alpha_invariant_hash(sent::AbstractSentence, h::UInt = 0x0000000000000000)::UInt
    num_vars = count(is_variable, sent)
    if num_vars == 0
        return hash(sent, h)
    end

    vars = Vector{Variable}(undef, num_vars)
    n = 0

    for t in sent
        if is_variable(t)
            idx = @views findfirst(==(t), vars[1:n])
            if idx === nothing
                n += 1
                vars[n] = t
                h = hash(-n, h)
            else
                h = hash(-idx::Int, h)
            end
        else
            h = hash(t.idx, h)
        end
    end
    return h
end

"""
    is_equivalent(x::AbstractSentence, y::AbstractSentence)

Test if `x` and `y` are equal modulo alpha-conversion.

# Example
```jldoctest
julia> is_equivalent(Sentence("how [X] are [X] you [Y] ?"), Sentence("how [P] are [P] you [Q] ?"))
true

julia> is_equivalent(Sentence("how [X] are [X] you [Y] ?"), Sentence("how [P] are [Q] you [Q] ?"))
false
```
"""
function is_equivalent(sent_1::AbstractSentence, sent_2::AbstractSentence)
    if length(sent_1) != length(sent_2)
        return false
    end

    num_vars = count(is_variable, sent_1)
    if num_vars == 0
        return is_identical(sent_1, sent_2)
    end
    vars = Vector{Tuple{Variable,Variable}}(undef, num_vars)
    n = 0

    for (t_1, t_2) in zip(sent_1, sent_2)
        if t_1.type != t_2.type
            return false
        elseif is_variable(t_1)
            idx_1 = @views findfirst(x -> x[1] == t_1, vars[1:n])
            idx_2 = @views findfirst(x -> x[2] == t_2, vars[1:n])
            if (idx_1 === nothing) != (idx_2 === nothing)
                return false
            elseif idx_1 === nothing
                n += 1
                vars[n] = (t_1, t_2)
            elseif idx_1 != idx_2
                return false
            end
        else
            if t_1 != t_2
                return false
            end
        end
    end

    return true
end

function is_equivalent(
    sents_1::AbstractVector{<:AbstractSentence},
    sents_2::AbstractVector{<:AbstractSentence},
)
    if length(sents_1) != length(sents_2)
        return false
    end

    num_vars = sum(count(is_variable, sent) for sent in sents_1)
    if num_vars == 0
        return is_identical(sents_1, sents_2)
    end
    vars = Vector{Tuple{Variable,Variable}}(undef, num_vars)
    n = 0

    for (sent_1, sent_2) in zip(sents_1, sents_2)
        if length(sent_1) != length(sent_2)
            return false
        end
        for (t_1, t_2) in zip(sent_1, sent_2)
            if t_1.type != t_2.type
                return false
            elseif is_variable(t_1)
                idx_1 = @views findfirst(x -> x[1] == t_1, vars[1:n])
                idx_2 = @views findfirst(x -> x[2] == t_2, vars[1:n])
                if (idx_1 === nothing) != (idx_2 === nothing)
                    return false
                elseif idx_1 === nothing
                    n += 1
                    vars[n] = (t_1, t_2)
                elseif idx_1 != idx_2
                    return false
                end
            else
                if t_1 != t_2
                    return false
                end
            end
        end
    end

    return true
end

function is_equivalent(
    first_sent_1::AbstractSentence,
    sents_remain_1::AbstractVector{<:AbstractSentence},
    first_sent_2::AbstractSentence,
    sents_remain_2::AbstractVector{<:AbstractSentence},
)
    if length(first_sent_1) != length(first_sent_2) ||
       length(sents_remain_1) != length(sents_remain_2)
        return false
    elseif isempty(sents_remain_1)
        return is_equivalent(first_sent_1, first_sent_2)
    end


    num_vars =
        count(is_variable, first_sent_1) +
        sum(count(is_variable, sent) for sent in sents_remain_1)
    if num_vars == 0
        return is_identical(first_sent_1, first_sent_2) &&
               is_identical(sents_remain_1, sents_remain_2)
    end
    vars = Vector{Tuple{Variable,Variable}}(undef, num_vars)
    n = 0

    for (t_1, t_2) in zip(first_sent_1, first_sent_2)
        if t_1.type != t_2.type
            return false
        elseif is_variable(t_1)
            idx_1 = @views findfirst(x -> x[1] == t_1, vars[1:n])
            idx_2 = @views findfirst(x -> x[2] == t_2, vars[1:n])
            if (idx_1 === nothing) != (idx_2 === nothing)
                return false
            elseif idx_1 === nothing
                n += 1
                vars[n] = (t_1, t_2)
            elseif idx_1 != idx_2
                return false
            end
        else
            if t_1 != t_2
                return false
            end
        end
    end

    for (sent_1, sent_2) in zip(sents_remain_1, sents_remain_2)
        if length(sent_1) != length(sent_2)
            return false
        end
        for (t_1, t_2) in zip(sent_1, sent_2)
            if t_1.type != t_2.type
                return false
            elseif is_variable(t_1)
                idx_1 = @views findfirst(x -> x[1] == t_1, vars[1:n])
                idx_2 = @views findfirst(x -> x[2] == t_2, vars[1:n])
                if (idx_1 === nothing) != (idx_2 === nothing)
                    return false
                elseif idx_1 === nothing
                    n += 1
                    vars[n] = (t_1, t_2)
                elseif idx_1 != idx_2
                    return false
                end
            else
                if t_1 != t_2
                    return false
                end
            end
        end
    end

    return true
end

"""
    is_concrete(sent::AbstractSentence)

Test if `sent` is a concrete sentence (i.e., sentences without variable).

# Example
```jldoctest
julia> is_concrete(Sentence("hello [X] world"))
false

julia> is_concrete(Sentence("hello world"))
true
```
"""
function is_concrete(sent::AbstractSentence)
    return all(!is_variable(t) for t in sent)
end

"""
    has_no_special_symbol(sent::AbstractSentence)

Test if `sent` has no special symbol.

# Example
```jldoctest
julia> has_no_special_symbol(Sentence("hello [X] world"))
true

julia> has_no_special_symbol(Sentence("\\\$TRUE\\\$ hello world"))
false
```
"""
function has_no_special_symbol(sent::AbstractSentence)
    return all(!is_special_symbol(t) for t in sent)
end

"""
    startswith_word(sent::AbstractSentence)

Test if `sent` starts with a word.

# Example
```jldoctest
julia> startswith_word(Sentence("how [X] are you ?"))
true

julia> startswith_word(Sentence("[X] are you ?"))
false

julia> startswith_word(Sentence())
false
```
"""
function startswith_word(sent::AbstractSentence)
    return !isempty(sent) && is_word(sent[begin])
end

"""
    startswith_variable(sent::AbstractSentence)

Test if `sent` starts with a variable.
"""
function startswith_variable(sent::AbstractSentence)
    return !isempty(sent) && is_variable(sent[begin])
end

"""
    startswith_special_symbol(sent::AbstractSentence)

Test if `sent` starts with a special symbol.
"""
function startswith_special_symbol(sent::AbstractSentence)
    return !isempty(sent) && is_special_symbol(sent[begin])
end

"""
    endswith_word(sent::AbstractSentence)

Test if `sent` ends with a word.
"""
function endswith_word(sent::AbstractSentence)
    return !isempty(sent) && is_word(sent[end])
end

"""
    is_one_variable(sent::AbstractSentence)

Test if `sent` has a single token, which is a variable.

# Example
```jldoctest
julia> is_one_variable(Sentence("[X]"))
true

julia> is_one_variable(Sentence("[X] [Y]"))
false

julia> is_one_variable(Sentence("hi [X]"))
false

julia> is_one_variable(Sentence())
false
```
"""
function is_one_variable(sent::AbstractSentence)
    return length(sent) == 1 && is_variable(sent[begin])
end

"""
    has_only_variables(sent::AbstractSentence)::Bool

Test if `sent` has only variables.

# Example
```jldoctest
julia> has_only_variables(Sentence("[X]"))
true

julia> has_only_variables(Sentence("[X] [Y]"))
true

julia> has_only_variables(Sentence("hi [X]"))
false

julia> has_only_variables(Sentence())
false
```
"""
function has_only_variables(sent::AbstractSentence)
    return !isempty(sent) && all(is_variable(t) for t in sent)
end

function Base.findfirst(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
)::Union{Nothing,UnitRange{Int}}
    len_1 = length(sent_1)
    for i = 1:length(sent_2)-len_1+1
        if is_identical(sent_1, view(sent_2, i:i+len_1-1))
            return i:i+len_1-1
        end
    end
    return nothing
end

function Base.findall(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
)::Vector{UnitRange{Int}}
    matches = UnitRange{Int}[]
    len_1 = length(sent_1)
    for i = 1:length(sent_2)-len_1+1
        if is_identical(sent_1, view(sent_2, i:i+len_1-1))
            push!(matches, i:i+len_1-1)
        end
    end
    return matches
end

"""
    occursin(x::AbstractSentence, y::AbstractSentence)

Test if `x` is a sub-sentence of `y`.

# Example
```jldoctest
julia> occursin(sent"world !", sent"hello world !")
true

julia> occursin(sent"world ?", sent"hello world !")
false
```
"""
function Base.occursin(sent_1::AbstractSentence, sent_2::AbstractSentence)
    return findfirst(sent_1, sent_2) !== nothing
end

function Base.occursin(t::Token, sent::AbstractSentence)
    return t in sent.tokens
end

function Base.in(t::Token, sent::AbstractSentence)
    return t in sent.tokens
end

"""
    startswith(x::AbstractSentence, y::AbstractSentence)

Test if `x` starts with a sub-sentence `y`.

# Example
```jldoctest
julia> startswith(sent"hello world !", sent"hello world")
true

julia> startswith(sent"hello world !", sent"world !")
false
```
"""
function Base.startswith(sent_1::AbstractSentence, sent_2::AbstractSentence)
    return length(sent_2) <= length(sent_1) &&
           is_identical((@view sent_1[1:length(sent_2)]), sent_2)
end

function Base.endswith(sent_1::AbstractSentence, sent_2::AbstractSentence)
    return length(sent_2) <= length(sent_1) &&
           is_identical((@view sent_1[end-length(sent_2)+1:end]), sent_2)
end

function get_de_bruijn(
    sent::AbstractSentence,
    vars::Vector{Variable} = Variable[],
)::Tuple{Sentence,Vector{Variable}}
    tokens = Vector{Token}(undef, length(sent))

    for (j, t) in enumerate(sent)
        if is_variable(t)
            idx = findfirst(==(t), vars)
            if idx === nothing
                push!(vars, t)
                idx = length(vars)
            end
            tokens[j] = create_variable(-idx)
        else
            tokens[j] = t
        end
    end

    return Sentence(tokens), vars
end

function get_de_bruijn(
    sents::AbstractVector{<:AbstractSentence},
)::Tuple{Vector{Sentence},Vector{Variable}}
    vars = Variable[]
    result = Vector{Sentence}(undef, length(sents))
    for (j, sent) in enumerate(sents)
        result[j] = get_de_bruijn(sent, vars)[1]
    end
    return result, vars
end

"""
    concat(sent_1::AbstractSentence, sent_2::AbstractSentence)::Sentence

Concatenate `sent_1` and `sent_2`.

# Example
```jldoctest
julia> concat(Sentence("how are"), Sentence("you ?"))
how are you ?
```
"""
function concat(sent_1::AbstractSentence, sent_2::AbstractSentence)::Sentence
    return Sentence([sent_1.tokens; sent_2.tokens])
end

"""
    concat(t::Token, sent::AbstractSentence)::Sentence

Concatenate `t` and `sent`.

# Example
```jldoctest
julia> concat(word"are", sent"you ?")
are you ?
```
"""
function concat(t::Token, sent::AbstractSentence)::Sentence
    return Sentence([t; sent.tokens])
end

"""
    concat(sent::AbstractSentence, t::Token)::Sentence

Concatenate `sent` and `t`.

# Example
```jldoctest
julia> concat(sent"how are", word"you")
how are you
```
"""
function concat(sent::AbstractSentence, t::Token)::Sentence
    return Sentence([sent.tokens; t])
end

function Base.join(sents::AbstractVector{<:AbstractSentence}, delim::Token)::Sentence
    len = sum(length(s) for s in sents) + length(sents) - 1
    tokens = Vector{Token}(undef, len)
    j = 1
    for (i, s) in enumerate(sents)
        for t in s
            tokens[j] = t
            j += 1
        end
        if i < length(sents)
            tokens[j] = delim
            j += 1
        end
    end
    return Sentence(tokens)
end

"""
    (sent_1::AbstractSentence) * (sent_2::AbstractSentence)

An alias of [`concat`](@ref).

# Example
```jldoctest
julia> Sentence("how are") * Sentence("you ?")
how are you ?
```
"""
function Base.:*(
    sent_1::Union{AbstractSentence,Token},
    sent_2::Union{AbstractSentence,Token},
)::Sentence
    return concat(sent_1, sent_2)
end


"""
    prefix, suffix_1, suffix_2 = find_common_prefix(sent_1, sent_2; requires_concrete::Bool)

Split `sent_1` and `sent_2` into a common prefix and two different suffixes.

If `requires_concrete == true`, then `prefix` is required to be a concrete prefix.

# Example
```jldoctest
julia> sent_1 = Sentence("hello world [X] world foo foo");

julia> sent_2 = Sentence("hello world [X] world bar bar");

julia> find_common_prefix(sent_1, sent_2, requires_concrete=true)
(hello world, [X] world foo foo, [X] world bar bar)

julia> find_common_prefix(sent_1, sent_2, requires_concrete=false)
(hello world [X] world, foo foo, bar bar)
```
"""
function find_common_prefix(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence;
    requires_concrete::Bool,
)::NTuple{3,SentenceView}
    diff_idx = min(length(sent_1), length(sent_2)) + 1
    for (i, (t_1, t_2)) in enumerate(zip(sent_1, sent_2))
        if t_1 != t_2 || (requires_concrete && is_variable(t_1))
            diff_idx = i
            break
        end
    end
    prefix = @view sent_1[1:diff_idx-1]
    suffix_1 = @view sent_1[diff_idx:end]
    suffix_2 = @view sent_2[diff_idx:end]
    return prefix, suffix_1, suffix_2
end

"""
    prefix_1, prefix_2, suffix = find_common_suffix(sent_1, sent_2; requires_concrete::Bool)

Split `sent_1` and `sent_2` into a common suffix and two different prefixes.

If `requires_concrete == true`, then `suffix` is required to be a concrete suffix.
"""
function find_common_suffix(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence;
    requires_concrete::Bool,
)::NTuple{3,SentenceView}
    min_len = min(length(sent_1), length(sent_2))
    diff_rev_idx = min_len + 1
    for i = 1:min_len
        t_1 = sent_1[end+1-i]
        t_2 = sent_2[end+1-i]
        if t_1 != t_2 || (requires_concrete && is_variable(t_1))
            diff_rev_idx = i
            break
        end
    end
    prefix_1 = @view sent_1[1:end+1-diff_rev_idx]
    prefix_2 = @view sent_2[1:end+1-diff_rev_idx]
    suffix = @view sent_1[end+1-diff_rev_idx+1:end]

    return prefix_1, prefix_2, suffix
end

"""
    infix_1, infix_2 = find_different_infixes(sent_1, sent_2; requires_concrete::Bool)

Return the different infixes of `sent_1` and `sent_2`.
"""
function find_different_infixes(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence;
    requires_concrete::Bool,
)::NTuple{2,SentenceView}
    _, suffix_1, suffix_2 =
        find_common_prefix(sent_1, sent_2, requires_concrete = requires_concrete)
    infix_1, infix_2, _ =
        find_common_suffix(suffix_1, suffix_2, requires_concrete = requires_concrete)
    return infix_1, infix_2
end

"""
    flip_variables(sent::AbstractSentence)::Sentence

Flip the signs of the variable indexs in `sent`. 

Variables with negative indexes are for internal use only.
"""
function flip_variables(sent::AbstractSentence)
    return Sentence([is_variable(t) ? create_variable(-t.idx) : t for t in sent])
end

export AbstractSentence,
    Sentence,
    SentenceView,
    @sent_str,
    is_concrete,
    has_no_special_symbol,
    get_variables,
    is_one_variable,
    has_only_variables,
    startswith_word,
    startswith_variable,
    startswith_special_symbol,
    endswith_word,
    is_equivalent,
    is_identical,
    alpha_invariant_hash,
    get_de_bruijn,
    concat,
    find_common_prefix,
    find_common_suffix,
    find_different_infixes,
    flip_variables
