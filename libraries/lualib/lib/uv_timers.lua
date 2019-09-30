--Simple timer module with luv. Always call uv event loop. Timeouts in miliseconds
--needs local uv = require("luv") on main file

local module = {};

--creates timer that is triggered once
function module.set_timeout(uv,timeout, callback)
	local timer = uv.new_timer()
	local function ontimeout()
	  uv.timer_stop(timer)
	  uv.close(timer)
	  callback(timer)
	end
	uv.timer_start(timer, timeout, 0, ontimeout)
	return timer
end

--creates repeating timer
function module.set_interval(uv,interval, callback)
	local timer = uv.new_timer()
	local function ontimeout()
	  callback(timer)
	end
	uv.timer_start(timer, interval, interval, ontimeout)
	return timer
end

--Disables timer called with set_interval
function module.clear_timeout(uv,timer)
	uv.timer_stop(timer)
	uv.close(timer)
end

return module
--[[Example:

stri=''

--create repeating timer
timer1=set_interval(1000,function()
	stri=stri..'.'
	if stri=='....' then
		stri='.'
	end
	print('t0.txt="'..stri..'"')
end)

stop timer
set_timeout(5000, function()
	clear_timeout(timer1)
end)

--Don't forget about uv event loop :)
while true do
	uv.run();
end


]]