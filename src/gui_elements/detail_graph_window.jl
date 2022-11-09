function DetailBarPlot(
	label_id, values, labels, ships, num_bars, bar_width,
	bar_inner_pad, bar_outer_pad, bar_color, bar_alpha; sort=true, filter_zero=true)

	p = sort ? sortperm(values; rev=true) : collect(eachindex(values))
	filter!(i -> !iszero(values[i]), p)
	n = length(p)
	if num_bars < n 
		p = p[1:num_bars]
		n = num_bars
	end

	stack_height = n >= 2 ? 2*bar_outer_pad + bar_width*n + bar_inner_pad*(n-1) : 2*bar_outer_pad + bar_width
	start = bar_outer_pad + bar_width/2
	step = bar_width + bar_inner_pad
	finish = step*(n)
	positions = collect(start:step:finish) # empty when n=0

	ImPlot.SetNextPlotLimits(0, maximum(values; init=1)*1.1, 0, stack_height, CImGui.ImGuiCond_Always)
	n > 0 && ImPlot.SetNextPlotTicksY(positions, n, labels[p])
	if ImPlot.BeginPlot(label_id, "", "", CImGui.ImVec2(-1,165); y_flags = ImPlot.ImPlotAxisFlags_Invert, x_flags=ImPlot.ImPlotAxisFlags_NoDecorations)
		if n > 0
			ImPlot.SetNextFillStyle(bar_color, bar_alpha)
			ImPlot.PlotBarsH(Float64.(values[p]), positions, width=bar_width)
			for i in 1:n
				if ships[p[i]] == labels[p[i]]
					ImPlot.Annotate(0, positions[i], CImGui.ImVec2(10, 0), "$(trunc(Int, values[p[i]]))")
				else
					ImPlot.Annotate(0, positions[i], CImGui.ImVec2(10, 0), "($(ships[p[i]]))  $(trunc(Int, values[p[i]]))")
				end
			end
		end

		ImPlot.EndPlot()
	end
end



function ShowDetailGraphWindow(p_open::Ref{Bool}, parser, processor, settings)
	CImGui.SetNextWindowSize((532,232), CImGui.ImGuiCond_FirstUseEver)
	CImGui.Begin("Details", p_open) || (CImGui.End(); return)

	@cstatic(
		top_total_series_idx = 1,
		top_total_num = Cint(4),
		top_alpha_series_idx = 1,
		top_alpha_num = Cint(4),
		app_idx = 1,
	begin
		col_sum = processor.columns[top_total_series_idx]
		col_max = processor.columns[top_alpha_series_idx]
		sources, ships, sums, maxs = get_source_stats(parser.data, col_sum, col_max, settings.graph_window_s)

		bar_width = 3
		bar_inner_pad = 0.1
		bar_outer_pad = 1
		
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
			top_total_num < 1 && (top_total_num = 1)

			DetailBarPlot("##total", sums, sources, ships, top_total_num,
				bar_width, bar_inner_pad, bar_outer_pad, series_colors[col_sum], 0.5)
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
			top_alpha_num < one(Int32) && (top_alpha_num = Cint(1))
		
			DetailBarPlot("##alpha", maxs, sources, ships, top_alpha_num,
				bar_width, bar_inner_pad, bar_outer_pad, series_colors[col_max], 0.5)
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
			applications, counts = get_hit_dist(parser.data, col, settings.graph_window_s)
			ticks_labels = ["Wrecks", "Smashes", "Penetrates", "Hits", "Glances Off", "Grazes"]
			n = length(ticks_labels)
			values = zeros(n)
			for (i, applic) in enumerate(ticks_labels)
				idx = findfirst(==(applic), applications)
				values[i] = isnothing(idx) ? 0 : counts[idx]
			end

			DetailBarPlot(
				"##appli", values, ticks_labels, ticks_labels, n, bar_width,
				bar_inner_pad, bar_outer_pad, series_colors[col], 0.5; sort=false, filter_zero=false)
		end
	end) #cstatic

	CImGui.End()
end