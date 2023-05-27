import ZipFile
using ParserCombinator: parse_one, @p_str, @E_str, Delayed, Eos
using Combinatorics: combinations
using Downloads: download
using SHA: sha256

"""
    load_rule_taker(train_split, val_split, test_split)::Dict{Symbol,Dataset}

Load the [RuleTaker](https://allenai.org/data/ruletaker) dataset.

Return a Dict from `:train`, `:val`, or `:test` to the corresponding split.
"""
function load_rule_taker(
    train_split::Union{String,Nothing},
    val_split::Union{String,Nothing},
    test_split::Union{String,Nothing},
    num_train::Union{Int,Nothing} = nothing,
)::Dict{Symbol,Dataset}
    @info "Loading RuleTaker (OWA)..."

    artificat_toml = "Artifacts.toml"
    h = artifact_hash("RuleTaker", artificat_toml)
    if h === nothing || !artifact_exists(h)
        h = create_artifact() do dir
            @info "Downloading RuleTaker..."
            zip_file = joinpath(dir, "RuleTaker.zip")
            bar = Progress(214649149, 1)
            download(
                "https://aristo-data-public.s3.amazonaws.com/proofwriter/proofwriter-dataset-V2020.12.2.zip",
                zip_file,
                progress = (_, now) -> update!(bar, now),
            )
            signature = bytes2hex(open(sha256, zip_file))
            if signature !=
               "fbe79e1ed7db57d9e40a836dd5fcd892993609bfbc2ea03b08633080ec50e93c"
                @warn "Incorrect SHA256 signature. Proceed at your own discretion."
            end
            rd = ZipFile.Reader(zip_file)
            for f in rd.files
                if match(
                    r"^proofwriter-dataset-V2020.12.2/OWA/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+.jsonl$",
                    f.name,
                ) === nothing
                    continue
                end
                dst_name = split(f.name, "/OWA/")[2]
                dst_path = joinpath(dir, dst_name)
                mkpath(splitdir(dst_path)[1])
                open(dst_path, "w") do oup
                    write(oup, read(f, String))
                end
            end
            close(rd)
            rm(zip_file)
        end
        bind_artifact!(artificat_toml, "RuleTaker", h, force = true)
    end
    datapath = artifact_path(h)

    name = "RuleTaker"
    ds = Dict{Symbol,Dataset}()

    if train_split !== nothing
        path_train = joinpath(datapath, "$train_split/meta-train.jsonl")
        @info "Training data: $path_train"
        examples_train = load_rule_taker_split(path_train, true, num_train)
        ds[:train] = Dataset(name, :train, examples_train)
    end

    if val_split !== nothing
        path_val = joinpath(datapath, "$val_split/meta-dev.jsonl")
        @info "Validation data: $path_val"
        examples_val = load_rule_taker_split(path_val, false, nothing)
        ds[:val] = Dataset(name, :val, examples_val)
    end

    if test_split !== nothing
        path_test = joinpath(datapath, "$test_split/meta-test.jsonl")
        @info "Test data: $path_test"
        examples_test = load_rule_taker_split(path_test, false, nothing)
        ds[:test] = Dataset(name, :test, examples_test)
    end

    return ds
end

function load_rule_taker_split(path, is_train, max_num)
    examples = Example[]
    lines = readlines(path)
    shuffle!(lines)
    cnt = 0

    @showprogress for line in lines
        data = JSON3.read(line)
        assumptions = extract_assumptions(data)

        for question in values(data["questions"])
            goal = extract_goal(question)

            if question["answer"] == true
                proofs = extract_proofs(data, question, false)
                depth = question["QDep"]
                @assert depth !== nothing
                push!(
                    examples,
                    Example(
                        assumptions,
                        goal,
                        PROVABLE,
                        [Substitution()],
                        false,
                        Dict(:proofs => proofs, :depth => depth),
                    ),
                )
                push!(
                    examples,
                    Example(
                        assumptions,
                        negate(goal),
                        UNPROVABLE,
                        [Substitution()],
                        false,
                        Dict(:proofs => Proof[], :depth => depth),
                    ),
                )
            elseif question["answer"] == false
                proofs = extract_proofs(data, question, true)
                depth = question["QDep"]
                @assert depth !== nothing
                push!(
                    examples,
                    Example(
                        assumptions,
                        negate(goal),
                        PROVABLE,
                        [Substitution()],
                        false,
                        Dict(:proofs => proofs, :depth => depth),
                    ),
                )
                push!(
                    examples,
                    Example(
                        assumptions,
                        goal,
                        UNPROVABLE,
                        [Substitution()],
                        false,
                        Dict(:proofs => Proof[], :depth => depth),
                    ),
                )
            else
                @assert question["answer"] === "Unknown"
                proofs = Proof[]
                push!(
                    examples,
                    Example(
                        assumptions,
                        goal,
                        UNPROVABLE,
                        [Substitution()],
                        false,
                        Dict(:proofs => proofs, :depth => nothing),
                    ),
                )
                push!(
                    examples,
                    Example(
                        assumptions,
                        negate(goal),
                        UNPROVABLE,
                        [Substitution()],
                        false,
                        Dict(:proofs => proofs, :depth => nothing),
                    ),
                )
            end

            cnt += 1
            if max_num !== nothing && cnt >= max_num
                return examples
            end
        end
    end

    return examples
