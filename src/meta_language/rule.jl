using Combinatorics: permutations

"""
A rule takes the form of ``p_1; p_2; \\dots; p_n \\vdash c``, where ``p_i \\in \\Sigma^{*}`` are premises, and ``c \\in \\Sigma^{*}`` is the conclusion. 

# Fields
* `premises::Vector{Sentence}`
* `conclusion::Sentence`
"""
struct Rule
    premises::Vector{Sentence}
    conclusion::Sentence
end

"""
    is_identical(rule_1::Rule, rule_2::Rule)

Test if `rule_1` and `rule_2` are identical (without considering premise reordering and ``\\alpha``-conversion).
"""
function is_identical(rule_1::Rule, rule_2::Rule)
    return is_identical(rule_1.conclusion, rule_2.conclusion) &&
           length(rule_1.premises) == length(rule_2.premises) &&
           all(is_identical(x, y) for (x, y) in zip(rule_1.premises, rule_2.premises))
end

"""
    is_equivalent(rule_1::Rule, rule_2::Rule)

Test if `rule_1` and `rule_2` are equal modulo premise reordering and ``\\alpha``-conversion.
"""
function is_equivalent(rule_1::Rule, rule_2::Rule)
    # Shortcuts for performance.
    if is_identical(rule_1, rule_2)
        return true
    elseif length(rule_1.premises) != length(rule_2.premises)
        return false
    end

    for prems_2 in permutations(rule_2.premises)
        if is_equivalent(rule_1.conclusion, rule_1.premises, rule_2.conclusion, prems_2)
            return true
        end
    end

    return false
end

"""
    rule_1::Rule == rule_2::Rule

Test if `rule_1` and `rule_2` are equal modulo premise reordering and ``\\alpha``-conversion.
"""
function Base.:(==)(rule_1::Rule, rule_2::Rule)
    return is_equivalent(rule_1, rule_2)
end

function Base.isless(rule_1::Rule, rule_2::Rule)
    if length(rule_1.premises) > length(rule_2.premises)
        return true
    elseif length(rule_1.premises) < length(rule_2.premises)
        return false
    end

    for (p_1, p_2) in zip(rule_1.premises, rule_2.premises)
        if p_1 > p_2
            return true
        elseif p_1 < p_2
            return false
        end
    end

    return rule_1.conclusion > rule_2.conclusion
end

"""
    hash(rule::Rule, h)

Compute the hash code of `rule` modulo premise reordering and ``\\alpha``-conversion.
"""
function Base.hash(rule::Rule, h::UInt)::UInt
    h = hash(length(rule.premises), h)
    for p in rule.premises
        h = xor(alpha_invariant_hash(p), h)
    end
    h = alpha_invariant_hash(rule.conclusion, h)
    return h
end

function Base.show(io::IO, rule::Rule)
    for p in rule.premises
        print(io, p, "\n")
    end
    print(io, "---\n", rule.conclusion, "\n")
end

"""
    load_rule(str::AbstractString)::Rule

Load a rule from its string representation `str`.

# Example
```jldoctest
julia> load_rule("\\\$TRUE\\\$ [A] be not [B]\\n---\\n\\\$FALSE\\\$ [A] be [B]")
\$TRUE\$ [A] be not [B]
---
\$FALSE\$ [A] be [B]
```
"""
function load_rule(str::AbstractString)::Rule
    premises = []
    is_conclusion = false

    for line in split(str, '\n')
        if line == "---"
            is_conclusion = true
            continue
        end

        if is_conclusion
            concl = Sentence(line)
            return Rule(convert(Vector{typeof(concl)}, premises), concl)
        else
            push!(premises, Sentence(line))
        end
    end

    error("Invalid rule:\n$str")
end

"""
    load_rules_from_file(filename::AbstractString)

Load rules from a text file `filename`.
"""
function load_rules_from_file(filename::AbstractString)
    return [load_rule(str) for str in split(read(open(filename), String), r"\n\n+")]
end

"""
    macro rule_str(str::AbstractString)

Alias of [`load_rule`](@ref).
"""
macro rule_str(str::AbstractString)
    return load_rule(str)
end

"""
    is_concrete(rule::Rule)::Bool

Test if `rule` is a concrete rule (i.e., rule without variable).
"""
function is_concrete(rule::Rule)
    return is_concrete(rule.conclusion) && all(is_concrete(p) for p in rule.premises)
end

function get_variables(rule::Rule)::Set{Variable}
    vars = get_variables(rule.premises)
    return get_variables!(rule.conclusion, vars)
end

