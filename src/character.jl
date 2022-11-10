using Dates

include("log_reader.jl")
include("parserconfig.jl")

mutable struct Character
	const name::String
	session_start::DateTime
	log_reader::TailReader
	customoverview::String
	compiled_regexes::Dict{String, Regex}
	Character(name, session, logpath, oviewpath) = new(
		name,
		session,
		TailReader(logpath),
		oviewpath,
		build_regular_expressions(oviewpath)
	)
end

isrunning(C::Character) = isrunning(C.log_reader)
start_reading!(C::Character) = start!(C.log_reader)
stop_reading!(C::Character) = stop!(C.log_reader)
getchannel(C::Character) = getchannel(C.log_reader)
readerdelay(C::Character) = getfield(C.log_reader, :delay)
getlog(C::Character) = getfield(C.log_reader, :path)

#expand this to relive fight.
rereadlog(C::Character) = resetposition!(C.log_reader)

hascustomoverview(C::Character) = !isempty(C.customoverview)
getdictionary(C::Character) = getfield(C, :compiled_regexes)

function update_overview!(C::Character, file)
	@info "Updating overview file for $(C.name).\n Rebuilding regular expressions with $file"
	new_regex_dict = build_regular_expressions(file)
	@info "Metadata string is: $(new_regex_dict["metadata"])"
	C.compiled_regexes = new_regex_dict
	C.customoverview = file
end


####################### Simulations ######################

mutable struct SimulatedCharacter
	const name::String
	session_start::DateTime
	simulated_lines::Vector{String}
	customoverview::String
	compiled_regexes::Dict{String, Regex}
	channel::Channel{String}
	run::Bool
end
SimulatedCharacter(name, overview = "") = SimulatedCharacter(
	name,
	now(),
	SIMULATED_LINES,
	overview,
	build_regular_expressions(overview),
	Channel{String}(4096),
	false
)

function start_reading!(SC::SimulatedCharacter)
	isrunning(SC) && return

	setfield!(SC, :run, true)
	while SC.run
		line = rand(SC.simulated_lines)
		time = now(UTC)
		timestr = "[ "*Dates.format(time, "yyyy.mm.dd HH:MM:SS")*" ] "

		put!(SC.channel, timestr*line)
		sleep(rand(0.95:0.05:1.05))
		# sleep(4.52)
	end
	setfield!(reader, :run, false)
end
stop_reading!(SC::SimulatedCharacter) = setfield!(SC, :run, false)
isrunning(SC::SimulatedCharacter) = getfield(SC, :run)
getchannel(SC::SimulatedCharacter) = getfield(SC, :channel)
hascustomoverview(SC::SimulatedCharacter) = !isempty(SC.customoverview)
readerdelay(SC::SimulatedCharacter) = rand()
getlog(SC::SimulatedCharacter) = "The Universe."
getdictionary(SC::SimulatedCharacter) = getfield(SC, :compiled_regexes)

function update_overview!(SC::SimulatedCharacter, file)
	@info "Updating overview file for $(SC.name).\n Rebuilding regular expressions with $file"
	new_regex_dict = build_regular_expressions(file)
	@info "Metadata string is: $(new_regex_dict["metadata"])"
	SC.compiled_regexes = new_regex_dict
	SC.customoverview = file
end

generate_line_dps_out(dmg_min=1, dmg_max = 100) = begin
	appl_str = ["Hits", "Hits", "Hits", "Penetrates", "Glances Off", "Wrecks", "Grazes", "Smashes"]
	"(combat) <color=0xff00ffff><b>$(rand(dmg_min, dmg_max))</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target $(rand(1:4))</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - $(rand(appl_str))"
end

const SIMULATED_LINES = [
# "(combat) <color=0xff00ffff><b>100</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target 1</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
# "(combat) <color=0xff00ffff><b>200</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target 1</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Penetrates",
# "(combat) <color=0xff00ffff><b>300</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target 1</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Grazes",
# "(combat) <color=0xff00ffff><b>150</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target 2</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Glances Off",
# "(combat) <color=0xff00ffff><b>250</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target 2</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
# "(combat) <color=0xff00ffff><b>350</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Target 2</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
"(combat) <color=0xffcc0000><b>60</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Source 1</b><font size=10><color=0x77ffffff> - Penetrates",
"(combat) <color=0xffcc0000><b>70</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Source 2</b><font size=10><color=0x77ffffff> - Scourge Heavy Missile - Hits",
"(combat) <color=0xffcc0000><b>80</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Source 1</b><font size=10><color=0x77ffffff> - Scourge Heavy Missile - Hits",
"(combat) <color=0xffcc0000><b>90</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Source 1</b><font size=10><color=0x77ffffff> - Hits",
"(combat) <color=0xffcc0000><b>100</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Source 2</b><font size=10><color=0x77ffffff> - Scourge Heavy Missile - Hits",
"(combat) <color=0xffcc0000><b>110</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Source 1</b><font size=10><color=0x77ffffff> - Penetrates",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player A[EFE-X](Ship 1)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player B[EFE-X](Ship 2)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player C[EFE-X](Ship 3)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player D[EFE-X](Ship 4)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player E[EFE-X](Ship 5)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>43</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 1[SSPTI](Ship 1)</b><font size=10><color=0x77ffffff> - 650mm Artillery Cannon II - Wrecks",
# "(combat) <color=0xffcc0000><b>78</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 1[SSPTI](Ship 1)</b><font size=10><color=0x77ffffff> - 650mm Artillery Cannon II - Grazes",
# "(combat) <color=0xffcc0000><b>47</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 1[SSPTI](Ship 1)</b><font size=10><color=0x77ffffff> - 650mm Artillery Cannon II - Hits",
# "(combat) <color=0xffcc0000><b>55</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 1[SSPTI](Ship 1)</b><font size=10><color=0x77ffffff> - 650mm Artillery Cannon II - Smashes",
# "(combat) <color=0xffcc0000><b>443</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 2[EFE-X](Ship 2)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Penetrates",
# "(combat) <color=0xffcc0000><b>306</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 2[EFE-X](Ship 2)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Glances Off",
# "(combat) <color=0xffcc0000><b>396</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 2[EFE-X](Ship 2)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>437</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Player 2[EFE-X](Ship 2)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Penetrates",
]


