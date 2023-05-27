
@testset "Sentences" begin
    s1 = Sentence()
    @test is_identical(s1, Sentence())
    @test is_equivalent(s1, Sentence())
    @test isempty(s1)
    @test length(s1) == 0
    @test is_concrete(s1)
    @test !is_one_variable(s1)
    @test !has_only_variables(s1)
    @test !startswith_word(s1)
    @test !startswith_variable(s1)
    @test_throws BoundsError s1[1]
    @test_throws BoundsError s1[end]

    s2 = sent"hello world"
    @test is_identical(s2, Sentence([create_word("hello"), create_word("world")]))
    @test !isempty(s2)
    @test length(s2) == 2
    @test is_concrete(s2)
    @test !is_one_variable(s2)
    @test !has_only_variables(s2)
    @test startswith_word(s2)
    @test !startswith_variable(s2)
    @test s2[1] == create_word("hello")
    @test s2[end] == create_word("world")
    @test is_identical(s2[2:end], Sentence("world"))
    @test is_identical(s2[3:end], Sentence())

    s3 = Sentence("[Y] hello [X] world")
    @test string(s3) == "[Y] hello [X] world"
    @test !isempty(s3)
    @test length(s3) == 4
    @test !is_concrete(s3)
    @test !is_one_variable(s3)
    @test !has_only_variables(s3)
    @test !startswith_word(s3)
    @test startswith_variable(s3)
    @test s3[1] == variable"Y"
    @test is_identical((@views s3[1:3]), Sentence("[Y] hello [X]"))

    let s4 = Sentence("[X] [Y]")
        @test has_only_variables(s4)
    end

    @test_throws AssertionError Sentence("all [X], [Y] things are [Z]")
    Sentence("all [X] , [Y] things are [Z]")

    # Concatenation
    @test is_identical(s1 * s2, Sentence("hello world"))
    @test is_identical(s2 * s3, Sentence("hello world [Y] hello [X] world"))
    @test is_identical(create_variable("Z") * s3, Sentence("[Z] [Y] hello [X] world"))

    # Find common prefix
    let (prefix_1, suffix_11, suffix_12) = find_common_prefix(
            Sentence("hi [X] hi hello how"),
            Sentence("hi [X] hi lALA"),
            requires_concrete = true,
        )
        @test is_identical(prefix_1, Sentence("hi"))
        @test is_identical(suffix_11, Sentence("[X] hi hello how"))
        @test is_identical(suffix_12, Sentence("[X] hi lALA"))
    end

    let (prefix_11, prefix_12, suffix_1) = find_common_suffix(
            Sentence("how hello hi [X] hi"),
            Sentence("lALA hi [X] hi"),
            requires_concrete = true,
        )
        @test is_identical(suffix_1, Sentence("hi"))
        @test is_identical(prefix_11, Sentence("how hello hi [X]"))
        @test is_identical(prefix_12, Sentence("lALA hi [X]"))
    end

    let (prefix_1, suffix_11, suffix_12) = find_common_prefix(
            Sentence("hi [X] hi hello how"),
            Sentence("hi [X] hi lALA"),
            requires_concrete = false,
        )
        @test is_identical(prefix_1, Sentence("hi [X] hi"))
        @test is_identical(suffix_11, Sentence("hello how"))
        @test is_identical(suffix_12, Sentence("lALA"))
    end

    let (prefix_11, prefix_12, suffix_1) = find_common_suffix(
            Sentence("how hello hi [X] hi"),
            Sentence("lALA hi [X] hi"),
            requires_concrete = false,
        )
        @test is_identical(suffix_1, Sentence("hi [X] hi"))
        @test is_identical(prefix_11, Sentence("how hello"))
        @test is_identical(prefix_12, Sentence("lALA"))
    end

    @test !is_identical(
        Sentence("[X] hello [Y] hi [X] ? [X]"),
        Sentence("[Z] hello [Y] hi [Z] ? [Z]"),
    )
    @test is_equivalent(
        Sentence("[X] hello [Y] hi [X] ? [X]"),
        Sentence("[Z] hello [Y] hi [Z] ? [Z]"),
    )
    @test hash(Sentence("[X] hello [Y] hi [X] ? [X]")) !=
          hash(Sentence("[Z] hello [Y] hi [Z] ? [Z]"))
    @test alpha_invariant_hash(Sentence("[X] hello [Y] hi [X] ? [X]")) ==
          alpha_invariant_hash(Sentence("[Z] hello [Y] hi [Z] ? [Z]"))
    @test !is_identical(
        Sentence("[X] hello [Y] hi [X] ? [X]"),
        Sentence("[Z] hello [Y] hi [Y] ? [Z]"),
    )
    @test !is_equivalent(
        Sentence("[X] hello [Y] hi [X] ? [X]"),
        Sentence("[Z] hello [Y] hi [Y] ? [Z]"),
    )
    @test hash(Sentence("[X] hello [Y] hi [X] ? [X]")) !=
          hash(Sentence("[Z] hello [Y] hi [Y] ? [Z]"))

    @test hash(Sentence("hello world [X]")) == hash(Sentence("hello world [X]"))
    @test alpha_invariant_hash(Sentence("hello world [X]")) ==
          alpha_invariant_hash(Sentence("hello world [X]"))
end

@testset "More sentences" begin
    let sent_1 = sent"$IS$ \" hello world . \""
        @test !isempty(sent_1)
        @test length(sent_1) == 6
        @test is_concrete(sent_1)
        @test isempty(get_variables(sent_1))
    end

    let sent_2 = sent"\" hello world . \" $IS$ \" how are you ? \""
        @test length(sent_2) == 12
        @test is_concrete(sent_2)
    end

    let sent_3 = Sentence(
            "\$IS\$ \" hello [X] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        )
        @test length(sent_3) == 19
        @test !is_concrete(sent_3)
    end

    @test is_identical(
        Sentence(
            "\$IS\$ \" hello [X] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
        Sentence(
            "\$IS\$ \" hello [X] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
    )

    @test !is_identical(
        Sentence(
            "\$IS\$ \" hello [X] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
        Sentence(
            "\$IS\$ \" hello [X] [Z] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
    )

    @test is_equivalent(
        Sentence(
            "\$IS\$ \" hello [X] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
        Sentence(
            "\$IS\$ \" hello [X] [Z] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
    )
    @test alpha_invariant_hash(
        Sentence(
            "\$IS\$ \" hello [X] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
    ) == alpha_invariant_hash(
        Sentence(
            "\$IS\$ \" hello [X] [Z] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
    )
    @test !is_equivalent(
        Sentence(
            "\$IS\$ \" hello [Y] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
        Sentence(
            "\$IS\$ \" hello [X] [Z] world \" \" [U] hello [Y] world [W] \" \" hello [P] world \"",
        ),
    )
    @test hash(
        Sentence(
            "\$IS\$ \" hello [Y] [Y] world \" \" [U] hello [X] world [W] \" \" hello [P] world \"",
        ),
    ) != hash(
        Sentence(
            "\$IS\$ \" hello [X] [Z] world \" \" [U] hello [Y] world [W] \" \" hello [P] world \"",
        ),
    )
end
