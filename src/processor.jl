# process the data from a dataframe, the processor, only ever reads data, never writes to it.
include("utils.jl")

mutable struct Processor
	process::Function

	data_ref::Ref{DataFrame}
	columns::Vector{Symbol}
	series::DataFrame #Time + length(columns) columns
	current_values::Dict # length(columns)

	max_history_s::Int32

	Processor(max_hist) = begin
		proc = new()
		proc.max_history_s = max_hist

		return proc
	end
end

function Processor(parser::Parser, columns::Vector{Symbol}, max_history_s=60*2)
	#check if all columns provided are valid
	@assert valid_columns(parser.data, columns)

	proc = Processor(max_history_s)
	link_data!(proc, parser.data, columns)
	return proc
end

function link_data!(proc::Processor, data::DataFrame, columns::Vector{Symbol})
	@assert valid_columns(data, columns)

	series = DataFrame([:Time => DateTime[], [col => Float64[] for col in columns]...])
	current_values = Dict()
	for col in columns
		current_values[col] = 0.0
	end
	current_values[:Time] = now()
	push!(series, current_values)

	proc.data_ref = Ref(data)
	proc.columns = columns
	proc.series = series
	proc.current_values = current_values
end
link_data!(proc, data, columns::Vector{T}) where T <: Union{String, Symbol} = link_data!(proc, data, Symbol.(columns))
link_data!(proc, data, column::T) where T <: Union{String, Symbol} = link_data!(proc, data, [column])

hasdata(proc::Processor) = begin
	maybe_undef = [:data_ref, :columns, :series, :current_values]
	defined_properties = isdefined.(Ref(proc), maybe_undef)
	if all(defined_properties)
		return true
	else
		@error " $(maybe_undef[findfirst(==(false), defined_properties)]) is not defined yet. cannot proceeed."
		return false
	end
end

function process_data!(proc)
	hasdata(proc) || (@error "you need to initialise all data first! use link_data!"; return)

	if size(proc.data_ref[], 1) >= 0
		cleanup!(proc.series, 5000, proc.max_history_s; live = true)

		for col in proc.columns
			proc.current_values[col] = proc.process(proc.data_ref[], col)
		end
		proc.current_values[:Time] = now()
		push!(proc.series, proc.current_values)
	end
end
