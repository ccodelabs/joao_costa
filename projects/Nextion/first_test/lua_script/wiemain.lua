local uv = require 'luv'
local uci = require 'uci'
local coroutine = require 'coroutine'
local serial = require 'luv-serial'
require 'myfunctions'
require 'nixio'

debug = true  --change to true/false to enable/disable console output

mode= nil


--init function
getserialport()

-- kick on the serial receiver for the first time
if serial_port~=nil then
  local cr = coroutine.create(serial_loop)
  coroutine.resume(cr)
end

uv.run()
