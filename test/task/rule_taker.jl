@testset "Load RuleTaker" begin
    ds = load_rule_taker("depth-3", "depth-5", "NatLang")
    ds_train = ds[:train]
    ds_val = ds[:val]
    ds_test = ds[:test]

    @test typeof(ds_train) == typeof(ds_val) == typeof(ds_test) == Dataset
    @test ds_train.name == ds_val.name == ds_test.name == "RuleTaker"
    @test ds_train.split == :train
    @test ds_val.split == :val
    @test ds_test.split == :test
    @test eltype(ds_train) == eltype(ds_val) == eltype(ds_test) == Example
end

@testset "Negation" begin
    sent_1 = sent"$TRUE$ today is sunny"
    sent_2 = sent"$FALSE$ today is sunny"
    @test negate(sent_1) == sent_2
    @test negate(sent_2) == sent_1
end
