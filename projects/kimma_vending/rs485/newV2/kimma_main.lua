--Simple control API for Kimma's vending machine. 
local coroutine = require "coroutine"
local uv = require "luv"
local serial = require("periphery").Serial
require "kimma_functions"
require "help_functions"

--init function
serial_port = getserialport()

--main loop
while 1 do
    msg= serial_port:read(100, 500) --clear buffer
    print(message)
end
