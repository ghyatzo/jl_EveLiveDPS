
################# Property Inspector ###################
function ShowPropertyInspectorWindow(p_open::Ref{Bool}, parser, processor)
	CImGui.Begin("Property Inspector", p_open, CImGui.ImGuiWindowFlags_AlwaysAutoResize) || (CImGui.End();  return)

	CImGui.Text("Log Directory:"); CImGui.SameLine(200); CImGui.Text("$(parser.log_directory)")
	CImGui.Text("Overview Directory:"); CImGui.SameLine(200); CImGui.Text("$(parser.overview_directory)")
	CImGui.Dummy((10, 20))
	framerate = CImGui.GetIO().Framerate
	CImGui.Text("Application: "); CImGui.SameLine(200); CImGui.Text("$(round(1000/framerate; sigdigits=5)) ms/frame ($(round(framerate; sigdigits=3)) FPS)")
	CImGui.Text("Active Character:"); CImGui.SameLine(200);
	isnothing(parser.active_character) ? CImGui.Text("no character") : CImGui.Text("$(parser.active_character.name)")
	CImGui.Text("Is Parser Running:"); CImGui.SameLine(200);
	color1 = isrunning(parser) ? Cfloat[0.0, 0.8, 0.0, 1.0] : Cfloat[0.8, 0.0, 0.0, 1.0]
	CImGui.TextColored(color1, "$(parser.run)")
	CImGui.Text("Is Processor Running:"); CImGui.SameLine(200);
	color2 = isrunning(processor) ? Cfloat[0.0, 0.8, 0.0, 1.0] : Cfloat[0.8, 0.0, 0.0, 1.0]
	CImGui.TextColored(color2, "$(processor.run)")

	CImGui.Separator()
	if CImGui.TreeNode("Characters ($(length(parser.chars)))###Chars")
		for (n, char) in enumerate(parser.chars)
			CImGui.PushID("$(char.name)")
			active_flag = isactive(char, parser) ? " <-- Active" : "" 
			if CImGui.TreeNode("$(char.name)"*active_flag)
				CImGui.Text("Last Session:"); CImGui.SameLine(200); CImGui.Text(string(Dates.format(char.session_start, "HH:MM (dd u)")))
				CImGui.Text("Custom overview:")
				CImGui.SameLine(200); hascustomoverview(char) ? CImGui.Text("$(basename(char.customoverview))") : CImGui.Text("false")
				# reg = string(char.compiled_regexes["metadata"])[3:end-1]
				# CImGui.SetNextItemWidth(500)
				# CImGui.InputText("", reg, length(reg))
				if CImGui.TreeNode("Reader")
					color = isrunning(char) ? Cfloat[0.0, 0.8, 0.0, 1.0] : Cfloat[0.8, 0.0, 0.0, 1.0]
					CImGui.Text("running:"); CImGui.SameLine(200); CImGui.TextColored(color, "$(isrunning(char))")
					CImGui.Text("backlog:"); CImGui.SameLine(200); CImGui.Text("$(getchannel(char).n_avail_items)")
					CImGui.Text("delay:"); CImGui.SameLine(200); CImGui.Text("$(readerdelay(char))")
					CImGui.Text("log file:"); CImGui.SameLine(200); CImGui.Text("$(basename(getlog(char)))")
					CImGui.TreePop()
				end
				CImGui.TreePop()
			end
			CImGui.PopID()
		end
		CImGui.TreePop()
	end
	if CImGui.TreeNode("Data ($(size(parser.data, 1) + size(processor.series, 1)) entries)###Data")

		CImGui.Text("Parser Data Size: $(Base.summarysize(parser.data) / 1000) KB")
		CImGui.Text("Processor Data Size: $(Base.summarysize(processor.series) / 1000) KB")
		# CImGui.BeginChild("data", (500, 100), true, CImGui.ImGuiWindowFlags_HorizontalScrollbar)
		# buf = IOBuffer()
		# show(buf, last(parser.data, 5))
		# CImGui.TextUnformatted(read(buf, String))

		# CImGui.EndChild()
		CImGui.TreePop()
	end

	CImGui.End()
end