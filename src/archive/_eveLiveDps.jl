using Dates
using DataFrames
using Term
using Term.Layout
using UnicodePlots
using REPL: Terminals

include("termutils.jl")

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
		throw(error("No Log Directory Detected:"))
	else
		@info "Log Directory Path: " path
		return path
	end
end

const LOG_DIRECTORY = load_log_directory()

const THROTTLE_SECONDS = 0.2
const HISTORY_MIN_ENTRIES = 3
const HISTORY_MAX_ENTRIES = 2000
const HISTORY_MAX_TIME_WINDOW_SECONDS = 60*1 #keep an history of 1 minutes

function parser(str)
	DATE_FORMAT="y.m.d H:M:S"

	date = DateTime(match(r"\[ (.+) \]", str)[1], DATE_FORMAT) + Dates.Hour(2) #Eve online server time is -2h local time.

	damage_match = match(r">(\d+)<", str)
	damage = isnothing(damage_match) ? 0 : parse(Int, damage_match[1])

	directions = match(r"(to|from|by).+>(.+)<\/b>", str)
	direction = directions[1] == "to" ? "outgoing" : "incoming"
	target_source = directions[2]

	missile = match(r" - (.+) -", str)
	weapon = isnothing(missile) ? "Gunnery" : missile[1]
	application = match(r"(\w+\s\w+|\w+)$", str)[1]

	return [date, damage, direction, target_source, weapon, application]
end

function read_log_stream!(data, iostream)
	#ignore non-combat lines or combat lines with misses or jamms
	reg = r"\(combat\)(?!.*misses)(?!.*jammed)"

	while !eof(iostream)
		line = readline(iostream)
		!occursin(reg, line) && continue
		push!(data, parser(line))
	end
end

function test_log_stream!(data)
	while true
		sleep(rand(0.1:0.1:1))
		sources = ["Pithati Mother", "H-PA crew mother", "Motherfather", "Titan Mather"]
		application = ["Penetrates", "Hits", "Glances Off", "Smashes"]
		push!(data, [now(), rand(1:100), rand(["incoming","outgoing"]), rand(sources), "Gunnery", rand(application)])
	end
end

## Select the correct Log File
# TODO: make this for windows as well?
function select_log_file()
	files = readdir(LOG_DIRECTORY; join=true)
	filter!(files) do file
		occursin(r"\d+_\d+_\d+", basename(file))
	end
	return files[findmax(mtime.(files))[2]]
end

function get_character_name(iostream)
	character = ""
	for _ = 1:5 #Log files have a 5 lines header.
		line = readline(iostream)
		m = match(r"(?<=Listener: )(.*)", line)
		!isnothing(m) && return m.match
	end
end

function sma(df, time_window_seconds, key)
	values = @view df[df.Time .> now() - Dates.Second(time_window_seconds), key]
	return isempty(values) ? 0 : round(Int, sum(values)/time_window_seconds)
end

function clean_db!(data, max_entries, max_history_time)
	isempty(data) && return

	if size(data, 1) > max_entries
		excess =  size(data, 1) - max_entries
		deleteat!(data, 1:excess) #FIFO
	end

	t_bound = now() - Dates.Second(max_history_time) #not older than this
	if (data.Time[1] < t_bound)
		filter!(:Time => t -> t > t_bound, data)
	end
end

