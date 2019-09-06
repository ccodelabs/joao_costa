local uv = require "luv"
local linuquick=require'LinuquickMQTT.LinuquickMQTT'
require "io"
local str_utils = require("str_utils");

local udpServer = nil;

--Default values
local ip ='192.168.1.113:50000' --ip which will receive the command
local command_str = 'in%s.mp3' --command which will be sent to IP

local fileArr = {};

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

function on_config_change(config)
    if config ~=nil then 
        ip=config.ip
        command_str=config.command
    end
end

function triggered_func(pinNum,status)
    fileArr[pinNum]:seek("set",0)
    local state = fileArr[pinNum]:read("*n")
    print("Changed ", pinNum);
    print("State ", state);

    if state==0 then
        return
    end

    local arr = str_utils.split(ip, ":")

    if #arr>1 then
        local addr = arr[1]
        local port = tonumber(arr[2])
        if port==nil or port<1 or port>65535 then
            return
        end

        local toSend = string.format(command_str, tostring(pinNum));

        if addr=="0.0.0.0" then
            udpServer:set_broadcast(true);
            for i=1,#brdAddresses,1 do
                udpServer:send(toSend, brdAddresses[i], port);
            end
            udpServer:set_broadcast(false);
        else
            udpServer:send(toSend, addr, port);
        end
    end
end

function main()
    linuquick.start(on_config_change)
    local config = linuquick.getConfig()

    if config~=nil and config.ip~=nil and config.command~=nil then 
        ip=config.ip
        command_str=config.command
    end

    udpServer = uv.new_udp();

    brdAddresses = getBroadcastAddresses();

    for i=1,8,1 do
        fileArr[i] = io.open("/dev/gpio/in"..tostring(i).."/value", "r");
        if fileArr[i]==nil then

        else
            local fse = uv.new_fs_event()
            uv.fs_event_start(fse,"/dev/gpio/in"..tostring(i).."/value",{recursive=true},function(err,fname,status)
                if(err) then
                    print("Error "..err)
                else
                    triggered_func(i,status);
                end
            end)
        end
    end
end


main()

while true do
    uv.run()
end
