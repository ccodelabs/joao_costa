--local coroutine = require 'coroutine'
--local serial = require 'luv-serial'
require "io"
uv = require('luv')
uvtimer=require('lib.uv_timers')
dashtx = require("dashtx.dashtx");
local serial = require('serial');
local str_utils = require('lib/str_utils');
local argparse = require('lib/argparse')
local inspect = require('lib/inspect')
local toboolean = require('lib/toboolean')
local socket = require('socket')
local dashwallet = require("dashtx.dashwallet");

require "products"

--Gets all the broadcast addresses
function getBroadcastAddresses()
    local file = io.popen('ip -f inet addr');
  
    local output = file:read('*all');
    file:close();
  
    local arr = str_utils.split(output,"\r\n");
  
    local addresses = {};
  
    local interface;
  
    io.write("DEBUG BRD ADDRESSES",'\n');
    for i=1,#arr,1 do
      io.write(arr[i],'\n');
      if i%3==1 then
        interface = nil;
        if arr[i]:find("BROADCAST") then
          interface = str_utils.split(arr[i],":")[2]:sub(2);
        end
      end
      if i%3==2 then
        local lineArr = str_utils.split(arr[i]," ");
        if interface~=nil and #lineArr>3 and lineArr[3]=="brd" then
          local brdAddr = lineArr[4];
          addresses[#addresses+1]=brdAddr;  
        end
      end
    end
    io.flush();
  
    io.write("Broadcast addresses:",'\n');
    for i=1,#addresses,1 do
      io.write(addresses[i],'\n');
    end
    io.flush();
  
    return addresses;
end

--creates 3x2 matrix of constant strings to send, to activate/deactivate (concat 0 or 1) each output of VEMIO
function create_matrixes()
    DL_matrix = {}
    DH_matrix = {}
    for row = 1, 2, 1 do
        DL_matrix[row] = {}
        DH_matrix[row] = {}
        for col = 1, 3, 1 do
            DH_matrix[row][col]= 'o'..tostring(24+col)..','
            DL_matrix[row][col]= 'o'..tostring(row)..','
        end
    end
    return DL_matrix,DH_matrix
end

--concats all elements and prints 2D matrix (for debug purpose only)
function print_2D_matrix(matrix)
    rows=#matrix --get num rows
    cols=#matrix[1] --get num cols
    matstr = "[\n"
    for row = rows, 1, -1 do
        for col = 1, cols, 1 do
            matstr = matstr .. matrix[row][col] .. "  "
        end
        matstr = matstr .. "\n"
    end
    matstr = matstr .. "]"
    print(matstr)
end

--Simple animation while qr code is not loaded
function change_dots()
    sendNextion('tsw m0,0')
    sendNextion('tsw m1,0')
    stri='.'
    sendNextion('t0.txt="'..stri..'"')
    timer1=uvtimer.set_interval(uv,300,function()
        stri=stri..' .'
	    if stri=='. . . . . .' then
		    stri='.'
	    end
	    sendNextion('t0.txt="'..stri..'"')
    end)
    return timer1
end

--detect argument from command line
function detect_args()
    local parser = argparse()
    parser:option("-n --portnextion", "Nextion Display port (ex.: /dev/ttyUSB0)", nil)
    parser:option("-v --portvemio", "VEMIO port (ex.: /dev/ttyUSB0)", nil)
    parser:option("-d --debug", "Enable Debug mode (ex.: true)", 'false')
    parser:option("-t --transactiondebug", "Enable Dash Debug mode (ex.: true)", 'false')
    local args = parser:parse()
    args.debug=toboolean(args.debug)
    args.transactiondebug=toboolean(args.transactiondebug)
    portnextion=args.portnextion
    portvemio=args.portvemio
    if args.debug then print('[DEBUG] Arguments:\n'..inspect(args)) end
    return args.debug,args.portnextion,args.portvemio,args.transactiondebug
end

--Discover device on USB port. Inputs are retrying interval and acknowledge message from device
function discover_port(device,interval,ACK_msg,req_msg)
    connected=false
    while not connected do
        for i=0,10,1 do
            port='/dev/ttyUSB'..tostring(i)
            if debug then print('[DEBUG] Trying '..port) end
            err, pv = serial.open(port);

            if pv~=nil then --port avaliable
                if debug then print('[DEBUG] Connection to port '..port..' accepted. Sending ACK_msg...') end
                sendVemio(req_msg)
                os.execute("sleep " .. tonumber(1))
                err,response,size = pv:read(string.len(ACK_msg),1000);

                if debug then print('[DEBUG] Response: ',response) end
                if response~=nil and string.find(ACK_msg, response) ~= nil then 
                    connected=true
                    if debug then print('[DEBUG] '..device..' discovered on: '..port) end
                    pv:close()
                    break;
                end
                pv:close()
            end
        end

        if not connected then
            for i=0,10,1 do
                port='/dev/ttyACM'..tostring(i)
                if debug then print('[DEBUG] Trying '..port) end
                err, pv = serial.open(port);

                if pv~=nil then --port avaliable
                    if debug then print('[DEBUG] Connection to port '..port..' accepted. Sending ACK_msg...') end
                    sendVemio(req_msg)
                    os.execute("sleep " .. tonumber(1))
                    err,response,size = pv:read(string.len(ACK_msg),1000);

                    if debug then print('[DEBUG] Response: ',response) end
                    if response~=nil and string.find(ACK_msg, response) ~= nil then 
                        connected=true
                        if debug then print('[DEBUG] '..device..' discovered on: '..port) end
                        pv:close()
                        break;
                    end
                    pv:close()
                end
            end
        end

        if not connected then 
            if debug then print('[DEBUG] Could not conect to '..device..'! Retrying in '..tostring(interval).. ' seconds...') end
            os.execute("sleep " .. tostring(interval))
        end
    end
    return port
end

--Sends data through the serial port (Nextion format)
function sendNextion(data)
    data = data..string.char(0xff,0xff,0xff)
    if debug then print('[DEBUG] Nextion Send: '..data:sub(1,-4)) end;
    if pn~=nil then 
        pn:write(data)
    end
end

--Sends data through the serial port (without formating)
function sendVemio(data)
    if debug then print('[DEBUG] Vemio Send: '..data) end;
    if pv~=nil then 
        pv:write(data)
    end
    lastVmsg=data --save to use in case of response=ERR
end

--remove nils from fragmented messages
function removeNils(data)
    local dataArr = {};
    local ret = '';
    local firstIndex = 1;
    for i=1,#data,1 do
        dataArr[i]=string.byte(data,i);
    end
    for i=1,#dataArr,1 do
        if dataArr[i]==0 then
            ret=ret..'';
        else
            ret=ret..string.char(dataArr[i]);
        end
    end
    return ret;
end

--Initialize Display (all messages must end with linefeed)
function initializeDisplay(device,port)
    --Get serial handle
    displayErr, display_port = serial.open(port);
    if display_port==nil then
        --Cannot open handle
        io.write('Could not connect to '..device..', retrying in 30 seconds...','\n');
        os.execute('sleep 30');
        initializeDisplay();
        return false;
    end
  
    displayPoll = uv.new_poll(display_port:fd());  
    --Init buffers
    local dataBufferReader = '';
    local dataTableReader = {};  
    displayPoll:start('rd', function(_, events) --register callback
        err, data, size = display_port:read(100);
  
        if size==0 then --Disconnected
            io.write("Display Disconnected",'\n');
            local previousPoll = displayPoll;
            initializeDisplay();
            previousPoll:stop();
        end
  
        if data~=nil then
            dataBufferReader=dataBufferReader..removeNils(data);
            --print("DATA BUFFER: "..dataBufferReader);
            dataTableReader = {};
            local arrLF = str_utils.split(dataBufferReader,'\n');
            for i=1,#arrLF,1 do
                local arrCR = str_utils.split(arrLF[i], '\r');
                for e=1,#arrCR,1 do
                    dataTableReader[#dataTableReader+1] = arrCR[e];
                end
            end
            for i=1,#dataTableReader-1,1 do
                local str = dataTableReader[i];
                if str~='' then
                    if debug then
                        --io.write("[DEBUG] Received1: "..str, "\n");
                        --io.flush();
                    end
                end
                dataBufferReader=dataBufferReader:sub(str:len()+1,#dataBufferReader);
            end
            if string.char(dataBufferReader:byte(dataBufferReader:len()))=='\n' or
            string.char(dataBufferReader:byte(dataBufferReader:len()))=='\r' then
                local str = dataBufferReader:sub(1,dataBufferReader:len()-1);
                str = string.gsub(str, '\n', "");
                str = string.gsub(str, '\r', "");
                dataBufferReader = '';
                process_data(str)
                if debug then
                    --io.write("[DEBUG] Received: "..str, "\n");
                    --io.flush();
                end
            end
        end
    end);
    if debug then io.write('[DEBUG] '..device..' was initialized successfully...\n') end
    return display_port --returns serial port handler
end

--Initialize Vemio (all messages must end with linefeed)
function initializeVemio(device,port)
    --Get serial handle
    vemioErr, vemio_port = serial.open(port);
    if vemio_port==nil then
        --Cannot open handle
        io.write('Could not connect to '..device..', retrying in 30 seconds...','\n');
        os.execute('sleep 30');
        initializeVemio();
        return false;
    end
  
    vemioPoll = uv.new_poll(vemio_port:fd());  
    --Init buffers
    local dataBufferReader = '';
    local dataTableReader = {};  
    vemioPoll:start('rd', function(_, events) --register callback
        verr, vdata, vsize = vemio_port:read(100);
  
        if vsize==0 then --Disconnected
            io.write("Vemio Disconnected",'\n');
            local previousPoll = vemioPoll;
            initializeVemio();
            previousPoll:stop();
        end
  
        if vdata~=nil then
            dataBufferReader=dataBufferReader..removeNils(vdata);
            --print("DATA BUFFER: "..dataBufferReader);
            dataTableReader = {};
            local arrLF = str_utils.split(dataBufferReader,'\n');
            for i=1,#arrLF,1 do
                local arrCR = str_utils.split(arrLF[i], '\r');
                for e=1,#arrCR,1 do
                    dataTableReader[#dataTableReader+1] = arrCR[e];
                end
            end
            for i=1,#dataTableReader-1,1 do
                local str = dataTableReader[i];
                if str~='' then
                    if debug then
                        --io.write("[DEBUG] Received1: "..str, "\n");
                        --io.flush();
                    end
                end
                dataBufferReader=dataBufferReader:sub(str:len()+1,#dataBufferReader);
            end
            if string.char(dataBufferReader:byte(dataBufferReader:len()))=='\n' or
            string.char(dataBufferReader:byte(dataBufferReader:len()))=='\r' then
                local str = dataBufferReader:sub(1,dataBufferReader:len()-1);
                str = string.gsub(str, '\n', "");
                str = string.gsub(str, '\r', "");
                dataBufferReader = '';
                process_vdata(str)
                if debug then
                    --io.write("[DEBUG] Received: "..str, "\n");
                    --io.flush();
                end
            end
        end
    end);
    if debug then io.write('[DEBUG] '..device..' was initialized successfully...\n') end
    return vemio_port --returns serial port handler
end

--Initializes page home with price per product
function init_prices()
    if debug then print('[DEBUG] Updating prices in page home') end
    sendNextion('page home')
    for i=1,#Products,1 do
        sendNextion('t'..tostring(9+i)..'.picc=11')
        sendNextion('t'..tostring(9+i)..'.txt="'..tostring(Products[i].price)..' EUR"')
    end

    --init vemio readings
    sendVemio('i1\n')
end

--parse result from DASH transaction
function parse_result(txObject)
    result=txObject.success
    if result then 
        txObject.accept() --send money to main wallet
        sendNextion('page dispensing')
        --activate motors
        prod=tonumber(product)
        if debug then print('[DEBUG] Product: ',product) end

       if Products[prod].m then --has a motor
            low_drive=Products[prod].m[1]
            high_drive=Products[prod].m[2]

            sendVemio('o'..tostring(low_drive)..',1\n')
            uvtimer.set_timeout(uv,100,function()
                sendVemio('o'..tostring(high_drive)..',1\n')
            end)

            --create timer for those which dont have pulse counting or fo triggering if there is error counting them
            stoprot_timer=uvtimer.set_timeout(uv,Products[prod].timerstop*1000,function()
                sendVemio('o'..tostring(low_drive)..',0\n')
                uvtimer.set_timeout(uv,100,function()
                    sendVemio('o'..tostring(high_drive)..',0\n')
                end)
            end)

        else --external product. Send UDP command
            udpServer = uv.new_udp() -- ?? maybe do this in init
            send_address=Products[prod].ip
            send_command=Products[prod].ext
            send_port=Products[prod].port
            udpServer:send(send_command, send_address, send_port,function()
		print("udp sent")
	    end)
	    print("sent to " .. send_address)
        end

        timer_count=0
        progress_timer=uvtimer.set_interval(uv,80,function()
            if timer_count==95 then 
                if debug then print('[DEBUG] Going page home') end
                uvtimer.clear_timeout(uv,progress_timer)
                return 
            end
            sendNextion('j0.val=j0.val+1')
            timer_count=timer_count+1
        end)

    elseif not result then
        sendNextion('page fail')
        if debug then print('[DEBUG] Going page fail then page home') end
    end
end

--process incoming data from VEMIO
function process_vdata(data)
    if debug then print('[DEBUG] Data from VEMIO arrived: '..data) end


    if str_utils.starts_with(data, "i,") then --vemio reported change in inputs so motor is rotating
        current = data:sub(string.find(data, "i,")+2):sub(1,2) --extract current data from msg
        if debug then print('Switch: ',current) end

        if Products[prod].pulse then --if pulses specified
            if current=='01' then
                switch_count=switch_count+1 --count them
            end


            if switch_count==Products[prod].pulse then --if number of pulses reached -> Stop motors
                if debug then print('Stop motors!!!!') end
                low_drive=Products[prod].m[1]
                high_drive=Products[prod].m[2]
		switch_count=0

                uvtimer.clear_timeout(uv,stoprot_timer) --clear redundant timer created above

                sendVemio('o'..tostring(low_drive)..',0\n')
                uvtimer.set_timeout(uv,100,function()
                    sendVemio('o'..tostring(high_drive)..',0\n')
                end)
            end
        end

    elseif str_utils.starts_with(data, "ERR") then
        uvtimer.set_timeout(uv,100,function()    
            sendVemio(lastVmsg)
        end)
    end
end

--process incoming data from display
function process_data(data)
    if debug then print('[DEBUG] Data from Display arrived: '..data) end
    if proceed then
        if data=='1' then --proceed to page payment
            change_dots() --start animation and disable touch while QR not loaded
            price=Products[tonumber(product)].price
            --if debug then print('Before transaction') end
            result=start_transaction(price,'Thank you for buying with qiba!',60)
            for i=1,3,1 do
                str='.'
                sendNextion('t0.txt="."')
            end
        else --user pressed dislike button -> home page
            sendNextion('page home') 
        end
        proceed = false
    else
        if string.sub(data,1,1)=='P' then --each product X choosed by user, Nextion sends 'PX'
            proceed=true
            product=string.sub(data,2,2) --get product number
            sendNextion('proceed.pic='..product) --update image in page proceed
            if debug then print("[DEBUG] User choosed product "..product) end

        elseif  string.find(data, "home")~=nil then --arrived page home. Put every flag in default state
            proceed=false
            product=nil
            prod=nil
            switch_count=0

        else --should never be executed. Only to prevent errors
            if debug then print('Unknown message received. Going back to default state...') end
            sendNextion('page home')
            proceed=false
            product=nil
        end
    end
end

--Listen to transaction
function start_transaction(eur_amount,tx_label,timeout_s)
    local object = dashtx.startListeningToTransaction(--[[LUV handle]] uv,--[[TX label]] tx_label,--[[EUR amount]] eur_amount,--[[Timeout in seconds]] timeout_s,
    function(qrCode)
        --QR code has been generated, so you can show it to customer (WARNING: can be null if this fails!)
        if debug then print("QR code generated: ", qrCode) end
        uvtimer.clear_timeout(uv,timer1)
        if qrCode~=nil then
            sendNextion('page payment')
            sendNextion('qr0.txt="'..qrCode..'"')
        else
            sendNextion('page fail')
        end
    end, function(success, accept, refund)
        local txObject = { --just to keep things encapsulated
            success=success,
            accept=accept,
            refund=refund
        };
        if debug then print("[DEBUG] TX success: ",txObject.success) end
        parse_result(txObject)
    end, function(secondsLeft)
        --Called every second to report number of seconds left to pay
        sendNextion('t0.txt="Time left: '..tostring(secondsLeft)..' seconds"')
    end);
end