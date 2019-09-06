local str_utils = require('str_utils');
uv = require ("luv");
local wrapper = require("vemioWrapper")
require("kimma_functions");

debug = false;
sniff = false;

USB_RECONNECT_DELAY = 30000;
TCP_SERVER_PORT = 31421;
TCP_INITIAL_TIMEOUT = 3000; --Max allowed time from initializing connection to starting a session

TCP_ONLY_LOCAL = true; --Will allow connection only from addresses 127.0.0.1

VEND_APPROVE_TIMEOUT=10;

DISCONNECTED = 0;
CONNECTED = 1;
VENDING = 2;

state = DISCONNECTED;

desiredTemperature = 10;

local currentClient = nil;
local dropped = false;

local state = DISCONNECTED;
local doorOpen = true;

function initializeDevice()
  io.write("initializing MDB device...\n");
  io.flush();
  wrapper.initialize(function()
  	--On connect
  	state = CONNECTED;
	
	local motorArr = motors_matrix(wrapper);
	print_2D_matrix(motorArr);

	all_low(wrapper);
	
	wrapper.send("I1\n");
	wrapper.send("I1\n");
	wrapper.send("I1\n");
	wrapper.send("I1\n");

  end, function()
  	--On disconnect
  	state = DISCONNECTED;
  end, processSerial);
  if debug then
  	print("Continuing");
  end
end

--Sends data to MDB-USB device
function send(data)
  if debug then io.write('[DEBUG] Send: '..data..'\n'); io.flush() end;
  connector.write(data);
end

function initializeTimer()
	local tempChecker = uv.new_timer();
	tempChecker:start(10000,10000, function()
		if wrapper~=nil and state~=DISCONNECTED then
			read_temp(wrapper, function (temp)
				temp = tonumber(temp);
				if temp~=nil then
					print("Desired temp: ", desiredTemperature);
					print("Actual temp: ", temp)
					if temp>desiredTemperature and not doorOpen then
						wrapper.send("O32,1\n");
					else
						wrapper.send("O32,0\n");
					end
				else
					print("error getting temperature");
				end
			end);
		end
	end);
end

