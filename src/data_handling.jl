using DataFrames
using DataFramesMeta: @with
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
	weigths = Iterators.reverse(ema_weights(a, n)) #the least important values are first in the array
	w_norm = sum(weigths; init=0)
	for i in eachindex(vals)
		vals[i] = dot(Iterators.map(k-> pad_getindex(k, data, :Same), i-n+1:i), weigths) / w_norm
	end
end

gaussian_kernel(x, gamma) = inv(gamma*sqrt(2*pi))*exp(-x^2/(2*gamma^2))
gaussian_weights(values, i, gamma) = Iterators.map(k -> gaussian_kernel(values[i] - values[k], gamma), eachindex(values)) 

function gaussian_smoothing!(svals, values; gamma = 2)
	for i in eachindex(svals)
		w = gaussian_weights(values, i , gamma)
		svals[i] = dot(values, w) / sum(w)
	end
end
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
	else # there is an overlap (it can't happen that maybe_idx > n_max...)
		return data[maybe_idx:n_max, :]
	end
end

# worst offenders
function top_total(data, col, time_window_s; live=true)
	relevant_data = extract_data_in_window(data, time_window_s; live)

	g_data = groupby(relevant_data, :Source; skipmissing=true)
	c_data = combine(g_data, col => sum => :sum; threads=false)
	return sort(c_data, :sum; rev = true)
end

function top_alpha(data, col, time_window_s; live=true)
	relevant_data = extract_data_in_window(data, time_window_s; live)

	g_data = groupby(relevant_data, :Source; skipmissing=true)
	c_data = combine(g_data, col => (c -> maximum(c; init=0)) => :max; threads=false)
	return sort(c_data, :max; rev=true)
end

# application stats
function hit_dist(data, col, time_window_s; live=true)
	relevant_data = extract_data_in_window(data, time_window_s; live)

	f_data = filter(col => !iszero, relevant_data; view=true)
	g_data = groupby(f_data, :Application; skipmissing=true)
	return combine(g_data, nrow => :counts)
end