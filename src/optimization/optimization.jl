@reexport module Optimization

using DataStructures: Queue, enqueue!, dequeue!
using ProgressMeter: @showprogress, Progress, next!
using DataStructures: DefaultDict
using Serialization: serialize

using ..MetaLanguage
using ..Task
using ..Model
using ..TheoremProving

abstract type Trainer end

function train(::Trainer, ::Dataset)::ReasoningModel
    error("Not implemented")
end

include("trivial_trainers.jl")
include("metainduce_trainer.jl")

export train

end
