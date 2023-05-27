using Coverage

coverage = process_folder()
covered_lines, total_lines = get_summary(coverage)
@info "Total lines: $total_lines"
@info "Covered lines: $covered_lines"
# @show get_summary(process_file(joinpath("src", "MyPkg.jl")))
@info "Percentage covered: $(covered_lines / total_lines)"
