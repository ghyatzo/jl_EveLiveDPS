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
    "mined" => raw"\(mining\) .*? <.*?><.*?>(\d+).*> units of <.*?><.*?>(.+?)<.*?residue of <.*?><.*?>(.+?)<"
)
const _META_STRINGS = Dict(
	"relevant_line" => raw"(?:\(combat\)|\(mining\))(?!(?:.*misses|.*jammed|.*Warp))",
	"default_metadata" => raw"(?:.*f{8}>(?<default_pilot>[^\(\)<>]*)(?:\[.*\((?<default_ship>.*)\)<|<)/b.*> \-(?: (?<default_weapon>.*?)(?: \-|<))?(?: (?<application>\w+\s?\w+$)?))"
	# "default_metadata" => raw"(?:.*f{8}>(?<default_pilot>[^\(\)<>]*)(?:\[.*\((?<default_ship>.*)\)<|<)/b.*> \-(?: (?<default_weapon>.*?)(?: \-|<)|.*))"
)

const MINERAL_VOLUMES = Dict(
	"Veldspar"				=> 0.1,
	"Concentrated Veldspar"	=> 0.1,
	"Dense Veldspar"		=> 0.1,
	"Scordite"				=> 0.15,
	"Condensed Scordite"	=> 0.15,
	"Massive Scordite"		=> 0.15,
	"Pyroxeres"				=> 0.3,
	"Solid Pyroxeres"		=> 0.3,
	"Viscous Pyroxeres"		=> 0.3,
	"Plagioclase"			=> 0.35,
	"Azure Plagioclase"		=> 0.35,
	"Rich Plagioclase"		=> 0.35,
	"Omber"					=> 0.6,
	"Silvery Omber"			=> 0.6,
	"Golden Omber"			=> 0.6,
	"Kernite"				=> 1.2,
	"Luminous Kernite"		=> 1.2,
	"Fiery Kernite"			=> 1.2,
	"Jaspet"				=> 2,
	"Pure Jaspet"			=> 2,
	"Pristine Jaspet"		=> 2,
	"Hemorphite"			=> 3,
	"Vivid Hemorphite"		=> 3,
	"Radiant Hemorphite"	=> 3,
	"Hedbergite"			=> 3,
	"Vitric Hedbergite"		=> 3,
	"Glazed Hedbergite"		=> 3,
	"Gneiss"				=> 5,
	"Iridescent Gneiss"		=> 5,
	"Prismatic Gneiss"		=> 5,
	"Dark Ochre"			=> 8,
	"Onyx Ochre"			=> 8,
	"Obsidian Ochre"		=> 8,
	"Crokite"				=> 16,
	"Sharp Crokite"			=> 16,
	"Crystalline Crokite"	=> 16,
	"Spodumain"				=> 16,
	"Bright Spodumain"		=> 16,
	"Gleaming Spodumain"	=> 16,
	"Bistot"				=> 16,
	"Triclinic Bistot"		=> 16,
	"Monoclinic Bistot"		=> 16,
	"Arkonor"				=> 16,
	"Crimson Arkonor"		=> 16,
	"Prime Arkonor"			=> 16,
	"Mercoxit"				=> 40,
	"Magma Mercoxit"		=> 40,
	"Vitreous Mercoxit"		=> 40
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