using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CSwitch
using CImGui.CSyntax.CStatic

using ImPlot

clear(buffer::IOBuffer) = (truncate(buffer, 0); seekstart(buffer))
include("gui_elements/gui_utils.jl")
include("gui_elements/property_inspection_window.jl")
include("gui_elements/logging_console_window.jl")
include("gui_elements/main_menu_character_window.jl")
include("gui_elements/file_dir_selector_window.jl")
include("gui_elements/main_graph_window.jl")
include("gui_elements/detail_graph_window.jl")

# let 
# show_log_window 				= false
# show_inspector_window 	= false
# show_graph_window				= true
# show_graph_config_window		= false

# column_mask						= fill(true, 8) # length(_data_columns) = 8
# graph_window_seconds			= Cint(30)
# graph_padding					= Cint(30)
# graph_smoothing					= Cint(40) #number of processor samples to use for the exponential mean.
# sample_freq						= Cfloat(0.1)
# enable_gaussian_smoothing       = true
# gaussian_gamma					= Cint(5)

# proc_window_seconds				= Cint(13)
# ema_wilder						= true

# global function ui(logger, parser, processor, settings)
function ui(logger, parser, processor, settings)

	processor.process = sma_process(settings.proc_averaging_window_s, true)
	processor.delay = settings.proc_sampling_freq

	settings.proc_averaging_window_s <= 0 && (settings.proc_averaging_window_s = Cint(1))

	settings.show_log_window 			&& @c ShowLogWindow(&settings.show_log_window, logger)
	settings.show_inspector_window 		&& @c ShowPropertyInspectorWindow(&settings.show_inspector_window, parser, processor)
	settings.show_graph_window 			&& @c ShowMainGraphWindow(&settings.show_graph_window, processor, settings)
	settings.show_graph_detail_window 	&& @c ShowDetailGraphWindow(&settings.show_graph_detail_window, parser, processor, settings)

	check_base_folders(parser)

	if CImGui.BeginMainMenuBar()
		if CImGui.BeginMenu("menu")
				# CImGui.Button("print Parser Data") && println(stdout, last(parser.data, 10))
				@c CImGui.MenuItem("Show Log", C_NULL, &settings.show_log_window)
				@c CImGui.MenuItem("Show Property Inspector", C_NULL, &settings.show_inspector_window)
				@c CImGui.MenuItem("Show Graph Window", C_NULL, &settings.show_graph_window)
				@c CImGui.MenuItem("Show Config Window", C_NULL, &settings.show_graph_config_window)
			CImGui.EndMenu()
		end
		CImGui.Separator();

		color_parser = isrunning(parser) ? Cfloat[0.0, 0.5, 0.1, 0.8] : Cfloat[0.5, 0.5, 0.1, 0.8]
		parser_text = isrunning(parser) ? "Stop Parsing" : "Start Parsing"
		CImGui.PushStyleColor(CImGui.ImGuiCol_Button, color_parser)
		if CImGui.Button("$parser_text")
			isrunning(parser) ? stop_parsing!(parser) : (@async start_parsing!(parser))
		end	
		if !isrunning(processor)
			CImGui.PushStyleColor(CImGui.ImGuiCol_Button, [0.5, 0.5, 0.1, 0.8])
			if CImGui.Button("Processor stopped; Restart")
				@async live_process!(processor; max_entries=settings.proc_max_entries, max_history_seconds=settings.proc_max_history_s)
			end
			CImGui.PopStyleColor();
		end
		CImGui.PopStyleColor();

		CImGui.Separator();

		ListCharacterButtons(parser)
	end

	if settings.show_graph_config_window
		@c CImGui.Begin("Config", &settings.show_graph_config_window, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
			@c CImGui.DragInt("Graph Time Span (sec)", 		&settings.graph_window_s, 1.0, 30, 120, "%d")
			@c CImGui.DragInt("Graph Padding (sec)", 		&settings.graph_padding_s, 1.0, 5, 30, "%d")
			@c CImGui.Checkbox("Wilder Weigthing (EMA)", 	&settings.graph_use_ema_wilder_weights)
			@c CImGui.Checkbox("Gaussian Smoothing (CPU intensive)", &settings.graph_gauss_smoothing_enable)
			@c CImGui.DragInt("Gaussian Gamma", 			&settings.graph_gauss_smoothing_gamma, 1.0, 1, 20, "%d")
			@c CImGui.DragInt("Smoothing Samples", 			&settings.graph_smoothing_samples, 1.0, 1, 120, "%d")

			@c CImGui.DragFloat("Sample Frequency",			&settings.proc_sampling_freq, 0.1, 0.1, 1.0, "%.1f")
			CImGui.Text("Smoothing with a $(settings.graph_smoothing_samples*settings.proc_sampling_freq) seconds EMA")

			@c CImGui.InputInt("SMA time window seconds", &settings.proc_averaging_window_s)
			CImGui.Dummy(10,20)
			CImGui.Text("Select which data to track")
			for i=1:length(settings.graph_column_mask)
				CImGui.PushID(i)
				CImGui.Checkbox("$(string(processor.columns[i]))", Ref(settings.graph_column_mask, i))
				colr = series_colors[processor.columns[i]]
				CImGui.SameLine(160); CImGui.ColorEdit4("", colr)
				CImGui.PopID()
			end
		CImGui.End()
	end

end
# end #let