function initializeTcpServer()
  if debug then
  	print("Initializng TCP server");
  end
  local tcpServer = uv.new_tcp();
  if TCP_ONLY_LOCAL then
 	 tcpServer:bind("127.0.0.1", TCP_SERVER_PORT);
  else
 	 tcpServer:bind("0.0.0.0", TCP_SERVER_PORT);
  end
  tcpServer:listen(128, function(err)

    if err~=nil then
      io.write("Error when accepting client's connection\n");
      io.write(err, '\n');
      io.flush();
      return;
    end
    
    local client = uv.new_tcp();
    tcpServer:accept(client);

    local address = client:getpeername().ip;
    io.write("Client connected from address ");
    io.write(address,'\n')
    io.flush();

    if TCP_ONLY_LOCAL and address~="127.0.0.1" then
    	client:shutdown();
    	client:close();
    	return;
    end

    local disconnectTimer = uv.new_timer();
    uv.timer_start(disconnectTimer,TCP_INITIAL_TIMEOUT,0,function()
    	disconnectTimer:stop();
		disconnectTimer:close();
        pcall(function()
          client:shutdown();
          client:close();
        end);
    end);
    
    local dataBuffer = '';
    local dataTable = {};

    client:read_start(function(err, chunk)
      
      if chunk~=nil then
	    dataBuffer=dataBuffer..chunk;
	    dataTable = str_utils.split(dataBuffer,'\n');
	    for i=1,#dataTable,1 do
	      local str = dataTable[i];
	      local pStr = removeNils(str);
	      if pStr~='' then
	        if debug then io.write('[DEBUG] TCP Receive: '..pStr..'\n') end;
	        processTcp(pStr,client,disconnectTimer);
	      end
	      dataBuffer=dataBuffer:sub(#str+1,#dataBuffer);
	    end
      else
        pcall(function()
          client:shutdown();
          client:close();
        end);
      end
    end);
  end);
end

function processSerial(data)
    print("Process serial: ", data);

	if str_utils.starts_with(data, "i,") then
        local byteStr = data:sub(string.find(data, "i,")+4):sub(1,2);
        local byte = tonumber(byteStr, 16);
        local bitArr = toBits(byte, 8);

        if bitArr[7]==1 then
        	print("Door opened");
        	doorOpen=true;
        else
        	print("Door closed");
        	doorOpen=false;
       	end

       	if bitArr[8]==1 then
       		dropped = true;
       	end
	end
end

-- Commands:
--  - VEND,<x>,<y>,<(optional)vendTimeout:seconds> [initiates a VEND]
--  - T,<temperature> [sets the temperature]
-- Responses:
--  - FAILED,DISCONNECTED [failed to start the session because vaimo]
--  - FAILED,MISSING_ARGUMENTS [<x> and <y> argument is probably missing]
--  - FAILED,INVALID_ARGUMENT,<number> [argument number <number> is invalid and cannot be parsed]
--  - FAILED,TIMEOUT,VEND [vend timeout timed out]
--  - FAILED,NO_DROP [vend failed, due to item not being detected]
--
--  - SUCCESS
function processTcp(data,client,timer)
	if str_utils.starts_with(data,"VEND,") then
		--Start vend process
		timer:stop();
		timer:close();
		if state~=CONNECTED then
			--Invalid state
			client:write("FAILED,DISCONNECTED\n");
			client:shutdown();
			client:close();
			return;
		end

		local arr = str_utils.split(data,",");
		if #arr<3 then
			client:write("FAILED,MISSING_ARGUMENTS\n");
			client:shutdown();
			client:close();
			return;
		end

		local x = tonumber(arr[2]);
		if x==nil then
			client:write("FAILED,INVALID_ARGUMENT,1\n");
			client:shutdown();
			client:close();
			return;
		end
		
		local y = tonumber(arr[3]);
		if y==nil then
			client:write("FAILED,INVALID_ARGUMENT,2\n");
			client:shutdown();
			client:close();
			return;
		end

		local vendTimeout = VEND_APPROVE_TIMEOUT;

		if arr[4]~=nil then
			local vTimeout = tonumber(arr[4]);
			if vTimeout==nil then
				client:write("FAILED,INVALID_ARGUMENT,3\n");
				client:shutdown();
				client:close();
				return;
			end
			vendTimeout = vTimeout;
		end

		state = VENDING;

		if debug then
			print("Enabling motor");
		end
		dropped = false;
		enable_motor(wrapper, x, y, vendTimeout*1000, function(success)
			if success then
				if dropped then
					client:write("SUCCESS\n");
					client:shutdown();
					client:close();
					state = CONNECTED;
				else
					local dropTimer = uv.new_timer();
					dropTimer:start(1000,0,function()
						if dropped then
							client:write("SUCCESS\n");
							client:shutdown();
							client:close();
							state = CONNECTED;
						else
							client:write("FAILED,NO_DROP\n");
							client:shutdown();
							client:close();
							state = CONNECTED;
						end
						dropTimer:stop();
						dropTimer:close();
					end);
				end
			else
				client:write("FAILED,TIMEOUT,VEND\n");
				client:shutdown();
				client:close();
				state = CONNECTED;
			end
		end)
	end

	if str_utils.starts_with(data, "T,") then
		local arr = str_utils.split(data,",");
		if #arr>1 then
			local temp = tonumber(arr[2]);
			if temp==nil then
				client:write("FAILED,INVALID_ARGUMENT,1\n");
				client:shutdown();
				client:close();
				return;
			end

			desiredTemperature = temp;

			client:write("SUCCESS\n");
			client:shutdown();
			client:close();

		else
			client:write("FAILED,MISSING_ARGUMENTS\n");
		end
	end
end

-- Run with parameters, example:
-- lua kimma_daemon.lua timeout-vend=10 tcp-client-timeout=10
-- Parameters available (default):
--  - timeout-vend (0) [timeout for vend approval by cashless device]
--  - tcp-client-timeout (3000) [timeout for clients to send VEND]
--  - tcp-allow-remote-hosts (false) [to allow tcp connections outside 127.0.0.1 set this to true]
--  - tcp-port (31421) [tcp server port]
--  - debug 
function main()
	create_dl_matrix();
	create_dh_matrix();

	for i=1,#arg,1 do
		local arr = str_utils.split(arg[i],'=');
		if #arr>0 then
			if arr[1]=="tcp-allow-remote-hosts" then
				if arr[2]=="true" then
					TCP_ONLY_LOCAL = false;
				end
			end
			if arr[1]=="tcp-port" then
				local port = tonumber(arr[2]);
				if port==nil or port<1 or port>65535 then
					io.write("Invalid tcp-port specified, must be a number between 1 to 65535 (both inclusive)!\n");
					io.flush();
					return false;
				end
				TCP_SERVER_PORT = port;
			end
			if arr[1]=="tcp-client-timeout" then
				local timeout = tonumber(arr[2]);
				if timeout==nil or timeout<0 then
					io.write("Invalid tcp-client-timeout specified, must be a number bigger than 0!\n");
					io.flush();
					return false;
				end
				TCP_INITIAL_TIMEOUT = timeout*1000;
			end
			if arr[1]=="timeout-vend" then
				local timeout = tonumber(arr[2]);
				if timeout==nil or timeout<0 then
					io.write("Invalid timeout-vend specified, must be a number bigger than 0!\n");
					io.flush();
					return false;
				end
				VEND_APPROVE_TIMEOUT = timeout;
			end
			if arr[1]=="debug" then
				if arr[2]=="true" then
					debug = true;
				end
			end
		end
	end

	initializeDevice();
	initializeTimer();
	initializeTcpServer();

	return true;
end

if not main() then return; end
uv.run();