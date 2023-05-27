@testset "Basic checks of the vocabulary" begin
    @test @isdefined word_vocab
    @test @isdefined variable_vocab

    push!(word_vocab, "hello")
    w = word_vocab[1]
    @test word_vocab[w] == 1

    v = variable_vocab[10]
    @test variable_vocab[v] == 10

    filename = tempname()
    save_vocabs(filename)
    load_vocabs(filename)
    rm(filename)
end
