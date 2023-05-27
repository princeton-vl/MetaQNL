@testset "EmptyTrainer on MiniSCAN" begin
    ds = load_mini_scan()
    model = train(EmptyTrainer(), ds[:train])

    preds_train = predict(model, ds[:train])
    @test all(isempty.(preds_train))
    metrics_train = evaluate(ds[:train], preds_train)
    @test metrics_train["precision"] == 1
    @test metrics_train["recall"] == 0

    preds_test = predict(model, ds[:test])
    @test all(isempty.(preds_test))
    metrics_test = evaluate(ds[:test], preds_test)
    @test metrics_test["precision"] == 1
    @test metrics_test["recall"] == 0
end

@testset "DummyTrainer on MiniSCAN" begin
    ds = load_mini_scan()
    model = train(DummyTrainer(), ds[:train])

    preds_train = predict(model, ds[:train])
    metrics_train = evaluate(ds[:train], preds_train)
    @test metrics_train["accuracy"] == 1

    preds_test = predict(model, ds[:test])
    @test all(isempty.(preds_test))
    metrics_test = evaluate(ds[:test], preds_test)
    @test metrics_test["accuracy"] == 0
end
