using DataFrames
using LinearAlgebra: dot


get_sources(data) = unique(data[!, :Source]) |> skipmissing |> collect
time_window(data) = time_window(data.Time)
time_window(data::Vector{DateTime}) = interval_seconds(data[1], data[end])

function interval_seconds(tstart, tend; min_clip = 1, min_val = 1)
	if tend < tstart
		dT = (tstart - tend).value/1000
	else
		dT = (tend - tstart).value/1000
	end
	return dT < min_clip ? min_val : dT
end

mean(data, column) = sum(data[!, column]) / time_window(data)

function sma(data, time_window_seconds, key; live=true)
	starting_time = live ? trunc(now(), Dates.Second) : data.Time[end]
	values = data[data.Time .>= starting_time - Dates.Second(time_window_seconds), key]
	return sum(values; init=0) / time_window_seconds
end

sma_process(time_window, live) = (df, col) -> sma(df, time_window, col; live)

ema_weights(a, n) = Iterators.map(k -> (1-a)^k, 0:n-1)
function ema(data, window_seconds, key, wilder=false; live=true)
	t0 = live ? trunc(now(), Dates.Second) : data.Time[end]
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

ema_process(wilder, seconds, live) = (df, col) -> ema(df, seconds, col, wilder; live)

function pad_getindex(i, arr, p = :Same)
	p == :Zero && (p_start = p_end = 0)
	p == :Same && (p_start = arr[1]; p_end = arr[end])
	if i <= 0
		return p_start
	elseif i <= length(arr)
		return arr[i]
	else
		return p_end
	end
end
function ema_conv(data, n; wilder=false)
	vals = zeros(length(data))
	ema_conv!(vals, data, n; wilder)
	return vals
end
function ema_conv!(vals, data, n; wilder=false)
	N = length(data)
	a = wilder ? 1/N : 2/(N+1)
	weigths = Iterators.reverse(ema_weights(a, n)) #the least important values are first in the array
	w_norm = sum(weigths)
	for i in eachindex(vals)
		vals[i] = dot(Iterators.map(k-> pad_getindex(k, data, :Zero), i-n+1:i), weigths) / w_norm
	end
end
function ema_conv2!(vals, data, n; wilder=false)
	a = wilder ? 1/n : 2/(n+1)
	min_k = trunc(Int, log(0.05)/log(1-a))+one(Int) # at least 95% of the weights
	weigths = Iterators.reverse(ema_weights(a, min_k)) #the least important values are first in the array
	w_norm = sum(weigths)
	for i in eachindex(vals)
		vals[i] = dot(Iterators.map(k-> pad_getindex(k, data, :Zero), i-min_k+1:i), weigths) / w_norm
	end
end

gaussian_kernel(x, gamma) = inv(gamma*sqrt(2*pi))*exp(-x^2/(2*gamma^2))
weights(values, i, gamma) = Iterators.map(k -> gaussian_kernel(values[i] - values[k], gamma), eachindex(values)) 

function gaussian_smoothing!(svals, values; gamma = 2)
	for i in eachindex(svals)
		w = weights(values, i , gamma)
		svals[i] = dot(values, w) / sum(w)
	end
end
function gaussian_smoothing(values; gamma=2)
	smoothed_values = similar(values)
	gaussian_smoothing!(smoothed_values, values; gamma)
	return smoothed_values
end

## worst Offenders
top_total(g_data, col) = sort(combine(groupby(g_data, :Source; skipmissing=true), col => sum => :sum), :sum, rev=true)
top_alpha(g_data, col) = sort(combine(groupby(g_data, :Source; skipmissing=true), col => (c -> maximum(c; init=0)) => :max), :max, rev=true)

function top_total(data, col, time_window_s; live=true)
	n_max = size(data, 1)
	t0 = live ? now() : data.Time[n_max]
	t_bound = t0 - Dates.Second(time_window_s)
	maybe_idx = findlast(t -> t < t_bound, data.Time)
	
	if isnothing(maybe_idx) # all entries are within the time window
		return top_total(data[1:n_max, :], col)
	elseif maybe_idx == length(data.Time) # no entries within the time window
		return DataFrame()
	else
		return top_total(data[maybe_idx:n_max, :], col)
	end
end
function top_alpha(data, col, time_window_s; live=true)
	n_max = size(data, 1)
	t0 = live ? now() : data.Time[n_max]
	t_bound = t0 - Dates.Second(time_window_s)
	maybe_idx = findlast(t -> t < t_bound, data.Time)
	
	if isnothing(maybe_idx) # all entries are within the time window
		return top_alpha(data[1:n_max, :], col)
	elseif maybe_idx == length(data.Time) # no entries within the time window
		return DataFrame()
	else
		return top_alpha(data[maybe_idx:n_max, :], col)
	end
end

## application stats
hit_dist(data) = combine(groupby(data, :Application; skipmissing=true), nrow => :counts)

function hit_dist(data, time_window_s; live=true)
	n_max = size(data, 1)
	t0 = live ? now() : data.Time[n_max]
	t_bound = t0 - Dates.Second(time_window_s)
	maybe_idx = findlast(t -> t < t_bound, data.Time)

	if isnothing(maybe_idx) # all entries are within the time window
		return hit_dist(data[1:n_max, :])
	elseif maybe_idx == length(data.Time) # no entries within the time window
		return DataFrame()
	else
		return hit_dist(data[maybe_idx:n_max, :])
	end
end
# series_colors = Dict(
# 	"DamageIn" =>  :red,
# 	"DamageOut" => :cyan,
# 	"LogisticsIn" => :light_red,
# 	"LogisticsOut" => :light_blue,
# 	"CapTransfered" => :gold1,
# 	"CapReceived" => :yellow,
# 	"CapDamageDone" => :light_green,
# 	"CapDamageReceived" => :green)
