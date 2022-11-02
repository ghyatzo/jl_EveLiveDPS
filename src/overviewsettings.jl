using YAML

const _ESCAPE_CHARS = ['[', ']', '(', ')', '-', '$', '*', '?', '\\', '^', '{', '}', '+', '|', '#', '.', '`', ''',]
sanitise_spacers(s) = return if isempty(s) "" else Base.escape_string(s, _ESCAPE_CHARS) end

# regex string generation helpers
bold(str) = "<b>$str</b>"
italic(str) = "<i>$str</i>"
underscore(str) = "<u>$str</u>"
pre_post(str, pre, post) = "$pre$str$post"
color(str) = "<color=0x.{8}>$str</color>"
font(str) = "<font size=\\d+>$str</font>"
non_matching_group(str) = "(?:$str)"
named_matching_group(name, str) = "(?<$name>$str)"

# The typical log line influenced by the overview settings is broken down like so:
# Time: [ yyyy.mm.dd HH:MM:SS ]
# Section: (combat)
# Amount and Type: <color=0xffccff66><b>0</b><color=0x77ffffff><font size=10> remote shield boosted to </font>
# Metadata:
# 	header: <b><color=0xffffffff>
# 	<... Overview Dependent ...>
# 	Ship Type: <font size=12><color=0xFFFFB300><i><u><b>Imperial Navy Infiltrator</b></u></i></color></font>
# 	Ally: <font size=9><color=0xFFBF0000>&lt;<i><u><b>-TIME</b></u></i>&gt;</color></font>
# 	Corp: <font size=10><color=0xFF3380FF>[<i><u><b>DWAS</b></u></i>]</color></font>
# 	Separator: [o (no style)
# 	Pilot Name: <font size=14><color=0xFFF5DEB3> <i><u><b>Imperial Navy Infiltrator</b></u></i> </color></font>
# 	<... End ...>
# 	footer: </b>
# 	Weapon Type: <color=0x77ffffff><font size=10> - Small Murky Compact Remote Shield Booster</font>
# 
# Each group in the overview dependent section above can also be separated as:
# 
# 		font color pre italic underline bold STRING /bold /underline /italic post /color /font
#
# to correctly match STRING, we then generate a regular expression by wrapping `.*?` with the various descriptior
# as defined by the overview settings.
function build_capture_group(conf)
	type = conf["type"]
	(type == "linebreak") && return " "

	pre = sanitise_spacers(conf["pre"])
	post = sanitise_spacers(conf["post"])
	hascolor = haskey(conf, "color") && !isnothing(conf["color"])
	hasbold = haskey(conf, "bold") && Bool(conf["bold"])
	hasitalic = haskey(conf, "italic") && Bool(conf["italic"])
	hasunderline = haskey(conf, "underline") && Bool(conf["underline"])
	hasfont = haskey(conf, "fontsize") && !isnothing(conf["fontsize"])
	isactive = haskey(conf, "state") && Bool(conf["state"])

	if isnothing(type)
		if isactive
			reg = "(?:$pre)"
		else
			return ""
		end
	elseif !isactive
		# add empty matching groups when something is not active.
		# It makes it easier later to match on all groups automatically without checking if it's there or not.
		reg = named_matching_group(join(split(type), "_"), "")
	else
		reg = named_matching_group(join(split(type), "_"), ".*?")
		reg = hasbold ? bold(reg) : reg
		reg = hasunderline ? underscore(reg) : reg
		reg = hasitalic ? italic(reg) : reg
		reg = pre_post(reg, pre, post) # no check, when not present it is defined as an empty string.
		reg = hascolor ? color(reg) : reg
		reg = hasfont ? font(reg) : reg 
	end
	reg = non_matching_group(reg)
	return if type == "ship name" reg*"?" else reg end
end

function build_overview_metadata_regex(file)
	ispath(file) || error("Overview file $(basename(file)) doesn't exist.")
	data = YAML.load_file(file)
	("shipLabelOrder" in keys(data)) || error("Invalid overview file.")

	shipLabelOrder = data["shipLabelOrder"]
	hideCorpTicker = isempty(data["userSettings"]) ? false : data["userSettings"][1][2]
	shipLabels = Dict(v[1] => Dict(Pair(vv...) for vv in v[2]) for v in data["shipLabels"])
	header = ".*<b><color=0xf{8}>"
	reg = "$header"
	for (idx, shipLabel) in enumerate(shipLabelOrder)
		(shipLabel == "corporation" && hideCorpTicker) && continue
		(shipLabel == "linebreak" && (idx == 1 || idx == length(shipLabels))) && continue
		conf = shipLabels[shipLabel]
		reg *= build_capture_group(conf)
	end
	footer = "</b>"
	reg *= "$footer"

	reg *= raw".*> \-(?: (?<weapon>.*?)(?: \-|<)|.*)"
	return reg
end









