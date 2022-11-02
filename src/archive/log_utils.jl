using Dates

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
