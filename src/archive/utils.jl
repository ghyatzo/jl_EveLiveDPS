function tailf(f::Function, file, delay = 0.1)
	cur_position = 0
	while true
		try
			open(file, "r") do io
				seekend(io)
				if position(io) < cur_position
					seekstart(io)
				else
					seek(io, cur_position)
					for line in eachline(io)
						f(line)
					end
				end
				cur_position = position(io)
			end
		catch err
			@error err
		end
		sleep(delay)
	end
end
