@testset "Forward Chaining 1" begin
    sent_1 = sent"wif kiki dax blicket lug $MAPS_TO$ RED BLUE RED GREEN"
    sent_2 = sent"dax fep $MAPS_TO$ RED RED RED"

    rule_1 = Rule(Sentence[], sent_1)
    rule_2 = Rule(Sentence[], sent_2)
    rule_3 = Rule([sent_1], sent_2)

    let prover = NaiveForwardChaining([rule_1, rule_2, rule_3])
        prover(Sentence[], callback = (concl, cr) -> concl == sent_2)
    end

    let prover = ReteForwardChaining([rule_1, rule_2, rule_3])
        prover(Sentence[], callback = (concl, cr) -> concl == sent_2)
    end
end


@testset "Forward Chaining 2" begin
    implications = Set{Sentence}()

    function record(concl, cr)
        push!(implications, concl)
        return true
    end

    rule_1 = Rule(
        [sent"$TRUE$ the squirrel like the squirrel"],
        sent"$FALSE$ the squirrel do not like the squirrel",
    )

    rule_2 = Rule(
        [
            sent"$TRUE$ the squirrel be round",
            sent"$TRUE$ if someone be round then they like the squirrel",
        ],
        sent"$TRUE$ the squirrel like the squirrel",
    )

    let prover = NaiveForwardChaining([rule_1, rule_2])
        prover(
            [
                sent"$TRUE$ the squirrel be round",
                sent"$TRUE$ if someone be round then they like the squirrel",
            ],
            callback = record,
        )
        @test sent"$FALSE$ the squirrel do not like the squirrel" in implications
    end

    empty!(implications)
    let prover = ReteForwardChaining([rule_1, rule_2])
        prover(
            [
                sent"$TRUE$ the squirrel be round",
                sent"$TRUE$ if someone be round then they like the squirrel",
            ],
            callback = record,
        )
        @test sent"$FALSE$ the squirrel do not like the squirrel" in implications
    end
end

@testset "Forward Chaining 3" begin
    rule_1 = Rule(
        [sent"[A] be [B]", sent"[A] be [C]", sent"[B] , [C] people be [D]"],
        sent"[A] be [D]",
    )
    rule_2 = Rule(
        [sent"[A] be [B]", sent"[C] be [D]", sent"if [A] be [B] and [C] be [D] then [E]"],
        sent"[E]",
    )
    function check(concl, cr)
        @assert cr === nothing || concl == sent"harry be green"
        return true
    end
    NaiveForwardChaining([rule_1, rule_2])(
        [sent"harry be red", sent"harry be blue", sent"red , blue people be green"],
        callback = check,
    )
    ReteForwardChaining([rule_1, rule_2])(
        [sent"harry be red", sent"harry be blue", sent"red , blue people be green"],
        callback = check,
    )
end

@testset "Forward Chaining 4" begin
    implications = Set{Sentence}()

    function record(concl, cr)
        push!(implications, concl)
        return true
    end

    assumptions = [
        sent"$TRUE$ fiona be quiet",
        sent"$TRUE$ fiona be young",
        sent"$TRUE$ all young things be smart",
        sent"$TRUE$ if something be smart and quiet then it be white",
        sent"$TRUE$ if something be young and white then it be big",
    ]
    goal = sent"$TRUE$ fiona be big"
    rules = [
        Rule(
            [
                sent"$TRUE$ fiona be smart",
                sent"$TRUE$ fiona be quiet",
                sent"$TRUE$ if something be smart and quiet then it be white",
            ],
            sent"$TRUE$ fiona be white",
        ),
        Rule(
            [
                sent"$TRUE$ fiona be young",
                sent"$TRUE$ fiona be white",
                sent"$TRUE$ if something be young and white then it be big",
            ],
            sent"$TRUE$ fiona be big",
        ),
        Rule(
            [sent"$TRUE$ fiona be young", sent"$TRUE$ all young things be smart"],
            sent"$TRUE$ fiona be smart",
        ),
    ]

    let prover = NaiveForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end

    empty!(implications)
    let prover = ReteForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end
end

@testset "Forward Chaining 5" begin
    implications = Set{Sentence}()

    function record(concl, cr)
        push!(implications, concl)
        return true
    end

    assumptions = [
        sent"$TRUE$ the cow be not big",
        sent"$TRUE$ the cow be not green",
        sent"$TRUE$ the lion eat the tiger",
        sent"$TRUE$ the lion see the cow",
        sent"$TRUE$ the lion visit the cow",
        sent"$TRUE$ the lion do not visit the squirrel",
        sent"$TRUE$ the lion visit the tiger",
        sent"$TRUE$ the squirrel be big",
        sent"$TRUE$ the squirrel be round",
        sent"$TRUE$ the tiger be not green",
        sent"$TRUE$ the tiger do not see the cow",
        sent"$TRUE$ if something see the squirrel and the squirrel eat the cow then the cow be round",
        sent"$TRUE$ if something be green then it eat the tiger",
        sent"$TRUE$ if the squirrel be round then the squirrel visit the cow",
        sent"$TRUE$ if something eat the cow then it see the squirrel",
        sent"$TRUE$ if something see the tiger and the tiger visit the squirrel then it be nice",
        sent"$TRUE$ if something be round then it eat the cow",
        sent"$TRUE$ if something be kind then it eat the cow",
        sent"$TRUE$ if the tiger visit the cow then the cow see the squirrel",
        sent"$TRUE$ if something see the cow then the cow eat the tiger",
    ]
    goal = sent"$FALSE$ the tiger be green"
    rules = [Rule([sent"$TRUE$ [A] be not [B]"], sent"$FALSE$ [A] be [B]")]

    let prover = NaiveForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end

    empty!(implications)
    let prover = ReteForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end
