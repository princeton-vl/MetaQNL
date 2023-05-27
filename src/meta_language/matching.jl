"""
    Base.match(sent_1::AbstractSentence, sent_2::AbstractSentence)::Vector{Substitution}

Match `sent_1` with `sent_2`.

# Example
```jldoctest
julia> match(sent"dax fep", sent"dax [X]")
Substitution[]

julia> match(sent"dax [X]", sent"dax fep")
1-element Vector{Substitution}:
 {[X] -> fep, }
```
"""
function Base.match(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
)::Vector{Substitution}
    if isempty(sent_1) && isempty(sent_2)
        return [Substitution()]
    elseif isempty(sent_1) || isempty(sent_2)
        return Substitution[]
    elseif is_concrete(sent_1)
        return is_identical(sent_1, sent_2) ? [Substitution()] : Substitution[]
    elseif SentenceTemplate(sent_1) != SentenceTemplate(sent_2)
        return Substitution[]
    end

    alignment = Vector{Int}(undef, length(sent_1))  # Align sent_1[i] with sent_2[alignment[i]]
    i = 1
    backtracking = false
    results = Substitution[]

    while i >= 1

        # A complete solution is available.
        if i > length(sent_1)
            append!(results, resolve_variables(sent_1, sent_2, alignment))
            backtracking = true
            i -= 1
            continue
        end

        t = sent_1[i]
        base = (i == 1) ? 0 : alignment[i-1]

        if is_variable(t)  # Skip variables.
            alignment[i] = base
            if !backtracking
                i += 1
            else
                i -= 1
            end

        elseif i == 1  # Starting words must match
            if sent_1[begin] != sent_2[begin]
                return Substitution[]
            elseif !backtracking && (length(sent_1) > 1 || length(sent_2) == 1)
                alignment[i] = 1
                i += 1
            else
                break
            end

        elseif i == length(sent_1)  # Ending words must match
            if sent_1[end] != sent_2[end]
                return Substitution[]
            elseif (!is_variable(sent_1[i-1]) && alignment[i-1] != length(sent_2) - 1)
                backtracking = true
                i -= 1
                continue
            end
            if !backtracking
                alignment[i] = length(sent_2)
                i += 1
            else
                break
            end

        elseif !is_variable(sent_1[i-1]) # Consecutive words
            if backtracking
                i -= 1
            elseif 1 + alignment[i-1] <= length(sent_2) && t == sent_2[1+alignment[i-1]]
                alignment[i] = 1 + alignment[i-1]
                i += 1
            else
                backtracking = true
                i -= 1
            end

        elseif backtracking
            j = findfirst(==(t), @view sent_2[alignment[i]+1:end])
            if j === nothing  # Backtrack further.
                i -= 1
            else  # Stop backtracking.
                alignment[i] = j + alignment[i]
                backtracking = false
                i += 1
            end

        else
            j = findfirst(==(t), @view sent_2[base+1:end])
            if j === nothing  # Backtrack.
                backtracking = true
                i -= 1
            else  # Proceed.
                alignment[i] = j + base
                i += 1
            end
        end
    end

    return results
end

function Base.match(
    sents_1::AbstractVector{<:AbstractSentence},
    sents_2::AbstractVector{<:AbstractSentence},
)::Vector{Substitution}
    @assert length(sents_1) == length(sents_2)
    if isempty(sents_1)
        return [Substitution()]
    end

    return match(join(sents_1, symbol"DELIMI"), join(sents_2, symbol"DELIMI"))
end

"""
    Base.match(rule_1::Rule, rule_2::Rule)::Vector{Substitution}

Match `rule_1` with `rule_2`.

# Example
```jldoctest
julia> r1 = Rule([sent"dax \$MAPS_TO\$ [Y]"], sent"dax fep \$MAPS_TO\$ [Y] [Y] [Y]");

julia> r2 = Rule([sent"dax \$MAPS_TO\$ RED"], sent"dax fep \$MAPS_TO\$ RED RED RED");

julia> match(r1, r2)
1-element Vector{Substitution}:
 {[Y] -> RED, }
```
"""
function Base.match(rule_1::Rule, rule_2::Rule)::Vector{Substitution}
    results = Substitution[]
    if length(rule_1.premises) != length(rule_2.premises)
        return results
    elseif isempty(rule_1.premises)
        return match(rule_1.conclusion, rule_2.conclusion)
    elseif is_concrete(rule_1)
        return is_equivalent(rule_1, rule_2) ? [Substitution()] : Substitution[]
    end

    sents_1 = [rule_1.conclusion; rule_1.premises]

    for prems_2 in permutations(rule_2.premises)
        append!(results, match(sents_1, [rule_2.conclusion; prems_2]))
    end

    unique!(results)
    return results
end

