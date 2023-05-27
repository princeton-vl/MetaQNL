@testset "Substitution" begin
    let subst_1 = Substitution(
            Dict(
                create_variable("X") => Sentence("[Y]"),
                create_variable("Y") => Sentence("hello world"),
                create_variable("Z") => Sentence("hello [P] world"),
            ),
        )
        @test !is_concrete(subst_1)
        @test !isempty(subst_1)
        @test haskey(subst_1, "Z")
        @test !haskey(subst_1, create_variable("Q"))
        @test length(subst_1) == 3
        subst_1[create_variable("Q")] = Sentence("[U] [V] [W]")
        @test haskey(subst_1, "Q")
        @test length(subst_1) == 4
    end

    subst_2 = Substitution(Dict(create_variable("X") => Sentence("hello [P] hello")))
    subst_3 = Substitution(Dict(create_variable("P") => Sentence("hi")))
    @test subst_2 ∘ subst_3 == Substitution(
        Dict(
            create_variable("X") => Sentence("hello hi hello"),
            create_variable("P") => Sentence("hi"),
        ),
    )

    @test subst_2 + subst_3 == Substitution(
        Dict(
            create_variable("X") => Sentence("hello [P] hello"),
            create_variable("P") => Sentence("hi"),
        ),
    )

    let subst_5 = Substitution(Dict(create_variable("X") => Sentence("hi")))
        @test_throws AssertionError subst_2 + subst_5
    end

    let subst_6 = Substitution(Dict(create_variable("A") => Sentence("hello [X]"))),
        subst_7 = Substitution(Dict(create_variable("A") => Sentence("hello [Y]")))

        @test subst_6 != subst_7
    end
end
