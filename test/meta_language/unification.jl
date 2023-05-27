function checked_unify(x, y)
    substs = unify(x, y)
    @test unique(substs) == substs
    for subst in substs
        @test is_identical(subst(x), subst(y))
    end
    return substs
end

function checked_match(x, y)
    substs = match(x, y)
    @test unique(substs) == substs
    for subst in substs
        @test is_identical(subst(x), y)
    end
    return substs
end

@testset "Unify two sentences" begin
    let substs_1 = checked_unify(sent"hello [X]", sent"hello")
        @test isempty(substs_1)
    end

    let substs_2 = checked_unify(sent"hello [X]", sent"[X] hello")
        @test length(substs_2) == 5
        for subst in substs_2
            @test length(subst) == 1
            sent = subst["X"]
            @test match(r"hello( hello)*", string(sent)) !== nothing
        end
    end

    let substs_3 = checked_unify(sent"hello [X]", sent"[Y] hello")
        @test length(substs_3) == 2
    end

    let substs_4 = checked_unify(sent"hello WORLD", sent"hello world")
        @test isempty(substs_4)
    end

    let substs_5 = checked_unify(sent"hello [X]", sent"hello WORLD")
        @test length(substs_5) == 1
        @test is_identical(substs_5[1]["X"], sent"WORLD")
    end

    let substs_6 = checked_unify(sent"hello WORLD [X]", sent"hello WORLD")
        @test isempty(substs_6)
    end

    let substs_7 = checked_unify(sent"[X] [X]", sent"WORLD WORLD")
        @test length(substs_7) == 1
        @test is_identical(substs_7[1]["X"], sent"WORLD")
    end

    let substs_8 = checked_unify(sent"hello [X] [X]", sent"hello WORLD hi")
        @test isempty(substs_8)
    end

    let substs_9 = checked_unify(sent"hello [X] [Y]", sent"hello WORLD hi")
        @test length(substs_9) == 1
        @test length(substs_9[1]) == 2
    end

    let substs_10 = checked_unify(sent"hello [X] world", sent"hello world")
        @test isempty(substs_10)
    end

    let substs_11 = checked_unify(sent"hello [X] world", sent"hello world [Y]")
        @test length(substs_11) == 2
    end

    let substs_12 = checked_unify(
            sent"if something be [B] then it be [B]",
            sent"if something be [C] [B] then it something be [C] [B] then it be [C] [B]",
        )
        @test isempty(substs_12)
    end

    let substs_13 = checked_unify(
            sent"if something be [C] [D] then it [C] [D]",
            sent"if something be [B] then it something be then it be [B] be [B]",
        )
        @test isempty(substs_13)
    end

    let sent_11 = sent"[A] be [A]", sent_12 = sent"[A] be [B]"
        checked_unify(sent_11, sent_12)
        @test is_more_general(sent_12, sent_11)
        @test !is_more_general(sent_11, sent_12)
    end

    checked_unify(sent"if if be [B]", sent"[A] [C] [D] [E]")
    is_more_general(
        sent"if [C] [D] [E] [C] [A] the the bear [D] [E] [C] [A] the the bear [D] [E] [C] [A] the the bear [D] [E] then the the bear [D] [E] [C] [A] the the bear [D] [E] [C] [A] the the bear [D] [E] [A] the the bear [D] [E]",
        sent"[D] [E] [C] [A] be the bear [D] [E] [C] [A] the the bear [D] [E] [C] [A] the the bear [D] [E]",
    )
    is_more_general(
        sent"if [A] [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E] then the the bear [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E] the the bear [D] [E]",
        sent"[D] [E] [A] be the bear [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E] [A] the the bear [D] [E]",
    )

    let substs_14 =
            checked_unify(sent"dax $MAPS_TO$ RED", sent"dax fep $MAPS_TO$ RED RED RED")
        @test isempty(substs_14)
    end

    let substs_15 = checked_match(
            sent"[E] [A] [B] [C] [D] [C] [F]",
            sent"s o b r e l l e v e m o s",
        )
        @test !isempty(substs_15)
    end

    let substs_16 = checked_match(
            sent"wif blicket dax $MAPS_TO$ [X]",
            sent"wif blicket dax kiki lug $MAPS_TO$ BLUE GREEN RED GREEN",
        )
        @test isempty(substs_16)
    end

    let substs_17 = checked_match(
            sent"[A] kiki [C] $MAPS_TO$ [D] [B]",
            sent"wif kiki dax blicket lug $MAPS_TO$ RED BLUE RED GREEN",
        )
        @test length(substs_17) == 3
    end
