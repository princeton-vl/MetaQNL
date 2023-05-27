using Serialization: serialize, deserialize

"""
A vocabulary is a bijection between strings and their indexes (integers).

Three built-in vocabularies are accessible globally:
* [`word_vocab`](@ref) for words, ``\\Sigma_w``
* [`variable_vocab`](@ref) for variables, ``\\Sigma_v``
* [`special_symbol_vocab`](@ref) for special symbols, ``\\Sigma_s``
Users usually do not need to create new vocabularies.
"""
struct Vocab
    idx2str::Vector{String}
    str2idx::Dict{String,Int}
    valid_pattern::Regex

    function Vocab(idx2str, valid_pattern)
        str2idx = Dict(str => idx for (idx, str) in enumerate(idx2str))
        @assert all(match(valid_pattern, str) !== nothing for str in idx2str)
        return new(idx2str, str2idx, valid_pattern)
    end
end

function Vocab(valid_pattern::Regex)
    return Vocab(String[], valid_pattern)
end

"""
    vocab[idx]

Return the `idx`th string in `vocab`.
"""
function Base.getindex(vocab::Vocab, idx::Integer)
    return vocab.idx2str[idx]
end

"""
    vocab[str]

Return the index of `str` in `vocab`; add `str` to the vocabulary if it does not already exist.
"""
function Base.getindex(vocab::Vocab, str::AbstractString)
    idx = get(vocab.str2idx, str, nothing)
    if idx === nothing
        @assert match(vocab.valid_pattern, str) !== nothing "Invalid token \"$str\""
        push!(vocab.idx2str, str)
        idx = length(vocab.idx2str)
        vocab.str2idx[str] = idx
    end
    return idx
end

function Base.iterate(vocab::Vocab)
    return iterate(vocab.idx2str)
end

function Base.iterate(vocab::Vocab, state)
    return iterate(vocab.idx2str, state)
end

function Base.length(vocab::Vocab)
    return length(vocab.idx2str)
end

"""
    push!(vocab, str)

Add a new token `str` to `vocab`.
"""
function Base.push!(vocab::Vocab, str)
    @assert match(vocab.valid_pattern, str) !== nothing "Invalid token \"$str\""
    if !haskey(vocab.str2idx, str)
        push!(vocab.idx2str, str)
        vocab.str2idx[str] = length(vocab.idx2str)
    end
    return vocab
end

"""
    append!(vocab, strs)

Add multiple new tokens `strs` to `vocab`.
"""
function Base.append!(vocab::Vocab, strs)
    for s in strs
        push!(vocab, s)
    end
    return vocab
end

function Base.empty!(vocab::Vocab)
    empty!(vocab.idx2str)
    empty!(vocab.str2idx)
    return vocab
end

"""
    Word vocabulary ``\\Sigma_w``

Words must conform to the regular expression `^[^\\s\\[\\]\\\$]+\$`.
"""
const word_vocab = Vocab(r"^[^\s\[\]\$]+$")

"""
    Variable vocabulary ``\\Sigma_v``

Variables must conform to the regular expression `^[A-Z]+\$`.
"""
const variable_vocab = Vocab(r"^[A-Z]+$")

"""
Special symbol vocabulary ``\\Sigma_s``

Special symbols must conform to the regular expression `^[^\\s\\[\\]\\\$]+\$`.
"""
const special_symbol_vocab = Vocab(r"^[^\s\[\]\$]+$")

"""
    save_vocabs(filename::AbstractString)

Save the three vocabularies to `filename`.
"""
function save_vocabs(filename::AbstractString)
    serialize(
        filename,
        Dict(
            "word" => word_vocab.idx2str,
            "variable" => variable_vocab.idx2str,
            "special_symbol" => special_symbol_vocab.idx2str,
        ),
    )
end

function reset_vocab!(vocab, idx2str)
    @assert length(vocab) <= length(idx2str) && idx2str[1:length(vocab)] == vocab.idx2str "The new vocab is incompatible with the existing one."
    empty!(vocab)
    return append!(vocab, idx2str)
end

"""
    load_vocabs(filename::AbstractString)

Load the three vocabularies from `filename`.
"""
function load_vocabs(filename::AbstractString)
    vocabs = deserialize(filename)
    reset_vocab!(word_vocab, vocabs["word"])
    reset_vocab!(variable_vocab, vocabs["variable"])
    reset_vocab!(special_symbol_vocab, vocabs["special_symbol"])
    return nothing
end

reset_vocab!(variable_vocab, [string('A' + i) for i = 0:25])

export word_vocab,
    variable_vocab, special_symbol_vocab, save_vocabs, reset_vocab!, load_vocabs
