"Abstract type for backward chaining provers"
abstract type BackwardChaining <: Prover end

include("naive_backward_chaining.jl")

export BackwardChaining
