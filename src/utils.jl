using FileWatching
using Dates
using DataFrames

function check_on_created(callb::Function, dir)
	last_registered = ""
	while true
		try
			file, event = watch_folder(dir)
			long_path = joinpath(dir, file)

			if event.renamed == true && ispath(long_path) && long_path != last_registered
				# don't know why but upon a combat log creation this event fires twice. We avoid the second one.
				last_registered = long_path
				# we exclude real renames, and deletions by checking that the file exists in the path.
				# sadly, renaming generates two events with event.renamed = true. One with the old file name
				# and one with the new. We can exclude the one with the old file name by checking that the file exist
				# but we can't reliably exclude the second event which has the new modified name.
				# hence we will just pass it along, all in all, it is practically a new file to check ;)
				callb(long_path)
			end
		catch err
			Base.show_exception_stack(stdin, stacktrace(catch_backtrace()))
			#call unwatch_folder(dir) to end the task
			@info "Folder watching task terminated."
			break
		end
	end
end

function valid_columns(df::AbstractDataFrame, cols::Vector{T}) where T <: Union{Symbol, String}
	return all(valid_columns.(Ref(df), cols))
end
valid_columns(df::AbstractDataFrame, col::Symbol) = in(col, propertynames(df))
valid_columns(df::AbstractDataFrame, col::String) = in(col, names(df))

function cleanup!(data::AbstractDataFrame, max_entries, max_history_time; live=false)
	isempty(data) && return

	if size(data, 1) > max_entries
		excess = size(data, 1) - max_entries
		deleteat!(data, 1:excess)
	end

	valid_columns(data, :Time) || (@warn "The database does not have a :Time column. Ignoring"; return)
	# assumes DateTime format
	t0 = live ? now() : data.Time[end]
	t_bound = t0 - Dates.Second(max_history_time)
	if data.Time[1] < t_bound
		filter!(:Time => t -> t > t_bound, data)
	end
end

################################## DIRECTORY FINDING #################################
isvalidfolder(path) = !isnothing(path) && ispath(path) && isdir(path)

function game_basedir()
	default_log_path = joinpath(homedir(), "Documents", "EVE")
	if isvalidfolder(default_log_path)
		@info "Game files folder $default_log_path"
		return default_log_path
	else
		@error "Game folder not found"
		return ""
	end
end
function load_log_overview_folder(base_directory = nothing)
	gamebasedir = isvalidfolder(base_directory) ? base_directory : game_basedir()

	if isvalidfolder(gamebasedir)
		log_dir = joinpath(gamebasedir, "logs", "Gamelogs") |> normpath
		over_dir = joinpath(gamebasedir, "Overview") |> normpath
		
		if isdir(log_dir) && isdir(over_dir)
			return log_dir, over_dir
		else
			@error "Either 'Gamelogs' or 'Overview' folders are not in their default locations."
			return "", ""
		end		
	else
		@error "Could not detect a valid game base directory: " gamebasedir
		return "",""
	end
end

######################################### LOG FILE HANDLING HELPER FUNCTIONS ##########################################

function is_valid_character_log(file)
	# keep only characters logs newer than a day.
	return occursin(r"\d+_\d+_\d+\.txt", basename(file)) && Dates.unix2datetime(mtime(file)) >= now() - Dates.Day(1)
end

function get_log_files(dir)
	files = readdir(dir; join=true)
	filter!(is_valid_character_log, files)
	sort!(files, by=mtime, rev=true) # newest first (biggest unix date number)
	unique!(files) do file
		match(r"_(\d+)\.txt", file)[1]
	end # ignore the older files.

	@info "Candidate log files" files
	
	return files
end

function process_log_header(log)
	char_line = session_line = ""
	open(log, "r") do io
		readline(io)
		readline(io)
		char_line = readline(io)
		session_line = readline(io)
	end

	char = match(r"(?<=Listener: ).*", char_line)
	session = match(r"(?<=Session Started: ).*", session_line)
	if !isnothing(char) && !isnothing(session)
		return char.match, DateTime(session.match, "yyyy.mm.dd H:M:S")
	else
		@warn "$(basename(log)) is an invalid character log."
		return nothing, nothing
	end
end