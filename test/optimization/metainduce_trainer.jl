include("maxsat_solvers.jl")


@testset "Run MetaInduceTrainer on MiniSCAN" begin
    ds = load_mini_scan()
    model = train(
        MetaInduceTrainer(
            num_epochs = 5,
            rule_proposer = SCANRuleProposer(ds[:train]),
            prover_type = NaiveBackwardChaining,
            weight_existing = 0.3,
            weight_candidate = 0.4,
            maxsat_solver = :Z3,
            lambda_provable = Inf,
            lambda_unprovable = Inf,
            on_the_fly_proposal = false,
            log_dir = "./",
        ),
        ds[:train],
    )

    preds_train = predict(model, ds[:train])
    preds_test = predict(model, ds[:test])
end

@testset "Run MetaInduceTrainer on SCAN" begin
    for data_split in ("length", "simple", "addprim_jump", "addprim_turn_left")
        ds = load_scan(data_split)
        sort!(
            ds[:train].examples,
            by = ex -> length(split(string(first(concrete_goals(ex))), " \$MAPS_TO\$ ")[1]),
        )
        ds[:train] = ds[:train][1:400]
        model = train(
            MetaInduceTrainer(
                num_epochs = 5,
                rule_proposer = SCANRuleProposer(ds[:train]),
                prover_type = NaiveBackwardChaining,
                weight_existing = 0.15,
                weight_candidate = 0.15,
                maxsat_solver = :Z3,
                lambda_provable = Inf,
                lambda_unprovable = Inf,
                on_the_fly_proposal = true,
                log_dir = "./",
            ),
            ds[:train],
        )

        preds_train = predict(model, ds[:train])
        preds_test = predict(model, ds[:test])
    end
end

@testset "Run MetaInduceTrainer on RuleTaker" begin
    ds = load_rule_taker("depth-3", "depth-5", "depth-5")
    ds[:train] = subsample(ds[:train], 2000)  # Should be 16000 because of preprocessing
    model = train(
        MetaInduceTrainer(
            num_epochs = 5,
            rule_proposer = RuleTakerRuleProposer(),
            prover_type = ReteForwardChaining,
            weight_existing = 0.1,
            weight_candidate = 0.1,
            maxsat_solver = :Z3,
            lambda_provable = Inf,
            lambda_unprovable = Inf,
            on_the_fly_proposal = false,
            log_dir = "./",
            ds_val = ds[:val],
        ),
        ds[:train],
    )

    preds_train = predict(model, ds[:train])
    preds_test = predict(model, ds[:test])
end

@testset "Run MetaInduceTrainer on SIGMORPHON 2018" begin
    ds = load_sigmorphon2018("spanish", "hard", "hard", 5)
    model = train(
        MetaInduceTrainer(
            num_epochs = 8,
            rule_proposer = SigmorphonRuleProposer(),
            prover_type = ReteForwardChaining,
            weight_existing = 1.0,
            weight_candidate = 1.0,
            maxsat_solver = :Z3,
            lambda_provable = Inf,
            lambda_unprovable = Inf,
            on_the_fly_proposal = false,
            log_dir = "./",
            ds_val = ds[:val],
        ),
        ds[:train],
    )

    preds_train = predict(model, ds[:train])
    preds_test = predict(model, ds[:test])
end