function main()
	chide()
	display_size(46, 74)
	clear_screen()
	
	df = DataFrame(Time=DateTime[], Damage=Int[], Direction=String[], Target_Source=String[], Weapon_Type=String[], Application=String[])
	incoming_stat_df = DataFrame(Time=DateTime[], Mean_DPS=Float64[], SMA_DPS=Float64[])
	outgoing_stat_df = DataFrame(Time=DateTime[], Mean_DPS=Float64[], SMA_DPS=Float64[])

	LOGFILE = select_log_file()
	io = open(LOGFILE, "r"; lock=false)
	CHARACTER = get_character_name(io)
	@info "Log file: " basename(LOGFILE) CHARACTER;
	sleep(0.5)

	## Start Services
	# Monitor inputs and exit gracefully with ctrl-C
	monitor(() -> begin
		close(io)
		display_size(30, 100)
		clear_screen()
		exit()
	end)
	# read the log file and save to the database each entry.
	@async read_log_stream!(df, io)
	# @async test_log_stream!(df)

	# If an old log is opened, or the log contains old entries, purge them immediately.
	Timer(t -> clean_db!(df, HISTORY_MAX_ENTRIES, HISTORY_MAX_TIME_WINDOW_SECONDS), 0, interval=1)
	Timer(t -> clean_db!(incoming_stat_df, HISTORY_MAX_ENTRIES, HISTORY_MAX_TIME_WINDOW_SECONDS), 0, interval=1)
	Timer(t -> clean_db!(outgoing_stat_df, HISTORY_MAX_ENTRIES, HISTORY_MAX_TIME_WINDOW_SECONDS), 0, interval=1)	

	DefaultHeader = Panel("{gold1 bold}EvE Live DPS{/gold1 bold}\n{gray}$(CHARACTER){/gray}"; fit=true, box=:SIMPLE, justify=:center)

	NoCombatPanel = Panel(
					PlaceHolder(5, 24; style="bold gold1") * 
					Panel("{bold gold1}NO COMBAT{/bold gold1}"; height=5, width=20, justify=:center, box=:HEAVY, style="gold1", padding=(2,2,1,1)) * 
					PlaceHolder(5, 24; style="bold gold1"); 
					fit=true, box=:SIMPLE, justify=:center)
	header_panel = DefaultHeader
	Timer(t -> begin
		if size(df,1) <= HISTORY_MIN_ENTRIES
			header_panel = NoCombatPanel
		else
			header_panel = DefaultHeader
		end
	end, 0, interval = 5)

	while true
		sleep(THROTTLE_SECONDS)

		if select_log_file() != LOGFILE
			close(io)
			LOGFILE = select_log_file()
			header_panel = Panel("{bold cyan}Info:{/bold cyan} Detected a newer logfile, switching...\n"*basename(LOGFILE);
			 box=:HEAVY, justify=:center, style="cyan bold")

			io = open(LOGFILE, "r"; lock=false)
		end

		if size(df, 1) <= HISTORY_MIN_ENTRIES
			display_size(8, 74)
			clear_screen()
			print(header_panel)
			continue
		end

		### DATA ANALYSIS

		dT = (df.Time[end]-df.Time[1]).value/1000 #seconds
		current_time_span = dT == 0 ? 0.1 : dT

		## Incoming
		incoming_df = filter(:Direction => ==("incoming"), df)

		# 20 and 60 seconds moving averages.
		inc_sma = sma(incoming_df, 20, :Damage)
		mean_inc_dps = round(Int, sum(incoming_df.Damage)/current_time_span)

		push!(incoming_stat_df, [now(), mean_inc_dps, inc_sma])

		inc_gd = groupby(incoming_df, :Target_Source)
		worst_offenders = sort(combine(inc_gd, :Damage => sum => :Damage), :Damage, rev=true)
		heavy_hitters = sort(combine(inc_gd, :Damage => maximum => :Max_Damage), :Max_Damage, rev=true)
		# TODO Check how often they hit, and use it to show some kind of group dps.

		inc_gd = groupby(incoming_df, :Application)
		app_distribution = combine(inc_gd, :Direction => length => :Count)

		## Outgoing
		outgoing_df = filter(:Direction => ==("outgoing"), df)

		out_sma = sma(outgoing_df, 15, :Damage)
		mean_out_dps = round(Int, sum(outgoing_df.Damage)/current_time_span)

		push!(outgoing_stat_df, [now(), mean_out_dps, out_sma])

		### INTERFACE
		display_size(46, 74)
		clear_screen()

		IncomingPanel = Panel("{bold red}$(mean_inc_dps){/bold red}"*Spacer(1,7)*"{bold yellow}$(inc_sma){/bold yellow}";
		    justify=:left, title="Incoming", title_style="italic", title_justify=:center,
			padding=(3,3,0,0), fit=true, style="gray", box=:ROUNDED
		)
		OutgoingPanel = Panel("{bold cyan}$(out_sma){/bold cyan}"*Spacer(1,7)*"{bold blue}$(mean_out_dps){/bold blue}";
			justify=:right, title="Outgoing", title_style="italic", title_justify=:center,
			padding=(3,3,0,0), fit=true, style="gray", box=:ROUNDED
		)

		inc_plt = lineplot(incoming_stat_df.Time, [incoming_stat_df.SMA_DPS incoming_stat_df.Mean_DPS];
			name=["sma20" "sma60"], height=6, border=:none, color=[:yellow :red])
		label!(inc_plt, :bl, "-1m")
		label!(inc_plt, :br, "t")
		out_plt = lineplot(outgoing_stat_df.Time, [outgoing_stat_df.SMA_DPS outgoing_stat_df.Mean_DPS];
			name=["sma20" "sma60"], height=6, border=:none, color=[:cyan :blue])
		label!(out_plt, :bl, "-1m")
		label!(out_plt, :br, "t")

		incPlotPanel = Panel(string(inc_plt; color=true); 
			fit=true, box=:MINIMAL, title="Incoming", title_style="bold")
		outPlotPanel = Panel(string(out_plt; color=true); 
			fit=true, box=:MINIMAL, title="Outgoing", title_style="bold")

		worst_offender_plt = barplot(first(worst_offenders, 4).Target_Source, first(worst_offenders, 4).Damage;
			color=:red)
		worstOffenderPanel = Panel(string(worst_offender_plt; color=true);
			fit=true, box=:MINIMAL, title="Worst Offender", title_justify=:left, title_style="bold")

		heavy_hitter_plt = barplot(first(heavy_hitters, 4).Target_Source, first(heavy_hitters, 4).Max_Damage;
			color=:yellow)
		heavyHitterPanel = Panel(string(heavy_hitter_plt; color=true);
			fit=true, box=:MINIMAL, title="Heavy Hitter", title_justify=:left, title_style="bold")

		num_panel = (IncomingPanel * Spacer(3,5) * OutgoingPanel)
		plt_panel1 = incPlotPanel
		plt_panel2 = outPlotPanel
		bar_panel1 = worstOffenderPanel
		bar_panel2 = heavyHitterPanel
		center!(header_panel, num_panel, plt_panel1, plt_panel2, bar_panel1, bar_panel2)
		println(
			header_panel/num_panel/plt_panel1/plt_panel2/bar_panel1/bar_panel2
		)
	end
end

gaussian_kernel(x, gamma) = inv(gamma*2*pi)*exp(-x^2/2*gamma^2)
function gaussian_smoothing(values; gamma=2)
	smoothed_values = similar(values)
	length(values)
	for i in eachindex(values)
		weigths = gaussian_kernel.(values[i] .- values, gamma)
		length(weigths)
		smoothed_values[i] = dot(values, weigths) ./ sum(weigths)
	end
	return smoothed_values
end

main()

# TODO:	Parse neuting.
# TODO: gracefully exit

