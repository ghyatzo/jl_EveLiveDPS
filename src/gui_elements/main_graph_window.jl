##################### Main Graph #####################

# TODO: redo colors
const series_colors = Dict(
	:DamageIn 			=> CImGui.ImVec4(1.0, 0.2, 0.0, 1.0), # red
	:DamageOut 			=> CImGui.ImVec4(0.3, 0.5, 1.0, 1.0), # light-blue
	:LogisticsIn 		=> CImGui.ImVec4(1.0, 0.4, 0.2, 0.5), # orange
	:LogisticsOut 		=> CImGui.ImVec4(0.2, 0.4, 1.0, 0.5), # blue
	:CapTransfered 		=> CImGui.ImVec4(0.5, 0.5, 0.1, 1.0), # light-green
	:CapReceived 		=> CImGui.ImVec4(0.8, 0.4, 0.1, 1.0), # green
	:CapDamageDone 		=> CImGui.ImVec4(0.4, 1.0, 0.2, 0.5), # pink
	:CapDamageReceived 	=> CImGui.ImVec4(0.2, 1.0, 0.0, 1.0)  # purple
)

const series_labels = Dict(
	:DamageIn 			=> "DmgIn",
	:DamageOut 			=> "DmgOut",
	:LogisticsIn 		=> "LogiIn",
	:LogisticsOut 		=> "LogiOut",
	:CapTransfered 		=> "CapTransOut",
	:CapReceived 		=> "CapTransIn",
	:CapDamageDone 		=> "CapDmgOut",
	:CapDamageReceived 	=> "CapDmgIn"
)

function ShowMainGraphWindow(p_open::Ref{Bool}, 
		processor, graph_window_seconds, graph_padding, 
		graph_smoothing, ema_wilder, column_mask)
	
	x_max = now()
	x_min = (x_max - Dates.Second(graph_window_seconds))
	clipped_series = processor.series[processor.series.Time .> x_min - Dates.Second(graph_padding), column_mask]

	@cstatic show_tank = true max_tank = 10.0 y_min_max = 49 begin
	## limits
		y_min = 0
		y_max = max(y_min_max, maximum(maximum.(eachcol(clipped_series[!, Not(:Time)]); init=0)))
		n = size(clipped_series, 1)

		CImGui.SetNextWindowSize((1000,500), CImGui.ImGuiCond_FirstUseEver)
	## Window
		CImGui.Begin("Live Graph", p_open, CImGui.ImGuiWindowFlags_NoTitleBar) || (CImGui.End(); return)

	## Current Values:
		for col in processor.columns
			val = string(round(Int, processor.current_values[col]))
			CImGui.SameLine()
			CImGui.TextColored(series_colors[col], series_labels[col]*": ");CImGui.SameLine();CImGui.TextColored(series_colors[col], val)
		end

	## Actual Plot
	    ImPlot.SetNextPlotLimits(x_min |> datetime2unix, x_max |> datetime2unix, y_min, y_max+1, CImGui.ImGuiCond_Always)
	    if ImPlot.BeginPlot("##line", "", "", CImGui.ImVec2(-1,-25); flags=ImPlot.ImPlotFlags_AntiAliased, x_flags=ImPlot.ImPlotAxisFlags_Time)
	    	xs = clipped_series.Time .|> datetime2unix
	    	show_tank && @c ImPlot.DragLineY("tank", &max_tank, false, CImGui.ImVec4(1,0.5,1,1))
	    	
	    	if n > 2
		 		ys = zeros(n)

		    	for (i, col) in enumerate(eachcol(clipped_series))
		    		eltype(col) == DateTime && continue
		    		sum(col) > 0 || continue # show a time series only if it has at least a non zero value in the window

		    		col_symbol = propertynames(clipped_series)[i]
		    		ema_conv!(ys, col, graph_smoothing; wilder=ema_wilder)

		    		ImPlot.PushStyleColor(ImPlotCol_Line, series_colors[col_symbol])
		    		ImPlot.PlotLine(string(col_symbol), xs, ys, n)
		    		ImPlot.PopStyleColor()
		    	end
	    	end
	        ImPlot.EndPlot()
	    end
	    @c CImGui.Checkbox("Show Reference Line", &show_tank); CImGui.SameLine(); @c CImGui.InputDouble("##ref_value", &max_tank, 0.0, 0.0, "%.1f")

		CImGui.End()
	end #cstatic
end