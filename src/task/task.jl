@reexport module Task

import JSON3
using Random: shuffle, shuffle!
using Statistics: mean
using ProgressMeter: @showprogress, Progress, update!, next!
using Pkg.Artifacts:
    artifact_hash, artifact_exists, create_artifact, bind_artifact!, artifact_path

using ..MetaLanguage

include("example.jl")
include("dataset.jl")

"Abstract type for rule proposers"
abstract type RuleProposer end

"""
    propose(rule_proposer::RuleProposer, ds::Dataset, n::Int)::Vector{Rule}

Use `rule_proposer` to propose rules for the `n`th example in `ds`.
"""
function propose(::RuleProposer, ::Dataset, ::Int)::Vector{Rule}
    error("Not implemented")
end

include("scan.jl")
include("rule_taker.jl")
include("sigmorphon2018.jl")

export RuleProposer, propose

end
