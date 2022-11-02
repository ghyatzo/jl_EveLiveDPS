using REPL

cdown(n) = print("\x1B[$(n)B")
cup(n) = print("\x1B[$(n)A")
cleft(n) = print("\x1B[$(n)D")
cright(n) = print("\x1B[$(n)C")
cbegin_up(n) = print("\x1B[$(n)F")
cbegin_down(n) = print("\x1B[$(n)E")
chome() = cline(0)
cline(n) = print("\x1B[$(n);0H")
cmove(l,c) = print("\x1B[$(l);$(c)H")
chide() = print("\x1B[?25l")
cshow() = print("\x1B[?25h")

clear_screen() = begin 
	print("\x1B[2J")
	chome()
end
erase_line() = print("\x1B[2K")
erase_left_of_cursor() = print("\x1B[1J")
erase_right_of_cursor() = print("\x1B[0J")

erase_line_above() = begin 
	cbegin_up(1)
	erase_line()
end
erase_line_below() = begin 
	cbegin_down(1)
	erase_line()
end
refresh_below_line(n) = begin
	cline(n+1)
	print("\x1B[0J")
end
refresh_above_line(n) = begin
	cline(n)
	erase_line()
	print("\x1B[1J")
	cline(1)
end

display_size(H, W) = print("\x1b[8;$(H);$(W)t")

# Asynchronously listens on term stdin (keypresses) in RAW mode. Intercept Ctrl-C, Ctrl-D and Q and runs callb on exit.
monitor(callb::Function) = @async begin
	term = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)
	try
		REPL.Terminals.raw!(term, true)
		while !eof(term)
			c = read(term, Char)
			c == 'Q' && break
			c in ['\x3', '\x4', 'Q'] && break # ^C, ^D, Q
			Base.escape_string(stdout, string(c))
		end
	finally
		REPL.Terminals.raw!(term, false)
	end
	callb()
end