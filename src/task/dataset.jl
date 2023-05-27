"""
A dataset contains a sequence of data examples.

# Fields
* `name::String`: the name of the dataset
* `split::Symbol`: `:train`, `:val`, `:test`, etc.
* `examples::Vector{Example}`: data examples
"""
struct Dataset
    name::String
    split::Symbol
    examples::Vector{Example}
end

function Base.iterate(ds::Dataset)
    if length(ds) == 0
        return nothing
    end
    return ds[1], 2
end

function Base.iterate(ds::Dataset, idx)
    if length(ds) < idx
        return nothing
    end
    return ds[idx], idx + 1
end

function Base.firstindex(::Dataset)
    return 1
end

function Base.lastindex(ds::Dataset)
    return length(ds)
end

function Base.eltype(::Type{<:Dataset})
    return Example
end

function Base.keys(ds::Dataset)
    return keys(1:length(ds))
end

function Base.show(io::IO, ds::Dataset)
    print(io, "$(typeof(ds))($(ds.name), $(ds.split), $(length(ds)))")
end

function Base.length(ds::Dataset)
    return length(ds.examples)
end

function Base.getindex(ds::Dataset, idx::Integer)
    return ds.examples[idx]
end

function Base.getindex(ds::Dataset, slice::AbstractRange)
    return Dataset(ds.name, ds.split, ds.examples[slice])
end

"""
    subsample(ds::Dataset, n::Int)::Dataset

Subsample `n` examples from `ds`, or return `ds` itself if `length(ds) <= n`.
"""
function subsample(ds::Dataset, n::Int)::Dataset
    if n >= length(ds)
        return ds
    else
        return Dataset(ds.name, ds.split, shuffle(ds.examples)[1:n])
    end
end

"""
A prediction consists of a label and a substitution.
"""
struct Prediction
    substitution::Substitution
    proof::Union{Proof,Nothing}

    function Prediction(subst = Substitution(), proof = nothing)
        return new(subst, proof)
    end
end

function Base.:(==)(pred_1::Prediction, pred_2::Prediction)
    return pred_1.substitution == pred_2.substitution && pred_1.proof == pred_2.proof
end

function Base.hash(pred::Prediction, h::UInt)::UInt
    h = hash(pred.substitution, h)
    return hash(pred.proof, h)
end

function evaluate(ds::Dataset, all_preds::AbstractVector{<:AbstractVector{<:Prediction}})
    # Some generic evaluation metrics.
    # May be different from the metrics for specific tasks.
    @assert length(ds) == length(all_preds)
    acc = 0.0

    for (ex, preds) in zip(ds, all_preds)
        if ex.label == PROVABLE
            gt_substs = Set(ex.substitutions)
            pred_substs = Set(p.substitution for p in preds)
            @assert !isempty(ex.substitutions)
            if !isempty(preds) && preds[begin].substitution == ex.substitutions[begin]
                acc += 1
            end
        else
            @assert ex.label == UNPROVABLE
            if isempty(preds)
                acc += 1
            end
        end
    end

    acc /= length(ds)

    return Dict(
        "accuracy" => acc,
    )
end

export Dataset, subsample, KGCDataset, Prediction, evaluate
