function ShowDetailGraphWindow(p_open::Ref{Bool}, parser, processor, settings)
	CImGui.SetNextWindowSize((532,232), CImGui.ImGuiCond_FirstUseEver)
	CImGui.Begin("Details", p_open) || (CImGui.End(); return)

	@cstatic(
		top_total_series_idx = 1,
		top_total_num = Cint(5),
		top_alpha_series_idx = 1,
		top_alpha_num = Cint(5),
		app_idx = 1,
	begin
		
		if CImGui.CollapsingHeader("Top Total")
			CImGui.SetNextItemWidth(-CImGui.GetContentRegionAvail().x*0.51)
			if CImGui.BeginCombo("##combo_total", series_labels[processor.columns[top_total_series_idx]])
				for (i, symcol) in enumerate(processor.columns)
					selected = i == top_total_series_idx
					CImGui.Selectable(series_labels[symcol], selected) && (top_total_series_idx = i)
				end
				CImGui.EndCombo()
			end
			CImGui.SetNextItemWidth(CImGui.GetContentRegionAvail().x*0.50)
			CImGui.SameLine(CImGui.GetContentRegionAvail().x*0.51); @c CImGui.InputInt("##top_total_top", &top_total_num)
		
			col = processor.columns[top_total_series_idx]
			top_total_df = first(top_total(parser.data, col, settings.graph_window_s), top_total_num)
			totals = top_total_df.sum
			ticks_labels = top_total_df.Source
			n = length(ticks_labels)

			bar_width = 0.2
			bar_inner_pad = 0.05
			bar_outer_pad = 0.1
			stack_height = n >= 2 ? 2*bar_outer_pad + bar_width*n + bar_inner_pad*(n-1) : 2*bar_outer_pad + bar_width
			start = bar_outer_pad + bar_width/2
			step = bar_width + bar_inner_pad
			finish = step*(n)
			positions = collect(start:step:finish)

			ImPlot.SetNextPlotLimits(0, maximum(totals; init=1)*1.05, 0, stack_height, CImGui.ImGuiCond_Always)
			ImPlot.SetNextPlotTicksY(positions, n, ticks_labels)
			if ImPlot.BeginPlot("##bars_details_total", "", "", CImGui.ImVec2(-1,150);y_flags = ImPlot.ImPlotAxisFlags_Invert, x_flags=ImPlot.ImPlotAxisFlags_NoDecorations)

				ImPlot.SetNextFillStyle(series_colors[col])
				ImPlot.PushStyleVar(ImPlotStyleVar_FillAlpha, 0.2)
				ImPlot.PlotBarsH(convert.(eltype(positions), totals), positions, width=bar_width)
				for i in 1:n
					ImPlot.Annotate(0, positions[i], CImGui.ImVec2(10, 0), "$(trunc(totals[i]))")
				end
				ImPlot.PopStyleVar()

				ImPlot.EndPlot()
			end
		end
		if CImGui.CollapsingHeader("Top Alpha")
			CImGui.SetNextItemWidth(-CImGui.GetContentRegionAvail().x*0.51)
			if CImGui.BeginCombo("##combo_alpha", series_labels[processor.columns[top_alpha_series_idx]])
				for (i, symcol) in enumerate(processor.columns)
					selected = i == top_alpha_series_idx
					CImGui.Selectable(series_labels[symcol], selected) && (top_alpha_series_idx = i)
				end
				CImGui.EndCombo()
			end
			CImGui.SetNextItemWidth(CImGui.GetContentRegionAvail().x*0.50)
			CImGui.SameLine(CImGui.GetContentRegionAvail().x*0.51); @c CImGui.InputInt("##top_alpha_top", &top_alpha_num)
		
			col = processor.columns[top_alpha_series_idx]
			top_alpha_df = first(top_alpha(parser.data, col, settings.graph_window_s), top_alpha_num)
			totals = top_alpha_df.max
			ticks_labels = top_alpha_df.Source
			n = length(ticks_labels)

			bar_width = 0.2
			bar_inner_pad = 0.05
			bar_outer_pad = 0.1
			stack_height = n >= 2 ? 2*bar_outer_pad + bar_width*n + bar_inner_pad*(n-1) : 2*bar_outer_pad + bar_width
			start = bar_outer_pad + bar_width/2
			step = bar_width + bar_inner_pad
			finish = step*(n)
			positions = collect(start:step:finish)

			ImPlot.SetNextPlotLimits(0, maximum(totals; init=1)*1.05, 0, stack_height, CImGui.ImGuiCond_Always)
			ImPlot.SetNextPlotTicksY(positions, n, ticks_labels)
			if ImPlot.BeginPlot("##bars_details_alpha", "", "", CImGui.ImVec2(-1,150);y_flags = ImPlot.ImPlotAxisFlags_Invert, x_flags=ImPlot.ImPlotAxisFlags_NoDecorations)

				ImPlot.SetNextFillStyle(series_colors[col])
				ImPlot.PushStyleVar(ImPlotStyleVar_FillAlpha, 0.2)
				ImPlot.PlotBarsH(convert.(eltype(positions), totals), positions, width=bar_width)
				for i in 1:n
					ImPlot.Annotate(0, positions[i], CImGui.ImVec2(10, 0), "$(trunc(Int, totals[i]))")
				end
				ImPlot.PopStyleVar()

				ImPlot.EndPlot()
			end
		end

		if CImGui.CollapsingHeader("Application Distribution")
			CImGui.SetNextItemWidth(-CImGui.GetContentRegionAvail().x*0.51)
			if CImGui.BeginCombo("##combo_app", series_labels[processor.columns[app_idx]])
				for (i, symcol) in enumerate(processor.columns)
					symcol == :DamageIn || symcol == :DamageOut || continue
					selected = i == app_idx
					CImGui.Selectable(series_labels[symcol], selected) && (app_idx = i)
				end
				CImGui.EndCombo()
			end
		
			col = processor.columns[app_idx]
			app_dist_df = hit_dist(parser.data, col, settings.graph_window_s)
			ticks_labels = ["Wrecks", "Smashes", "Penetrates", "Hits", "Glances Off", "Grazes"]
			n = length(ticks_labels)
			totals = zeros(n)
			for (i, applic) in enumerate(ticks_labels)
				idx = findfirst(==(applic), app_dist_df.Application)
				totals[i] = isnothing(idx) ? 0 : app_dist_df.counts[idx]
			end
			# totals = app_dist_df.counts
			# ticks_labels = app_dist_df.Application

			bar_width = 0.2
			bar_inner_pad = 0.05
			bar_outer_pad = 0.1
			stack_height = n >= 2 ? 2*bar_outer_pad + bar_width*n + bar_inner_pad*(n-1) : 2*bar_outer_pad + bar_width
			start = bar_outer_pad + bar_width/2
			step = bar_width + bar_inner_pad
			finish = step*(n)
			positions = collect(start:step:finish)

			ImPlot.SetNextPlotLimits(0, maximum(totals; init=1)*1.05, 0, stack_height, CImGui.ImGuiCond_Always)
			ImPlot.SetNextPlotTicksY(positions, n, ticks_labels)
			if ImPlot.BeginPlot("##bars_details_app", "", "", CImGui.ImVec2(-1,200);y_flags = ImPlot.ImPlotAxisFlags_Invert, x_flags=ImPlot.ImPlotAxisFlags_NoDecorations)

				ImPlot.SetNextFillStyle(series_colors[col])
				ImPlot.PushStyleVar(ImPlotStyleVar_FillAlpha, 0.2)
				ImPlot.PlotBarsH(totals, positions, width=bar_width)
				for i in 1:n
					ImPlot.Annotate(0, positions[i], CImGui.ImVec2(10, 0), "$(trunc(Int, totals[i]))")
				end
				ImPlot.PopStyleVar()

				ImPlot.EndPlot()
			end
		end
	end) #cstatic

	CImGui.End()
end