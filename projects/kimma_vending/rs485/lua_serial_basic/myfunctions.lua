local coroutine = require 'coroutine'
local uv = require 'luv'
local serial = require 'luv-serial'

debug = true

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


--Searches for avaliable port between ttyACM0 to ttyACM5 and open serial comunication
function getserialport()
    for i=0,5,1 do
        err, serial_port = serial:open("/dev/ttyUSB"..i)
        if err ~= serial.ERR_NOERROR then
            if debug then print('No USBIOC Dongle found on ttyUSB',i,'. Trying another port...') end
            serial_port=nil
        else
            if debug then print('USBIOC Dongle found on ttyUSB',i,'. Starting serial comunication...') end
            break
        end
    end
end

--Switch case like in lua to decide what to do when msg is received
local switch_table=
{
    ['1']=function() --increment progress bar 5% at a time
        luvdelay(200)--wait for display page to change
        packet = string.char(0x6a, 0x30, 0x2e, 0x76, 0x61, 0x6c, 0x3d, 0x6a, 0x30, 0x2e, 0x76, 0x61, 0x6c, 0x2b, 0x35, 0xff, 0xff, 0xff)
        print('Case 1. Sending:',packet)
        for i =0,18,1 do
            serial_port:write(packet)
            luvdelay(200)
        end
    end,

    ['2']=function()
        luvdelay(200)--wait for display page to change
        packet = string.char(0x6a, 0x30, 0x2e, 0x76, 0x61, 0x6c, 0x3d, 0x6a, 0x30, 0x2e, 0x76, 0x61, 0x6c, 0x2b, 0x35, 0xff, 0xff, 0xff)
        print('Case 2. Sending:',packet)
        for i =0,18,1 do
            serial_port:write(packet)
            luvdelay(200)
        end
    end,

    ['3']=function()
        luvdelay(200)--wait for display page to change
        packet = string.char(0x6a, 0x30, 0x2e, 0x76, 0x61, 0x6c, 0x3d, 0x6a, 0x30, 0x2e, 0x76, 0x61, 0x6c, 0x2b, 0x35, 0xff, 0xff, 0xff)
        print('Case 3. Sending:',packet)
        for i =0,18,1 do
            serial_port:write(packet)
            luvdelay(200)
        end
    end,

    ['P0']=function()
        print('case P0')
    end
}

--Reads incoming bytes from serial port and writes a comand if timeout is triggered
function serial_loop()
    while true do
        local data = serial_port:readln_timeout(2000,100)
        if data ~= nil then
            print(data)
        else
            if debug then print('Timeout triggered. Waiting for activity...') end
        end
    end
end

