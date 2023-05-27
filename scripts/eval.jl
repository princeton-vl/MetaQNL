"Script for evaluating models trained on MiniSCAN, SCAN, RuleTaker, and SIGMORPHON 2018"

using MetaQNL
using MetaQNL.Model: update!
using ArgParse
using Serialization

function restore_checkpoint()
    s = ArgParseSettings(description = "Testing script")

    @add_arg_table s begin
        "checkpoint"
        arg_type = String
        required = true
        "--split"
        arg_type = String
        required = true
        help = """Data splits to use. 
            For SCAN, it should be one of `simple`, `length`, `addprim_jump`, and `addprim_turn_left`. 
            For RuleTaker, it is one of `depth-0`, `depth-1`, `depth-2`, `depth-3`, and `depth-5`.
            For SIGMORPHON 2018, it is one of `easy` and `hard`; and it only specifies evaluation data"""
        "--validate"
        arg_type = Bool
        required = true
        help = "Perform validation instead of testing"
        "--weight"
        arg_type = Float64
        default = 0.15
        help = "Weights for rules in theorem proving"
    end

    opts = parse_args(s)

    @info "Loading model checkpoint from $(opts["checkpoint"])"
    checkpoint = deserialize(opts["checkpoint"])
    reset_vocab!(word_vocab, checkpoint["vocabs"]["word"])
    reset_vocab!(variable_vocab, checkpoint["vocabs"]["variable"])
    reset_vocab!(special_symbol_vocab, checkpoint["vocabs"]["special_symbol"])
    model = checkpoint["model"]
    update!(model, checkpoint["model"].rules, opts["weight"])
    @info "$(length(model)) rules in the model"

    for (k, v) in checkpoint["opts"]
        if !haskey(opts, k)
            opts[k] = v
        end
    end

    if opts["dataset"] == "SCAN"
        @assert opts["split"] in ("simple", "length", "addprim_jump", "addprim_turn_left")
    elseif opts["dataset"] == "RuleTaker"
        @assert opts["split"] in (
            "depth-0",
            "depth-1",
            "depth-2",
            "depth-3",
            "depth-3ext",
            "depth-3ext-NatLang",
            "depth-5",
            "NatLang",
            "birds-electricity",
        )
    elseif opts["dataset"] == "Sigmorphon"
        @assert opts["split"] in ("easy", "hard")
    end

    return model, opts
end

function load_test_data(opts)
    if opts["dataset"] == "MiniSCAN"
        ds = load_mini_scan()
    elseif opts["dataset"] == "SCAN"
        ds = load_scan(opts["split"])
    elseif opts["dataset"] == "RuleTaker"
        ds = load_rule_taker(nothing, opts["split"], opts["split"])
    else
        @assert opts["dataset"] == "Sigmorphon"
        ds = load_sigmorphon2018(opts["lang"], opts["split"], opts["split"], opts["copy"])
    end

    if opts["validate"]
        return ds[:val]
    else
        return ds[:test]
    end
end

function main()
    model, opts = restore_checkpoint()
    @info opts

    ds = load_test_data(opts)

    # General evaluation.
    preds = predict(model, ds)
    metrics = evaluate(ds, preds)
    @info "General testing results:"
    @info "\tAccuracy: $(metrics["accuracy"])"

    # Dataset-specific evaluation.
    if opts["dataset"] == "RuleTaker"
        acc_overall, acc_depth = evaluate_rule_taker(ds, preds)
        @info "Overall accuracy: $acc_overall"
        @info "Accuracies by depth: $acc_depth"
    elseif opts["dataset"] == "Sigmorphon"
        @info evaluate_sigmorphon2018(ds, preds)
    end
end

main()
