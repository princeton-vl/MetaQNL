@testset "Load MiniSCAN" begin
    ds = load_mini_scan()
    ds_train = ds[:train]
    ds_test = ds[:test]

    @test typeof(ds_train) == typeof(ds_test) == Dataset
    @test ds_train.name == ds_test.name == "MiniSCAN"
    @test ds_train.split == :train
    @test ds_test.split == :test
    @test length(ds_train) == 14
    @test length(ds_test) == 10
    @test eltype(ds_train) == eltype(ds_test) == Example
end


@testset "Load SCAN" begin
    ds = load_scan("simple")
    ds_train = ds[:train]
    ds_test = ds[:test]

    @test typeof(ds_train) == typeof(ds_test) == Dataset
    @test ds_train.name == ds_test.name == "SCAN"
    @test ds_train.split == :train
    @test ds_test.split == :test
    @test length(ds_train) == 16728
    @test length(ds_test) == 4182
    @test eltype(ds_train) == eltype(ds_test) == Example

    ds = load_scan("length")
    @test length(ds[:train]) == 16990
    @test length(ds[:test]) == 3920

    ds = load_scan("addprim_jump")
    @test length(ds[:train]) == 13204
    @test length(ds[:test]) == 7706

    ds = load_scan("addprim_turn_left")
    @test length(ds[:train]) == 19702
    @test length(ds[:test]) == 1208
end
