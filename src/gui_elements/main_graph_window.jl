##################### Main Graph #####################

# TODO: redo colors
series_colors = Dict(
	:DamageIn 			=> Cfloat[1.0, 0.2, 0.0, 1.0], # red
	:DamageOut 			=> Cfloat[0.3, 0.7, 1.0, 1.0], # light-blue
	:LogisticsIn 		=> Cfloat[1.0, 0.4, 0.2, 0.5], # orange
	:LogisticsOut 		=> Cfloat[0.2, 0.4, 1.0, 0.5], # blue
	:CapTransfered 		=> Cfloat[0.5, 0.5, 0.1, 1.0], # light-green
	:CapReceived 		=> Cfloat[0.8, 0.4, 0.1, 1.0], # green
	:CapDamageDone 		=> Cfloat[0.4, 1.0, 0.2, 0.5], # pink
	:CapDamageReceived 	=> Cfloat[0.2, 1.0, 0.0, 1.0]  # purple
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
		graph_smoothing, ema_wilder, column_mask,
		enable_gaussian_smoothing, gaussian_gamma)
	
	x_max = now()
	x_min = (x_max - Dates.Second(graph_window_seconds))
	y_min = 0
	n_cols = length(processor.columns)

	# clip the series wrt time
	clipped_series = processor.series[processor.series.Time .> x_min - Dates.Second(graph_padding), :]
	n_vals = size(clipped_series, 1)

	@cstatic show_tank = true show_tank_heated = false max_tank = 10.0 max_tank_heated = 15.0 y_min_max = 49 c_vals = fill(0, 8) begin

		# computer upper limit
		y_max = y_min_max
		for (i,col) in enumerate(eachcol(clipped_series))
			i == 1 && continue # skip time
			iszero(column_mask[i-1]) && continue # skip ignored series
			col_max = maximum(col; init=0)
			col_max > y_max && (y_max = col_max)
		end

		CImGui.SetNextWindowSize((1000,500), CImGui.ImGuiCond_FirstUseEver)
		CImGui.Begin("Live Graph", p_open, CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoBringToFrontOnFocus) || (CImGui.End(); return)

		for i in 1:n_cols
			iszero(column_mask[i]) && continue
			col = processor.columns[i]
			val = string(c_vals[i])
			CImGui.SameLine()
			CImGui.TextColored(series_colors[col], series_labels[col]*": ");CImGui.SameLine();CImGui.TextColored(series_colors[col], val)
		end

	    ImPlot.SetNextPlotLimits(x_min |> datetime2unix, x_max |> datetime2unix, y_min, y_max+1, CImGui.ImGuiCond_Always)
	    if ImPlot.BeginPlot("##line", "", "", CImGui.ImVec2(-1,-40); flags=ImPlot.ImPlotFlags_AntiAliased, x_flags=ImPlot.ImPlotAxisFlags_Time)
	    	xs = clipped_series.Time .|> datetime2unix
	    	show_tank && @c ImPlot.DragLineY("tank", &max_tank, false, CImGui.ImVec4(1,0.5,1,1))
	    	show_tank_heated && @c ImPlot.DragLineY("heated", &max_tank_heated, false, CImGui.ImVec4(1,0.5,1,0.5))
	    	if n_vals > 1
	    		ys = zeros(n_vals)
	    		for i in 1:n_cols
	    			iszero(column_mask[i]) && continue
	    			col_name = processor.columns[i]
	    			col_data = clipped_series[:, col_name]
	    			sum(col_data) > 0 || continue # show a time series only if it has at least a non zero value in the time window

	    			ema_conv!(ys, col_data, graph_smoothing; wilder=ema_wilder)
	    			enable_gaussian_smoothing && (ys = gaussian_smoothing(ys; gamma=gaussian_gamma))
	    			c_vals[i] = round(Int, ys[end])

		    		ImPlot.SetNextLineStyle(series_colors[col_name], 2.5)
		    		ImPlot.PlotLine(string(col_name), xs, ys, n_vals)
	    		end
	    	end
	        ImPlot.EndPlot()
	    end
	    @c CImGui.Checkbox("Reference Line 1", &show_tank); CImGui.SameLine(); @c CImGui.InputDouble("##tank", &max_tank, 0.0, 0.0, "%.1f")
	    @c CImGui.Checkbox("Reference Line 2", &show_tank_heated); CImGui.SameLine(); @c CImGui.InputDouble("##tank_heated", &max_tank_heated, 0.0, 0.0, "%.1f")

		CImGui.End()
	end #cstatic
end
