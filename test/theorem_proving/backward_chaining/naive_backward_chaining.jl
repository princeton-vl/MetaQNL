@testset "Backward Chaining 1" begin
    sent_1 = Sentence("wif kiki dax blicket lug \$MAPS_TO\$ RED BLUE RED GREEN")
    sent_2 = Sentence("dax fep \$MAPS_TO\$ RED RED RED")

    rule_1 = Rule(Sentence[], sent_1)
    rule_2 = Rule(Sentence[], sent_2)
    rule_3 = Rule([sent_1], sent_2)

    prover = NaiveBackwardChaining([rule_1, rule_2, rule_3])
    prover(Sentence[], sent_2)

    let rules = [
            Rule([sent"[X] $neighborOf$ [Y]"], sent"[Y] $neighborOf$ [X]"),
            Rule(
                [sent"[X] $locatedIn$ [Z]", sent"[Z] $locatedIn$ [Y]"],
                sent"[X] $locatedIn$ [Y]",
            ),
        ]
        prover = NaiveBackwardChaining(rules)
        assumptions = [
            sent"saudi_arabia $locatedIn$ western_asia",
            sent"western_asia $locatedIn$ asia",
        ]
        goal = sent"saudi_arabia $locatedIn$ asia"
        @test !isempty(prover(assumptions, goal))
    end

    let rules = [
            Rule([sent"[X] $neighborOf$ [Y]"], sent"[Y] $neighborOf$ [X]"),
            Rule(
                [sent"[X] $locatedIn$ [Z]", sent"[Z] $locatedIn$ [Y]"],
                sent"[X] $locatedIn$ [Y]",
            ),
            Rule(
                [sent"[X] $neighborOf$ [Z]", sent"[Z] $locatedIn$ [Y]"],
                sent"[X] $locatedIn$ [Y]",
            ),
        ]
        prover = NaiveBackwardChaining(rules, fill(0.2, length(rules)))
        assumptions = [sent"qatar $locatedIn$ asia", sent"saudi_arabia $neighborOf$ qatar"]
        goal = sent"saudi_arabia $locatedIn$ asia"
        @test !isempty(prover(assumptions, goal))
    end
end


@testset "Backward Chaining 2" begin
    rule = Rule([sent"[A] $MAPS_TO$ [B]"], sent"[A] left $MAPS_TO$ I_TURN_LEFT [B]")
    prover = NaiveBackwardChaining([rule], [0.15])
    prover(Sentence[], sent"run left $MAPS_TO$ I_TURN_LEFT I_RUN", true)
end
