using Combinatorics: permutations

struct BiSubstitutionNode
    parent::Union{BiSubstitutionNode,Nothing}
    var::Variable
    sent_1::Sentence
    sent_2::Sentence
end

function BiSubstitutionNode(var, sent_1, sent_2)
    return BiSubstitutionNode(nothing, var, sent_1, sent_2)
end

mutable struct BiSubstitution
    leaf::Union{BiSubstitutionNode,Nothing}
    accepts_free_variable::Bool
end

function BiSubstitution()
    return BiSubstitution(nothing, true)
end

function Base.iterate(bi_subst::BiSubstitution)
    if bi_subst.leaf === nothing
        return nothing
    end
    node = bi_subst.leaf
    return (node.var, (node.sent_1, node.sent_2)), bi_subst.leaf.parent
end

function Base.iterate(::BiSubstitution, node)
    if node === nothing
        return nothing
    end
    return (node.var, (node.sent_1, node.sent_2)), node.parent
end

function Base.:(==)(bi_subst_1::BiSubstitution, bi_subst_2::BiSubstitution)
    return get_substitutions(bi_subst_1) == get_substitutions(bi_subst_2)
end

function get_substitutions(bi_subst::BiSubstitution)
    subst_1 = Substitution()
    subst_2 = Substitution()
    for (var, (sent_1, sent_2)) in bi_subst
        subst_1[var] = sent_1
        subst_2[var] = sent_2
    end
    return subst_1, subst_2
end

function retrieve_variable(
    bi_subst::BiSubstitution,
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
)::Tuple{Variable,Bool}
    for (var, (s_1, s_2)) in bi_subst
        if is_identical(sent_1, s_1) && is_identical(sent_2, s_2)
            return var, false
        end
    end
    new_var = isempty(bi_subst) ? first_variable() : next_variable(bi_subst.leaf.var)
    return new_var, true
end

function push(
    bi_subst::BiSubstitution,
    var::Variable,
    sent_1::Sentence,
    sent_2::Sentence,
    is_free::Bool,
)
    @assert bi_subst.accepts_free_variable || !is_free
    node = BiSubstitutionNode(bi_subst.leaf, var, sent_1, sent_2)
    return BiSubstitution(node, bi_subst.accepts_free_variable && !is_free)
end

function push(
    bi_subst::BiSubstitution,
    var::Variable,
    sent_1::SentenceView,
    sent_2::SentenceView,
    is_free::Bool,
)
    return push(bi_subst, var, sent_1[begin:end], sent_2[begin:end], is_free)
end

function bind_variable!(
    bi_subst::BiSubstitution,
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1,
    sents_remain_2,
)::Tuple{Variable,Union{Nothing,BiSubstitution}}
    var, is_new = retrieve_variable(bi_subst, sent_1, sent_2)
    if is_new
        is_free = !occurs_in_remaining(sent_1, sent_2, sents_remain_1, sents_remain_2)
        if is_free && !bi_subst.accepts_free_variable
            return var, nothing
        else
            return var, push(bi_subst, var, sent_1, sent_2, is_free)
        end
    else
        return var, bi_subst
    end
end


function Base.show(io::IO, bi_subst::BiSubstitution)
    print(io, "{")
    for (var, (sent_1, sent_2)) in bi_subst
        print(io, var, " -> (\"", sent_1, "\", \"", sent_2, "\"), ")
    end
    print(io, "}")
end

struct AntiUnifier{T<:Union{Sentence,Rule,Vector{Sentence}}}
    general_instance::T
    bi_substitution::BiSubstitution
end

function AntiUnifier(sent::SentenceView, bi_subst)
    return AntiUnifier{Sentence}(sent[begin:end], bi_subst)
end

function Base.:(==)(au_1::AntiUnifier, au_2::AntiUnifier)
    return au_1.general_instance == au_2.general_instance &&
           au_1.bi_substitution == au_2.bi_substitution
end

function get_specific_instances(au::AntiUnifier)
    subst_1, subst_2 = get_substitutions(au.bi_substitution)
    return subst_1(au.general_instance), subst_2(au.general_instance)
end

function occurs_in_remaining(
    sent::AbstractSentence,
    remaining_sents::Union{Vector{<:AbstractSentence},Nothing},
)
    return remaining_sents === nothing || any(occursin(sent, s) for s in remaining_sents)
end

function occurs_in_remaining(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1::Union{Vector{<:AbstractSentence},Nothing},
    sents_remain_2::Union{Vector{<:AbstractSentence},Nothing},
)
    return occurs_in_remaining(sent_1, sents_remain_1) &&
           occurs_in_remaining(sent_2, sents_remain_2)
