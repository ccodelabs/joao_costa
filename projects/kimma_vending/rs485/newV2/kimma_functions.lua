local coroutine = require "coroutine"
local uv = require "luv"
local serial = require("periphery").Serial
require "help_functions"

debug = true

--Searches for avaliable port between ttyACM0 to ttyACM5 and open serial comunication
function getserialport()
    for i = 0, 5, 1 do
        status, err =
            pcall(
            function()
                serial_port =
                    serial {
                    device = "/dev/ttyACM" .. i,
                    baudrate = 115200,
                    databits = 8,
                    parity = "none",
                    stopbits = 1,
                    xonxoff = false,
                    rtscts = false
                }
            end
        )
        if status ~= true then --Failed to open port
            if debug then
                print("No VEMIO2 found on ttyACM", i, ". Trying another port...")
            end
            serial_port = nil
        else --succeed to open port
            if debug then
                print("VEMIO2 found on ttyACM", i, ". Starting serial comunication...")
            end
            break
        end
    end
    return serial_port
end

--creates 10x6 matrix of constant strings to send, to activate/deactivate (concat 0 or 1) each "driver high" of VEMIO2
function create_dh_matrix()
    DH_matrix = {}
    for i = 0, 9, 1 do --columns
        DH_matrix[i] = {}
        for j = 0, 5, 1 do --lines
            if i <= 1 then
                DH_matrix[i][j] = "o25,"
            elseif i > 1 and i <= 3 then
                DH_matrix[i][j] = "o26,"
            elseif i > 3 and i <= 5 then
                DH_matrix[i][j] = "o27,"
            elseif i > 5 and i <= 7 then
                DH_matrix[i][j] = "o28,"
            elseif i > 7 and i <= 9 then
                DH_matrix[i][j] = "o29,"
            end
        end
    end
    return DH_matrix
end

--creates 10x6 matrix of constant strings to send, to activate/deactivate (concat 0 or 1) each "driver low" of VEMIO2
function create_dl_matrix()
    DL_matrix = {}
    for i = 0, 9, 1 do --columns
        DL_matrix[i] = {}
        for j = 0, 5, 1 do --lines
            if j == 0 then --bottom (1st) line
                if math.fmod(i, 2) == 0 then --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o2,"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o1,"
                end
            elseif j == 1 then --2nd line
                if math.fmod(i, 2) == 0 then --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o4,"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o3,"
                end
            elseif j == 2 then --2nd line
                if math.fmod(i, 2) == 0 then --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o6,"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o5,"
                end
            elseif j == 3 then --2nd line
                if math.fmod(i, 2) == 0 then --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o8,"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o7,"
                end
            elseif j == 4 then --2nd line
                if math.fmod(i, 2) == 0 then --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o10,"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o9,"
                end
            elseif j == 5 then --2nd line
                if math.fmod(i, 2) == 0 then --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o12,"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o11,"
                end
            end
        end
    end
    return DL_matrix
end

--rotate motor (1 complete turn) placed in coordinates x,y (matrix 10x6)
function enable_motor(DL_matrix, DH_matrix, serial_port, x, y)
    local min_delay = 500
    serial_port:write(DL_matrix[x][y] .. "1\n")
    serial_port:write(DH_matrix[x][y] .. "1\n")
    serial_port:read(100, min_delay) --clear buffer

    local signal = ""
    --read turn signal while turn is incomplete
    while string.find(signal, "i,00ff") == nil and string.find(signal, "i,01ff") == nil do
        serial_port:write("I\n")
        signal = serial_port:read(100, min_delay)
    end

    serial_port:write(DL_matrix[x][y] .. "0\n")
    serial_port:write(DH_matrix[x][y] .. "0\n")
    serial_port:read(100, min_delay) --clear buffer
end

--detect presence of motor placed in x,y coordinates
function detect_motor(DL_matrix, DH_matrix, serial_port, x, y)
    local min_delay = 500
    serial_port:write(DL_matrix[x][y] .. "1\n")
    serial_port:write(DH_matrix[x][y] .. "1\n")
    serial_port:read(100, min_delay) --clear buffer

    serial_port:write("a\n")
    analog = serial_port:read(100, min_delay) --read analog value from VEMIO must not be 'a,0000'
    serial_port:write(DL_matrix[x][y] .. "0\n") --stop motors
    serial_port:write(DH_matrix[x][y] .. "0\n")
    serial_port:read(100, min_delay) --clear buffer

    if string.find(analog, "a,0000") == nil then
        return true
    else
        return false
    end
end

--Read temperature from DS18B20
function read_temp()
    local min_delay = 2
    local temp = nil
    serial_port:write("t") --ask for temperature reading
    local temp_str = serial_port:read(100, min_delay) --read answer

    if string.find(temp_str, "t,") then
        temp = string.sub(temp_str, string.find(temp_str, "t,"), string.find(temp_str, "t,")+3)
    end

    return temp
end
