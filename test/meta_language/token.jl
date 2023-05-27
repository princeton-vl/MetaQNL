@testset "Word" begin
    @test isbitstype(Word)

    let w1 = word"hello"
        @test string(w1) == "hello"
        @test w1 == create_word("hello")
        @test w1 != word"hi"
        @test is_word(w1)
    end
end

@testset "Variable" begin
    @test isbitstype(Variable)

    existing_vars = [create_variable(string('A' + i)) for i = 0:24]
    @test fresh_variable(existing_vars) == variable"Z"

    let v1 = variable"A"
        @test v1 == create_variable("A")
        @test v1 != create_variable("B")
        @test string(v1) == "[A]"
        @test is_variable(v1)
    end
end

@testset "Special symbols" begin
    @test isbitstype(SpecialSymbol)
    @test symbol"MAPS_TO" == create_special_symbol("MAPS_TO")
end
