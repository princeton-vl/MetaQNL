import Tar
using DataStructures: DefaultOrderedDict

function load_sigmorphon2018(lang::String, val_split::String, test_split::String, copy::Int)
    name = "SIGMORPHON 2018"
    @info "Loading $name..."

    artificat_toml = "Artifacts.toml"
    h = artifact_hash(name, artificat_toml)
    if h === nothing || !artifact_exists(h)
        h = create_artifact() do dir
            @info "Downloading $name..."
            tar_file = joinpath(dir, "morph_data.tar.gz")
            download(
                "https://recomb.s3.us-east-2.amazonaws.com/morph_data.tar.gz",
                tar_file,
            )
            signature = bytes2hex(open(sha256, tar_file))
            if signature !=
               "e2541638b57161724789758bee07b56cbc2128765404c69f65fe77346110af17"
                @warn "Incorrect SHA256 signature. Proceed at your own discretion."
            end
            Tar.extract(`gzip -cd $tar_file`, joinpath(dir, name))
            rm(tar_file)
        end
        bind_artifact!(artificat_toml, name, h, force = true)
    end
    datapath = artifact_path(h)

    function split_chars(s)
        @assert !occursin(s, "-")
        # return replace(join(collect(s), ' '), "   " => " \$SPACE\$ ")
        return join(collect(replace(s, " " => "-")), ' ')
    end

    function construct_train_split(path)
        surface2lemmas = DefaultOrderedDict{String,Set{String}}(Set{String})
        surface2tags = DefaultOrderedDict{String,Set{String}}(Set{String})

        for line in eachline(path)
            lemma, surface, tags = split(line, '\t')
            push!(surface2lemmas[surface], lemma)
            union!(surface2tags[surface], split(tags, ';'))
        end

        examples = Example[]

        for (surface, lemmas) in surface2lemmas
            @assert length(lemmas) == 1
            lemma = first(lemmas)
            tags = surface2tags[surface]
            assumptions = [Sentence(split_chars(surface))]
            push!(
                examples,
                Example(
                    assumptions,
                    sent"$LEMMA$ [X]",
                    PROVABLE,
                    [Substitution("X" => split_chars(lemma))],
                    true,
                ),
            )
            push!(
                examples,
                Example(
                    assumptions,
                    sent"$TAG$ [X]",
                    PROVABLE,
                    [Substitution("X" => t) for t in tags],
                    true,
                ),
            )
        end

        return examples
    end

    function construct_eval_split(path)
        examples = Example[]

        for line in eachline(path)
            lemma, surface, tags = split(line, '\t')
            assumptions = [Sentence(split_chars(surface))]
            push!(
                examples,
                Example(
                    assumptions,
                    sent"$LEMMA$ [X]",
                    PROVABLE,
                    [Substitution("X" => split_chars(lemma))],
                    true,
                ),
            )
            push!(
                examples,
                Example(
                    assumptions,
                    sent"$TAG$ [X]",
                    PROVABLE,
                    [Substitution("X" => t) for t in split(tags, ';')],
                    true,
                ),
            )
        end

        return examples
    end

    path_train =
        joinpath(datapath, name, "data/SIGDataSet", lang, "train.hints-8.$copy.txt")
    @info "Training data: $path_train"
    examples_train = construct_train_split(path_train)

    path_val = joinpath(
        datapath,
        name,
        "data/SIGDataSet",
        lang,
        "val_$val_split.hints-8.$copy.txt",
    )
    @info "Validation data: $path_val"
    examples_val = construct_eval_split(path_val)

    path_test = joinpath(
        datapath,
        name,
        "data/SIGDataSet",
        lang,
        "test_$test_split.hints-8.$copy.txt",
    )
    @info "Testing data: $path_test"
    examples_test = construct_eval_split(path_test)

    return Dict(
        :train => Dataset(name, :train, examples_train),
        :val => Dataset(name, :val, examples_val),
        :test => Dataset(name, :test, examples_test),
    )
end


struct SigmorphonRuleProposer <: RuleProposer end

function propose(rule_proposer::SigmorphonRuleProposer, ds::Dataset, n::Int)
    ex = ds[n]
    @assert length(ex.assumptions) == 1
    surface = first(ex.assumptions)
    rules = Rule[]
    for g in concrete_goals(ex)
        push!(rules, Rule([surface], g))
    end
    return rules
end

function Base.isvalid(::SigmorphonRuleProposer, rule::Rule)
    return isvalid(rule)
end

export load_sigmorphon2018, SigmorphonRuleProposer