end

function can_match(
    suffix_1::AbstractSentence,
    suffix_2::AbstractSentence,
    bi_subst::BiSubstitution,
)
    if length(suffix_1) == length(suffix_2)
        return true
    elseif isempty(suffix_1) || isempty(suffix_2)
        return false
    end

    for (_, (sent_1, sent_2)) in bi_subst
        if startswith(suffix_1, sent_1) &&
           startswith(suffix_2, sent_2) &&
           (is_identical(suffix_1, sent_1) == is_identical(suffix_2, sent_2))
            return true
        end
    end

    return suffix_1[begin] == suffix_2[begin] &&
           ((length(suffix_1) == 1) == (length(suffix_2) == 1))
end

function anti_unify(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1::Union{Vector{Sentence},Nothing} = nothing,
    sents_remain_2::Union{Vector{Sentence},Nothing} = nothing,
    bi_subst::BiSubstitution = BiSubstitution(),
)::Vector{AntiUnifier{Sentence}}
    if sent_1 == sent_2 && is_concrete(sent_1)
        return [AntiUnifier(sent_1, bi_subst)]
    end

    if has_no_special_symbol(sent_1) && has_no_special_symbol(sent_2)
        return anti_unify_no_special_symbol(
            sent_1,
            sent_2,
            sents_remain_1,
            sents_remain_2,
            bi_subst,
        )
    end

    tpl_1, segments_1 = decompose(sent_1)
    tpl_2, segments_2 = decompose(sent_2)
    if tpl_1 != tpl_2
        return AntiUnifier{Sentence}[]
    end

    return [
        AntiUnifier(compose(tpl_1, au.general_instance), au.bi_substitution) for
        au in anti_unify_no_special_symbol(
            segments_1,
            segments_2,
            sents_remain_1,
            sents_remain_2,
            bi_subst,
        )
    ]
end

function anti_unify(
    sents_1::AbstractVector{<:AbstractSentence},
    sents_2::AbstractVector{<:AbstractSentence},
    sents_remain_1::Union{Vector{Sentence},Nothing},
    sents_remain_2::Union{Vector{Sentence},Nothing},
    bi_subst::BiSubstitution,
)::Vector{AntiUnifier{Vector{Sentence}}}
    @assert length(sents_1) == length(sents_2)
    if isempty(sents_1)
        return [AntiUnifier(Sentence[], bi_subst)]
    end

    if all(has_no_special_symbol(s) for s in sents_1) &&
       all(has_no_special_symbol(s) for s in sents_2)
        return anti_unify_no_special_symbol(
            sents_1,
            sents_2,
            sents_remain_1,
            sents_remain_2,
            bi_subst,
        )
    end

    all_tpls_1, all_segments_1 = decompose(sents_1)
    all_tpls_2, all_segments_2 = decompose(sents_2)
    if all_tpls_1 != all_tpls_2
        return AntiUnifier{Vector{Sentence}}[]
    end

    aus = anti_unify_no_special_symbol(
        reduce(vcat, all_segments_1),
        reduce(vcat, all_segments_2),
        sents_remain_1,
        sents_remain_2,
        bi_subst,
    )
    results = Vector{AntiUnifier{Vector{Sentence}}}(undef, length(aus))

    for (i, au) in enumerate(aus)
        all_segs = Vector{Vector{Sentence}}(undef, length(all_segments_1))
        base = 1
        for (j, s) in enumerate(all_segments_1)
            l = length(s)
            all_segs[j] = au.general_instance[base:base+l-1]
            base += l
        end
        general_instance = compose(all_tpls_1, all_segs)
        results[i] = AntiUnifier(general_instance, au.bi_substitution)
    end

    return results
end

function anti_unify(rule_1::Rule, rule_2::Rule)::Vector{Rule}
    if length(rule_1.premises) != length(rule_2.premises)
        return Rule[]
    end

    results = Set{Rule}()

    for au_concl in anti_unify(
        rule_1.conclusion,
        rule_2.conclusion,
        rule_1.premises,
        rule_2.premises,
        BiSubstitution(nothing, false),  # No free variables in the conclusion.
    )
        au_concl.bi_substitution.accepts_free_variable = true
        for permuted_prems_2 in permutations(rule_2.premises)
            for au_prems in anti_unify(
                rule_1.premises,
                permuted_prems_2,
                Sentence[],
                Sentence[],
                au_concl.bi_substitution,
            )
                g = Rule(au_prems.general_instance, au_concl.general_instance)
                g = normalize(g)
                if !isvalid(g)
                    continue
                end
                push!(results, g)
            end
        end
    end

    return collect(results)
