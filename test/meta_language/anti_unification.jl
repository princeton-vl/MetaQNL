function checked_anti_unify(x, y)
    aus = anti_unify(x, y)
    @test unique(aus) == aus
    for au in aus
        @test is_more_general(au.general_instance, x)
        @test is_more_general(au.general_instance, y)
        u, v = get_specific_instances(au)
        if x isa Rule
            @test u == x && v == y
        else
            @test is_identical(u, x) && is_identical(v, y)
        end
    end
    return aus
end

function checked_anti_unify(x::Rule, y::Rule)
    aus = anti_unify(x, y)
    @test unique(aus) == aus
    for au in aus
        @test is_more_general(au, x)
        @test is_more_general(au, y)
    end
    return aus
end


@testset "Anti-unify two sentences without parse trees" begin
    let sent_1 = sent"how are you ?"
        aus1 = checked_anti_unify(sent_1, sent_1)
        @test length(aus1) == 1
        au = aus1[1]
        @test is_identical(au.general_instance, sent"how are you ?")
        @test isempty(au.bi_substitution)
    end

    let sent_21 = sent"how are how", sent_22 = sent"and or and"
        aus2 = checked_anti_unify(sent_21, sent_22)
        @test findfirst(au -> au.general_instance == sent"[A] [B] [A]", aus2) !== nothing
    end

    let sent_31 = sent"how are how", sent_32 = sent"and how and"
        aus3 = checked_anti_unify(sent_31, sent_32)
        @test findfirst(au -> au.general_instance == sent"[A] [B] [A]", aus3) !== nothing
    end

    let sent_41 = sent"how are you ?", sent_42 = sent"how ARE you ?"
        aus4 = checked_anti_unify(sent_41, sent_42)
        @test length(aus4) == 1
        au = aus4[1]
        @test is_identical(au.general_instance, sent"how [A] you ?")
    end

    let sent_51 = sent"[X]", sent_52 = sent"how are you ?"
        aus5 = checked_anti_unify(sent_51, sent_52)
        @test length(aus5) == 1
        au = aus5[1]
        @test is_identical(au.general_instance, sent"[A]")
    end

    let sent_61 = sent"how are you ?", sent_62 = sent"[X]"
        aus6 = checked_anti_unify(sent_61, sent_62)
        @test length(aus6) == 1
        au = aus6[1]
        @test is_identical(au.general_instance, sent"[A]")
    end

    let sent_71 = sent"[X] old are [Z]", sent_72 = sent"how [Y] are [Z]"
        aus7 = checked_anti_unify(sent_71, sent_72)
        @test findfirst(
            au -> is_equivalent(au.general_instance, sent"[A] [B] are [C]"),
            aus7,
        ) !== nothing
    end

    let sent_8 = Sentence()
        aus8 = checked_anti_unify(sent_8, sent_8)
        @test length(aus8) == 1
        au = aus8[1]
        @test is_identical(au.general_instance, Sentence())
    end

    let sent_91 = sent"how are [X]", sent_92 = sent"how are"
        aus9 = checked_anti_unify(sent_91, sent_92)
        @test length(aus9) == 1
        au = aus9[1]
        @test is_identical(au.general_instance, sent"how [A]")
    end

    let sent_101 = sent"how are you [X]", sent_102 = sent"how are"
        aus10 = checked_anti_unify(sent_101, sent_102)
        @test length(aus10) == 1
        au = aus10[1]
        @test is_identical(au.general_instance, sent"how [A]")
    end

    let sent_111 = sent"how are", sent_112 = sent"how are you [X]"
        aus11 = checked_anti_unify(sent_111, sent_112)
        @test length(aus11) == 1
        au = aus11[1]
        @test is_identical(au.general_instance, sent"how [A]")
    end

    let sent_121 = sent"[E] [F]", sent_122 = sent"BLUE BLUE"
        aus12 = checked_anti_unify(sent_121, sent_122)
        @test findfirst(au -> au.general_instance == sent"[A] [B]", aus12) !== nothing
        @test is_more_general(sent_121, sent_122)
    end
end

