@testset "Example" begin
    for label in [PROVABLE, UNPROVABLE]
        ex = Example(Sentence[], sent"hello world !", label)
        @test concrete_goals(ex) == [sent"hello world !"]
    end

    let ex =
            Example(Sentence[], sent"hello [X] !", PROVABLE, [Substitution("X" => "world")])
        @test concrete_goals(ex) == [sent"hello world !"]
    end
end
