@testset "GroundTruthModel on MiniSCAN" begin
    ds = load_mini_scan()[:test]
    model = GroundTruthModel()
    preds = predict(model, ds)
    @test evaluate(ds, preds)["accuracy"] == 1
end

@testset "DummyModel on MiniSCAN" begin
    ds = load_mini_scan()[:test]
    model = DummyModel()
    preds = predict(model, ds)
    metrics = evaluate(ds, preds)
    @test metrics["recall"] == 0
    @test metrics["precision"] == 1
end

#=
@testset "GroundTruthModel on Countries" begin
    ds = load_countries(:S3)[:test]
    model = GroundTruthModel()
    preds = first.(predict(model, ds))
    @test accuracy(ds, preds) == 1
end

@testset "DummyModel on Countries" begin
    ds = load_countries(:S3)[:test]
    model = DummyModel(NEUTRAL)
    preds = first.(predict(model, ds))
end
=#
