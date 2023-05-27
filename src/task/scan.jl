import LibGit2

"""
    load_mini_scan()::Dict{Symbol,Dataset}
Load the [MiniSCAN](https://arxiv.org/abs/1901.04587) dataset.

Return a Dict from `:train` or `:test` to the corresponding data split.
"""
function load_mini_scan()::Dict{Symbol,Dataset}
    @info "Loading MiniSCAN..."

    artificat_toml = "Artifacts.toml"
    h = artifact_hash("MiniSCAN", artificat_toml)
    if h === nothing || !artifact_exists(h)
        train = Dict(
            "dax" => "RED",
            "lug" => "BLUE",
            "wif" => "GREEN",
            "zup" => "YELLOW",
            "dax fep" => "RED RED RED",
            "lug fep" => "BLUE BLUE BLUE",
            "wif blicket dax" => "GREEN RED GREEN",
            "lug blicket wif" => "BLUE GREEN BLUE",
            "dax kiki lug" => "BLUE RED",
            "lug kiki wif" => "GREEN BLUE",
            "lug fep kiki wif" => "GREEN BLUE BLUE BLUE",
            "lug kiki wif fep" => "GREEN GREEN GREEN BLUE",
            "wif kiki dax blicket lug" => "RED BLUE RED GREEN",
            "wif blicket dax kiki lug" => "BLUE GREEN RED GREEN",
        )
        test = Dict(
            "zup fep" => "YELLOW YELLOW YELLOW",
            "zup blicket lug" => "YELLOW BLUE YELLOW",
            "zup kiki dax" => "RED YELLOW",
            "zup fep kiki lug" => "BLUE YELLOW YELLOW YELLOW",
            "wif kiki zup fep" => "YELLOW YELLOW YELLOW GREEN",
            "lug kiki wif blicket zup" => "GREEN YELLOW GREEN BLUE",
            "zup blicket wif kiki dax fep" => "RED RED RED YELLOW GREEN YELLOW",
            "zup blicket zup kiki zup fep" => "YELLOW YELLOW YELLOW YELLOW YELLOW YELLOW",
            "dax blicket zup" => "RED YELLOW RED",
            "wif kiki zup" => "YELLOW GREEN",
        )
        h = create_artifact() do dir
            open(joinpath(dir, "train.json"), "w") do oup
                JSON3.write(oup, train)
            end
            open(joinpath(dir, "test.json"), "w") do oup
                JSON3.write(oup, test)
            end
        end
        bind_artifact!(artificat_toml, "MiniSCAN", h, force = true)
    end
    datapath = artifact_path(h)

    function construct_mini_scan_example(k, v)
        # E.g., k = "dax fep", v = "RED RED RED"
        goal = Sentence("$(string(k)) \$MAPS_TO\$ [X]")
        subst = Substitution("X" => v)
        return Example(Sentence[], goal, PROVABLE, [subst])
    end

    path_train = joinpath(datapath, "train.json")
    @info "Training data: $path_train"
    examples_train = [
        construct_mini_scan_example(k, v) for (k, v) in JSON3.read(read(path_train, String))
    ]

    path_test = joinpath(datapath, "test.json")
    @info "Test data: $path_test"
    examples_test = [
        construct_mini_scan_example(k, v) for (k, v) in JSON3.read(read(path_test, String))
    ]

    name = "MiniSCAN"
    return Dict(
        :train => Dataset(name, :train, examples_train),
        :test => Dataset(name, :test, examples_test),
    )
end


