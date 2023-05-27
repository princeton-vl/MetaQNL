# Templates are used internally in unification/matching/anti-unification for pruning invalid solutions for computational efficiency.
# They are not that important conceptually.

"""
A sentence template is obtained by replacing all segments of words/variables with special symbols of index -1.

# Fields
`symbols::Vector{SpecialSymbol}`
"""
struct SentenceTemplate
    symbols::Vector{SpecialSymbol}
end

function Base.show(io::IO, tpl::SentenceTemplate)
    len = length(tpl.symbols)
    for (i, s) in enumerate(tpl.symbols)
        print(io, s)
        if i < len
            print(io, ' ')
        end
    end
end

"""
    SentenceTemplate(sent::AbstractSentence)

Create a sentence template from `sent`.

# Example
```jldoctest
julia> SentenceTemplate(sent"hello world !")
\$-1\$

julia> SentenceTemplate(sent"hello world ! \$MAPS_TO\$ hallo welt !")
\$-1\$ \$MAPS_TO\$ \$-1\$
```
"""
function SentenceTemplate(sent::AbstractSentence)
    symbols = SpecialSymbol[]
    for t in sent
        if is_special_symbol(t)
            push!(symbols, t)
        elseif isempty(symbols) || symbols[end].idx >= 1
            push!(symbols, create_special_symbol(-1))
        end
    end
    return SentenceTemplate(symbols)
end

function decompose(sent::Sentence)::Tuple{SentenceTemplate,Vector{Sentence}}
    symbols = SpecialSymbol[]
    segments = Sentence[]
    start_idx = 0

    for (i, t) in enumerate(sent)
        if is_special_symbol(t)
            push!(symbols, t)
            if start_idx > 0
                push!(segments, sent[start_idx:i-1])
                start_idx = 0
            end
        else
            if isempty(symbols) || symbols[end].idx >= 1
                push!(symbols, create_special_symbol(-1))
                start_idx = i
            end
        end
    end

    if start_idx > 0
        push!(segments, sent[start_idx:end])
    end

    return SentenceTemplate(symbols), segments
end

function decompose(
    sents::AbstractVector{Sentence},
)::Tuple{Vector{SentenceTemplate},Vector{Vector{Sentence}}}
    len = length(sents)
    all_tpls = Vector{SentenceTemplate}(undef, len)
    all_segments = Vector{Vector{Sentence}}(undef, len)

    for (i, sent) in enumerate(sents)
        tpl, segments = decompose(sent)
        all_tpls[i] = tpl
        all_segments[i] = segments
    end

    return all_tpls, all_segments
end

function compose(
    tpl::SentenceTemplate,
    segments::AbstractVector{<:AbstractSentence},
)::Sentence
    len = length(tpl.symbols) - length(segments)
    for seg in segments
        len += length(seg)
    end
    tokens = Vector{Token}(undef, len)

    i = 1
    j = 1
    for s in tpl.symbols
        if s.idx >= 1
            tokens[j] = s
            j += 1
        else  # $-1$
            for t in segments[i]
                tokens[j] = t
                j += 1
            end
            i += 1
        end
    end
    @assert i == length(segments) + 1

    return Sentence(tokens)
end

function compose(
    all_tpls::AbstractVector{SentenceTemplate},
    all_segments::AbstractVector{<:AbstractVector{<:AbstractSentence}},
)::Vector{Sentence}
    @assert length(all_tpls) == length(all_segments)
    return [compose(tpl, segments) for (tpl, segments) in zip(all_tpls, all_segments)]
end

function Base.:(==)(t1::SentenceTemplate, t2::SentenceTemplate)
    return t1.symbols == t2.symbols
end

function Base.hash(tpl::SentenceTemplate, h::UInt)::UInt
    h = xor(h, 0x0f38fbcad91f7f0d)  # h = hash(SentenceTemplate, h)
    for s in tpl.symbols
        h = hash(s, h)
    end
    return h
end

function Base.isless(t1::SentenceTemplate, t2::SentenceTemplate)
    return t1.symbols < t2.symbols
end

struct RuleTemplate
    premises::Vector{SentenceTemplate}
    conclusion::SentenceTemplate

    function RuleTemplate(premises, conclusion)
        sort!(premises)
        return new(premises, conclusion)
    end
end

function RuleTemplate(rule::Rule)
    premises = [SentenceTemplate(p) for p in rule.premises]
    conclusion = SentenceTemplate(rule.conclusion)
    return RuleTemplate(premises, conclusion)
end

function Base.:(==)(t1::RuleTemplate, t2::RuleTemplate)
    return t1.conclusion == t2.conclusion && t1.premises == t2.premises
end

function Base.hash(t::RuleTemplate, h::UInt)::UInt
    h = xor(h, 0xdc3ac64605dbe521)  # h = hash(RuleTemplate, h)
    h = hash(t.conclusion, h)
    for p in t.premises
        h = hash(p, h)
    end
    return h
end

function Base.isless(t1::RuleTemplate, t2::RuleTemplate)
    return t1.conclusion < t2.conclusion ||
           (t1.conclusion == t2.conclusion && t1.premises < t2.premises)
end

export SentenceTemplate, RuleTemplate
