include("utils.jl")
include("character.jl")
using Unicode: normalize

# (now() - now(UTC)) is in milliseconds. 1000*60*60: 
#		1000 milliseconds in a second, 60 seconds in a minute, 60 minute in an hour.
const TIMEZONE_DELTA = round(Int, (now() - now(UTC)).value*inv(1000*60*60)) # hours

mutable struct Parser
	log_directory::String 			# The game log folder
	overview_directory::String  	# the overview folder
	chars::Vector{AbstractCharacter}		# the array of currently loaded characters
	active_character::Union{AbstractCharacter, Nothing}		# the character currently being shown in the graph
	
	data::DataFrame 				# the database where we put the parsed informations
	max_entries::Int32   			# the max amount of entries that we allow in the database (prevent too much memory usage)
	max_history_seconds::Int32	 	# keep data in the database that does not span more than this much time
	
	delay::Float64 					# how frequently we check for new data
	run::Bool 						# the toggle for starting and stopping
	log_folder_watching_task::Task 	# the task that check the log_directory for new logs.

	Parser(log_directory, overview_directory, delay, max_entries, max_history_seconds) = begin
		parser = new()
		parser.chars = Character[]
		parser.active_character = nothing
		parser.delay = delay
		parser.run = false
		parser.data = DataFrame(
			Time=DateTime[],
			DamageIn=Int[],
			DamageOut=Int[],
			LogisticsIn=Int[],
			LogisticsOut=Int[],
			CapTransfered=Int[],
			CapReceived=Int[],
			CapDamageDone=Int[],
			CapDamageReceived=Int[],
			Mined=Float64[],
			Source=Union{String, Missing}[],
			Ship=Union{String, Missing}[],
			Weapon=Union{String, Missing}[],
			Application=Union{String, Missing}[]
		)

		parser.max_entries = max_entries
		parser.max_history_seconds = max_history_seconds

		if isvalidfolder(log_directory)
			parser.log_directory = log_directory
			parser.log_folder_watching_task = @async check_on_created(parser.log_directory) do file
				is_valid_character_log(file) && create_or_update_character!(parser, file)
			end
		else
			@error "Something went wrong while detecting the log directory" log_directory ispath(log_directory) isdir(log_directory)
			parser.log_directory = ""
			parser.log_folder_watching_task = Task(()->nothing)
		end

		if isvalidfolder(overview_directory)
			parser.overview_directory = overview_directory
		else
			@error "Something went wrong while detecting the overview directory" overview_directory ispath(overview_directory) isdir(overview_directory)
			parser.overview_directory = ""
		end
		return parser
	end
end
Parser(base_directory = nothing, delay = 0.5, max_entries = 5000, max_history = 60*3) = Parser(load_log_overview_folder(base_directory)..., delay, max_entries, max_history) #autodetects base_directory if not specified.

function update_log_directory!(parser, directory)
	if !isvalidfolder(directory)
		@error "The log directory must be a valid directory path"
		return
	end

	unwatch_folder(parser.log_directory)
	parser.log_directory = directory
	parser.log_folder_watching_task = @async check_on_created(parser.log_directory) do file
		is_valid_character_log(file) && create_or_update_character!(parser, file)
	end
end

function update_overview_directory!(parser, directory)
	if !isvalidfolder(directory)
		@error "The overview directory must be a valid directory path"
		return
	end
	parser.overview_directory = directory
end

function populate_characters!(parser)
	isvalidfolder(parser.log_directory) || (@warn "Invalid log folder"; return)

	log_files = get_log_files(parser.log_directory)
	length(log_files) == 0 && (@warn "No recent logs found.\nEither you haven't log in a while or the target directory is not correct."; return)

	for file in log_files
		try
			create_or_update_character!(parser, file)
		catch e
			@warn "Something went wrong while initialising the character for $file." e
			Base.show_backtrace(stderr, catch_backtrace())
			continue
		end
	end
	length(parser.chars) == 0 && @warn "I found some logs, but none of them were valid character logs."

	return nothing
end

function match_overview_file(char_name::AbstractString, dir)
	isvalidfolder(dir) || (@warn "Invalid overview directory"; return "")
	# matches the overview files `jeld_<name character>.*.yaml`
	# if more than one file is found with this pattern, only the first is loaded.

	files = readdir(dir; join=true)
	reg = Regex("(?:^jeld_)(?<name>\\Q$(normalize(char_name; casefold=true))\\E)(?:.*?\\.yaml)")
	overview = ""
	for file in files
		m = match(reg, normalize(basename(file); casefold=true))
		isnothing(m) && continue
		if !isempty(overview)
			@warn "Found another overview setting for $char_name. Ignoring.\nPlease make sure to only have the active in-game overview starting with `jeld_`."
			return overview
		end
		@info "Found a matching overview file. Loading $(basename(file))."
		overview = file
	end
	isempty(overview) && @warn "No overview settings found for $(char_name).\nMake sure you exported the overview in use,\nand renamed it to start with jeld_$(char_name)."
	return overview
end

function create_or_update_character!(parser, new_log)
	name, session = process_log_header(new_log)

	@info "Detected new log $new_log." name session
	(isnothing(name) || isnothing(session)) && return

	character_names = [char.name for char in parser.chars]
	idx = Base.findfirst(isequal(name), character_names)
	if isnothing(idx)
		@info "New Character!" new_log name session
		overview_file = match_overview_file(name, parser.overview_directory)
		newchar = Character(name, session, new_log, overview_file)
		push!(parser.chars, newchar)
	else
		@info "Character $name already had a log registered."
		char = parser.chars[idx]
		if session > char.session_start
			@info "The new file is newer, updating $name's combat log file."
			@logmsg LogLevel(1) "|------------------------------> COMBAT LOG CHANGE <-------------------------------|"
			char.log_reader.path = new_log
			char.session_start = session
		end
	end

	return nothing
