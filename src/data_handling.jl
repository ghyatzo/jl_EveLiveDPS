using DataFrames
using DataFramesMeta
using LinearAlgebra: dot


get_sources(data) = unique(data[!, :Source]) |> skipmissing |> collect
time_window(data) = time_window(data.Time)
time_window(dates::Vector{DateTime}) = interval_seconds(first(dates), last(dates))
function interval_seconds(tstart, tend; min_clip = 1, min_val = 1)
	dT = abs(tstart - tend).value/1000
	return dT < min_clip ? min_val : dT
end
function pad_getindex(i, arr, p = :Same)
	p == :Zero && (p_start = p_end = zero(eltype(arr)))
	p == :Same && (p_start = first(arr); p_end = last(arr))
	i < one(i) && return p_start
	return if i <= length(arr) arr[i] else p_end end
end

sma(data, time_window_s, col, live = true) = @with data begin
	t0 = live ? trunc(now(), Dates.Second) : last(:Time)
	return sum(data[:Time .>= t0 - Dates.Second(time_window_s), ^(col)]; init=0) / time_window_s
end
function fast_sma(data, dt, col, live = true)
	@with data begin
		n_max = size(data, 1)
		S = 0
		t0 = live ? trunc(now(), Dates.Second) : :Time[n_max]
		t_bound = t0 - Dates.Millisecond(round(dt; sigdigits=3)*1000)
		t_idx = findprev(idx -> :Time[idx] < t_bound, eachindex(:Time), n_max)
		if isnothing(t_idx)
			return sum($col; init=0) / dt
		elseif t_idx == n_max
			return 0
		else
			return sum($col[t_idx+1:n_max]; init=0) / dt
		end
	end
end

sma_process(time_window, live) = (df, col) -> fast_sma(df, time_window, col, live)

ema_weights(a, n) = Iterators.map(k -> (1-a)^k, 0:n-1)

## EMA CONVOLUTION

function ema_conv(data, n; wilder=false)
	vals = zeros(length(data))
	ema_conv!(vals, data, n; wilder)
	return vals
end

function ema_conv!(vals, data, n; wilder=false)
	a = wilder ? 1/n : 2/(n+1)
	min_k = -trunc(Int64, log(0.05)/a)
	weigths = ema_weights(a, min_k) #the least important values are first in the array
	w_norm = sum(weigths; init=0)
	for i in eachindex(vals)
		vals[i] = dot(Iterators.map(k-> pad_getindex(i-k, data, :Same), 0:min_k-1), weigths) / w_norm
	end
end

## SINGLE POINT FUNCTIONS

function single_point_ema(data, n, wilder=false)
	@assert n > 0
	n_max = size(data, 1)
	a = wilder ? 1/n : 2/(n+1)
	min_k = -trunc(Int64, log(0.05)/a)
	weigths = ema_weights(a, min_k)
	w_norm = sum(weigths; init=0)
	dot(Iterators.map(k-> pad_getindex(n_max-k, data, :Same), 0:min_k-1), weigths) / w_norm
end

# GAUSSIAN SMOOTHING

gaussian_kernel(x, gamma) = exp(-x^2/(2*gamma^2))
gaussian_weights(gamma) = Iterators.map(k -> gaussian_kernel(k, gamma), -gamma:gamma) # grezza, in intervalli e non in secondi. magari si potrebbe shiftare in secondi o decimi almeno...
function gaussian_smoothing!(svals, values; gamma=2)
	w = gaussian_weights(gamma)
	S = sum(w; init=0)
	for i in eachindex(svals)
		svals[i] = dot(Iterators.map(k -> pad_getindex(i+k, values, :Same), -gamma:gamma), w) / S
	end
end

function gaussian_smoothing(values; gamma=2)
	smoothed_values = similar(values)
	gaussian_smoothing!(smoothed_values, values; gamma)
	return smoothed_values
end


### DETAILS HELPERS

function extract_data_in_window(data, time_window_s; live=true)
	n_max = size(data, 1) # we use n_max instead of end, to avoid problems if a push! happens during the execution
	n_max == 0  && return empty(data)

	t0 = @with(data, live ? now() : :Time[n_max])
	t_bound = t0 - Dates.Second(time_window_s)
	maybe_idx = findlast(t -> t < t_bound, data.Time)

	if isnothing(maybe_idx) # all entries are within the time window
		return data[1:n_max, :]
	elseif maybe_idx == n_max
		return empty(data)
	else # there is an overlap 
		return data[maybe_idx:n_max, :]
	end
end