function contains_premise(rule::Rule, sent)
    for p in rule.premises
        if is_identical(p, sent)
            return true
        end
    end
    return false
end

function count_variables(rule::Rule)
    cnt = counter(Variable)
    for j = 1:(1+length(rule.premises))
        sent = (j == 1) ? rule.conclusion : rule.premises[j-1]
        for (i, t) in enumerate(sent)
            if is_variable(t)
                inc!(cnt, t)
            end
        end
    end
    return cnt
end

function num_free_variables(rule::Rule)
    return count(x -> x[2] == 1, count_variables(rule))
end

function collect_variables_context(rule::Rule)
    cnt = count_variables(rule)
    prev_tokens = Dict{Variable,Vector{Token}}()
    next_tokens = Dict{Variable,Vector{Token}}()
    for (var, n) in cnt
        prev_tokens[var] = Vector{Token}(undef, n)
        next_tokens[var] = Vector{Token}(undef, n)
    end

    for j = 1:(1+length(rule.premises))
        sent = (j == 1) ? rule.conclusion : rule.premises[j-1]
        for (i, t) in enumerate(sent)
            if is_variable(t)
                n = cnt[t]
                prev_tokens[t][end-n+1] =
                    (i == 1) ? create_special_symbol("START") : sent[i-1]
                next_tokens[t][end-n+1] =
                    (i == length(sent)) ? create_special_symbol("END") : sent[i+1]
                dec!(cnt, t)
            end
        end
    end

    return prev_tokens, next_tokens
end

function elements_are_same(vec)
    if isempty(vec)
        return false
    end
    e1 = first(vec)
    return all(e == e1 for e in (@view vec[1:end]))
end

"""
    isvalid(rule::Rule)

Test if `rule` is a valid rule.

# Example
```jldoctest
julia> rule_1 = load_rule("if something is red then tomorrow will be sunny\\n[X] is red\\n---\\ntomorrow will be sunny");

julia> isvalid(rule_1)
true

julia> rule_2 = load_rule("if something is red then tomorrow will be sunny\\n[X]\\n---\\ntomorrow will be sunny");

julia> isvalid(rule_2)
false

julia> rule_3 = load_rule("if something is red then tomorrow will be sunny\\n[X] is red\\n---\\ntomorrow will be [Y]");

julia> isvalid(rule_3)
false
```
"""
function Base.isvalid(rule::Rule)
    if is_concrete(rule)
        return true
    end

    prev_tokens, next_tokens = collect_variables_context(rule)

    # No > 1 variables always appear together.
    for (var_1, ts_1) in prev_tokens
        if elements_are_same(ts_1)
            var_2 = first(ts_1)
            if is_variable(var_2)
                ts_2 = next_tokens[var_2]
                if elements_are_same(ts_2) && first(ts_2) == var_1
                    return false
                end
            end
        end
    end

    # Variables in the conclusion must also appear in premises.
    @assert !isempty(rule.conclusion)
    vars_in_premises = get_variables(rule.premises)
    for t in rule.conclusion
        if is_variable(t) && !(t in vars_in_premises)
            return false
        end
    end

    function is_free(var)
        length(prev_tokens[var]) == 1
    end

    for sent in rule.premises
        @assert !isempty(sent)
        # No premises consisting of only a single free variable.
        if is_one_variable(sent) && is_free(sent[begin])
            return false
        end
        # No free variable adjacent with other variables.
        #=
        for (i, t) in enumerate(sent)
            if is_variable(t) && is_free(t)
                if (i > 1 && is_variable(sent[i-1])) || (i < length(sent) && is_variable(sent[i+1]))
                    return false
                end
            end
        end
        =#
    end

    # 4. No more than 1 free variable.
    return num_free_variables(rule) <= 1
end

function normalize(rule::Rule)
    # Replace multiple consecutive variables that always appear together.
    # And remove premises consisting of only a single free variable.

    prev_tokens, next_tokens = collect_variables_context(rule)
    vars_to_remove = Variable[]

    for (var_1, ts_1) in prev_tokens
        if elements_are_same(ts_1)
            var_2 = first(ts_1)
            if is_variable(var_2)
                ts_2 = next_tokens[var_2]
                if elements_are_same(ts_2) && first(ts_2) == var_1
                    push!(vars_to_remove, var_1)
                end
            end
        end
    end

    function process(sent)
        return Sentence([t for t in sent if !(t in vars_to_remove)])
    end

    return Rule(process.(rule.premises), process(rule.conclusion))
end

export Rule, is_identical, load_rule, load_rules_from_file, @rule_str, num_free_variables