end

function negate(sent::AbstractSentence)::Sentence
    if sent[1] == symbol"TRUE"
        return symbol"FALSE" * sent[2:end]
    else
        @assert sent[1] == symbol"FALSE"
        return symbol"TRUE" * sent[2:end]
    end
end

function create_positive(text::AbstractString)::Sentence
    return symbol"TRUE" * Sentence(preprocess_rule_taker(text))
end

function create_negative(text::AbstractString)::Sentence
    return symbol"FALSE" * Sentence(preprocess_rule_taker(text))
end

function preprocess_rule_taker(text::AbstractString)::String
    @assert endswith(text, '.')
    text = lowercase(text[1:end-1])
    text = replace(text, "," => " ,")
    text = lemmatize(text)
    return text
end

function lemmatize(text)
    # Can use tokenizer.jl, but this is much faster.
    text = replace(text, " likes" => " like")
    text = replace(text, " chases" => " chase")
    text = replace(text, " eats" => " eat")
    text = replace(text, " sees" => " see")
    text = replace(text, " visits" => " visit")
    text = replace(text, " needs" => " need")
    text = replace(text, " includes" => " include")
    text = replace(text, " runs" => " run")
    text = replace(text, " does" => " do")
    text = replace(text, " has" => " have")
    text = replace(text, " is" => " be")
    text = replace(text, " are" => " be")
    return text
end

function extract_assumptions(data)::Vector{Sentence}
    assumptions = Sentence[]
    for (name, triple) in data["triples"]
        sent = create_positive(triple["text"])
        push!(assumptions, sent)
    end
    for (name, rule) in data["rules"]
        sent = create_positive(rule["text"])
        push!(assumptions, sent)
    end
    return unique(assumptions)
end

function extract_goal(question)::Sentence
    return create_positive(question["question"])
end

const triple_matcher = p"triple\d+"
const rule_matcher = p"rule\d+"
const conclusion_matcher = p"int\d+"
const single_condition_matcher = Delayed()
const conditions_matcher =
    E"(" +
    (
        (single_condition_matcher & (E" "+single_condition_matcher)[0:end, :&]) >
        (x, y) -> [[x]; y]
    ) +
    E")"
const rule_application_matcher =
    E"(" +
    conditions_matcher +
    E" -> (" +
    rule_matcher +
    E" % " +
    conclusion_matcher +
    E"))"
const single_condition_matcher.matcher = triple_matcher | rule_application_matcher
const proof_matcher = (triple_matcher | rule_application_matcher) + Eos()

function parse_proof(input::AbstractString)
    return parse_one(input, proof_matcher)
end

function extract_proofs(data, question, is_disproved)::Vector{Proof}
    proofs = Proof[]

    for raw_proof in question["proofsWithIntermediates"]
        parsed_proof = parse_proof(raw_proof["representation"])
        prf = build_proof(parsed_proof, data, raw_proof["intermediates"])

        if is_disproved
            if length(parsed_proof) == 3
                pos = create_positive(raw_proof["intermediates"][parsed_proof[3]]["text"])
            else
                pos = create_positive(data["triples"][parsed_proof[1]]["text"])
            end
            neg = create_negative(question["question"])
            rule = Rule([pos], neg)
            apply!(prf, rule)
        end

        push!(proofs, prf)
    end

    return proofs
end

function build_proof(parsed_proof, data, intermediates)
    len = length(parsed_proof)
    if len == 1
        let name = parsed_proof[1]
            return Proof(create_positive(data["triples"][name]["text"]))
        end
    end

    proof = Proof()
    premises = Sentence[]
    for pf in parsed_proof[1]
        subproof = build_proof(pf, data, intermediates)
        push!(premises, get_goal(subproof))
        merge!(proof, subproof)
    end

    name = parsed_proof[2]
    sent_synthetic = create_positive(data["rules"][name]["text"])
    get_or_create_vertex!(proof, sent_synthetic)
    push!(premises, sent_synthetic)
    conclusion = create_positive(intermediates[parsed_proof[3]]["text"])
    rule = Rule(unique(premises), conclusion)
    apply!(proof, rule)
    proof = trim(proof, conclusion)
    @assert isvalid(proof) && get_goal(proof) == conclusion
    return proof
end

struct RuleTakerRuleProposer <: RuleProposer end

function Base.isvalid(::RuleTakerRuleProposer, rule::Rule)
    return isvalid(rule)
end

function propose(::RuleTakerRuleProposer, ds::Dataset, n::Int)
    ex = ds[n]
    proofs = ex.metadata[:proofs]
    if isempty(proofs)
        return Rule[]
    else
        return get_rules(first(proofs))
    end
end


export load_rule_taker, negate, RuleTakerRuleProposer
