	function check_base_folders(parser)
		# force the existance of these folders. If both are missing or are invalid, don't bother with the overview folder
		# if there isn't the log one, which is more important.
		isvalidfolder(parser.log_directory) || CImGui.OpenPopup("Error##log")
		isvalidfolder(parser.log_directory) && !isvalidfolder(parser.overview_directory) && CImGui.OpenPopup("Error##overview")

		if CImGui.BeginPopupModal("Error##log", C_NULL,  CImGui.ImGuiWindowFlags_AlwaysAutoResize)
			CImGui.TextColored([1.0, 0.2, 0.0, 1.0], "ERROR:")
			CImGui.Text("The application needs a valid game log folder path.")
			CImGui.Dummy((10,10))
			CImGui.Text("Automatic detection failed. Please select it manually.")
			CImGui.Dummy((15,15))
			if CImGui.Button("Select Log Folder")
				CImGui.OpenPopup("Select Folder")
			end
			CImGui.SetNextWindowSize((487,270), CImGui.ImGuiCond_FirstUseEver)
			SelectDirectoryModal("Select Folder", (path) -> begin
				update_log_directory!(parser, path)
			end)

			isvalidfolder(parser.log_directory) && CImGui.CloseCurrentPopup()
			CImGui.EndPopup()
		end
		if CImGui.BeginPopupModal("Error##overview", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
			CImGui.TextColored([1.0, 0.6, 0.3, 1.0], "WARNING:")
			CImGui.Text("The application needs a valid overview folder path\n\
				for automatic overview setting detection.")
			CImGui.Dummy((10,10))
			CImGui.Text("Automatic detection failed. Please select it manually.")
			CImGui.Dummy((15,15))
			CImGui.Button("Select Overview Folder") && CImGui.OpenPopup("Select Folder")

			CImGui.SetNextWindowSize((475,175), CImGui.ImGuiCond_FirstUseEver)
			SelectDirectoryModal("Select Folder", (path) -> begin
				update_overview_directory!(parser, path)
			end)

			isvalidfolder(parser.overview_directory) && CImGui.CloseCurrentPopup()
			CImGui.EndPopup()
		end
	end