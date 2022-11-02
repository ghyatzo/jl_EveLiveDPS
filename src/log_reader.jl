
mutable struct TailReader
	path::String
	pos::Integer
	delay::Real
	run::Bool
	const channel::Channel{String}
end
TailReader(path) = TailReader(path, 0, 0.5, false, Channel{String}(4096))
TailReader(path, delay::Real) = TailReader(path, 0, delay, false, Channel{String}(4096))

# Needs an @async in front for correct behaviour, It was not included in the function itself for clarity when called.
function start!(reader::TailReader)
	reader.run && (@warn "Logger already running. Ignoring"; return)

	# Continiously reopen the file, this allows for automatic handling of logrotations,
	# renames and errors.

	setfield!(reader, :run, true)
	while reader.run
		try
			open(reader.path, "r") do file
				seekend(file)
				if position(file) < reader.pos
					# the log file has changed/was rotated/got truncated, go to the beginning
					seekstart(file)
				else
					seek(file, reader.pos)
					for line in eachline(file)
						# if used with an unbuffered channel (Channel(0)),
						# the process hangs here until a `take!(ch)` is invoked somewhere.
						put!(reader.channel, line)
					end
				end
				reader.pos = position(file)
			end
		catch err
			@error "Error while reading the log" exception = (err, catch_backtrace())
			continue
		end
		sleep(reader.delay)
	end
	@info "Stopped reading Log: $(reader.path)"
	setfield!(reader, :run, false)
end
stop!(reader::TailReader) = setfield!(reader, :run, false)
isrunning(reader::TailReader) = getfield(reader, :run)
getchannel(reader::TailReader) = getfield(reader, :channel)
resetposition!(reader::TailReader) = reader.pos = 0