@reexport module TheoremProving

using DataStructures: OrderedDict
using Serialization

using ..MetaLanguage

"Abstract type for provers"
abstract type Prover end

include("forward_chaining/forward_chaining.jl")
include("backward_chaining/backward_chaining.jl")

export Prover

end
