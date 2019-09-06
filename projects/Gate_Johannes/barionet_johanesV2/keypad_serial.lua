local coroutine = require 'coroutine'
local uv = require 'luv'
local serial = require 'luv-serial'

--Standard delay function with luv library (timeout in ms)
function luvdelay(timeout)
    local cr = coroutine.running()
    local timer = uv.new_timer()

    timer:start(timeout, 0, function()
        timer:close()
        timer:stop()
        coroutine.resume(cr)
    end)
    coroutine.yield()
end



--Turns ON/OFF relay, with time interval=time. Serial port is the handler that comunicates with the keypad, initialized in the main script
function opengate(time,serial_port)
    file = io.open("/sys/class/gpio/gpio500/value", "w")
    file:write('1')
    file:close() 
    serial_port:write("\n")		--turn ON green light on keypad
    serial_port:write("O1,0\n")
    
    --os.execute("sleep " .. tonumber(time))
    luvdelay(time)

    file = io.open("/sys/class/gpio/gpio500/value", "w")
    file:write('0')
    file:close()
    serial_port:write("\n")              --turn ON red light on keypad
    serial_port:write("O1,1\n")
end

--Searches for avaliable port between ttyACM0 to ttyACM5 and open serial comunication
function getserialport()
    for i=0,5,1 do
        err, serial_port = serial:open("/dev/ttyACM"..i)
        if err ~= serial.ERR_NOERROR then
            if debug then print('No USBIOC Dongle found on ttyACM',i,'. Trying another port...') end
            serial_port=nil
        else
            if debug then print('USBIOC Dongle found on ttyACM',i,'. Starting serial comunication...') end
            break
        end
    end
end

--Reads incoming groups of 4 characters from keypad
function serial_loop()
    local code
    while true do
        local data = serial_port:readln_timeout(2000,100)
        if data ~= nil then
            code = wie_decode(data)
            if code then
                if code==access_key then    
                    if debug then print('Access Granted!', code) end
                    opengate(1000,serial_port)
                else
                    if debug then print('Access Denied!', code) end 
                end
            end
        else
            if debug then print('Timeout triggered') end
            serial_port:write("r\r")
            code=nil
            data=nil
        end
    end
end