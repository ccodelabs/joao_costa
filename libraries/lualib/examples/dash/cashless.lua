local sConnector = require("serial-connector");
local dashtx = require("dashtx.dashtx");
local str_utils = require("str_utils");

local module = {};
MDBUSB_PATH = "/dev/ttyUSB";
RECONNECT_TIMEOUT = 10;

STATE_DISCONNECTED = 0;
STATE_CONNECTED = 1;
STATE_VEND_REQ = 2;
STATE_VENDING = 3;

function module.setDebug(debug)
	sConnector.DEBUG = debug;
	dashtx.DEBUG = debug;
	module.DEBUG = debug;
end

function module.setDashAddress(address)
	dashtx.address = address;
end

function module.setDashNetworkFee(fee)
	dashtx.NETWORK_FEE = fee;
end

function printDebug(...)
	if module.DEBUG then print(...); end
end

--[[
Params:
	uv - luv handle
	transactionLabel - label of the dash transaction
	transactionTimeout - timeout of the dash transaction
	show_qr_code - function called when QR should be shown
	on_tick - function called with amount of seconds left for customer to pay
	on_tx_result - function called with either true or false, indicating if the transaction was successful
	on_vend_result - function called with either nil or checkTxUrl, nil - vend success, checkTxUrl - vend failed and customer refunded
	vendResultTimeout - max amount of seconds to wait for vend result from VMC (default 30 seconds)
]]

function module.startListeningToTransaction(uv, transactionLabel, transactionTimeout, show_qr_code, on_tick, on_tx_result, on_vend_result, vendResultTimeout)
	
	local state = DISCONNECTED;
	local txInProgress = nil;
	local txResultObject = nil;
	local vendResultTimer = nil;
	local object;

	if vendResultTimeout==nil then
		vendResultTimeout = 30;
	end

	local function cancel()
		if state==STATE_VEND_REQ then
			if txInProgress~=nil then
				txInProgress.cancel();
				txInProgress = nil;
			end
			if vendResultTimer~=nil then
				vendResultTimer:stop();
				vendResultTimer:close();
				vendResultTimer = nil;
			end
			on_tx_result(false);
			state = STATE_CONNECTED;
			object.write("C,STOP\n");
		end
		if state==STATE_VENDING then
			if txResultObject~=nil then
				on_vend_result(txResultObject.failed());
				txResultObject = nil;
			end
			if vendResultTimer~=nil then
				vendResultTimer:stop();
				vendResultTimer:close();
				vendResultTimer = nil;
			end
			state = STATE_CONNECTED;
			object.write("C,STOP\n");
		end
	end

	object = sConnector.new(uv, MDBUSB_PATH, RECONNECT_TIMEOUT, function()
		--On connect
		object.write("C,0\nM,0\nS,0\nX,0\nD,0\n");
		object.write("C,1\n");
		cancel();
		state = STATE_CONNECTED;
	end, function()
		--On disconnect
		cancel();
		state = STATE_DISCONNECTED;
	end, function(line)
		--On line read
		if str_utils.starts_with(line, "c,STATUS,INACTIVE") or 
			str_utils.starts_with(line, "c,STATUS,DISABLED") or
			str_utils.starts_with(line, "c,STATUS,ENABLED") or
			str_utils.starts_with(line, "c,STATUS,IDLE") then

			cancel();
			state = STATE_CONNECTED;
		end
		if str_utils.starts_with(line,"c,VEND,SUCCESS") and state==STATE_VENDING and txResultObject~=nil then
			txResultObject.success();
			txResultObject = nil;
			if on_vend_result~=nil then
				on_vend_result(nil);
			end
			if vendResultTimer~=nil then
				vendResultTimer:stop();
				vendResultTimer:close();
				vendResultTimer = nil;
			end
			state = STATE_CONNECTED;
		end
		if str_utils.starts_with(line,"c,ERR,VEND") and state==STATE_VENDING and txResultObject~=nil then
			local txCheckUrl = txResultObject.failed();
			txResultObject = nil;
			if on_vend_result~=nil then
				on_vend_result(txCheckUrl);
			end
			if vendResultTimer~=nil then
				vendResultTimer:stop();
				vendResultTimer:close();
				vendResultTimer = nil;
			end
			state = STATE_CONNECTED;
		end
		if str_utils.starts_with(line,"c,STATUS,VEND,") then
			local arr = str_utils.split(line, ",");
			local amount = tonumber(arr[4]);

			printDebug("Vend for amount: ", amount);

			state = STATE_VEND_REQ;

			if amount~=nil then

				txInProgress = dashtx.startListeningToTransaction(uv, transactionLabel, amount, transactionTimeout,
					function(qrCode)
						if show_qr_code~=nil then
							show_qr_code(qrCode,
								function()
									--Cancel function
									cancel();
								end);
						end
					end,
					function(success, accept, refund)
						if on_tx_result~=nil then on_tx_result(success); end
						txInProgress = nil;
						if success then
							state = STATE_VENDING;
							txResultObject = {
								success = accept,
								failed = refund
							};
							--Start vend result timeout
							vendResultTimer = uv.new_timer();
							vendResultTimer:start(vendResultTimeout*1000,0,function()
								cancel();
							end);
							object.write("C,VEND,"..tostring(amount).."\n");
						else
							object.write("C,VEND,0\n");
						end
					end,
					on_tick);

			else
				object.write("C,VEND,0\n");
			end
		end
	end);

	object.init(); --Don't forget to initialize the serial port!
end

return module;