end

function anti_unify_infixes(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1::Union{Vector{Sentence},Nothing},
    sents_remain_2::Union{Vector{Sentence},Nothing},
    bi_subst::BiSubstitution,
)::Vector{AntiUnifier{Sentence}}
    results = AntiUnifier{Sentence}[]

    if length(sent_1) > 1 && length(sent_2) > 1
        matches = Tuple{Int,Int}[]

        for len_p_1 = 1:(length(sent_1)-1)
            prefix_1 = @view sent_1[begin:begin+len_p_1-1]
            suffix_1 = @view sent_1[begin+len_p_1:end]
            for len_p_2 = 1:length(sent_2)-1
                if findfirst(m -> len_p_1 > m[1] && len_p_2 > m[2], matches) !== nothing
                    continue
                end

                prefix_2 = @view sent_2[begin:begin+len_p_2-1]
                suffix_2 = (@view sent_2[begin+len_p_2:end])

                # sent_1 = prefix_1 suffix_1
                # sent_2 = prefix_2 suffix_2
                # prefix_1 <- [X] -> prefix_2
                # suffix_1 <- [Y] -> suffix_2
                is_new = retrieve_variable(bi_subst, prefix_1, prefix_2)[2]
                if is_new && (
                    !can_match(suffix_1, suffix_2, bi_subst) ||
                    (prefix_1[end] == prefix_2[end] && is_word(prefix_1[end]))
                )
                    continue
                end

                var_p, bi_subst_p = bind_variable!(
                    bi_subst,
                    prefix_1,
                    prefix_2,
                    sents_remain_1,
                    sents_remain_2,
                )
                if bi_subst_p === nothing
                    continue
                end

                push!(matches, (len_p_1, len_p_2))
                aus = anti_unify_no_special_symbol(
                    suffix_1,
                    suffix_2,
                    sents_remain_1,
                    sents_remain_2,
                    bi_subst_p,
                )

                if isempty(aus)
                    continue
                end

                for au in aus
                    pushfirst!(au.general_instance, var_p)
                    push!(results, au)
                end
            end
        end

    end

    if isempty(results)
        # sent_1 <- [X] -> sent_2
        let (var, bi_subst_new) =
                bind_variable!(bi_subst, sent_1, sent_2, sents_remain_1, sents_remain_2)
            if bi_subst_new !== nothing
                push!(results, AntiUnifier(Sentence([var]), bi_subst_new))
            end
        end
    end

    return results
end

function anti_unify_long_sentences(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1::Union{Vector{Sentence},Nothing},
    sents_remain_2::Union{Vector{Sentence},Nothing},
    bi_subst::BiSubstitution,
)::Vector{AntiUnifier{Sentence}}
    LCSs = find_longest_common_subsequences(sent_1, sent_2)
    results = AntiUnifier{Sentence}[]

    for lcs in LCSs
        if isempty(lcs)
            return results
        end

        bi_subst_new = bi_subst
        tokens = Token[]
        prev_i = prev_j = 0

        for (i, j) in lcs
            if ((i == length(sent_1)) != (j == length(sent_2))) ||
               ((i == prev_i + 1) != (j == prev_j + 1))

            elseif i == prev_i + 1 && j == prev_j + 1
                push!(tokens, sent_1[i])
                prev_i, prev_j = i, j
            elseif i != prev_i + 1 && j != prev_j + 1
                var, bi_subst_new = bind_variable!(
                    bi_subst_new,
                    (@view sent_1[prev_i+1:i-1]),
                    (@view sent_2[prev_j+1:j-1]),
                    sents_remain_1,
                    sents_remain_2,
                )
                if bi_subst_new === nothing
                    break
                end
                push!(tokens, var)
                push!(tokens, sent_1[i])
                prev_i, prev_j = i, j
            end
        end

        if bi_subst_new !== nothing && prev_i < length(sent_1) && prev_j < length(sent_2)
            var, bi_subst_new = bind_variable!(
                bi_subst_new,
                (@view sent_1[prev_i+1:end]),
                (@view sent_2[prev_j+1:end]),
                sents_remain_1,
                sents_remain_2,
            )
            if bi_subst_new !== nothing
                push!(tokens, var)
            end
        end

        if bi_subst_new !== nothing
            push!(results, AntiUnifier(Sentence(tokens), bi_subst_new))
        end
    end

    return results
end

