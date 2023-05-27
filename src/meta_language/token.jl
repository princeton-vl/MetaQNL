@enum TokenType begin
    WORD
    VARIABLE
    SPECIAL_SYMBOL
end

"""
Three types of tokens:
* words
* variables
* special symbols
"""
struct Token
    idx::Int  # index in the vocabulary
    type::TokenType
end

"Alias of [`Token`](@ref)"
const Variable = Token

"Alias of [`Token`](@ref)"
const Word = Token

"Alias of [`Token`](@ref)"
const SpecialSymbol = Token

"""
    is_word(t::Token)::Bool

Test if `t` is a word (``t \\in \\Sigma_w``).

# Example
```jldoctest
julia> is_word(create_word("hello"))
true

julia> is_word(create_variable("X"))
false
```
"""
function is_word(t::Token)
    return t.type == WORD
end

"""
    is_variable(t::Token)::Bool

Test if `t` is a variable (``t \\in \\Sigma_v``).

# Example
```jldoctest
julia> is_variable(create_word("hello"))
false

julia> is_variable(create_variable("X"))
true
```
"""
function is_variable(t::Token)
    return t.type == VARIABLE
end

"""
    is_special_symbol(t::Token)::Bool

Test if `t` is a special symbol (``t \\in \\Sigma_s``).

# Example
```jldoctest
julia> is_special_symbol(create_special_symbol("TRUE"))
true
```
"""
function is_special_symbol(t::Token)
    return t.type == SPECIAL_SYMBOL
end

"""
    create_word(str::AbstractString)::Word

Create a word from `str`, which must be in [`word_vocab`](@ref).

# Example
```jldoctest
julia> create_word("hello")
hello
```
"""
function create_word(str::AbstractString)
    return Token(word_vocab[str], WORD)
end

"""
    create_variable(str::AbstractString)::Variable

Create a variable from `str`, which must be in [`variable_vocab`](@ref).

# Example
```jldoctest
julia> create_variable("X")
[X]
```
"""
function create_variable(name::AbstractString)
    if startswith(name, '-')
        return Token(parse(Int, name), VARIABLE)
    else
        return Token(variable_vocab[name], VARIABLE)
    end
end

function create_variable(idx::Integer)
    return Token(idx, VARIABLE)
end

"""
    create_special_symbol(str::AbstractString)::SpecialSymbol

Create a symbol from `str`, which must be in [`special_symbol_vocab`](@ref).

# Example
```jldoctest
julia> create_special_symbol("TRUE")
\$TRUE\$
```
"""
function create_special_symbol(str::AbstractString)
    return Token(special_symbol_vocab[str], SPECIAL_SYMBOL)
end

function create_special_symbol(idx::Integer)
    return Token(idx, SPECIAL_SYMBOL)
end

"""
    create_token(str::AbstractString)::Token

Create a token from `str`. It can be a word, a variable, or a special symbol.

# Example
```jldoctest
julia> create_token("hello")
hello

julia> create_token("[X]")
[X]

julia> create_token("\\\$TRUE\\\$")
\$TRUE\$

julia> create_token("\\\$TRUE")
ERROR: AssertionError
```
"""
function create_token(str::AbstractString)::Token
    if startswith(str, '[')
        return @views create_variable(str[2:end-1])
    elseif startswith(str, '$')
        @assert endswith(str, '$')
        return @views create_special_symbol(str[2:end-1])
    else
        return create_word(str)
    end
end

"""
    macro word_str(str::AbstractString)

Alias of [`create_word`](@ref).

# Example
```jldoctest
julia> word"hello"
hello
```
"""
macro word_str(str::AbstractString)
    return create_word(str)
end

"""
    macro variable_str(str::AbstractString)

Alias of [`create_variable`](@ref).

# Example
```jldoctest
julia> variable"X"
[X]
```
"""
macro variable_str(str::AbstractString)
    return create_variable(str)
end

"""
    macro symbol_str(str::AbstractString)

Alias of [`create_special_symbol`](@ref).

# Example
```jldoctest
julia> symbol"TRUE"
\$TRUE\$
```
"""
macro symbol_str(str::AbstractString)
    return create_special_symbol(str)
end

function next_variable(var::Variable)
    return create_variable(var.idx + 1)
end

function first_variable()::Variable
    return create_variable(1)
end

"""
    get_name(var::Variable)::String

Return the the name of `var`.

# Example
```jldoctest
julia> get_name(create_variable("X"))
"X"
```
"""
function get_name(var::Variable)::String
    if var.idx >= 1
        return variable_vocab[var.idx]
    else
        # Negative indexes are reserved for internal use only.
        return string(var.idx)
    end
end

function get_symbol(sym::SpecialSymbol)::String
    if sym.idx >= 1
        return special_symbol_vocab[sym.idx]
    else
        # Negative indexes are reserved for internal use only.
        return string(sym.idx)
    end
end

function Base.string(t::Token)
    if is_word(t)
        return word_vocab[t.idx]
    elseif is_variable(t)
        return "[$(get_name(t))]"
    else
        return "\$$(get_symbol(t))\$"
    end
end

function Base.show(io::IO, t::Token)
    print(io, string(t))
end

function Base.isless(t1::Token, t2::Token)
    return t1.type < t2.type || (t1.type == t2.type && t1.idx < t2.idx)
end

"""
    fresh_variable(existing_vars)

Return a fresh variable not in `existing_vars`.

# Example
```jldoctest
julia> fresh_variable([variable"A", variable"B"])
[C]
```
"""
function fresh_variable(existing_vars)::Variable
    num_vars = length(existing_vars)
    vocab_size = length(variable_vocab)

    for idx in Iterators.countfrom(num_vars)
        i = idx % vocab_size + 1
        @assert !(i == num_vars + 1 && i < idx)
        var = create_variable(variable_vocab[i])
        if !(var in existing_vars)
            return var
        end
    end
end

export Token,
    Word,
    Variable,
    SpecialSymbol,
    is_word,
    is_variable,
    is_special_symbol,
    create_word,
    create_variable,
    create_special_symbol,
    create_token,
    @word_str,
    @variable_str,
    @symbol_str,
    get_name,
    fresh_variable
