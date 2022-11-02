module JlEVELiveDPS


using Pkg

try
	using Logging
	include("parser.jl")
	include("processor.jl")
	include("renderer.jl")
	include("data_handling.jl")
	include("gui.jl")
catch
	Pkg.instantiate(; io=devnull)
	using Logging
	include("parser.jl")
	include("processor.jl")
	include("renderer.jl")
	include("data_handling.jl")
	include("gui.jl")
end

const MAX_TIME_WINDOW_SECONDS	= 60*5
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

	parser = Parser()
	processor = Processor(parser, _data_columns, 0.1)
	@async live_process!(processor; max_history_seconds=MAX_TIME_WINDOW_SECONDS)

	populate_characters!(parser)

	# sim_char1 = SimulatedCharacter("Franco Battiato")
	# push!(parser.chars, sim_char1)

	destructor = () -> begin
		unwatch_folder(parser.log_directory)
		isrunning(processor) && stop_processing!(processor)
		isrunning(parser) && stop_parsing!(parser)
		isnothing(parser.active_character) || (isrunning(parser.active_character) && stop_reading!(parser.active_character))
	end

	renderloop(window, ctx, ctxp, clearcolor, ()->ui(logger, parser, processor), destructor)
end

if abspath(PROGRAM_FILE) == @__FILE__
	real_main()
end

end # module JlEVELiveDPS
