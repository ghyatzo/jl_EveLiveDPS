using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CSwitch
using CImGui.CSyntax.CStatic

using ImPlot

clear(buffer::IOBuffer) = (truncate(buffer, 0); seekstart(buffer))
include("gui_elements/property_inspection_window.jl")
include("gui_elements/logging_console_window.jl")
include("gui_elements/main_menu_character_window.jl")
include("gui_elements/file_dir_selector_window.jl")
include("gui_elements/main_graph_window.jl")

let 
show_log_window 				= false
show_property_inspector_window 	= false
show_graph_window				= true
show_graph_config_window		= false

graph_window_seconds			= Cint(30)
graph_padding					= Cint(30)
graph_smoothing					= Cint(60) #number of processor samples to use for the exponential mean.
sample_freq						= Cfloat(0.1)
enable_gaussian_smoothing       = true
gaussian_gamma					= Cint(8)

column_mask						= fill(true, 8) # length(_data_columns) = 8
# processor_labels				= ["Simple Moving Avg", "Exponential Moving Avg", "SMA2 (std)", "SMA3 (mean)", "SMA4"] # sma, ema
# processor_kernels 				= [sma_process, ema_process, sma2_process, sma3_process, sma4_process]
selected_processor				= Cint(0)
proc_window_seconds				= Cint(17)
ema_wilder						= true

global function ui(logger, parser, processor)

	processor.process = sma_process(ema_wilder, proc_window_seconds, true)
	processor.delay = sample_freq

	proc_window_seconds <= 0 && (proc_window_seconds = Cint(1))
	# if selected_processor == 1 # EMA
	# 	processor.process = process(ema_wilder, proc_window_seconds, true)
	# else # SMA versions
	# 	processor.process = process(proc_window_seconds, true)
	# end

	show_log_window 				&& @c ShowLogWindow(&show_log_window, logger)
	show_property_inspector_window 	&& @c ShowPropertyInspectorWindow(&show_property_inspector_window, parser, processor)
	if show_graph_window 
		 @c ShowMainGraphWindow( &show_graph_window, 
				processor, graph_window_seconds, graph_padding, 
				graph_smoothing, ema_wilder, column_mask,
				enable_gaussian_smoothing, gaussian_gamma)
	end

	# force the existance of these folders. If both are missing or are invalid, don't bother with the overview folder
	# if there isn't the log one, which is more important.
	isvalidfolder(parser.log_directory) || CImGui.OpenPopup("Error##log")
	isvalidfolder(parser.log_directory) && !isvalidfolder(parser.overview_directory) && CImGui.OpenPopup("Error##overview")

	if CImGui.BeginPopupModal("Error##log", C_NULL,  CImGui.ImGuiWindowFlags_AlwaysAutoResize)
		CImGui.TextColored([1.0, 0.2, 0.0, 1.0], "ERROR:")
		CImGui.Text("The application needs a valid game log folder path.")
		CImGui.Dummy((10,10))
		CImGui.Text("Automatic detection failed. Please select it manually.")
		CImGui.Dummy((15,15))
		CImGui.Button("Select Log Folder") && CImGui.OpenPopup("Select Folder")

		SelectDirectoryModal("Select Folder", (path) -> begin
			update_log_directory!(parser, path)
		end)

		isvalidfolder(parser.log_directory) && CImGui.CloseCurrentPopup()
		CImGui.EndPopup()
	end
	if CImGui.BeginPopupModal("Error##overview", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
		CImGui.TextColored([1.0, 0.6, 0.3, 1.0], "WARNING:")
		CImGui.Text("The application needs a valid overview folder path\n\
			for automatic overview setting detection.")
		CImGui.Dummy((10,10))
		CImGui.Text("Automatic detection failed. Please select it manually.")
		CImGui.Dummy((15,15))
		CImGui.Button("Select Overview Folder") && CImGui.OpenPopup("Select Folder")

		SelectDirectoryModal("Select Folder", (path) -> begin
			update_overview_directory!(parser, path)
		end)

		isvalidfolder(parser.overview_directory) && CImGui.CloseCurrentPopup()
		CImGui.EndPopup()
	end

	if CImGui.BeginMainMenuBar()
		if CImGui.BeginMenu("menu")
				# CImGui.Button("print Parser Data") && println(stdout, last(parser.data, 10))
				@c CImGui.MenuItem("Show Log", C_NULL, &show_log_window)
				@c CImGui.MenuItem("Show Property Inspector", C_NULL, &show_property_inspector_window)
				@c CImGui.MenuItem("Show Graph Window", C_NULL, &show_graph_window)
				@c CImGui.MenuItem("Show Config Window", C_NULL, &show_graph_config_window)
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
				@async live_process!(processor; max_history_seconds=MAX_TIME_WINDOW_SECONDS)
			end
			CImGui.PopStyleColor();
		end
		CImGui.PopStyleColor();

		CImGui.Separator();

		ListCharacterButtons(parser)
	end

	if show_graph_config_window
		@c CImGui.Begin("Config", &show_graph_config_window)
			@c CImGui.DragInt("Graph Time Span (sec)", 		&graph_window_seconds, 1.0, 30, 120, "%d")
			@c CImGui.DragInt("Graph Padding (sec)", 		&graph_padding, 1.0, 5, 30, "%d")
			@c CImGui.Checkbox("Wilder Weigthing (EMA)", 	&ema_wilder)
			@c CImGui.Checkbox("Gaussian Smoothing (CPU intensive)", &enable_gaussian_smoothing)
			enable_gaussian_smoothing && @c CImGui.DragInt("Gaussian Gamma", &gaussian_gamma, 1.0, 1, 20, "%d")
			@c CImGui.DragInt("Smoothing Samples", 			&graph_smoothing, 1.0, 1, 120, "%d")
			@c CImGui.DragFloat("Sample Frequency",		&sample_freq, 0.1, 0.1, 1.0, "%f")
			CImGui.Text("Smoothing with a $(graph_smoothing*sample_freq) seconds EMA")
			# @c CImGui.Combo("Processor", 					&selected_processor, processor_labels, length(processor_labels))
			@c CImGui.InputInt("SMA time window seconds", &proc_window_seconds)
			CImGui.Dummy(10,20)
			CImGui.Text("Select which data to track")
			for i=1:length(column_mask)
				CImGui.PushID(i)
				CImGui.Checkbox("$(string(processor.columns[i]))", Ref(column_mask, i))
				CImGui.PopID()
			end
		CImGui.End()
	end

end
end #let