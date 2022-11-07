module JlEVELiveDPS


using Pkg

try
	using Logging
	include("settings.jl")
	include("parser.jl")
	include("processor.jl")
	include("renderer.jl")
	include("data_handling.jl")
	include("gui.jl")
catch
	Pkg.instantiate(; io=devnull)
	using Logging
	include("settings.jl")
	include("parser.jl")
	include("processor.jl")
	include("renderer.jl")
	include("data_handling.jl")
	include("gui.jl")
end

const _data_columns = [
	:DamageIn,
	:DamageOut,
	:LogisticsIn,
	:LogisticsOut,
	:CapTransfered,
	:CapReceived,
	:CapDamageDone,
	:CapDamageReceived
]

const series_labels = Dict(
	:DamageIn 			=> "DpsIn",
	:DamageOut 			=> "DpsOut",
	:LogisticsIn 		=> "LogiIn",
	:LogisticsOut 		=> "LogiOut",
	:CapTransfered 		=> "CapTrans",
	:CapReceived 		=> "CapReceived",
	:CapDamageDone 		=> "CapDmgOut",
	:CapDamageReceived 	=> "CapDmgIn"
)

function julia_main()::Cint
    try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function real_main()

	logger = ImGuiLogger()
	global_logger(logger)
	window, ctx, ctxp = init_renderer(1000, 700, "jlEVELiveDPS")
	clearcolor = Cfloat[0.15, 0.15, 0.15, 1.00]


	settings = load_settings()
	parser = Parser(;delay=settings.parser_delay, max_entries=settings.parser_max_entries, max_history=settings.parser_max_history_s)
	processor = Processor(parser, _data_columns, settings.proc_sampling_freq)
	@async live_process!(processor; max_entries=settings.proc_max_entries, max_history_seconds=settings.proc_max_history_s)

	populate_characters!(parser)

	sim_char1 = SimulatedCharacter("Franco Battiato")
	push!(parser.chars, sim_char1)

	destructor = () -> begin
		save_settings(settings)
		unwatch_folder(parser.log_directory)
		isrunning(processor) && stop_processing!(processor)
		isrunning(parser) && stop_parsing!(parser)
		isnothing(parser.active_character) || (isrunning(parser.active_character) && stop_reading!(parser.active_character))
	end

	renderloop(window, ctx, ctxp, clearcolor, ()->ui(logger, parser, processor, settings), destructor)
end

if abspath(PROGRAM_FILE) == @__FILE__
	real_main()
end

end # module JlEVELiveDPS