# stat by source
function source_stats(data, col_sum, col_max, time_window_s; live=true)
	relevant_data = extract_data_in_window(data, time_window_s; live)

	isempty(relevant_data) && return nothing
	g_data = groupby(relevant_data, :Source; skipmissing=true)
	c_data = combine(g_data, :Ship => unique => :ship, col_sum => sum => :sum, col_max => (c -> maximum(c; init=0)) => :max; threads=false)

	return c_data
end

function get_source_stats(data, col_sum, col_max, time_window_s; live=true)
	df = source_stats(data, col_sum, col_max, time_window_s; live)

	if isnothing(df)
		return String[], String[], Int64[], Int64[]
	else
		return df.Source, df.ship, df.sum, df.max
	end
end

# application stats
function _hit_dist(data, col, time_window_s; live=true)
	relevant_data = extract_data_in_window(data, time_window_s; live)
 
 	isempty(relevant_data) && return nothing
	f_data = filter(col => !iszero, relevant_data; view=true)
	g_data = groupby(f_data, :Application; skipmissing=true)
	c_data = combine(g_data, nrow => :counts)

end

function get_hit_dist(data, col, time_window_s; live =true)
	df = _hit_dist(data, col, time_window_s; live)

	if isnothing(df)
		return String[], Int64[]
	else
		return df.Application, df.counts
	end
end

## ARCHIVE

# function ema(data, window_seconds, key; wilder=false, live=true)
# 	t0 = @with(data, live ? trunc(now(), Dates.Second) : last(:Time))
# 	values = data[data.Time .>= t0 - Dates.Second(window_seconds), key]
# 	n = length(values)
# 	if n == 0
# 		return 0
# 	else
# 		a = wilder ? 1/n : 2/(n+1)
# 		w = Iterators.reverse(ema_weights(a, n)) #the least important values are first in the array
# 		w_norm = n/(sum(w; init=0)*window_seconds) 
# 		# dmg = dot(...)/sum(w) give the average damage received PER HIT in the time frame.
# 		# tot_dmg = dmg*n we multiply by the number of hits in the timeframe to obtain the total damage
# 		# dps = tot_dmg/window_seconds.

# 		return w_norm*dot(values, w)
# 	end
# end

# ema_process(wilder, seconds, live) = (df, col) -> ema(df, seconds, col; wilder, live)

# t_norm(range) = mapreduce((t -> return if t <= 0 0 else inv(t) end), +, range; init=0)
# function multi_window_sma(data, min_win_size, shift_s, n_shifts, col; live =true)
# 	@with data begin
# 		n_max = size(data, 1)
# 		max_t = min_win_size+shift_s*n_shifts
# 		S = 0
# 		p_idx = n_max # we start at the end
# 		t0 = live ? trunc(now(), Dates.Second) : :Time[n_max]
# 		t_bound = t0 - Dates.Second(min_win_size)
		
# 		for k in 0:n_shifts
# 			n_idx = findprev(idx -> :Time[idx] < t_bound - Dates.Second(shift_s*k), eachindex(:Time), p_idx)

# 			# Given an array [ 1 2 3 4 5 ...]
# 			# a telescopic sum of partial sums k terms means: sum[1] + sum[1 2] + sum[1 2 3] + ... + sum[1 2 ... k] = S1 + S2 + ... + Sk = S
# 			# we have that S = kA1 + (k-1)A2 + (k-2)A3 + ... + 1Ak
# 			# where the Ai are the elements that are in the i-th window, but not in the (i-1)-th window, i.e.: A1 = 1, A2 = 2, A3 = 3, ...

# 			# Since we want an average of averages, with respect to time, we will devide each partial sum by the size of the window it covers.
# 			# thus S = A1(1/t1 + 1/t2 + 1/t3 + ... + 1/tk) + A2(1/t2 + 1/t3 + ... + 1/tk) + ... + Ak(1/tk)

# 			tt = t_norm(min_win_size+shift_s*k:shift_s:max_t)

# 			if isnothing(n_idx) 
# 				# it means that there wasn't an an element outside the window -> we just add the whole remaining array.
# 				S += tt*sum($col[1:p_idx]; init=0)
# 				break # once we reach the end, all future Ais will be 0.
# 			elseif n_idx == p_idx 
# 				# it means that the most recent element is outside the window.
# 				S+=0
# 			else
# 				S += tt*sum($col[n_idx+1:p_idx]; init=0)
# 			end

# 			p_idx = n_idx
# 		end
# 		return S/(1+n_shifts)
# 	end
# end
# multi_sma_process(time_window, shift_s, n_shifts, live) = (df, col) -> multi_window_sma(df, time_window, shift_s, n_shifts, col; live)

