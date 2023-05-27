"Script for training models on MiniSCAN, SCAN, RuleTaker, and SIGMORPHON 2018"

using MetaQNL
using ArgParse
using UUIDs
using Serialization

function parse_commandline()
    s = ArgParseSettings(
        description = "Script for training models on MiniSCAN, SCAN, RuleTaker, and SIGMORPHON 2018",
    )

    @add_arg_table s begin
        "--log-dir"
        arg_type = String
        default = "./runs"
        help = "Directory for saving logs"
        "--exp-id"
        arg_type = String
        help = "Arbitrary experiment ID. Logs will be saved to `log-dir/exp-id/`"
        "--dataset"
        arg_type = String
        required = true
        help = "The dataset used for training (`MiniSCAN`, `SCAN`, `RuleTaker`, or `Sigmorphon`)"
        "--split"
        arg_type = String
        help = """Data splits to use. 
            For SCAN, it should be one of `simple`, `length`, `addprim_jump`, and `addprim_turn_left`. 
            For RuleTaker, it is one of `depth-0`, `depth-1`, `depth-2`, `depth-3`, and `depth-5`.
            For SIGMORPHON 2018, it is one of `easy` and `hard`; and it only specifies evaluation data"""
        "--lang"
        arg_type = String
        help = "Language to use (`spanish`, `swahili`, or `turkish`). SIGMORPHON 2018 only"
        "--copy"
        arg_type = Int
        help = "Data copy to use (from 0 to 4). SIGMORPHON 2018 only"
        "--log-to-file"
        action = :store_true
        help = "Write logs to a file instead of the console"
        "--num-train-examples"
        arg_type = Int
        help = "Sample a subset of training examples (use all training examples by default)"
        "--num-val-examples"
        arg_type = Int
        default = 4000
        help = "Sample a subset of validation examples"
        "--num-epochs"
        arg_type = Int
        default = 5
        "--weight-candidate"
        arg_type = Float64
        default = 0.15
        help = "Weights for candidate rules in theorem proving"
        "--weight-existing"
        arg_type = Float64
        default = 0.15
        help = "Weights for existing rules in theorem proving"
        "--lambda-provable"
        arg_type = Float64
        default = Inf
        help = "MAX-SAT weights for provable examples"
        "--lambda-unprovable"
        arg_type = Float64
        default = Inf
        help = "MAX-SAT weights for unprovable examples"
        "--maxsat-solver"
        arg_type = Symbol
        default = :OpenWBO
        help = "MAX-SAT solver to use (`Z3` or `OpenWBO`)"
    end

    opts = parse_args(s)

    # Generate a random experiment ID if unspecified.
    if opts["exp-id"] === nothing
        opts["exp-id"] = string(uuid1())
    end

    # Create the directory for saving logs.
    opts["log-dir"] = joinpath(opts["log-dir"], opts["exp-id"])
    if ispath(opts["log-dir"])
        @info "Overwriting $(opts["log-dir"]).."
        rm(opts["log-dir"], recursive = true)
    end
    mkpath(opts["log-dir"])
    if opts["log-to-file"]
        filename = joinpath(opts["log-dir"], "training_log.txt")
        logger = SimpleLogger(open(filename, "wt"))
        global_logger(logger)
    end

    # Check the data options
    @assert opts["dataset"] in ("MiniSCAN", "SCAN", "RuleTaker", "Sigmorphon")
    if opts["dataset"] == "SCAN"
        @assert opts["split"] in ("simple", "length", "addprim_jump", "addprim_turn_left")
    elseif opts["dataset"] == "RuleTaker"
        @assert opts["split"] in ("depth-0", "depth-1", "depth-2", "depth-3", "depth-5")
    elseif opts["dataset"] == "Sigmorphon"
        @assert opts["split"] in ("easy", "hard")
    end

    @assert opts["maxsat-solver"] in (:Z3, :OpenWBO)

    return opts
end

function load_dataset(opts)
    if opts["dataset"] == "MiniSCAN"
        ds = load_mini_scan()
        return ds, SCANRuleProposer(ds[:train]), NaiveBackwardChaining
    elseif opts["dataset"] == "SCAN"
        ds = load_scan(opts["split"], opts["num-train-examples"])
        return ds, SCANRuleProposer(ds[:train]), NaiveBackwardChaining
    elseif opts["dataset"] == "RuleTaker"
        ds = load_rule_taker(
            opts["split"],
            opts["split"],
            nothing,
            opts["num-train-examples"],
        )
        return ds, RuleTakerRuleProposer(), ReteForwardChaining
    else
        @assert opts["dataset"] == "Sigmorphon"
        ds = load_sigmorphon2018(opts["lang"], opts["split"], opts["split"], opts["copy"])
        return ds, SigmorphonRuleProposer(), NaiveForwardChaining
    end
end

function save_checkpoint(model, opts)
    # Save the model checkpoint to log-dir/checkpoint.bin.
    filename = joinpath(opts["log-dir"], "checkpoint.bin")
    serialize(
        filename,
        Dict(
            "model" => model,
            "opts" => opts,
            "vocabs" => Dict(
                "word" => word_vocab.idx2str,
                "variable" => variable_vocab.idx2str,
                "special_symbol" => special_symbol_vocab.idx2str,
            ),
        ),
    )
    @info "Model checkpoint saved to $filename"
end

function main()
    opts = parse_commandline()
    @info opts

    @info "Loading data.."
    ds, rule_proposer, prover_type = load_dataset(opts)

    if haskey(ds, :val)
        ds_val = subsample(ds[:val], opts["num-val-examples"])
    else
        ds_val = nothing
    end

    @info "Training on $(length(ds[:train])) examples.."
    model = train(
        MetaInduceTrainer(
            num_epochs = opts["num-epochs"],
            rule_proposer = rule_proposer,
            prover_type = prover_type,
            weight_existing = opts["weight-existing"],
            weight_candidate = opts["weight-candidate"],
            maxsat_solver = opts["maxsat-solver"],
            lambda_provable = opts["lambda-provable"],
            lambda_unprovable = opts["lambda-unprovable"],
            on_the_fly_proposal = (opts["dataset"] == "SCAN"),
            log_dir = opts["log-dir"],
            ds_val = ds_val,
        ),
        ds[:train],
    )

    save_checkpoint(model, opts)
end

main()
