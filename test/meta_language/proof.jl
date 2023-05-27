@testset "Proof" begin
    @test isempty(Proof())

    let sent_1 = Sentence("hello world how are you ?"),
        sent_2 = Sentence("fep fep dax"),
        sent_3 = Sentence("hello world")

        proof = Proof(sent_1, sent_2)
        @test !isvalid(proof)
        @test sent_1 in proof
        @test sent_2 in proof
        @test !(sent_3 in proof)

        rule_1 = Rule([sent_1, sent_2], sent_3)
        apply!(proof, rule_1)
        @test isvalid(proof)
        @test sent_3 in proof

        rule_2 = Rule([Sentence("hi")], Sentence("hello"))
        @test_throws KeyError apply!(proof, rule_2)
    end

    let sent_1 = Sentence("fep fep dax"), sent_2 = Sentence("hello world")
        proof_1 = Proof(sent_1)
        @test isvalid(proof_1)
        apply!(proof_1, Rule([sent_1], sent_2))
        @test isvalid(proof_1)
        @test sent_2 in proof_1
        @test_throws AssertionError apply!(proof_1, Rule([sent_2], sent_1))

        sent_3 = Sentence("hi")
        proof_2 = Proof(sent_2)
        @test isvalid(proof_2)
        apply!(proof_2, Rule([sent_2], sent_3))
        @test isvalid(proof_2)
        apply!(proof_2, Rule([sent_3], sent_1))
        @test isvalid(proof_2)
        @test_throws AssertionError merge!(proof_1, proof_2)
    end

end
