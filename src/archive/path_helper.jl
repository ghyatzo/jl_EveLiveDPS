function load_log_directory()
	native_client_log_path = joinpath(homedir(), "Documents", "EVE", "logs", "Gamelogs")
	path = ""
	if Sys.iswindows() || Sys.isapple()
		if isdir(native_client_log_path)
			path = native_client_log_path
		end
	else
		if isdir(native_client_log_path)
			path = native_client_log_path
		else
			steam_proto_log_path = joinpath(homedir(), ".local/share/Steam/steamapps/compatdata/8500/pfx/drive_c/users/steamuser/My Documents/EVE/logs/Gamelogs")
			if isdir(steam_proto_log_path)
				path = steam_proto_log_path
			end
		end
	end
	if isempty(path)
		@error "No log Directory Detected. Tried locations:" native_client_log_path, steam_proto_log_path
		error("No Log Directory Detected:")
	else
		@info "Log Directory Path: $path" 
		return path
	end
end

function load_overview_directory()
	if Sys.iswindows() || Sys.isapple()
		native_client_path = joinpath(homedir(), "Documents", "EVE", "Overview")
		path = isdir(native_client_path) ? native_client_path : ""
	else
		# TODO IN LINUX
		# TODO IN LINUX - STEAM/PROTO
	end
	if isempty(path)
		@error :"No overview folder found. I searched at these locations: " native_client_path
		error("No overview folder found.")
	else
		@info "Overview folder path: $path"
		return path
	end
end