end

isactive(char::AbstractCharacter, parser::Parser) = (char === parser.active_character)
function make_active!(char::AbstractCharacter, parser::Parser)
	isactive(char, parser) && isrunning(char) && return

	if !isnothing(parser.active_character)
		@info "Stopping Reader for $(parser.active_character.name)"
		stop_reading!(parser.active_character)
	end
	# replace the current active character with the selected one
	setfield!(parser, :active_character, char)
	@info "Started reading Log: $(parser.active_character.name)"
	@async start_reading!(parser.active_character)
end
function deactivate!(char::AbstractCharacter, parser::Parser)
	isactive(char, parser) || return

	@info "Stopping Reader for $(parser.active_character.name)"
	stop_reading!(parser.active_character)
end
function remove_char!(char::AbstractCharacter, parser::Parser)
	idx = findfirst(c -> ===(c, char), parser.chars)
	isnothing(idx) && return
	stop_reading!(char)
	if isactive(char, parser)
		parser.active_character = nothing
	end
	deleteat!(parser.chars, idx)
end

isrunning(parser::Parser) = getfield(parser, :run)
function start_parsing!(parser::Parser, live=true)
	# This would need an @async to function properly, decided to leave it outside the function body to make it explicit upon calling the method.
	isrunning(parser) && return

	if isnothing(parser.active_character)
		@warn "No Active Character. Ignoring."
		return
	end

	@info "Starting Parser for $(parser.active_character.name)"
	setfield!(parser, :run, true)
	while isrunning(parser)
		t = @elapsed try
			cleanup!(parser.data, parser.max_entries, parser.max_history_seconds; live)

			ch = getchannel(parser.active_character)
			dictionary = getdictionary(parser.active_character)
			while isready(ch)
				line = take!(ch)
				
				@logmsg LogLevel(1) replace(line, r"<.*?>" => s" ")
				if occursin(dictionary["relevant_line"], line)
					push!(parser.data, parse_line(line, dictionary))
				end
			end
		catch err
			@error "An error occured while parsing: Stopping" err
			println(stderr, err)
			Base.show_backtrace(stderr, catch_backtrace())
			break
		end
		if t < parser.delay
			sleep(parser.delay-t)
		end
	end
	setfield!(parser, :run, false)
end
function stop_parsing!(parser::Parser)
	setfield!(parser, :run, false)
	@info "Stopped parsing for $(parser.active_character.name)."
end

function parse_line(str, regex_dict)
	time, pilot_name, ship_type, weapon, application = extract_metadata(regex_dict, str)
	damage_out = extract_value_match(regex_dict["damage_out"], str)
	damage_in = extract_value_match(regex_dict["damage_in"], str)
	logistic_in = extract_value_match(regex_dict["shield_in"], str)
	logistic_in += extract_value_match(regex_dict["armor_in"], str)
	logistic_in += extract_value_match(regex_dict["hull_in"], str)
	logistic_out = extract_value_match(regex_dict["shield_out"], str)
	logistic_out += extract_value_match(regex_dict["armor_out"], str)
	logistic_out += extract_value_match(regex_dict["hull_out"], str)
	cap_transfer_out = extract_value_match(regex_dict["cap_transfer_out"], str)
	cap_transfer_in = extract_value_match(regex_dict["cap_transfer_in"], str)
	cap_transfer_in += extract_value_match(regex_dict["nos_drained_in"], str)
	cap_damage_done = extract_value_match(regex_dict["cap_damage_done"], str)
	cap_damage_done += extract_value_match(regex_dict["nos_drained_in"], str)
	cap_damage_taken = extract_value_match(regex_dict["cap_damage_taken"], str)
	cap_damage_taken += extract_value_match(regex_dict["nos_drained_out"], str)
	mined = extract_mining_M3(regex_dict["mined"], str) #units, not yet m3

	return [time,
			damage_in,
			damage_out,
			logistic_in,
			logistic_out,
			cap_transfer_out,
			cap_transfer_in,
			cap_damage_done,
			cap_damage_taken,
			mined,
			pilot_name,
			ship_type,
			weapon,
			application]
end

function extract_mining_M3(regex, str)
	m = match(regex, str)
	isnothing(m) && return 0
	ore = m[2]
	residue = m[3]
	units = m[1]
	vol = MINERAL_VOLUMES[ore]
	return parse(Int, units)*vol
end

function extract_value_match(regex, str)
	m = match(regex, str)
	return if isnothing(m) 0 else parse(Int, m[1]) end
end

function extract_metadata(regex_dict, str)
	time = DateTime(match(regex_dict["time"], str)[1], "yyyy.mm.dd HH:MM:SS")
	time += sign(TIMEZONE_DELTA)*Dates.Hour(abs(TIMEZONE_DELTA))

	m = match(regex_dict["metadata"], str)

	if isnothing(m) || isempty(m.match)
		@warn "Could not match the metadata of line: $str"
		return time, missing, missing, missing, missing
	else
		pilot_name = @something m[:default_pilot] m[:pilot_name] missing
		ship_type = @something m[:default_ship] m[:ship_type] pilot_name
		weapon = @something m[:default_weapon] m[:weapon] missing
		application = @something m[:application] missing
	end
	return time, pilot_name, ship_type, weapon, application
end
