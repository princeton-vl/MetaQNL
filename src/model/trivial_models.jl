"A ground truth model makes predictions using the ground truth."
struct GroundTruthModel <: AbstractModel end

function predict(::GroundTruthModel, ex::Example)::Vector{Prediction}
    if ex.label === UNPROVABLE
        return Prediction[]
    else
        return Prediction.(ex.substitutions)
    end
end

"A dummy model makes no prediction regardless of the input."
struct DummyModel <: AbstractModel end

function predict(model::DummyModel, ex::Example)::Vector{Prediction}
    return Prediction[]
end

export GroundTruthModel, DummyModel
