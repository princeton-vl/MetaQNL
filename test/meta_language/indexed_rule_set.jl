@testset "RuleTemplate" begin
    rule_1 = Rule(
        [sent"$TRUE$ china $in$ east asia", sent"$TRUE$ east asia $in$ asia"],
        sent"$TRUE$ china $in$ asia",
    )
    rule_2 = Rule(
        [
            sent"$TRUE$ dhjfshs $in$ lkjsdf sdfh",
            sent"$TRUE$ hello $in$ sdfkj sajf soppdsf sd",
        ],
        sent"$TRUE$ cc cc $in$ a",
    )
    @test RuleTemplate(rule_1) == RuleTemplate(rule_2)
end