"""
    is_more_general(x::Union{Rule,AbstractSentence}, y::Union{Rule,AbstractSentence})

Test if `x` is more general than `y`.

# Example
```jldoctest
julia> r1 = Rule([sent"dax \$MAPS_TO\$ [Y]"], sent"dax fep \$MAPS_TO\$ [Y] [Y] [Y]");

julia> r2 = Rule([sent"dax \$MAPS_TO\$ RED"], sent"dax fep \$MAPS_TO\$ RED RED RED");

julia> is_more_general(r1, r2)
true

julia> is_more_general(r2, r1)
false
```
"""
function is_more_general(x::Union{Rule,AbstractSentence}, y::Union{Rule,AbstractSentence})
    return !isempty(match(x, y))
end

function resolve_variables(
    sent_1::AbstractSentence,
    sent_2::AbstractSentence,
    alignment::Vector{Int},
)::Vector{Substitution}
    # Assign variables in `sent_1` to sentence segments in `sent_2`.
    results = Substitution[]
    subst = Substitution()
    max_alignment = get_max_alignment(sent_1, sent_2, alignment)
    i = 1
    backtracking = false

    function bind_variable(i, j_start, j_end)
        if j_end < j_start
            return false
        end

        var = sent_1[i]
        sent = @view sent_2[j_start:j_end]
        s = get(subst, var, nothing)
        if s !== nothing && s != sent
            return false
        end

        suffix_1 = @view sent_1[i+1:end]
        suffix_2 = @view sent_2[j_end+1:end]
        if var in suffix_1 && !occursin(sent, suffix_2)
            return false
        end

        subst[var] = sent
        return true
    end

    function last_variable_in_block(i)
        return is_variable(sent_1[i]) && (i == length(sent_1) || !is_variable(sent_1[i+1]))
    end

    function align_last_variable(i)
        return i == length(sent_1) ? length(sent_2) : alignment[i+1] - 1
    end

    while i >= 1
        if i > length(sent_1)  # A complete solution is available.
            push!(results, copy(subst))
            backtracking = true
            i -= 1
            continue
        end

        if is_variable(sent_1[i])
            var = sent_1[i]

            if i == 1  # The first tokens in sent_1 and sent_2 must match.
                alignment[i] = 1
            elseif !is_variable(sent_1[i-1])  # The first variable in a block.
                alignment[i] = alignment[i-1] + 1
            else
                # The middle variable in a block, i.e. sent_1[i-1] is also a variable.
                prev_var = sent_1[i-1]
                if !backtracking
                    success = false
                    for j = (1+alignment[i-1]):max_alignment[i]
                        if bind_variable(i - 1, alignment[i-1], j - 1)
                            success = true
                            alignment[i] = j
                            break
                        end
                    end
                    if !success
                        backtracking = true
                    end

                elseif findfirst(==(prev_var), sent_1) == i - 1
                    # The previous variable hasn't been constrained by previous bindings.
                    delete!(subst, prev_var)
                    if last_variable_in_block(i) && findfirst(==(var), sent_1) == i
                        delete!(subst, var)
                    end

                    if alignment[i] < max_alignment[i]
                        alignment[i] += 1
                        if !bind_variable(i - 1, alignment[i-1], alignment[i] - 1)
                            continue
                        end
                        if last_variable_in_block(i) &&
                           !bind_variable(
                            i,
                            alignment[i],
                            i == length(sent_1) ? length(sent_2) : alignment[i+1] - 1,
                        )
                            continue
                        end
                        backtracking = false

                    else
                        alignment[i] = align_last_variable(i) - 1
                    end
                end
            end

            if last_variable_in_block(i)
                if !backtracking
                    if !bind_variable(i, alignment[i], align_last_variable(i))
                        backtracking = true
                        continue
                    end
                else
                    if findfirst(==(var), sent_1) == i
                        delete!(subst, var)
                    end
                end
            end
        end

        if !backtracking
            i += 1
        else
            i -= 1
        end
    end

    return results
end


function get_max_alignment(sent_1, sent_2, alignment)
    max_alignment = Vector{Int}(undef, length(alignment))

    for (i, t) in enumerate(sent_1)
        if !is_variable(t)
            max_alignment[i] = alignment[i]
        end

        if i == 1
            max_alignment[i] = 1
        elseif !is_variable(sent_1[i-1])
            max_alignment[i] = alignment[i-1] + 1
        elseif i == length(sent_1)
            max_alignment[i] = length(sent_2)
        else
            k = findfirst(>(alignment[i]), @view (alignment[i+1:end]))
            if k === nothing
                max_alignment[i] = length(sent_2) - length(sent_1) + i
            else
                max_alignment[i] = alignment[i+k] - k
            end
        end
    end

    return max_alignment
end

export is_more_general
