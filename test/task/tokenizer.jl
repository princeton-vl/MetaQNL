@testset "Tokenization and lemmatization" begin
    text = "Apple is looking at buying U.K. startup for \$1 billion."
    tokens = tokenize(text)
    @test tokens == [
        "apple",
        "be",
        "look",
        "at",
        "buy",
        "u.k.",
        "startup",
        "for",
        "\$",
        "1",
        "billion",
        ".",
    ]
end
