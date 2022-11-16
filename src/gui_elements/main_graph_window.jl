##################### Main Graph #####################

# TODO: redo colors
series_colors = Dict(
	:DamageIn 			=> Cfloat[1.0, 0.2, 0.0, 1.0], # red
	:DamageOut 			=> Cfloat[77/255, 223/255, 1.0, 1.0], # light-blue
	:LogisticsIn 		=> Cfloat[1.0, 0.4, 0.2, 0.5], # orange
	:LogisticsOut 		=> Cfloat[0.2, 0.4, 1.0, 0.5], # blue
	:CapTransfered 		=> Cfloat[0.5, 0.5, 0.1, 1.0], # light-green
	:CapReceived 		=> Cfloat[0.8, 0.4, 0.1, 1.0], # green
	:CapDamageDone 		=> Cfloat[0.4, 1.0, 0.2, 0.5], # pink
	:CapDamageReceived 	=> Cfloat[0.2, 1.0, 0.0, 1.0], # purple
	:Mined  			=> Cfloat[0.5, 0.3, 0.5, 1.0] # boh
)

tounixtime(date; shift_second=0) = (date - Dates.Millisecond(trunc(Int64, shift_second*1000))) |> datetime2unix

function clip_series(series, time_bound)
	@with series begin
		return series[:Time .> time_bound, All()]	
	end
end
function clip_idx(times, time_bound)
	n_max = length(times)
	findprev(t -> t < time_bound, times, n_max)
end
using FFTW

function ShowMainGraphWindow(p_open::Ref{Bool}, processor, settings)
	
	time_shift = settings.graph_smoothing_delay_s
	x_max = now()
	x_min = (x_max - Dates.Second(settings.graph_window_s))
	y_min = 0
	n_cols = length(processor.columns)

	idx_bound = clip_idx(processor.series.Time, x_min - Dates.Second(settings.graph_padding_s))
	isnothing(idx_bound) && (idx_bound = 1)

	clipped_series = clip_series(processor.smooth_series, x_min - Dates.Second(settings.graph_padding_s))
	zero_mask = [iszero(sum(col; init=0)) for col in eachcol(clipped_series[!, Not(:Time)])]
	n_vals = size(clipped_series, 1)
	@cstatic(
		y_min_max = 49,
	begin

		# computer upper limit
		y_max = y_min_max
		for (i,col) in enumerate(eachcol(clipped_series))
			i == 1 && continue # skip time
			iszero(settings.graph_column_mask[i-1]) && continue # skip ignored series
			col_max = maximum(col; init=0)*1.5
			col_max > y_max && (y_max = col_max)
		end

		viewport = CImGui.igGetMainViewport()
	    workpos  = unsafe_load(viewport.WorkPos)
	    worksize = unsafe_load(viewport.WorkSize)
	    window_flags = 
	    	CImGui.ImGuiWindowFlags_NoDecoration |
	    	CImGui.ImGuiWindowFlags_NoBackground |
	    	CImGui.ImGuiWindowFlags_NoMove |
	    	CImGui.ImGuiWindowFlags_NoResize | 
	    	CImGui.ImGuiWindowFlags_NoSavedSettings

		CImGui.SetNextWindowPos(workpos)
		CImGui.SetNextWindowSize(worksize)
		CImGui.Begin("Live Graph", p_open, window_flags) || (CImGui.End(); return)

		for i in 1:n_cols
			zero_mask[i] && continue
			CImGui.PushID(i)
			col = processor.columns[i]
			val = string(round(Int32, processor.current_values[col]))
			CImGui.SameLine(); CImGui.Checkbox("", Ref(settings.graph_column_mask, i))
			CImGui.SameLine(); CImGui.Text(series_labels[col]*": ")
			CImGui.SameLine(); CImGui.TextColored(series_colors[col], val)
			CImGui.PopID()
		end

		plot_flags = ImPlot.ImPlotFlags_AntiAliased	| ImPlot.ImPlotFlags_CanvasOnly
		plot_x_flags = ImPlot.ImPlotAxisFlags_Time |
			ImPlot.ImPlotAxisFlags_NoTickLabels |
			ImPlot.ImPlotAxisFlags_NoGridLines |
			ImPlot.ImPlotAxisFlags_NoLabel
		plot_y_flags = ImPlot.ImPlotAxisFlags_NoLabel

	    ImPlot.SetNextPlotLimits(x_min |> datetime2unix, x_max |> datetime2unix, y_min, y_max+1, CImGui.ImGuiCond_Always)
	    if ImPlot.BeginPlot("##line", "", "", CImGui.ImVec2(-1,-100); flags=plot_flags, x_flags=plot_x_flags, y_flags=plot_y_flags)

	    	settings.graph_show_primary_tresh && @c ImPlot.DragLineY("Tank", &settings.graph_primary_tresh, false, CImGui.ImVec4(1,0.5,1,1))
	    	settings.graph_show_secondary_tresh && @c ImPlot.DragLineY("Heated", &settings.graph_secondary_tresh, false, CImGui.ImVec4(1,0.5,1,0.5))
	    	
	    	if settings.graph_show_shade & settings.graph_show_secondary_tresh & settings.graph_show_primary_tresh
	    		ImPlot.PushStyleVar(ImPlotStyleVar_FillAlpha, 0.2)
	    		ImPlot.SetNextFillStyle(CImGui.ImVec4(1,0.5,1,0.3))
	    		@c ImPlot.PlotShaded([x_min, x_max] .|> datetime2unix, fill(settings.graph_primary_tresh, 2), fill(settings.graph_secondary_tresh, 2))
	    		ImPlot.PopStyleVar()
	    	end
	    	
	    	if n_vals >= 1
	    		xs = clipped_series.Time  .|> datetime2unix
	    		ys = zeros(n_vals)
	    		for i in 1:n_cols
	    			zero_mask[i] && continue
	    			col_name = processor.columns[i]
	    			col_data = clipped_series[!, col_name]
	    			shadow_data = processor.series[idx_bound:end, col_name]

			    	iszero(settings.graph_column_mask[i]) && continue

			    	main_col = CImGui.ImVec4(series_colors[col_name]...)
			    	shadow_col = CImGui.ImVec4(series_colors[col_name][1:3]..., 0.2)

			    	# we want a gamma corresponds roughly to seconds, in terms of samples.
			    	gamma = convert(Int64, settings.graph_gauss_smoothing_gamma)
			    	settings.graph_gauss_smoothing_enable && gaussian_smoothing!(ys, col_data; gamma))

			    	ImPlot.SetNextLineStyle(main_col, 2.5)
		    		ImPlot.PlotLine(string(col_name), xs, ys, n_vals)

		    		ImPlot.SetNextLineStyle(shadow_col, 2)
		    		ImPlot.PlotLine(string(col_name), xs, shadow_data, length)
	    		end
	    	end
	        ImPlot.EndPlot()
	    end
	    CImGui.PushItemWidth(100)
	    @c CImGui.Checkbox("##tank", &settings.graph_show_primary_tresh); CImGui.SameLine(); @c CImGui.InputDouble("Primary threshold", &settings.graph_primary_tresh, 0, 0, "%.1f")
	    @c CImGui.Checkbox("##heated", &settings.graph_show_secondary_tresh); CImGui.SameLine(); @c CImGui.InputDouble("Secondary threshold", &settings.graph_secondary_tresh, 0, 0, "%.1f"); CImGui.SameLine(); @c CImGui.Checkbox("Shade Area", &settings.graph_show_shade)
	    CImGui.PopItemWidth()

		CImGui.End()
	end) #cstatic
end
