local uv = require 'luv'
local uci = require 'uci'
local coroutine = require 'coroutine'
local serial = require 'luv-serial'
require 'wiegand'
require 'keypad_serial'
require 'nixio'

debug = false  --change to true/false to enable/disable console output
access_key=1303  --to change the access_key, change this line



mode= nil

--init function
getserialport()

-- kick on the serial receiver for the first time
if serial_port~=nil then
  serial_port:write("r\r")

  local cr = coroutine.create(serial_loop)
  coroutine.resume(cr)
end

uv.run()