end


@testset "Unify two rules" begin
    let r11 = Rule([sent"[A] [X]", sent"if something [X] then [Y]"], sent"[Y]"),
        r12 = Rule(
            [
                sent"if something visits the rabbit then the rabbit sees the squirrel",
                sent"the mouse visits the rabbit",
            ],
            sent"the rabbit sees the squirrel",
        )

        @test is_more_general(r11, r12)
    end

    let r21 = Rule(
            [sent"$TRUE$ if something [X] then it [Y]", sent"$TRUE$ [A] [X]"],
            sent"$TRUE$ [A] [Y]",
        ),
        r22 = Rule(
            [sent"$TRUE$ if something be [A] then it [B]", sent"$TRUE$ [C] be [A]"],
            sent"$TRUE$ [C] [B]",
        )

        @test is_more_general(r21, r22)
    end


    let r21 = Rule(
            [sent"$TRUE$ if something [X] then it [Y]", sent"$TRUE$ [A] [X]"],
            sent"$TRUE$ [A] [Y]",
        ),
        r22 = Rule(
            [sent"$TRUE$ if something [A] then it [A]", sent"$TRUE$ [C] [A]"],
            sent"$TRUE$ [C] [A]",
        )

        # checked_unify(r21, r22)
        @test is_more_general(r21, r22)
        @test !is_more_general(r22, r21)
    end

    let r31 = Rule([sent"[A]", sent"be", sent"[B]"], sent"[A] [B]"),
        r32 = Rule([sent"[A]", sent"be", sent"[A]"], sent"[A] [A]")

        # checked_unify(r31, r32)
        @test is_more_general(r31, r32)
        @test !is_more_general(r32, r31)
    end

    let r41 = Rule([sent"[A]", sent"be", sent"[B]"], sent"[A] [B]"),
        r42 = Rule([sent"[C]", sent"be", sent"[C]"], sent"[C] [C]")

        # checked_unify(r41, r42)
        @test is_more_general(r41, r42)
        @test !is_more_general(r42, r41)
    end

    let r51 = Rule(
            [sent"[B] $MAPS_TO$ [C]", sent"[A] $MAPS_TO$ [D]"],
            sent"[A] kiki [B] $MAPS_TO$ [C] [D]",
        )
        r52 = Rule(
            [sent"[B] $MAPS_TO$ [C]", sent"[A] $MAPS_TO$ [D] [E] [D]"],
            sent"[A] kiki [B] $MAPS_TO$ [C] [D] [E] [D]",
        )
        @test is_more_general(r51, r52)
        @test !is_more_general(r52, r51)
    end

    let r61 = Rule([sent"[A] $MAPS_TO$ [B]"], sent"[A] twice $MAPS_TO$ [B] [B]"),
        r62 = Rule(
            [sent"[A] left $MAPS_TO$ I_TURN_LEFT [B]"],
            sent"[A] left twice $MAPS_TO$ I_TURN_LEFT [B] I_TURN_LEFT [B]",
        )

        @test is_more_general(r61, r62)
    end

    let r71 = Rule([sent"[A] $MAPS_TO$ [B]"], sent"[A] thrice $MAPS_TO$ [B] [C] [C]"),
        r72 = Rule(
            [sent"[A] left $MAPS_TO$ I_TURN_LEFT [B]"],
            sent"[A] left thrice $MAPS_TO$ I_TURN_LEFT [B] I_TURN_LEFT [B] I_TURN_LEFT [B]",
        )

        @test is_more_general(r71, r72)
    end

end


@testset "Match two sentences" begin
    let sent_11 = sent"hello [X] world [Y] !",
        sent_12 = sent"hello bear [X] lion world you !"

        substs = checked_match(sent_11, sent_12)
        @test length(substs) == 1
        @test is_more_general(sent_11, sent_12)
    end

    @test isempty(checked_match(sent"[A] [B] [A]", sent"z a r a n d e a m o s"))
end
