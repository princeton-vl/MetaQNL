"""
A reasoning model consists of rules. Training the model requires learning the rules from data.

# Fields
* `rules::Vector{Rule}`: MetaQNL rules
* `prover::Prover`: the prover used for theorem proving
"""
mutable struct ReasoningModel <: AbstractModel
    rules::Vector{Rule}
    prover::Prover
end

"""
    ReasoningModel(prover_type::Type{<:Prover}, rules = Rule[])

Create a reasoning model.
"""
function ReasoningModel(prover_type::Type{<:Prover}, rules = Rule[])
    sorted_rules = sort(rules)
    return ReasoningModel(sorted_rules, prover_type(sorted_rules))
end

function Base.copy(model::ReasoningModel)
    return ReasoningModel(copy(model.rules), typeof(model.prover)(model.rules))
end

function Base.iterate(model::ReasoningModel)
    return iterate(model.rules)
end

function Base.iterate(model::ReasoningModel, state)
    return iterate(model.rules, state)
end

function Base.length(model::ReasoningModel)
    return length(model.rules)
end

"""
    update!(model::ReasoningModel, rules::AbstractVector{Rule}, weight::Real)

Update the model with `rules`, each with `weight` as the weight.
"""
function update!(model::ReasoningModel, rules::AbstractVector{Rule}, weight::Real)
    model.rules = sort(rules)
    rule_weights = fill(weight, length(rules))
    model.prover = typeof(model.prover)(model.rules, rule_weights)
    return model
end

function predict(model::ReasoningModel, ex::Example)::Vector{Prediction}
    if model.prover isa ForwardChaining
        return forward_predict(model, ex)
    else
        @assert model.prover isa BackwardChaining
        return backward_predict(model, ex)
    end
end

function forward_predict(model, ex)
    preds = Set{Prediction}()

    function check_goal(concl, cr)
        for subst in match(ex.goal, concl)
            push!(preds, Prediction(subst))
        end
        return true
    end

    model.prover(ex.assumptions, callback = check_goal)
    return collect(preds)
end

function order_answers(pair)
    # When there are multiple answers, prefer simpler ones.
    subst, (depth, _) = pair
    _, sent = first(subst)
    return length(sent), depth
end

function backward_predict(model, ex)
    proof_paths = model.prover(ex.assumptions, ex.goal)
    if isempty(proof_paths)
        return Prediction[]
    end
    proof_paths = sort!(collect(proof_paths), by = order_answers)
    return unique([Prediction(subst) for (subst, _) in proof_paths])
end

export ReasoningModel, update!
