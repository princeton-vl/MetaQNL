"""
    unify(sent_1::AbstractSentence, sent_2::AbstractSentence)::Vector{Substitution}

Return the unifiers of `sent_1` and `sent_2`.

# Example
```jldoctest
julia> unify(sent"dax fep", sent"dax [X]")
1-element Vector{Substitution}:
 {[X] -> fep, }

julia> unify(sent"hello [X]", sent"[X] hello", depth_limit = 10)
10-element Vector{Substitution}:
 {[X] -> hello, }
 {[X] -> hello hello, }
 {[X] -> hello hello hello, }
 {[X] -> hello hello hello hello, }
 {[X] -> hello hello hello hello hello, }
 {[X] -> hello hello hello hello hello hello, }
 {[X] -> hello hello hello hello hello hello hello, }
 {[X] -> hello hello hello hello hello hello hello hello, }
 {[X] -> hello hello hello hello hello hello hello hello hello, }
 {[X] -> hello hello hello hello hello hello hello hello hello hello, }
```
"""
function unify(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence;
    depth_limit::Int = 5,
)::Vector{Substitution}
    if is_concrete(sent_1)
        return match(sent_2, sent_1)
    elseif is_concrete(sent_2)
        return match(sent_1, sent_2)
    end

    no_symbol_1 = has_no_special_symbol(sent_1)
    no_symbol_2 = has_no_special_symbol(sent_2)

    if no_symbol_1 && no_symbol_2
        return unify_no_special_symbol(sent_1, sent_2, depth_limit)
    elseif no_symbol_1 || no_symbol_2
        return Substitution[]
    else
        tpl_1, segments_1 = decompose(sent_1)
        tpl_2, segments_2 = decompose(sent_2)
        if tpl_1 != tpl_2
            return Substitution[]
        end
        return unify_no_special_symbol(segments_1, segments_2, depth_limit)
    end
end

function unify_no_special_symbol(
    sents_1::AbstractVector{<:AbstractSentence},
    sents_2::AbstractVector{<:AbstractSentence},
    depth_limit::Int,
)::Vector{Substitution}
    @assert length(sents_1) == length(sents_2)
    if isempty(sents_1)
        return [Substitution()]
    end

    first_sent_1 = sents_1[begin]
    first_sent_2 = sents_2[begin]
    first_substs = unify_no_special_symbol(first_sent_1, first_sent_2, depth_limit)
    if length(sents_1) == 1
        return first_substs
    end

    substs = Substitution[]
    sents_remain_2 = @view sents_2[2:end]

    for subst in first_substs
        sents_remain_1 = subst.(@view sents_1[2:end])
        for other_subst in
            unify_no_special_symbol(sents_remain_1, subst.(sents_remain_2), depth_limit)
            push!(substs, subst ∘ other_subst)
        end
    end

    return substs
end

struct UnificationSubproblem
    sentence_1::Sentence
    sentence_2::Sentence
    substitution::Substitution
    depth::Int
end

