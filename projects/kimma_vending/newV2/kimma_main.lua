--Simple control API for Kimma's vending machine. 
local coroutine = require "coroutine"
local uv = require "luv"
local serial = require("periphery").Serial
require "kimma_functions"
require "help_functions"

--create Driver matrixes
DH = create_dh_matrix()
DL = create_dl_matrix()

--init function
serial_port = getserialport()
print(serial_port)

--main loop
while 1 do
    print("\nEnter a command from the list:\nrotate,<x>,<y>\ndetect,<x>,<y>\ntest\nstop")
    local comand = io.read()
    if string.find(comand, "stop") ~= nil then --stop program
        print("Quiting...")
        serial_port:close() --close the instance
        break

    elseif string.find(comand, "test") ~= nil then
        for j = 0, 5, 1 do --for all rows
            for i = 0, 9, 1 do --for all columns
                exist = detect_motor(DL, DH, serial_port, i, j)
                if exist then
                    enable_motor(DL, DH, serial_port, i, j)
                    print("Motor " .. i .. "," .. j .. " present.")
                else
                    print("Motor " .. i .. "," .. j .. " NOT present.")
                end
               -- os.execute("sleep " .. tonumber(0.5))
            end
            print("Incrementing row...")
           -- os.execute("sleep " .. tonumber(2))
        end
        print("Test finished!")

    elseif string.find(comand, "detect") then --detect motor according to the input if one is correct
        coord = split(comand, ",")
        if coord[1] <= 9 and coord[2] <= 5 then
            exist = detect_motor(DL, DH, serial_port, coord[1], coord[2])
            if exist then
                print("Motor " .. coord[1] .. "," .. coord[2] .. " present.")
            else
                print("Motor " .. coord[1] .. "," .. coord[2] .. " NOT present.")
            end
        else
            print("Invalid motor. Please try again...")
        end

    elseif string.find(comand, "rotate") then --rotate motor according to the input if one is correct
        coord = split(comand, ",")
        if coord[1] <= 9 and coord[2] <= 5 then
            enable_motor(DL, DH, serial_port, coord[1], coord[2])
        else
            print("Invalid motor. Please try again...")
        end
    else
        print("Invalid command. Please try again...")
    end
end
