@testset "Rule" begin
    let r1 = Rule(Sentence[], Sentence("dax RED"))
        @test isempty(r1.premises)
        @test is_concrete(r1)
    end

    r2 =
        Rule([Sentence("[X] \$MAPS_TO\$ [P]")], Sentence("[X] fep \$MAPS_TO\$ [P] [P] [P]"))
    @test length(r2.premises) == 1
    @test !is_concrete(r2)

    @test is_identical(r2, r2)
    @test !is_identical(
        r2,
        Rule(
            [Sentence("[Q] \$MAPS_TO\$ [P]")],
            Sentence("[Q] fep \$MAPS_TO\$ [P] [P] [P]"),
        ),
    )
    @test r2 == Rule(
        [Sentence("[Q] \$MAPS_TO\$ [P]")],
        Sentence("[Q] fep \$MAPS_TO\$ [P] [P] [P]"),
    )
    @test hash(r2) == hash(
        Rule(
            [Sentence("[Q] \$MAPS_TO\$ [P]")],
            Sentence("[Q] fep \$MAPS_TO\$ [P] [P] [P]"),
        ),
    )
    @test r2 != Rule(
        [Sentence("[X] \$MAPS_TO\$ [P]")],
        Sentence("[Q] fep \$MAPS_TO\$ [P] [P] [P]"),
    )

    r3 =
        Rule([Sentence("[A] \$MAPS_TO\$ [B]")], Sentence("[C] fep \$MAPS_TO\$ [D] [D] [D]"))
    r4 =
        Rule([Sentence("[C] \$MAPS_TO\$ [D]")], Sentence("[C] fep \$MAPS_TO\$ [D] [D] [D]"))
    @test r3 != r4
    @test r4 != r3

    r5 =
        Rule([Sentence("[A] fep \$MAPS_TO\$ [B] [B] [B]")], Sentence("[A] \$MAPS_TO\$ [B]"))
    r6 =
        Rule([Sentence("[A] fep \$MAPS_TO\$ [B] [B] [B]")], Sentence("[C] \$MAPS_TO\$ [D]"))
    @test r5 != r6
    @test r6 != r5


    r7 = Rule(
        [Sentence("[A] \$MAPS_TO\$ [B]"), Sentence("[C] \$MAPS_TO\$ [D]")],
        Sentence("[C] [E] [F] [G] [B] GREEN [H] [D]"),
    )
    r8 = Rule(
        [Sentence("[A] [B]"), Sentence("[C] [D]")],
        Sentence("[C] [E] [A] [F] [G] GREEN [B] [D]"),
    )
    @test r7 != r8

    r9 = Rule(
        [
            Sentence("if something [A] the [B] then it [C] [D]"),
            Sentence("the [E] [A] the [B]"),
        ],
        Sentence("the [E] [C] [D]"),
    )
    r10 = Rule(
        [
            Sentence("if something [A] the [B] then it [C] [D]"),
            Sentence("the [B] [A] the [B]"),
        ],
        Sentence("the [B] [C] [D]"),
    )
    @test r9 != r10
end

@testset "Read rules from strings or files" begin
    @test load_rule("[X] , [Y] things are [Z]\n[A] is [X]\n[A] is [Y]\n---\n[A] is [Z]") ==
          Rule(
        [
            Sentence("[X] , [Y] things are [Z]"),
            Sentence("[A] is [X]"),
            Sentence("[A] is [Y]"),
        ],
        Sentence("[A] is [Z]"),
    )
    @test load_rule("\$TRUE\$ [X] sees [Y]\n---\n\$FALSE\$ [X] does not see [Y]") == Rule(
        [Sentence("\$TRUE\$ [X] sees [Y]")],
        Sentence("\$FALSE\$ [X] does not see [Y]"),
    )

    #=
    @test all(
        r isa Rule for r in load_rules_from_file(
            joinpath(rule_taker_path, "preprocessed_ground_truth_rules.txt"),
        )
    )
    @test all(
        r isa Rule for r in load_rules_from_file(
            joinpath(rule_taker_path, "preprocessed_ground_truth_rules_NatLang.txt"),
        )
    )
    @test all(
        r isa Rule for r in load_rules_from_file(
            joinpath(
                rule_taker_path,
                "preprocessed_ground_truth_rules_birds-electricity.txt",
            ),
        )
    )
    @test all(
        r isa Rule for
        r in load_rules_from_file(joinpath(scan_path, "ground_truth_rules.txt"))
    )
    =#
end
