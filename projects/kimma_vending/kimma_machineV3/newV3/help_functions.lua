local coroutine = require "coroutine"
local uv = require "luv"
local serial = require("periphery").Serial

--Standard delay function with luv library (timeout in ms)
function luvdelay(timeout)
    local cr = coroutine.running()
    local timer = uv.new_timer()

    timer:start(
        timeout,
        0,
        function()
            timer:close()
            timer:stop()
            coroutine.resume(cr)
        end
    )

    coroutine.yield()
end

    -- returns a table of bits
function toBits(num, bits)
    local t={} -- will contain the bits
    for b=bits,1,-1 do
        rest=math.fmod(num,2)
        t[b]=rest
        num=(num-rest)/2
    end
    if num==0 then return t else return {'Not enough bits to represent this number'}end
end

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
            if debug then print("No VEMIO2 found on ttyACM", i, ". Trying another port...") end
            serial_port = nil
        else --succeed to open port
            if debug then print("VEMIO2 found on ttyACM", i, ". Starting serial comunication...") end
            break
        end
    end
    return serial_port
end


--concats all elements and prints 2D (ixj) matrix (for debug purpose only)
function print_2D_matrix(matrix)
    matstr = "[\n"
    for j = 5, 0, -1 do
        for i = 0, 9, 1 do
            matstr = matstr .. matrix[i][j] .. " "
        end
        matstr = matstr .. "\n"
    end
    matstr = matstr .. "]"
    print(matstr)
end


--splits string s, according to the delimiter, convert to number and append to table
function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, tonumber(match));
    end
    return result;
end

