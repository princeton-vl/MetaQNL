"Abstract type for forward chaining provers."
abstract type ForwardChaining <: Prover end

function (::ForwardChaining)(assumptions::AbstractVector{Sentence}, callback::Function)
    error("Not implemented")
end

function update!(::ForwardChaining, ::AbstractVector{Rule}, ::AbstractVector{<:Real})
    error("Not implemented")
end

include("naive_forward_chaining.jl")
include("rete_forward_chaining.jl")

export ForwardChaining
