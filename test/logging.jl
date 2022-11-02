include("../src/log_handler.jl")

header(char, session_time) = begin 
	return """------------------------------------------------------------
		  Gamelog
		  Listener: $(char)
		  Session Started: $(session_time)
		------------------------------------------------------------"""
end
char_dict = Dict("6969747" => "buzz", "1234567" => "john")
dir = mktempdir()
file_names = ["20221010_193232_6969747.txt", "20221010_193233_6969747.txt", "20221010_193233_1234567.txt", "I_AM_NOT_A_LOG.txt"]
for name in file_names 
	file = touch(joinpath(dir, name))
	(name == "I_AM_NOT_A_LOG.txt") && continue
	char_id = match(r"(\d+).txt", name)[1]
	open(file, "w") do io
		write(io, header(char_dict[char_id], Dates.format(now(), "yyyy.mm.dd H:M:S")))

	end
	sleep(0.5)
end
logs = get_log_files(dir)


@testset verbose = true "Logging" begin
	@testset "Ignore files different than <num>_<num>_<num>.txt" begin
		@test !("I_AM_NOT_A_LOG.txt" in basename.(logs))
	end
	@testset "Only select the most recent log file for each character" begin
		@test basename.(logs) == ["20221010_193233_1234567.txt", "20221010_193233_6969747.txt"]
	end
	@testset "Character and Session Time are correctly extracted" begin
		tmplog, io = mktemp()
		try	write(io, header("michele", "2022.09.16 13:13:13")) finally close(io) end
		char, session_time = process_log_header(tmplog)

		@test char == "michele"
		@test session_time == DateTime("2022.09.16 13:13:13", "yyyy.mm.dd H:M:S")
	end
	@testset "Detects ill-formatted headers" begin
		bad_header_str = """------------------------------------------------------------
			  Gamelog
			------------------------------------------------------------
			JAOOASJDJ
			AJSDJASD
			ASDASJKDAJD
			AJSDKASDJASDALSDKJASD
			"""
		tmplog, io = mktemp()
		try write(io, bad_header_str) finally close(io) end

		@test_throws ErrorException process_log_header(tmplog)
	end
	@testset "New logs are detected and initialised" begin
		_combat_logs = CombatLog[]
		update_logs!(_combat_logs, dir)
		@test length(_combat_logs) == 2
		@test _combat_logs[1].log == logs[1]
		@test _combat_logs[1].character == process_log_header(logs[1])[1]
		@test _combat_logs[1].session_start == process_log_header(logs[1])[2]
		@test _combat_logs[2].log == logs[2]
		@test _combat_logs[2].character == process_log_header(logs[2])[1]
		@test _combat_logs[2].session_start == process_log_header(logs[2])[2]
	end
	@testset "Detect new session for existing character and change log file" begin

		# TODO: CHECK HOW TO EFFECTIVELY SWAP THE IOSTREAM.
		_combat_logs = CombatLog[]
		update_logs!(_combat_logs, dir)
		old_combat_log_idx = nothing
		old_combat_log = nothing
		for (idx, cl) in enumerate(_combat_logs)
			if cl.character == "buzz"
				old_combat_log_idx = idx
				old_combat_log = cl
			end
		end
		new_log = touch(joinpath(dir, "20221010_131313_6969747.txt"))
		new_time = Dates.format(now(), "yyyy.mm.dd H:M:S")
		open(new_log, "w") do io write(io, header("buzz", new_time)) end
		update_logs!(_combat_logs, dir)
		@test old_combat_log.character == _combat_logs[old_combat_log_idx].character
		@test _combat_logs[old_combat_log_idx].log == new_log
		@test Dates.format(_combat_logs[old_combat_log_idx].session_start, "yyyy.mm.dd H:M:S") == new_time
	end
end