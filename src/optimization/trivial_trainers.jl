"EmptyTrainer produces an empty model."
struct EmptyTrainer <: Trainer end

function train(::EmptyTrainer, ::Dataset)::ReasoningModel
    return ReasoningModel(NaiveForwardChaining)
end

"DummyTrainer produces a model with one rule for each provable example."
struct DummyTrainer <: Trainer end

function train(::DummyTrainer, ds::Dataset)::ReasoningModel
    rules = Rule[]
    for ex in ds
        if ex.label == PROVABLE
            append!(rules, Rule(ex.assumptions, goal) for goal in concrete_goals(ex))
        end
    end
    return ReasoningModel(NaiveBackwardChaining, rules)
end

export EmptyTrainer, DummyTrainer