function unify_no_special_symbol(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    depth_limit::Int,
)::Vector{Substitution}

    results = Substitution[]
    queue = Queue{UnificationSubproblem}()
    enqueue!(queue, UnificationSubproblem(sent_1, sent_2, Substitution(), 0))

    while !isempty(queue)
        problem = dequeue!(queue)
        sent_1, sent_2 = find_different_infixes(
            problem.sentence_1,
            problem.sentence_2,
            requires_concrete = false,
        )

        # problem.sentence_1 == problem.sentence_2
        if isempty(sent_1) && isempty(sent_2)
            push!(results, problem.substitution)
            continue
        end

        if isempty(sent_1) ||
           isempty(sent_2) ||
           problem.depth >= depth_limit ||
           (startswith_word(sent_1) && startswith_word(sent_2))
            continue
        end

        depth = problem.depth + 1

        if is_one_variable(sent_1)
            # sent_1: [X]
            # sent_2
            X = sent_1[1]
            if !(X in sent_2)
                push!(results, problem.substitution ∘ VariableBinding(X, sent_2[1:end]))
            end

        elseif is_one_variable(sent_2)
            # sent_1
            # sent_2: [X]
            X = sent_2[1]
            if !(X in sent_1)
                push!(results, problem.substitution ∘ VariableBinding(X, sent_1[1:end]))
            end

        elseif is_concrete(sent_1)
            for subst in match(sent_2, sent_1)
                push!(results, problem.substitution ∘ subst)
            end

        elseif is_concrete(sent_2)
            for subst in match(sent_1, sent_2)
                push!(results, problem.substitution ∘ subst)
            end

        elseif (!startswith_word(sent_1) && !startswith_word(sent_2))
            # sent_1: [X] suffix_1
            # sent_2: [Y] suffix_2
            X = sent_1[1]
            Y = sent_2[1]
            suffix_1 = sent_1[2:end]
            suffix_2 = sent_2[2:end]

            # Option a: [X] -> [Y], suffix_1' -> suffix_2'
            let subst_a = VariableBinding(X, Sentence([Y]))
                subproblem_a = UnificationSubproblem(
                    subst_a(suffix_1),
                    subst_a(suffix_2),
                    problem.substitution ∘ subst_a,
                    depth,
                )
                enqueue!(queue, subproblem_a)
            end

            # Option b: [X] -> [Y] [X], [X] suffix_1' -> suffix_2'
            let subst_b = VariableBinding(X, Sentence([Y, X]))
                subproblem_b = UnificationSubproblem(
                    X * subst_b(suffix_1),
                    subst_b(suffix_2),
                    problem.substitution ∘ subst_b,
                    depth,
                )
                enqueue!(queue, subproblem_b)
            end
            # Option c: [Y] -> [X] [Y], suffix_1' -> [Y] suffix_2'
            let subst_c = VariableBinding(Y, Sentence([X, Y]))
                subproblem_c = UnificationSubproblem(
                    subst_c(suffix_1),
                    Y * subst_c(suffix_2),
                    problem.substitution ∘ subst_c,
                    depth,
                )
                enqueue!(queue, subproblem_c)
            end

        elseif !startswith_word(sent_1)
            # sent_1: [X] suffix_1
            # sent_2: t suffix_2
            X = sent_1[1]
            t = sent_2[1]
            suffix_1 = sent_1[2:end]
            suffix_2 = sent_2[2:end]
            # Option a: [X] -> t, suffix_1' -> suffix_2'
            let subst_a = VariableBinding(X, Sentence([t]))
                subproblem_a = UnificationSubproblem(
                    subst_a(suffix_1),
                    subst_a(suffix_2),
                    problem.substitution ∘ subst_a,
                    depth,
                )
                enqueue!(queue, subproblem_a)
            end
            # Option 2: [X] -> t [X], [X] suffix_1' -> suffix_2'
            let subst_b = VariableBinding(X, Sentence([t, X]))
                subproblem_b = UnificationSubproblem(
                    X * subst_b(suffix_1),
                    subst_b(suffix_2),
                    problem.substitution ∘ subst_b,
                    depth,
                )
                enqueue!(queue, subproblem_b)
            end
        else
            @assert !startswith_word(sent_2)
            # sent_1: t suffix_1
            # sent_2: [X]  suffix_2
            t = sent_1[1]
            X = sent_2[1]
            suffix_1 = sent_1[2:end]
            suffix_2 = sent_2[2:end]
            # Option 1: [X] -> t, suffix_2' -> suffix_1'
            let subst_a = VariableBinding(X, Sentence([t]))
                subproblem_a = UnificationSubproblem(
                    subst_a(suffix_2),
                    subst_a(suffix_1),
                    problem.substitution ∘ subst_a,
                    depth,
                )
                enqueue!(queue, subproblem_a)
            end
            # Option 2: [X] -> t [X], [X] suffix_2' -> suffix_1'
            let subst_b = VariableBinding(X, Sentence([t, X]))
                subproblem_b = UnificationSubproblem(
                    X * subst_b(suffix_2),
                    subst_b(suffix_1),
                    problem.substitution ∘ subst_b,
                    depth,
                )
                enqueue!(queue, subproblem_b)
            end
        end
    end

    return results
end

export unify
