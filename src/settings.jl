using JSON

Base.@kwdef mutable struct Settings
	show_log_window::Bool 		   		= false
	show_inspector_window::Bool    		= false
	show_graph_window::Bool		   		= true
	show_graph_config_window::Bool 		= false

	proc_averaging_window_s::Int32		= 13
	proc_sampling_freq::Float32			= 0.1
	proc_max_history_s::Int32			= 60*3
	proc_max_entries::Int32				= 2000

	graph_column_mask::Vector{Bool}		= fill(true, 8)
	graph_window_s::Int32				= 30
	graph_padding_s::Int32				= 15
	graph_smoothing_samples::Int32		= 40
	graph_use_ema_wilder_weights::Bool	= true
	graph_gauss_smoothing_enable::Bool 	= true
	graph_gauss_smoothing_gamma::Int32 	= 5

	parser_delay::Float64				= 1.0
	parser_max_entries::Int32			= 5000
	parser_max_history_s::Int32			= 60*15 # 15 minutes

end

function load_settings()
	basedir = game_basedir()
	setting_file = joinpath(basedir, "JELD_settings.json")
	settings = Settings() #load a default skeleton
	if isfile(setting_file)
		settdict = JSON.parsefile(setting_file; inttype=Int32)
		if length(keys(settdict)) != length(fieldnames(Settings))
			@warn "Settings file appears to be either corrupted or missing some entries. Loading Defaults."
			return settings
		end
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

