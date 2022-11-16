using JSON

Base.@kwdef mutable struct Settings
	show_log_window::Bool 		   		= false
	show_inspector_window::Bool    		= false
	show_graph_window::Bool		   		= true
	show_graph_config_window::Bool 		= false
	show_graph_detail_window::Bool		= true
	show_simulated_character::Bool		= true

	proc_averaging_window_s::Int32		= 20

	graph_column_mask::Vector{Bool}		= [true, true, false, false, false, false, false, false, false] #dmgin, dmgout, logiin, logiout, captrans, caprec, capdmgout, capdmgin, mined
	graph_window_s::Int32				= 20
	graph_padding_s::Int32				= 5
	graph_smoothing_delay_s::Float32	= 100/60 # assuming 60 FPS
	graph_smoothing_samples::Int32		= 100  # 4 second smoothing window at 0.1 sample frequency.
	graph_use_ema_wilder_weights::Bool	= false
	graph_gauss_smoothing_enable::Bool 	= true # Given that by default we keep the time window short (30 sec) it should not be too impactful. 
	graph_gauss_smoothing_gamma::Int32 	= 5
	graph_manual_edit::Bool				= false
	graph_min_max_y::Int32				= 49

	graph_show_primary_tresh::Bool		= false
	graph_primary_tresh::Float64		= 10
	graph_show_secondary_tresh::Bool	= false
	graph_secondary_tresh::Float64		= 15
	graph_show_shade::Bool				= true

	parser_delay::Float64				= 0.5
	parser_max_entries::Int32			= 3000
	parser_max_history_s::Int32			= 60*3

end

function load_settings()
	basedir = game_basedir()
	setting_file = joinpath(basedir, "JELD_settings.json")
	settings = Settings() #load a default skeleton
	if isfile(setting_file)
		settdict = JSON.parsefile(setting_file; inttype=Int32)
		for key in keys(settdict)
			symkey = Symbol(key)
			hasfield(Settings, symkey) || continue
			val = convert(fieldtype(Settings, symkey), settdict[key])
			setfield!(settings, symkey, val)
		end
		@info "Loaded settings from $setting_file."
	else
		@warn "Setting file not found, loading default values."
	end
	settings
end

function save_settings(settings)
	basedir = game_basedir()
	file_location = joinpath(basedir, "JELD_settings.json")
	if isvalidfolder(basedir)
		sett_dict = Dict{String, Any}()
		for key in propertynames(settings)
			strkey = string(key)
			sett_dict[strkey] = getproperty(settings, key)
		end
		try
			open(file_location, "w") do f
				JSON.print(f, sett_dict)
			end
		catch e
			@error "Failed to save settings" err=(e, catch_backtrace())
		end
	else
		@warn "Could not determine the game base directory. Settings not saved."
	end
end