@testset "Examples of anti-unification required by MiniSCAN" begin
    let f11 = sent"dax fep $MAPS_TO$ RED RED RED",
        f12 = sent"lug fep $MAPS_TO$ BLUE BLUE BLUE"

        aus1 = checked_anti_unify(f11, f12)
        @test findfirst(
            au -> is_equivalent(au.general_instance, sent"[A] fep $MAPS_TO$ [B] [B] [B]"),
            aus1,
        ) !== nothing
    end

    let f21 = sent"wif blicket dax $MAPS_TO$ GREEN RED GREEN",
        f22 = sent"lug blicket wif $MAPS_TO$ BLUE GREEN BLUE"

        aus2 = checked_anti_unify(f21, f22)
        @test findfirst(
            au -> is_equivalent(
                au.general_instance,
                sent"[A] blicket [B] $MAPS_TO$ [C] [D] [C]",
            ),
            aus2,
        ) !== nothing
    end

    let f31 = sent"dax kiki lug $MAPS_TO$ BLUE RED",
        f32 = sent"lug kiki wif $MAPS_TO$ GREEN BLUE"

        aus3 = checked_anti_unify(f31, f32)
        @test findfirst(
            au -> is_equivalent(au.general_instance, sent"[A] kiki [B] $MAPS_TO$ [C] [D]"),
            aus3,
        ) !== nothing
    end

    let r41 = Rule([sent"dax $MAPS_TO$ RED"], sent"dax fep $MAPS_TO$ RED RED RED"),
        r42 = Rule([sent"lug $MAPS_TO$ BLUE"], sent"lug fep $MAPS_TO$ BLUE BLUE BLUE")

        aus4 = checked_anti_unify(r41, r42)
        @test length(aus4) == 1
        au = aus4[1]
        @test au == Rule([sent"[A] $MAPS_TO$ [B]"], sent"[A] fep $MAPS_TO$ [B] [B] [B]")
    end

    let r51 = Rule(
            [sent"wif $MAPS_TO$ GREEN", sent"dax $MAPS_TO$ RED"],
            sent"wif blicket dax $MAPS_TO$ GREEN RED GREEN",
        ),
        r52 = Rule(
            [sent"wif $MAPS_TO$ GREEN", sent"lug $MAPS_TO$ BLUE"],
            sent"lug blicket wif $MAPS_TO$ BLUE GREEN BLUE",
        )

        aus5 = checked_anti_unify(r51, r52)
        @test length(aus5) == 1
        @test first(aus5) == Rule(
            [sent"[X] $MAPS_TO$ [P]", sent"[Y] $MAPS_TO$ [Q]"],
            sent"[X] blicket [Y] $MAPS_TO$ [P] [Q] [P]",
        )
    end

    let r61 = Rule(
            [sent"dax $MAPS_TO$ RED", sent"lug $MAPS_TO$ BLUE"],
            sent"dax kiki lug $MAPS_TO$ BLUE RED",
        ),
        r62 = Rule(
            [sent"wif $MAPS_TO$ GREEN", sent"lug $MAPS_TO$ BLUE"],
            sent"lug kiki wif $MAPS_TO$ GREEN BLUE",
        )

        aus6 = checked_anti_unify(r61, r62)
        @test length(aus6) == 1
        @test first(aus6) == Rule(
            [sent"[A] $MAPS_TO$ [B]", sent"[C] $MAPS_TO$ [D]"],
            sent"[A] kiki [C] $MAPS_TO$ [D] [B]",
        )
    end

    let r71 = Rule([sent"red people are [A]", sent"[B] is red"], sent"[B] is [A]"),
        r72 = Rule([sent"kind people are [A]", sent"[B] is kind"], sent"[B] is [A]")

        aus7 = checked_anti_unify(r71, r72)
        @test findfirst(
            au -> is_equivalent(
                au,
                Rule([sent"[C] people are [A]", sent"[B] is [C]"], sent"[B] is [A]"),
            ),
            aus7,
        ) !== nothing
    end

    let r81 = Rule([sent"if something [X] then [Y]", sent"[A] [X]"], sent"[Y]"),
        r82 = Rule(
            [
                sent"if something visits the rabbit then the rabbit sees the squirrel",
                sent"the mouse visits the rabbit",
            ],
            sent"the rabbit sees the squirrel",
        )

        aus8 = checked_anti_unify(r81, r82)
        @test length(aus8) == 1
        au = aus8[1]
        @test au == r81
        @test is_more_general(r81, r82)
    end

    let r91 = Rule([sent"z a r a n d e a m o s"], sent"$TAG$ PL"),
        r92 = Rule([sent"f r a s e a m o s"], sent"$TAG$ PL")

        aus9 = checked_anti_unify(r91, r92)
        @test !isempty(aus9)
    end

    let r101 = Rule(
            [
                sent"the tiger like the tiger",
                sent"if something like the tiger then it be cold",
            ],
            sent"the tiger be cold",
        ),
        r102 = Rule(
            [sent"if something be big then it be nice", sent"bob be big"],
            sent"bob be nice",
        )

        aus10 = checked_anti_unify(r101, r102)
        @test !isempty(aus10)
    end
end

@testset "Profiling anti-unification" begin
    r1 = Rule(
        [
            sent"if someone is young and big then they are rough",
            sent"anne is young",
            sent"anne is big",
        ],
        sent"anne is rough",
    )
    r2 = Rule(
        [
            sent"if someone needs the bald eagle and the bald eagle does not see the squirrel then the bald eagle is nice",
            sent"the bald eagle needs the bald eagle",
            sent"the bald eagle does not see the squirrel",
        ],
        sent"the bald eagle is nice",
    )
    @time checked_anti_unify(r1, r2)
    # @benchmark checked_anti_unify(r1, r2)

    r3 = Rule(
        [
            sent"if harry is green and harry is red then harry is kind",
            sent"harry is green",
            sent"harry is red",
        ],
        sent"harry is kind",
    )
    r4 = Rule(
        [
            sent"if something sees the cat and the cat likes the lion then the lion is nice",
            sent"the bald eagle sees the cat",
            sent"the cat likes the lion",
        ],
        sent"the lion is nice",
    )
    @time checked_anti_unify(r3, r4)

    r5 = Rule(
        [
            sent"jump around left $MAPS_TO$ I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP",
        ],
        sent"jump around left thrice $MAPS_TO$ I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP I_TURN_LEFT I_JUMP",
    )
    r6 = Rule(
        [
            sent"walk around left $MAPS_TO$ I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK",
        ],
        sent"walk around left thrice $MAPS_TO$ I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK I_TURN_LEFT I_WALK",
    )
    @time checked_anti_unify(r5, r6)

end

@testset "Examples of anti-unification required by the NatLang part of RuleTaker" begin
    rule_1 = Rule(
        [sent"$TRUE$ young eric has red , rough skin , but is nice and kind"],
        sent"$TRUE$ eric is nice",
    )
    rule_2 = Rule(
        [
            sent"$TRUE$ most everyone considers charlie a rough fellow , but very kind; he's often categorized as blue , and he's big",
        ],
        sent"$TRUE$ charlie is blue",
    )
    checked_anti_unify(rule_1, rule_2)
end
