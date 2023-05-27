using Statistics: mean
using DataStructures: DefaultDict
using Serialization: serialize

function evaluate_rule_taker(ds, preds)
    @assert iseven(length(ds)) && length(ds) == length(preds)
    n = convert(Int, length(ds) / 2)
    num_correct = DefaultDict{Union{Int,Nothing},Int}(0)
    num_total = DefaultDict{Union{Int,Nothing},Int}(0)
    wrong_ids = Int[]

    for i = 1:n
        @assert ds[2*i-1].assumptions == ds[2*i].assumptions
        @assert negate(ds[2*i-1].goal) == ds[2*i].goal
        @assert ds[2*i-1].metadata[:depth] == ds[2*i].metadata[:depth]
        depth = ds[2*i-1].metadata[:depth]
        num_total[depth] += 1

        if ds[2*i-1].label == ds[2*i].label == UNPROVABLE
            @assert depth === nothing
            if isempty(preds[2*i-1]) && isempty(preds[2*i])
                num_correct[depth] += 1
            else
                if depth == 1
                    @warn i
                end
                push!(wrong_ids, i)
            end
        elseif ds[2*i-1].label == PROVABLE && ds[2*i].label == UNPROVABLE
            @assert depth !== nothing
            if !isempty(preds[2*i-1])
                num_correct[depth] += 1
            else
                if depth == 1
                    @warn i
                end
                push!(wrong_ids, i)
            end
        elseif ds[2*i-1].label == UNPROVABLE && ds[2*i].label == PROVABLE
            @assert depth !== nothing
            if isempty(preds[2*i-1]) && !isempty(preds[2*i])
                num_correct[depth] += 1
            else
                if depth == 1
                    @warn i
                end
                push!(wrong_ids, i)
            end
        else
            error("Invalid dataset.")
        end
    end

    acc_overall = sum(values(num_correct)) / sum(values(num_total))
    acc_by_depth =
        Dict(depth => num_correct[depth] / num_total[depth] for depth in keys(num_correct))

    return acc_overall, acc_by_depth
end

function evaluate_sigmorphon2018(ds, preds)
    @assert length(ds) == length(preds) && iseven(length(ds))
    em = tp = fp = fn = 0.0

    for i = 1:convert(Int, length(ds) / 2)
        surface = join(string.(ds[2*i-1].assumptions[1]))

        gt_lemma = join(string.(concrete_goals(ds[2*i-1])[1])[2:end])
        gt_tags = [subst[create_variable("X")] for subst in ds[2*i].substitutions]
        gt_lemma_tags = Set([gt_lemma; gt_tags])

        pred_lemmas = [
            join(string.(pred.substitution[create_variable("X")])) for
            pred in preds[2*i-1] if pred.label == ENTAILMENT
        ]
        pred_tags = [
            pred.substitution[create_variable("X")] for
            pred in preds[2*i] if pred.label == ENTAILMENT
        ]
        pred_lemma_tags = Set([pred_lemmas; pred_tags])

        em += (gt_lemma_tags == pred_lemma_tags)
        tp += length(intersect(pred_lemma_tags, gt_lemma_tags))
        fp += length(setdiff(pred_lemma_tags, gt_lemma_tags))
        fn += length(setdiff(gt_lemma_tags, pred_lemma_tags))
    end

    prec = (tp + fp == 0.0) ? 1.0 : tp / (tp + fp)
    rec = (tp + fn == 0.0) ? 1.0 : tp / (tp + fn)
    if prec + rec == 0.0
        f1 = 0.0
    else
        f1 = 2 * prec * rec / (prec + rec)
    end

    return Dict("exact_match" => em, "f1" => f1)
end

export evaluate_rule_taker, evaluate_sigmorphon2018
