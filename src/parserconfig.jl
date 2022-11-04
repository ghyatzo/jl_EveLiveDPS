include("overviewsettings.jl")

const _REGEX_STRINGS = Dict(
	"time" => raw"^\[ (.*) \]",
	"damage_in" => raw"<.*?><b>(\d+).*>from<",
	"damage_out" => raw"<.*?><b>(\d+).*>to<",
	"armor_out" => raw"<.*?><b>(\d+).*> remote armor repaired to <",
    "hull_out" => raw"<.*?><b>(\d+).*> remote hull repaired to <",
    "shield_out" => raw"<.*?><b>(\d+).*> remote shield boosted to <",
    "armor_in" => raw"<.*?><b>(\d+).*> remote armor repaired by <",
    "hull_in" => raw"<.*?><b>(\d+).*> remote hull repaired by <",
    "shield_in" => raw"<.*?><b>(\d+).*> remote shield boosted by <",
    "cap_transfer_out" => raw"\<.*?><b>(\d+).*> remote capacitor transmitted to <",
    "cap_transfer_in" => raw"\<.*?><b>(\d+).*> remote capacitor transmitted by <",
    "cap_damage_done" => raw"\<.*?ff7fffff><b>(\d+).*> energy neutralized <",
    "cap_damage_taken" => raw"\<.*?ffe57f7f><b>(\d+).*> energy neutralized <",
    "nos_drained_in" => raw"\<.*?><b>\+(\d+).*> energy drained from <",
    "nos_drained_out" => raw"\<.*?><b>\-(\d+).*> energy drained to <",
    "mined" => raw"\(mining\) .*? <.*?><.*?>(\d+).*> units of <.*?><.*?>(.+?)<"
)
const _META_STRINGS = Dict(
	"relevant_line" => raw"(?:\(combat\)|\(mining\))(?!(?:.*misses|.*jammed|.*Warp))",
	"default_metadata" => raw"(?:.*f{8}>(?<default_pilot>[^\(\)<>]*)(?:\[.*\((?<default_ship>.*)\)<|<)/b.*> \-(?: (?<default_weapon>.*?)(?: \-|<))?(?: (?<application>\w+\s?\w+$)?))"
	# "default_metadata" => raw"(?:.*f{8}>(?<default_pilot>[^\(\)<>]*)(?:\[.*\((?<default_ship>.*)\)<|<)/b.*> \-(?: (?<default_weapon>.*?)(?: \-|<)|.*))"
)

function compile_regex(strings::Dict)
	dict = Dict{String, Regex}()
	for key in keys(strings)
		dict[key] = Regex(strings[key])
	end
	return dict
end

function compile_metadata_regex(overviewsettings, default_str)
	overview_str = build_overview_metadata_regex(overviewsettings)
	overview_str *= "|" * default_str
	final = non_matching_group(overview_str)
	return Regex(final)
end

function build_regular_expressions(overview_file)
	@info "Compiling Regular Expressions."
	overview_file = isnothing(overview_file) ? "" : overview_file
	if !isempty(overview_file) && ispath(overview_file)
		metadata_regex = compile_metadata_regex(overview_file, _META_STRINGS["default_metadata"])
	else
		placeholders = ["ship_type", "alliance", "pilot_name", "ship_name", "weapon"]
		dummy_placeholder = non_matching_group(mapreduce(name -> named_matching_group(name, ""), *, placeholders))
		metadata_regex = Regex(_META_STRINGS["default_metadata"]*"|"*dummy_placeholder)
	end
	compiled_regexes = compile_regex(_REGEX_STRINGS)
	compiled_regexes["metadata"] = metadata_regex
	compiled_regexes["relevant_line"] = Regex(_META_STRINGS["relevant_line"])

	return compiled_regexes
end