function find_longest_common_subsequences(sent_1, sent_2)::Vector{Vector{Tuple{Int,Int}}}
    m = length(sent_1)
    n = length(sent_2)
    dp_table = zeros(Int, m + 1, n + 1)

    for i = 1:m
        for j = 1:n
            # Fill dp_table[i+1, j+1] with the length of LCSs of sent_1[1:i] and sent_2[1:j].
            if sent_1[i] == sent_2[j]
                dp_table[i+1, j+1] = 1 + dp_table[i, j]
            else
                dp_table[i+1, j+1] = max(dp_table[i, j+1], dp_table[i+1, j])
            end
        end
    end

    LCSs = Vector{Tuple{Int,Int}}[]
    queue = Queue{Tuple{Tuple{Int,Int},Vector{Tuple{Int,Int}}}}()
    enqueue!(queue, ((m, n), Tuple{Int,Int}[]))

    while !isempty(queue)
        (i, j), inv_suffix = dequeue!(queue)
        if i == 0 || j == 0
            push!(LCSs, reverse(inv_suffix))
            continue
        end

        if sent_1[i] == sent_2[j]
            push!(inv_suffix, (i, j))
            enqueue!(queue, ((i - 1, j - 1), inv_suffix))
        elseif dp_table[i, j+1] > dp_table[i+1, j]
            enqueue!(queue, ((i - 1, j), inv_suffix))
        elseif dp_table[i, j+1] < dp_table[i+1, j]
            enqueue!(queue, ((i, j - 1), inv_suffix))
        else
            enqueue!(queue, ((i - 1, j), inv_suffix))
        end
    end

    return unique(LCSs)
end

function anti_unify_same_lengths(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1::Union{Vector{Sentence},Nothing},
    sents_remain_2::Union{Vector{Sentence},Nothing},
    bi_subst::BiSubstitution,
)::Vector{AntiUnifier{Sentence}}
    @assert length(sent_1) == length(sent_2)
    tokens = Token[]

    for i = 1:length(sent_1)
        if sent_1[i] == sent_2[i]
            push!(tokens, sent_1[i])
        else
            var, bi_subst = bind_variable!(
                bi_subst,
                (@view sent_1[i:i]),
                (@view sent_2[i:i]),
                sents_remain_1,
                sents_remain_2,
            )
            if bi_subst === nothing
                return AntiUnifier{Sentence}[]
            end
            push!(tokens, var)
        end
    end

    return [AntiUnifier(Sentence(tokens), bi_subst)]
end

