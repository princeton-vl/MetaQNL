@testset "Ground truth rules of MiniSCAN" begin
    gt_rules = [
        Rule(Sentence[], sent"dax $MAPS_TO$ RED"),
        Rule(Sentence[], sent"lug $MAPS_TO$ BLUE"),
        Rule(Sentence[], sent"wif $MAPS_TO$ GREEN"),
        Rule(Sentence[], sent"zup $MAPS_TO$ YELLOW"),
        Rule([sent"[A] $MAPS_TO$ [B]"], sent"[A] fep $MAPS_TO$ [B] [B] [B]"),
        Rule(
            [sent"[A] $MAPS_TO$ [B]", sent"[C] $MAPS_TO$ [D]"],
            sent"[A] kiki [C] $MAPS_TO$ [D] [B]",
        ),
        Rule(
            [sent"[A] $MAPS_TO$ [B]", sent"[C] $MAPS_TO$ [D]"],
            sent"[A] blicket [C] $MAPS_TO$ [B] [D] [B]",
        ),
    ]
    model = ReasoningModel(NaiveBackwardChaining, gt_rules)
    ds = load_mini_scan()[:test]
    preds = predict(model, ds)
    @test evaluate(ds, preds)["accuracy"] == 1
end
