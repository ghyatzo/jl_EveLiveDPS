# process the data from a dataframe, the processor, only ever reads data, never writes to it.
include("utils.jl")

mutable struct Processor
	process::Function
	delay::Float32
	run::Bool

	data_ref::Ref{DataFrame}
	columns::Vector{Symbol}
	series::DataFrame #Time + length(columns) columns
	current_values::Dict # length(columns)

	Processor(delay) = begin
		proc = new()
		proc.delay = delay
		proc.run = false

		return proc
	end
end

function Processor(parser::Parser, columns::Vector{Symbol}, delay = 0.1)
	#check if all columns provided are valid
	@assert valid_columns(parser.data, columns)

	proc = Processor(delay)
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

isrunning(proc::Processor) = getfield(proc, :run)
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

stop_processing!(proc::Processor) = setfield!(proc, :run, false)
function live_process!(proc::Processor; max_entries = 5000, max_history_seconds = MAX_TIME_WINDOW_SECONDS)
	isrunning(proc) && return

	hasdata(proc) || (@error "you need to initialise all data first! use link_data!"; return)

	setfield!(proc, :run, true)
	while isrunning(proc)
		try
			if size(proc.data_ref[], 1) > 2 

				# live = true, means that we keep entries not older than max_history_seconds from now()
				cleanup!(proc.series, max_entries, max_history_seconds; live = true)

				for col in proc.columns
					proc.current_values[col] = proc.process(proc.data_ref[], col)
				end
				proc.current_values[:Time] = now()
				push!(proc.series, proc.current_values)
			end
		catch err
			@error "An error occured while processing: Stopping" exception=(err, catch_backtrace())
			@error "$(err)"
			@error "$(stacktrace(catch_backtrace()))"
			break
		end
		sleep(proc.delay)
	end
	setfield!(proc, :run, false)
end

function set_process!(proc::Processor, process)
	was_running = isrunning(proc)
	was_running && stop_processing!(proc)

	proc.process = process
	was_running && @async live_process!(proc)
end