end

@testset "Forward Chaining 6" begin
    implications = Set{Sentence}()

    function record(concl, cr)
        push!(implications, concl)
        return true
    end

    assumptions = [
        sent"$TRUE$ the squirrel be round",
        sent"$TRUE$ if the squirrel be round then the squirrel visit the cow",
    ]
    goal = sent"$TRUE$ the squirrel visit the cow"
    rules = [
        Rule(
            [sent"$TRUE$ [A] [B] [C]", sent"$TRUE$ if [A] [B] [C] then [D] [E] [F]"],
            sent"$TRUE$ [D] [E] [F]",
        ),
    ]

    let prover = NaiveForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end

    empty!(implications)
    let prover = ReteForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end
end

@testset "Forward Chaining 7" begin
    implications = Set{Sentence}()

    function record(concl, cr)
        push!(implications, concl)
        return true
    end

    assumptions = [
        sent"$TRUE$ the cat likes the tiger",
        sent"$TRUE$ the lion sees the rabbit",
        sent"$TRUE$ the rabbit eats the lion",
        sent"$TRUE$ the rabbit eats the tiger",
        sent"$TRUE$ the rabbit likes the cat",
        sent"$TRUE$ the tiger is not cold",
        sent"$TRUE$ the tiger likes the lion",
        sent"$TRUE$ if something likes the cat then it is nice",
        sent"$TRUE$ all young things are nice",
        sent"$TRUE$ if something eats the tiger then it is nice",
        sent"$TRUE$ if something eats the cat then the cat is young",
        sent"$TRUE$ if something eats the lion then the lion eats the cat",
        sent"$TRUE$ if something sees the cat then the cat does not see the lion",
        sent"$TRUE$ if something is round then it does not like the rabbit",
        sent"$TRUE$ if something is nice then it is round",
    ]
    goal = sent"$TRUE$ the cat is young"
    rules = [
        Rule(
            [
                sent"$TRUE$ the rabbit eat the lion",
                sent"$TRUE$ if something eat the lion then the lion eat the cat",
            ],
            sent"$TRUE$ the lion eat the cat",
        ),
        Rule(
            [
                sent"$TRUE$ the lion eat the cat",
                sent"$TRUE$ if something eat the cat then the cat be young",
            ],
            sent"$TRUE$ the cat be young",
        ),
        Rule([sent"$TRUE$ [A] eats [B]"], sent"$TRUE$ [A] eat [B]"),
        Rule([sent"$TRUE$ [A] is [B]"], sent"$TRUE$ [A] be [B]"),
        Rule([sent"$TRUE$ [A] be [B]"], sent"$TRUE$ [A] is [B]"),
    ]

    let prover = NaiveForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end

    empty!(implications)
    let prover = ReteForwardChaining(rules)
        prover(assumptions, callback = record)
        @test goal in implications
    end
end

@testset "Forward Chaining 8" begin
    implications = Set{Sentence}()

    function record(concl, cr)
        push!(implications, concl)
        return true
    end

    assumptions = [
        sent"$TRUE$ anne is cold",
        sent"$TRUE$ anne is not rough",
        sent"$TRUE$ bob is nice",
        sent"$TRUE$ charlie is white",
        sent"$TRUE$ charlie is young",
        sent"$TRUE$ harry is not white",
        sent"$TRUE$ harry is young",
        sent"$TRUE$ all nice people are cold",
        sent"$TRUE$ rough people are nice",
        sent"$TRUE$ if harry is young and harry is not white then harry is rough",
        sent"$TRUE$ if someone is cold and not young then they are not green",
        sent"$TRUE$ green people are furry",
        sent"$TRUE$ young , white people are furry",
        sent"$TRUE$ if anne is nice and anne is green then anne is cold",
        sent"$TRUE$ if harry is rough and harry is cold then harry is green",
    ]
    goal = sent"$TRUE$ harry is furry"
    rules = [
        Rule(
            [
                sent"$TRUE$ harry be young",
                sent"$TRUE$ harry be not white",
                sent"$TRUE$ if harry be young and harry be not white then harry be rough",
            ],
            sent"$TRUE$ harry be rough",
        ),
        Rule(
            [sent"$TRUE$ harry be rough", sent"$TRUE$ rough people be nice"],
            sent"$TRUE$ harry be nice",
        ),
        Rule(
            [sent"$TRUE$ harry be nice", sent"$TRUE$ all nice people be cold"],
            sent"$TRUE$ harry be cold",
        ),
        Rule(
            [
                sent"$TRUE$ harry be rough",
                sent"$TRUE$ harry be cold",
                sent"$TRUE$ if harry be rough and harry be cold then harry be green",
            ],
            sent"$TRUE$ harry be green",
        ),
        Rule(
            [sent"$TRUE$ harry be green", sent"$TRUE$ green people be furry"],
            sent"$TRUE$ harry be furry",
        ),
        Rule([sent"$TRUE$ [A] is [B]"], sent"$TRUE$ [A] be [B]"),
        Rule([sent"$TRUE$ [A] be [B]"], sent"$TRUE$ [A] is [B]"),
        Rule([sent"$TRUE$ [A] are [B]"], sent"$TRUE$ [A] be [B]"),
        Rule([sent"$TRUE$ [A] be [B]"], sent"$TRUE$ [A] are [B]"),
    ]

    let prover = NaiveForwardChaining(rules, fill(0.05, length(rules)))
        prover(assumptions, callback = record)
        @test goal in implications
    end

    empty!(implications)
    let prover = ReteForwardChaining(rules, fill(0.05, length(rules)))
        prover(assumptions, callback = record)
        @test goal in implications
    end
end
