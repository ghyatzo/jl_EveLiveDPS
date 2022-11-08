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

const SIMULATED_LINES = [
"(combat) <color=0xff00ffff><b>353</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Pith Eliminator</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
"(combat) <color=0xffcc0000><b>68</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Dire Pithum Abolisher</b><font size=10><color=0x77ffffff> - Penetrates",
"(combat) <color=0xffcc0000><b>89</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Dire Pithum Inferno</b><font size=10><color=0x77ffffff> - Scourge Heavy Missile - Hits",
"(combat) <color=0xffcc0000><b>55</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Dire Pithum Abolisher</b><font size=10><color=0x77ffffff> - Scourge Heavy Missile - Hits",
"(combat) <color=0xff00ffff><b>353</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Pith Eliminator</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
"(combat) <color=0xffcc0000><b>72</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Dire Pithum Abolisher</b><font size=10><color=0x77ffffff> - Penetrates",
"(combat) <color=0xffcc0000><b>89</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Dire Pithum Inferno</b><font size=10><color=0x77ffffff> - Scourge Heavy Missile - Hits",
"(combat) <color=0xff00ffff><b>353</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Pith Eliminator</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
"(combat) <color=0xffcc0000><b>63</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Dire Pithum Abolisher</b><font size=10><color=0x77ffffff> - Penetrates",
"(combat) <color=0xff00ffff><b>353</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Pith Eliminator</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
"(combat) <color=0xff00ffff><b>353</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Pith Eliminator</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
"(combat) <color=0xff00ffff><b>353</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Pith Eliminator</b><font size=10><color=0x77ffffff> - Caldari Navy Inferno Light Missile - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo E Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo D Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo A Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo B Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
# "(combat) <color=0xffcc0000><b>1268</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo C Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
"(combat) <color=0xffcc0000><b>43</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Leuna town[SSPTI](Stabber)</b><font size=10><color=0x77ffffff> - 650mm Artillery Cannon II - Grazes",
"(combat) <color=0xffcc0000><b>443</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo H Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Penetrates",
"(combat) <color=0xffcc0000><b>306</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo H Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Glances Off",
"(combat) <color=0xffcc0000><b>396</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo H Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Hits",
"(combat) <color=0xffcc0000><b>437</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Matteo H Patel[EFE-X](Phantasm)</b><font size=10><color=0x77ffffff> - Heavy Beam Laser II - Penetrates",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
"(combat) <color=0xffccff66><b>488</b><color=0x77ffffff><font size=10> remote shield boosted by </font><b><color=0xffffffff><font size=12><color=0xFFFFB300><b>Scythe</b></color></font> <font size=11><color=0xFFFFFFFF>Jeram</color></font></b><color=0x77ffffff><font size=10> - Medium Murky Compact Remote Shield Booster</font>",
]


