local uv = require "luv"
--local uci = require "uci"
local coroutine = require "coroutine"
local serial = require "luv-serial"

require "keypad_serial"
ipport = 59999
chan = 0

require "nixio"

mode = nil

local err, serial_port = serial:open("/dev/ttyUSB0")
if err ~= serial.ERR_NOERROR then
	print "No Dongle found on ttyUSB0. Working without..."
	serial_port = nil
else
	print "Dongle found"
end

function serial_loop()
	while true do
		local data = serial_port:read_timeout(1000, 1000) --data is 1 bit
		if data ~= nil then
			print(data)
		else
			print("No data received")
			serial_port:write("0x3f3f3f3f3f3f3f3f")
		end
	end
end

-- kick on the serial port for the first time
if serial_port ~= nil then
	serial_port:write("0x3f3f3f3f3f3f3f3f")

	local cr = coroutine.create(serial_loop)
	coroutine.resume(cr)
end

uv.run()
