##################### File/Directory Selector #########################

function SelectFileModal(id, on_select = (path) -> nothing, p_open=C_NULL; starting_folder="")
	if CImGui.BeginPopupModal(id, p_open)

		@cstatic current_path="" selected=Cint(-1) begin
			if isempty(current_path)
				current_path = isempty(starting_folder) ? homedir() : starting_folder
			end

			current_path_folders = splitpath(current_path)
			for (n, folder) in enumerate(current_path_folders)
				CImGui.SameLine()
				if CImGui.Button(folder)
					current_path=joinpath(current_path_folders[1:n])
				end
			end

			CImGui.Separator()

			paths = readdir(current_path; join=true)
			CImGui.BeginChild("folders", (0, -27))

			for (n, path) in enumerate(paths)
				if isdir(path)
					if CImGui.Selectable("[DIR]\t"*basename(path)*"/", selected == n, CImGui.ImGuiSelectableFlags_AllowDoubleClick)
						selected = n
						CImGui.IsMouseDoubleClicked(0) && (current_path = path)
					end
				else
					if CImGui.Selectable("\t\t"*basename(path), selected == n, CImGui.ImGuiSelectableFlags_AllowDoubleClick)
						selected = n
						if CImGui.IsMouseDoubleClicked(0)
							on_select(paths[selected])
							CImGui.CloseCurrentPopup()
						end						
					end
				end
			end
			CImGui.EndChild()

			CImGui.Separator()

			if CImGui.Button("Cancel")
				(p_open != C_NULL) && (p_open[] = false)
				CImGui.CloseCurrentPopup()
			end
			CImGui.SameLine()
			if CImGui.Button("Select")
				(p_open != C_NULL) && (p_open[] = false)
				on_select(paths[selected])
				CImGui.CloseCurrentPopup()
			end
		end

		CImGui.EndPopup()
	end
end

function SelectDirectoryModal(id, on_select=(path) -> nothing, p_open=C_NULL; starting_folder="")
	if CImGui.BeginPopupModal(id, p_open)

		@cstatic current_path="" selected=Cint(-1) begin
			if isempty(current_path)
				current_path = isempty(starting_folder) ? homedir() : starting_folder
			end
			current_path_folders = splitpath(current_path)
			for (n, folder) in enumerate(current_path_folders)
				CImGui.SameLine()
				if CImGui.Button(folder)
					current_path=joinpath(current_path_folders[1:n])
				end
			end

			CImGui.Separator()

			folders = filter(isdir, readdir(current_path; join=true))
			CImGui.BeginChild("folders", (0, -27))

			for (n, dir) in enumerate(folders)
				if CImGui.Selectable(basename(dir), selected == n, CImGui.ImGuiSelectableFlags_AllowDoubleClick)
					selected = n
					CImGui.IsMouseDoubleClicked(0) && (current_path = dir)
				end
			end
			CImGui.EndChild()

			CImGui.Separator()

			if CImGui.Button("Cancel")
				(p_open != C_NULL) && (p_open[] = false)
				CImGui.CloseCurrentPopup()
			end
			CImGui.SameLine()
			if CImGui.Button("Select")
				selected_dir = folders[selected]
				on_select(folders[selected])
				(p_open != C_NULL) && (p_open[] = false)
				CImGui.CloseCurrentPopup()
			end
		end

		CImGui.EndPopup()
	end
end
