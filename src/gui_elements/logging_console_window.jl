################# Logging Console ####################

mutable struct ImGuiLogger <: AbstractLogger
	debug_buf::IOBuffer
	combat_buf::IOBuffer
	autoscrolling::Bool
end
ImGuiLogger() = ImGuiLogger(IOBuffer(), IOBuffer(), true)
function Logging.handle_message(logger::ImGuiLogger, level::LogLevel, message, _module, group, id,
                        		filepath, line; kwargs...)
	debug_iob = logger.debug_buf
	combat_iob = logger.combat_buf
	if level == LogLevel(1)
		println(combat_iob, message)
	else
		levelstr = string(level)

		msglines = eachsplit(chomp(convert(String, string(message))::String), '\n')
	    msg1, rest = Iterators.peel(msglines)
	    println(debug_iob, levelstr, ": ", msg1)
	    for msg in rest
	        println(debug_iob, "|   ", msg)
	    end
	    for (key, val) in kwargs
	        key === :maxlog && continue
	        println(debug_iob, "|   ", key, " = ", val)
	    end
	end
    return nothing
end
Logging.shouldlog(logger::ImGuiLogger, level, _module, group, id) = true
Logging.min_enabled_level(logger::ImGuiLogger) = LogLevel(0)
Logging.catch_exceptions(logger::ImGuiLogger) = false
function draw(buffer::IOBuffer, autoscroll::Bool)

	CImGui.Button("Clear") && clear(buffer)
	CImGui.SameLine(); CImGui.Button("Copy") && CImGui.LogToClipboard()
	
	CImGui.Separator()
	CImGui.BeginChild("log window", (0,-25), true, CImGui.ImGuiWindowFlags_HorizontalScrollbar)

	seekstart(buffer)
	CImGui.TextUnformatted(read(buffer, String))
	if autoscroll
		(CImGui.GetScrollMaxY() >= CImGui.GetScrollY()) && CImGui.SetScrollHereY(1.0)
	end
	CImGui.EndChild()
end
function ShowLogWindow(p_open::Ref{Bool}, logger::ImGuiLogger)
	CImGui.SetNextWindowSize((500,200), CImGui.ImGuiCond_FirstUseEver)
	CImGui.Begin("Log", p_open) || (CImGui.End(); return)
	if CImGui.BeginTabBar("Log Tab Bar")
		if CImGui.BeginTabItem("Combat Log Mirror")
			draw(logger.combat_buf, logger.autoscrolling)
			CImGui.EndTabItem()
		end
		if CImGui.BeginTabItem("Debug")
			draw(logger.debug_buf, logger.autoscrolling)
			CImGui.EndTabItem()
		end
		CImGui.EndTabBar()
	end
	@c CImGui.Checkbox("Auto Scroll", &logger.autoscrolling)
	CImGui.End()
end