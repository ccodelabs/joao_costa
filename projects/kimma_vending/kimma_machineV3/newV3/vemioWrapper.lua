local connector = require("serial-connector");
require("kimma_functions");

local module = {};

local gRxCallback = nil;

local gCallback = {};
local gTimer = {};

local function process(data)
	if gRxCallback~=nil then
		gRxCallback(data);
	end
	if data~=nil and gCallback[data:sub(1,1)]~=nil then
		gCallback[data:sub(1,1)](data, function()
			gCallback[data:sub(1,1)] = nil;
			if gTimer[data:sub(1,1)]~=nil then 
				gTimer[data:sub(1,1)]:stop();
				gTimer[data:sub(1,1)]:close();
				gTimer[data:sub(1,1)] = nil;
			end
		end);
	end
end

function module.initialize(on_connect, on_disconnect, rx_callback)
	gRxCallback = rx_callback;
	connector.initializeDevice(function()
		if on_connect~=nil then on_connect(); end
		--all_low(module);
	end, on_disconnect, process);
end

function module.sendWithResponse(toSend, callback, timeout, prefix)
	gCallback[prefix] = callback;
	gTimer[prefix] = uv.new_timer();
	gTimer[prefix]:start(timeout, 0, function()
		if gCallback[prefix]~=nil then
			gCallback[prefix](nil);
			gCallback[prefix] = nil;
		end	
		gTimer[prefix]:stop();
		gTimer[prefix]:close();
		gTimer[prefix] = nil;
	end);
	connector.write(toSend);
end

function module.send(toSend)
	connector.write(toSend);
end

function module.getSerialPort()
	return connector.p;
end

return module;