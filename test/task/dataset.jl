@testset "Dataset" begin
    ds = Dataset("HelloWord", :train, Example[])
    @test isempty(ds)
    @test length(ds) == 0
end
