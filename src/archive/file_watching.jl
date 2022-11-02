using FileWatching

function check_on_created(callb::Function, dir)
	last_registered = ""
	while true
		try
			file, event = watch_folder(dir)
			long_path = joinpath(dir, file)

			if event.renamed == true && ispath(long_path) && long_path != last_registered
				# don't know why but upon a combat log creation this event fires twice. We avoid the second one.
				last_registered = long_path
				# we exclude real renames, and deletions by checking that the file exists in the path.
				# sadly, renaming generates two events with event.renamed = true. One with the old file name
				# and one with the new. We can exclude the one with the old file name by checking that the file exist
				# but we can't reliably exclude the second event which has the new modified name.
				# hence we will just pass it along, all in all, it is practically a new file to check ;)
				callb(long_path)
			end
		catch err
			Base.show_exception_stack(stdin, stacktrace(catch_backtrace()))
			#call unwatch_folder(dir) to end the task
			@info "Folder watching task terminated."
			break
		end
	end
end