"""
    load_scan(data_split::String)::Dict{Symbol,Dataset}
Load the [SCAN](https://github.com/brendenlake/SCAN) dataset.

Return a Dict from `:train` or `:test` to the corresponding data split.
"""
function load_scan(
    data_split::String,
    num_train::Union{Int,Nothing} = nothing,
)::Dict{Symbol,Dataset}
    @info "Loading SCAN ($data_split)..."

    artificat_toml = "Artifacts.toml"
    h = artifact_hash("SCAN", artificat_toml)
    if h === nothing || !artifact_exists(h)
        h = create_artifact() do dir
            @info "Downloading SCAN..."
            repo = LibGit2.clone("https://github.com/brendenlake/SCAN", dir)
            LibGit2.checkout!(repo, "c4b756cbc010d75c912f16c42c8f15dc6b7e6c8f")
        end
        bind_artifact!(artificat_toml, "SCAN", h, force = true)
    end
    datapath = artifact_path(h)

    function construct_scan_example(line, is_train)::Example
        # IN: jump after turn left OUT: I_TURN_LEFT I_JUMP
        m = match(r"^IN: (.+?) OUT: (.+)$", line)
        if is_train
            goal = Sentence("$(m[1]) \$MAPS_TO\$ $(m[2])")
            subst = Substitution()
        else
            goal = Sentence("$(m[1]) \$MAPS_TO\$ [X]")
            subst = Substitution("X" => m[2])
        end
        return Example(Sentence[], goal, PROVABLE, [subst])
    end

    if data_split == "simple"
        path_train = joinpath(datapath, "simple_split/tasks_train_simple.txt")
        path_test = joinpath(datapath, "simple_split/tasks_test_simple.txt")
    elseif data_split == "length"
        path_train = joinpath(datapath, "length_split/tasks_train_length.txt")
        path_test = joinpath(datapath, "length_split/tasks_test_length.txt")
    elseif data_split == "addprim_jump"
        path_train = joinpath(datapath, "add_prim_split/tasks_train_addprim_jump.txt")
        path_test = joinpath(datapath, "add_prim_split/tasks_test_addprim_jump.txt")
    elseif data_split == "addprim_turn_left"
        path_train = joinpath(datapath, "add_prim_split/tasks_train_addprim_turn_left.txt")
        path_test = joinpath(datapath, "add_prim_split/tasks_test_addprim_turn_left.txt")
    else
        error("Invalid split: $split")
    end

    @info "Training data: $path_train"
    examples_train =
        [construct_scan_example(line, true) for line in unique(readlines(path_train))]
    if num_train !== nothing
        sort!(
            examples_train,
            by = ex -> length(split(string(first(concrete_goals(ex))), " \$MAPS_TO\$ ")[1]),
        )
        examples_train = examples_train[1:num_train]
    end

    @info "Test data: $path_test"
    examples_test = [construct_scan_example(line, false) for line in eachline(path_test)]

    name = "SCAN"
    return Dict(
        :train => Dataset(name, :train, examples_train),
        :test => Dataset(name, :test, examples_test),
    )
end

"""
Rule proposer for MiniSCAN/SCAN

# Fields
* `compositional_filter::Bool`: whether to apply the filter based on  prior knowledge about compositional generalization
* `all_concrete_rules::Vector{Rule}`: concrete rules generated by the rule proposer
"""
struct SCANRuleProposer <: RuleProposer
    all_concrete_rules::Vector{Rule}
end

"""
    SCANRuleProposer(ds::Dataset, filter::Bool)

Create a rule proposer for MiniSCAN/SCAN.
"""
function SCANRuleProposer(ds::Dataset)
    return SCANRuleProposer(generate_concrete_rules(ds, 2))
end

function propose(rule_proposer::SCANRuleProposer, ::Dataset, ::Int)::Vector{Rule}
    return copy(rule_proposer.all_concrete_rules)
end

function generate_concrete_rules(ds, max_num_premises)
    # Return the set of all concrete rules instantiable in `ds` with no more than `max_num_premises` premises.
    sents = extract_all_concrete_sentences(ds)
    rules = Set{Rule}()

    for num_premises = 0:max_num_premises
        @info "Generating concrete rules with $num_premises premises..."
        @showprogress for premises in combinations(sents, num_premises)
            for conclusion in sents
                if !(conclusion in premises)
                    r = Rule(premises, conclusion)
                    if is_valid_composition(r)
                        push!(rules, r)
                    end
                end
            end
        end
    end

    @info "$(length(rules)) concrete rules generated"
    return collect(rules)
end

function extract_all_concrete_sentences(ds)
    # Return the set of all concrete sentences in `ds`.
    sents = Set{Sentence}()
    for example in ds
        union!(sents, concrete_goals(example))
        union!(sents, example.assumptions)
    end
    return collect(sents)
end

function Base.isvalid(rule_proposer::SCANRuleProposer, rule::Rule)
    return is_valid_composition(rule)
end

function is_valid_composition(rule::Rule)
    # The meaning of a long sequence depends on the meaning of its subsequences. 
    target = split(string(rule.conclusion), " \$MAPS_TO\$ ")[1]
    return all(
        occursin(split(string(p), " \$MAPS_TO\$ ")[1], target) for p in rule.premises
    )
end


export load_mini_scan, load_scan, SCANRuleProposer
