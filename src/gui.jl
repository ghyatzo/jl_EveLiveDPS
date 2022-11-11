using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CSwitch
using CImGui.CSyntax.CStatic
using CImGui.LibCImGui.CImGuiPack_jll

using ImPlot

clear(buffer::IOBuffer) = (truncate(buffer, 0); seekstart(buffer))
CImGui.Text(text) = @ccall libcimgui.igText("%s"::Cstring; text::Cstring)::Cvoid #patch upstream bug

const GRAPH_WINDOW_MAX_S = 60
const GRAPH_WINDOW_MIN_S = 10
const GRAPH_PADDING_MAX_S = 20
const GRAPH_PADDING_MIN_S = 5
const GAUSSIAN_GAMMA_MAX = 50
const GAUSSIAN_GAMMA_MIN = 1

include("gui_elements/gui_utils.jl")
include("gui_elements/property_inspection_window.jl")
include("gui_elements/logging_console_window.jl")
include("gui_elements/main_menu_character_window.jl")
include("gui_elements/file_dir_selector_window.jl")
include("gui_elements/main_graph_window.jl")
include("gui_elements/detail_graph_window.jl")

function ui(logger, parser, processor, settings)

	framerate = unsafe_load(CImGui.GetIO().Framerate)

	settings.proc_averaging_window_s <= 0 && (settings.proc_averaging_window_s = Cint(1))
	processor.process = sma_process(settings.proc_averaging_window_s, true)

	proc_t = @elapsed process_data!(processor)
	# println(stderr, "it took $t seconds to process data")

	settings.show_log_window 			&& @c ShowLogWindow(&settings.show_log_window, logger)
	settings.show_inspector_window 		&& @c ShowPropertyInspectorWindow(&settings.show_inspector_window, parser, processor)
	settings.show_graph_window 			&& @c ShowMainGraphWindow(&settings.show_graph_window, processor, settings)
	settings.show_graph_detail_window 	&& @c ShowDetailGraphWindow(&settings.show_graph_detail_window, parser, processor, settings)

	@cstatic sim_char_loaded = false begin
		if settings.show_simulated_character && !sim_char_loaded
			sim_char = SimulatedCharacter("Simulated Character")
			push!(parser.chars, sim_char)
			sim_char_loaded = true
		end
		if !settings.show_simulated_character && sim_char_loaded
			sim_idx = findfirst(c -> isa(c, SimulatedCharacter), parser.chars)
			sim_char = parser.chars[sim_idx]
			remove_char!(sim_char, parser)
			sim_char_loaded = false
		end
	end #cstatic
	check_base_folders(parser)

	if CImGui.BeginMainMenuBar()
		if CImGui.BeginMenu("Menu")
				# CImGui.Button("print Parser Data") && println(stdout, last(parser.data, 10))
				@c CImGui.MenuItem("Show Log", C_NULL, &settings.show_log_window)
				@c CImGui.MenuItem("Show Property Inspector", C_NULL, &settings.show_inspector_window)
				@c CImGui.MenuItem("Show Graph Window", C_NULL, &settings.show_graph_window)
				@c CImGui.MenuItem("Show Details Window", C_NULL, &settings.show_graph_detail_window)
				@c CImGui.MenuItem("Show Config Window", C_NULL, &settings.show_graph_config_window)
				CImGui.Separator()
				@c CImGui.MenuItem("Show Simulated Character", C_NULL, &settings.show_simulated_character)
			CImGui.EndMenu()
		end
		CImGui.Separator();

		color_parser = isrunning(parser) ? Cfloat[0.0, 0.5, 0.1, 0.8] : Cfloat[0.5, 0.5, 0.1, 0.8]
		parser_text = isrunning(parser) ? "Stop Parsing" : "Start Parsing"
		CImGui.PushStyleColor(CImGui.ImGuiCol_Button, color_parser)
		if CImGui.Button("$parser_text")
			isrunning(parser) ? stop_parsing!(parser) : (@async start_parsing!(parser))
		end	
		CImGui.PopStyleColor();

		CImGui.Separator();

		ListCharacterButtons(parser)
	end

	if settings.show_graph_config_window
		@c CImGui.Begin("Config", &settings.show_graph_config_window, CImGui.ImGuiWindowFlags_AlwaysAutoResize | CImGui.ImGuiWindowFlags_NoDocking)
			@c CImGui.DragInt("Graph Time Span (s)", 	&settings.graph_window_s, 1.0, GRAPH_WINDOW_MIN_S, GRAPH_WINDOW_MAX_S, "%d")
			@c CImGui.DragInt("Graph Padding (s)", 		&settings.graph_padding_s, 1.0, GRAPH_PADDING_MIN_S, GRAPH_PADDING_MAX_S, "%d")
			
			@c CImGui.Checkbox("Manual Edit", &settings.graph_manual_edit);
			# let the graph window dictate how much we want to have a "big picture".
			!settings.graph_manual_edit && (settings.proc_averaging_window_s = settings.graph_window_s)
			@c CImGui.InputInt("SMA time window seconds", &settings.proc_averaging_window_s)
			
			!settings.graph_manual_edit && (settings.graph_smoothing_delay_s = convert(Cfloat, settings.proc_averaging_window_s * 0.05)) # take the 5% of the graph window as extra smoothing. 
			@c CImGui.DragFloat("Smoothing delay", &settings.graph_smoothing_delay_s, 0.1, 0.0, 5.0, "%.1f")

			settings.graph_smoothing_samples = iszero(settings.graph_smoothing_delay_s) ? 1 : ceil(Int32, settings.graph_smoothing_delay_s * framerate)
			CImGui.Text("Smoothing with $(settings.graph_smoothing_samples) samples")

			@c CImGui.DragInt("##gauss_drag", &settings.graph_gauss_smoothing_gamma, 1.0, GAUSSIAN_GAMMA_MIN, GAUSSIAN_GAMMA_MAX, "%d")
			CImGui.SameLine(); @c CImGui.Checkbox("Gaussian Smoothing", &settings.graph_gauss_smoothing_enable);


			CImGui.Dummy(10,20)
			CImGui.Text("Select which data to track")
			for i=1:length(settings.graph_column_mask)
				CImGui.PushID(i)
				CImGui.Checkbox("$(string(processor.columns[i]))", Ref(settings.graph_column_mask, i))

				colr = series_colors[processor.columns[i]]
				CImGui.SameLine(160); @c CImGui.ColorEdit4("", colr)

				CImGui.PopID()
			end
		CImGui.End()
	end

end