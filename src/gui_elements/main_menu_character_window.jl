##################### Characters #######################

function ListCharacterButtons(parser)
	sorted_chars = sortperm(parser.chars; by=(c)->c.session_start, rev=true)
	for n in sorted_chars
		char = parser.chars[n]
		CImGui.PushID(n)
		color = hascustomoverview(char) ? Cfloat[0.5, 0.5, 0.1, 0.8] : Cfloat[0.6, 0.1, 0.0, 0.8]
		color = isactive(char, parser) && isrunning(char) ? Cfloat[0.0, 0.5, 0.1, 0.8] : color
		
		CImGui.SameLine();
		CImGui.PushStyleColor(CImGui.ImGuiCol_Button, color)
		if CImGui.Button("$(char.name)")
			if isactive(char, parser) && isrunning(char)
				deactivate!(char, parser)
			else
				if isa(char, SimulatedCharacter)
					make_active!(char, parser)
				else
					hascustomoverview(char) ? make_active!(char, parser) : CImGui.OpenPopup("Overview Warning")
				end
			end
		end; CImGui.PopStyleColor()

		if CImGui.BeginPopupContextItem("$(char.name)")
			
			if isactive(char, parser)
				CImGui.Selectable("Deactivate") && deactivate!(char, parser)
			else
				flags = hascustomoverview(char) ? 0 : CImGui.ImGuiSelectableFlags_Disabled
				CImGui.Selectable("Make Active", false, flags) && make_active!(char, parser)
			end

			str = hascustomoverview(char) ? "Change overview" : "Select overview"
			# Selectables and MenuItems call CloseCurrentPopup() by default unless otherwise specified by this flag.
			CImGui.Selectable(str, false, CImGui.ImGuiSelectableFlags_DontClosePopups) && CImGui.OpenPopup("Select File##context")

			modal_open = true # we need this here to collaps the context popup when closing the modal.
			@c SelectFileModal("Select File##context", (path) -> begin
				if isactive(char, parser)
					was_running = isrunning(parser)
					stop_parsing!(parser)
					update_overview!(char, path)
					was_running && @async start_parsing!(parser)
				else
					update_overview!(char, path)
				end
			end, &modal_open; starting_folder=parser.overview_directory)
			
			modal_open || CImGui.CloseCurrentPopup()
			CImGui.EndPopup()
		end

		if CImGui.BeginPopupModal("Overview Warning", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
			CImGui.TextColored([1.0, 0.6, 0.4, 1.0], "WARNING:")
			CImGui.Text("You are trying to activate a character\nwithout an associated overview file.")
			CImGui.Text("Without it parsing becomes unreliable.\n\
				Infomations such as name of the pilot,\nand ship types won't be recognized properly.")
			CImGui.Dummy((10,10))
			CImGui.Text("Hint:\nTo automatically select an overview\n\
				rename the desired file in the overview folder\n\
				such that it starts with:\n\n\t`jeld_$(lowercase(char.name))`.")
			CImGui.Dummy((15, 15))
			CImGui.Button("Close") && CImGui.CloseCurrentPopup()
			CImGui.SameLine(); CImGui.Button("Select Overview") && CImGui.OpenPopup("Select File##modal")
			CImGui.SameLine(); CImGui.Button("Activate Anyway") && (make_active!(char, parser); CImGui.CloseCurrentPopup())

			CImGui.SetNextWindowSize((487,270), CImGui.ImGuiCond_FirstUseEver)
			SelectFileModal("Select File##modal", (path) -> begin
				if isactive(char, parser)
					was_running = isrunning(parser)
					stop_parsing!(parser)
					update_overview!(char, path)
					was_running && @async start_parsing!(parser)
				else
					update_overview!(char, path)
				end
			end; starting_folder=parser.overview_directory)

			# if you exit the file selection modal, return to the previous one.
			hascustomoverview(char) && CImGui.CloseCurrentPopup()
			CImGui.EndPopup()
		end
		CImGui.PopID()
	end
end