function anti_unify_no_special_symbol(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    sents_remain_1::Union{Vector{Sentence},Nothing},
    sents_remain_2::Union{Vector{Sentence},Nothing},
    bi_subst::BiSubstitution,
    length_thres::Int = 10,
)::Vector{AntiUnifier{Sentence}}
    if sent_1 == sent_2 && is_concrete(sent_1)
        return [AntiUnifier(sent_1, bi_subst)]
    end

    results = AntiUnifier{Sentence}[]

    prefix, suffix_1, suffix_2 =
        find_common_prefix(sent_1, sent_2, requires_concrete = true)
    _, _, suffix = find_common_suffix(suffix_1, suffix_2, requires_concrete = true)

    if prefix == sent_1
        # sent_1 is a concrete prefix of sent_2
        @assert length(prefix) < length(sent_2)
        len_p = length(prefix) - 1
        var, bi_subst_new = bind_variable!(
            bi_subst,
            (@view sent_1[end:end]),
            (@view sent_2[begin+len_p:end]),
            sents_remain_1,
            sents_remain_2,
        )
        if bi_subst_new !== nothing
            push!(results, AntiUnifier(sent_1[begin:end-1] * var, bi_subst_new))
        end

    elseif prefix == sent_2
        # sent_2 is a concrete prefix of sent_1
        @assert length(prefix) < length(sent_1)
        len_p = length(prefix) - 1
        var, bi_subst_new = bind_variable!(
            bi_subst,
            (@view sent_1[begin+len_p:end]),
            (@view sent_2[end:end]),
            sents_remain_1,
            sents_remain_2,
        )
        if bi_subst_new !== nothing
            push!(results, AntiUnifier(sent_2[begin:end-1] * var, bi_subst_new))
        end

    elseif suffix == sent_1
        # sent_1 is a concrete suffix of sent_2
        @assert length(suffix) < length(sent_2)
        len_s = length(suffix) - 1
        var, bi_subst_new = bind_variable!(
            bi_subst,
            (@view sent_1[begin:begin]),
            (@view sent_2[begin:end-len_s]),
            sents_remain_1,
            sents_remain_2,
        )
        if bi_subst_new !== nothing
            push!(results, AntiUnifier(var * sent_1[begin+1:end], bi_subst_new))
        end

    elseif suffix == sent_2
        # sent_2 is a concrete suffix of sent_1
        @assert length(suffix) < length(sent_1)
        len_s = length(suffix) - 1
        var, bi_subst_new = bind_variable!(
            bi_subst,
            (@view sent_1[begin:end-len_s]),
            (@view sent_2[begin:begin]),
            sents_remain_1,
            sents_remain_2,
        )
        if bi_subst_new !== nothing
            push!(results, AntiUnifier(var * sent_2[begin+1:end], bi_subst_new))
        end

    elseif length(prefix) + length(suffix) == length(sent_1)
        # sent_2 is the result of inserting something into the middle of sent_1
        for (len_p, len_s) in
            ((length(prefix) - 1, length(suffix)), (length(prefix), length(suffix) - 1))
            var, bi_subst_new = bind_variable!(
                bi_subst,
                (@view sent_1[begin+len_p:begin+len_p]),
                (@view sent_2[begin+len_p:end-len_s]),
                sents_remain_1,
                sents_remain_2,
            )
            if bi_subst_new !== nothing
                push!(
                    results,
                    AntiUnifier(
                        sent_2[begin:begin+len_p-1] * var * sent_2[end-len_s+1:end],
                        bi_subst_new,
                    ),
                )
            end
        end

    elseif length(prefix) + length(suffix) == length(sent_2)
        # sent_1 is the result of inserting something into the middle of sent_2
        for (len_p, len_s) in
            ((length(prefix) - 1, length(suffix)), (length(prefix), length(suffix) - 1))
            var, bi_subst_new = bind_variable!(
                bi_subst,
                (@view sent_1[begin+len_p:end-len_s]),
                (@view sent_2[begin+len_p:begin+len_p]),
                sents_remain_1,
                sents_remain_2,
            )
            if bi_subst_new !== nothing
                push!(
                    results,
                    AntiUnifier(
                        sent_1[begin:begin+len_p-1] * var * sent_1[end-len_s+1:end],
                        bi_subst_new,
                    ),
                )
            end
        end

    else
        len_p = length(prefix)
        len_s = length(suffix)
        infix_1 = @view sent_1[begin+len_p:end-len_s]
        infix_2 = @view sent_2[begin+len_p:end-len_s]
        @assert !isempty(infix_1) && !isempty(infix_2)
        aus = AntiUnifier{Sentence}[]

        if length(infix_1) > length_thres || length(infix_2) > length_thres
            append!(
                aus,
                anti_unify_long_sentences(
                    infix_1,
                    infix_2,
                    sents_remain_1,
                    sents_remain_2,
                    bi_subst,
                ),
            )
        else
            append!(
                aus,
                anti_unify_infixes(
                    infix_1,
                    infix_2,
                    sents_remain_1,
                    sents_remain_2,
                    bi_subst,
                ),
            )
        end

        for au in aus
            sent = sent_1[begin:begin+len_p-1]
            append!(sent, au.general_instance)
            append!(sent, @view sent_2[end-len_s+1:end])
            push!(results, AntiUnifier(sent, au.bi_substitution))
        end
    end

    return results
end

function anti_unify_no_special_symbol(
    sents_1::AbstractVector{Sentence},
    sents_2::AbstractVector{Sentence},
    sents_remain_1::Union{Vector{Sentence},Nothing},
    sents_remain_2::Union{Vector{Sentence},Nothing},
    bi_subst::BiSubstitution,
)::Vector{AntiUnifier{Vector{Sentence}}}
    @assert length(sents_1) == length(sents_2)
    if isempty(sents_1)
        return [AntiUnifier(Sentence[], bi_subst)]
    end

    # Anti-unify the elements sequentially, starting with the first pair
    results = AntiUnifier{Vector{Sentence}}[]
    other_sents_1 = sents_1[2:end]
    other_sents_2 = sents_2[2:end]

    for au_first in anti_unify_no_special_symbol(
        sents_1[1],
        sents_2[1],
        sents_remain_1 === nothing ? nothing : [other_sents_1; sents_remain_1],
        sents_remain_2 === nothing ? nothing : [other_sents_2; sents_remain_2],
        bi_subst,
    )
        for au_others in anti_unify_no_special_symbol(
            other_sents_1,
            other_sents_2,
            sents_remain_1,
            sents_remain_2,
            au_first.bi_substitution,
        )
            pushfirst!(au_others.general_instance, au_first.general_instance)
            push!(results, au_others)
        end
    end

    return results
end

export anti_unify, AntiUnifier, get_specific_instances
