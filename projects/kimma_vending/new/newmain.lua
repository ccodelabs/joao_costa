local coroutine = require "coroutine"
local uv = require "luv"
local serial = require("periphery").Serial
require "newfunctions"

--create Driver matrixes
DH = create_DH_matrix()
DL = create_DH_matrix()

--init function
serial_port = getserialport()

--main loop
while 1 do
    print("Which motor do you want to turn? (input <x>,<y>)")
    local comand = io.read()
    if string.find(comand, "stop") ~= nil then --stop program
        serial_port:close() --close the instance
        break
    else   --rotate motor according to the input
        coord_xy=split(comand,',')
        enable_motor(serial_port,coord[1],coord[2])
    end
end
