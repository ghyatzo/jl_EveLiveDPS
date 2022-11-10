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

sma(data, time_window_s, col; live = true) = @with data begin
	t0 = live ? trunc(now(), Dates.Second) : last(:Time)
	return sum(data[:Time .>= t0 - Dates.Second(time_window_s), ^(col)]; init=0) / time_window_s
end
sma_process(time_window, live) = (df, col) -> sma(df, time_window, col; live)

ema_weights(a, n) = Iterators.map(k -> (1-a)^k, 0:n-1)
function ema(data, window_seconds, key; wilder=false, live=true)
	t0 = @with(data, live ? trunc(now(), Dates.Second) : last(:Time))
	values = data[data.Time .>= t0 - Dates.Second(window_seconds), key]
	n = length(values)
	if n == 0
		return 0
	else
		a = wilder ? 1/n : 2/(n+1)
		w = Iterators.reverse(ema_weights(a, n)) #the least important values are first in the array
		w_norm = n/(sum(w; init=0)*window_seconds) 
		# dmg = dot(...)/sum(w) give the average damage received PER HIT in the time frame.
		# tot_dmg = dmg*n we multiply by the number of hits in the timeframe to obtain the total damage
		# dps = tot_dmg/window_seconds.

		return w_norm*dot(values, w)
	end
end

ema_process(wilder, seconds, live) = (df, col) -> ema(df, seconds, col; wilder, live)

function pad_getindex(i, arr, p = :Same)
	p == :Zero && (p_start = p_end = zero(eltype(arr)))
	p == :Same && (p_start = first(arr); p_end = last(arr))
	i < one(i) && return p_start
	return if i <= length(arr) arr[i] else p_end end
end

function ema_conv(data, n; wilder=false)
	vals = zeros(length(data))
	ema_conv!(vals, data, n; wilder)
	return vals
end
function ema_conv!(vals, data, n; wilder=false)
	N = length(data)
	a = wilder ? 1/N : 2/(N+1) # Like this, the EMA becomes basically a SMA...
	weigths = ema_weights(a, n) #the least important values are first in the array
	w_norm = sum(weigths; init=0)
	for i in eachindex(vals)
		vals[i] = dot(Iterators.map(k-> pad_getindex(i-k, data, :Same), 0:n-1), weigths) / w_norm
	end
end
function ema_conv2!(vals, data, n; wilder=false)
	a = wilder ? 1/n : 2/(n+1)
	min_k = -trunc(Int64, log(0.05)/a)
	weigths = ema_weights(a, min_k) #the least important values are first in the array
	w_norm = sum(weigths; init=0)
	for i in eachindex(vals)
		vals[i] = dot(Iterators.map(k-> pad_getindex(i-k, data, :Same), 0:min_k-1), weigths) / w_norm
	end
end

gaussian_kernel(x, gamma) = exp(-x^2/(2*gamma^2))
gaussian_weights(gamma) = Iterators.map(k -> gaussian_kernel(k, gamma), -gamma:gamma) # grezza, in intervalli e non in secondi. magari si potrebbe shiftare in secondi o decimi almeno...
function gaussian_smoothing!(svals, values; gamma=2)
	w = gaussian_weights(gamma)
	S = sum(w; init=0)
	for i in eachindex(svals)
		svals[i] = dot(Iterators.map(k -> pad_getindex(i+k, values, :Same), -gamma:gamma), w) / S
	end
end

# Maybe fucked up version of gaussian smoothing
# gaussian_kernel2(x, gamma) = inv(gamma*sqrt(2*pi))*exp(-x^2/(2*gamma^2))
# gaussian_weights2(values, i, gamma) = Iterators.map(k -> gaussian_kernel2(values[i] - values[k], gamma), eachindex(values))

# function gaussian_smoothing2!(svals, values; gamma = 2)
# 	for i in eachindex(svals)
# 		w = gaussian_weights2(values, i , gamma)
# 		svals[i] = dot(values, w) / sum(w)
# 	end
# end
function gaussian_smoothing(values; gamma=2)
	smoothed_values = similar(values)
	gaussian_smoothing!(smoothed_values, values; gamma)
	return smoothed_values
end

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


