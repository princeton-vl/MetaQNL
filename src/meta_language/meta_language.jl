@reexport module MetaLanguage

using Bijections: Bijection
using DataStructures: Queue, enqueue!, dequeue!, counter, inc!, dec!
using LightGraphs:
    SimpleDiGraph,
    vertices,
    add_vertex!,
    add_edge!,
    nv,
    inneighbors,
    outneighbors,
    topological_sort_by_dfs,
    is_cyclic,
    indegree,
    outdegree,
    has_path,
    gdistances

include("vocab.jl")
include("token.jl")
include("sentence.jl")
include("rule.jl")
include("substitution.jl")
include("template.jl")
include("unification.jl")
include("matching.jl")
include("anti_unification.jl")
include("indexed_rule_set.jl")
include("proof.jl")

end
