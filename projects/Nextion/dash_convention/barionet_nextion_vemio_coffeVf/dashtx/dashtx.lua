local base64 = require("dashtx.base64");
local socket = require("socket");
local str_utils = require("dashtx.str_utils");
local url = require("socket.url");
local bit = require("dashtx.bit");
local json = require("dashtx.json");
local coroutine = require 'coroutine'
local dashwallet = require("dashtx.dashwallet");
math.randomseed(os.time());

local module = {};

module.DEBUG = false;

function debug_print(...)
	if module.DEBUG then print(...); end
end

function debug_write(...)
	if module.DEBUG then io.write(...); end
end

function debug_flush()
	if module.DEBUG then io.flush(); end
end

local STATE_DISCONNECTED = 0;
local STATE_CONNECTED = 1;
local STATE_PROTOCOL_UPGRADE = 2;
local STATE_ACTIVE = 3;

INSIGHT_API_BASE_URL = "insight.dash.org";
GET_RATE_URL = "https://rates2.dashretail.org/rates?source=dashretail&symbol=dasheur";
GET_TX_URL = "https://insight.dash.org/insight-api/tx/";
GET_CUSTOMER_TX_URL = "https://insight.dash.org/insight/tx/";
SEND_TX_URL = "https://insight.dash.org/insight-api/tx/send";

module.NETWORK_FEE = 200; --200 sats fee
SEND_TX_RETRY_COUNT = 3;

module.address = "Xbkt2mnNaKPQw1XEZknfTsnvN8bjZTgTHm";

local function decode(chunk)
  if #chunk < 2 then return end
  local second = string.byte(chunk, 2)
  local len = bit.band(second, 0x7f)
  local offset
  if len == 126 then
    if #chunk < 4 then return end
    len = bit.bor(
      bit.blshift(string.byte(chunk, 3), 8),
      string.byte(chunk, 4))
    offset = 4
  elseif len == 127 then
    if #chunk < 10 then return end
    len = bit.bor(
      -- Ignore lengths longer than 32bit
      bit.blshift(string.byte(chunk, 7), 24),
      bit.blshift(string.byte(chunk, 8), 16),
      bit.blshift(string.byte(chunk, 9), 8),
      string.byte(chunk, 10))
    offset = 10
  else
    offset = 2
  end
  if #chunk < offset + len then return end

  local first = string.byte(chunk, 1)
  local payload = string.sub(chunk, offset + 1, offset + len)
  assert(#payload == len, "Length mismatch")
  local extra = string.sub(chunk, offset + len + 1)
  local opcode = bit.band(first, 0xf)
  return extra, payload, opcode
end

local function encode(payload, opcode)
  opcode = opcode or 2
  assert(type(opcode) == "number", "opcode must be number")
  assert(type(payload) == "string", "payload must be string")
  local len = #payload
  local head;
  if len<126 then
	  head = string.char(
	    bit.bor(0x80, opcode),
	    bit.bor(0x80, len)
	  )
  elseif len>126 and len<0x10000 then
	  head = string.char(
	    bit.bor(0x80, opcode),
	    0xFE,
	    bit.band(bit.brshift(len, 8), 0xff),
	    bit.band(len, 0xff)
	  )
  else
	  head = string.char(
	    bit.bor(0x80, opcode),
	    0xFF,
	    0,0,0,0, -- 32 bit length is plenty, assume zero for rest
	    bit.band(bit.brshift(len, 24), 0xff),
	    bit.band(bit.brshift(len, 16), 0xff),
	    bit.band(bit.brshift(len, 8), 0xff),
	    bit.band(len, 0xff)
	  )
  end
  local maskingKey = "";
  --Add masking key
  for i=1,4,1 do
  	  maskingKey = maskingKey..string.char(math.random(0,255));
  end

  local encPayload = "";

  for i=1,#payload,1 do
  	  encPayload = encPayload..string.char(
  	  	bit.bxor(
  	  		payload:byte(i),
  	  	 	maskingKey:byte(math.fmod(i-1, 4)+1)
  	  	)
  	  );
  end

  return head .. maskingKey .. encPayload;
end

local function generateKey(length)
	local str = "";
	for i=1,length,1 do
		str = str..string.char(math.random(0,255));
	end
	return base64.encode(str);
end

local function connect(uv, timeout, cookies, host, path, port, on_connect, on_disconnect, message_handler)
  	local tcp = uv.new_tcp();
  	local key = generateKey(16);

  	local state = STATE_DISCONNECTED;

  	local pinger;

  	local function write(payload)
  		tcp:write(encode(payload,1));
  	end

  	local timeoutTimer = uv.new_timer();
  	timeoutTimer:start(timeout*1000,0,function()
  		--Timed out
  		if state~=STATE_ACTIVE then
  			debug_print("WS connection timed out!");
  			if on_connect~=nil then on_connect("WS connection timed out!"); end
  		end
  	end);

  	local function disconnect()
  		if pinger~=nil then
  			pinger:stop();
  			pinger:close();
  			pinger = nil;
  		end
  		if tcp~=nil then
  			tcp:read_stop();
  			tcp:close();
  			tcp = nil;
  		end
  		if timeoutTimer~=nil then
  			timeoutTimer:stop();
  			timeoutTimer:close();
  			timeoutTimer = nil;
  		end
  	end

  	tcp:connect(socket.dns.toip(host), port, function(err)
  		if err~=nil then
  			if on_connect~=nil then on_connect(err); end
  			return;
  		end

  		state = STATE_CONNECTED;

  		local buffer = "";
	    local dataBuffer = '';
	    local dataTable = {};

	    function on_http_data_read(str)
	    	if str_utils.str_contains(str, "HTTP/1.1 101 Switching Protocols") then
  				state = STATE_PROTOCOL_UPGRADE;
	    		debug_print("Sending 2probe");
	    		write("2probe");
	    	end
	    end

  		tcp:read_start(function(err,data)
  			
  			if err~=nil then
	  			if on_disconnect~=nil then on_disconnect(err); end
	  			return;
	  		end

	  		if state==STATE_CONNECTED and data~=nil then
	  		  debug_write(data);
	  		  debug_flush();
	  		  dataBuffer=dataBuffer..data;
		      --debug_print("DATA BUFFER: "..dataBuffer);
		      dataTable = str_utils.split(dataBuffer,'\n');
		      for i=1,#dataTable-1,1 do
		        local str = dataTable[i];
		        if str~='' then
		          on_http_data_read(str);
		        end
		        dataBuffer=dataBuffer:sub(str:len()+1,#dataBuffer);
		      end
		      if string.char(dataBuffer:byte(dataBuffer:len()))=='\n' then
		        local str = dataBuffer:sub(1,dataBuffer:len()-1);
		        dataBuffer = '';
		        on_http_data_read(str);
		      end
			elseif state~=STATE_DISCONNECTED and data~=nil then
	  			--Switch to binary protocol
	  			buffer = buffer .. data
		        while true do
		          local extra, payload, opcode = decode(buffer)
		          if opcode==0x8 then
		          	--Close
		          	state = STATE_DISCONNECTED;
		          	tcp:read_stop();
		          	tcp:close();
		          	tcp = nil;
		          	pinger:stop();
		          	pinger:close();
		          	pinger = nil;
		          	debug_print("DISCONNECTING...");
		          	if on_disconnect~=nil then on_disconnect(); end
		          end
		          if opcode==0x1 then
			          if payload~=nil then
				          if state==STATE_PROTOCOL_UPGRADE and str_utils.str_contains(payload, "3probe") then
				          	  state = STATE_ACTIVE;
					  		  
					  		  --Stop timeout timer
					  		  timeoutTimer:stop();
					  		  timeoutTimer:close();
					  		  timeoutTimer = nil;

				          	  debug_print("Writing 5");
			    			  tcp:write(encode("5",1));
			    			  --Start pinger
			    			  pinger = uv.new_timer();
			    			  pinger:start(10000,10000, function()
			    			  	write("2");
			    			  end);
  							  if on_connect~=nil then on_connect(); end

				          elseif payload=="3" then

	    					  debug_print("Received pong");

				          else

					          message_handler(payload)

					      end
			          end
			      end
		          buffer = extra or "";
		          if not extra then return end
		        end
		        return;
	  		end

  		end);

  		local sending = "GET "..path.." HTTP/1.1\r\n"..
  			"Content-Length: 0\r\n"..
  			"Content-Type: application/json\r\n"..
  			"Host: "..host.."\r\n"..
  			"Accept: */*\r\n"..
  			"Sec-WebSocket-Extensions: permessage-deflate\r\n"..
  			"Sec-WebSocket-Key: "..key.."\r\n"..
  			"Sec-WebSocket-Version: 13\r\n"..
  			"Connection: keep-alive, Upgrade\r\n"..
  			"Cache-Control: no-cache\r\n"..
  			"Pragma: no-cache\r\n"..
  			"Cookie: "..cookies.."\r\n"..
  			"Upgrade: websocket\r\n\r\n";

  		debug_print(sending);

  		tcp:write(sending);

  		debug_print("All sent");
  		--tcp:flush();

  	end);

  	return {
  		write=write,
  		close=disconnect
  	};
end

local function process_sendRatesGet(debug, url)
	
	DEBUG = debug;

	function debug_print(...)
		if DEBUG then print(...); end
	end

	function debug_write(...)
		if DEBUG then io.write(...); end
	end

	function debug_flush()
		if DEBUG then io.flush(); end
	end

	local json = require("dashtx.json");
	local http = require("ssl.https");

	http.TIMEOUT = 15;

	local response_body = {};
	local res, code, response_headers = http.request{
	    url = url,
	    method = "GET", 
	    headers = 
	        {
	        	["Content-Length"] = 0;
	        },
	    source = ltn12.source.string(''),
	    sink = ltn12.sink.table(response_body),
	};

	debug_write("Response code="..tostring(code),'\n');
	debug_flush();

	if code~=200 then
		return nil;
	end

	local str = table.concat(response_body);

	debug_write("Response body="..tostring(str),'\n');
	debug_flush();

	if str==nil or #str==0 then
		return nil;
	end

	local obj = json.decode(str);

	if obj==nil or obj[1]==nil or obj[1].price==nil then
		return nil;
	end

	debug_write("Dash price="..tostring(obj[1].price),'\n');
	debug_flush();
	return obj[1].price;

end

function getDashForEur(uv, euros, callback)
	local getDashWorker;
	getDashWorker = uv.new_work(process_sendRatesGet, function(rate)
		--Callback
		if rate==nil then
			callback(nil);
			return;
		end
		callback(math.ceil(euros/rate*100000000));
	end);

	getDashWorker:queue(module.DEBUG,GET_RATE_URL);

end

local function process_httpInit(debug, base_url)

	DEBUG = debug;

	function debug_print(...)
		if DEBUG then print(...); end
	end

	function debug_write(...)
		if DEBUG then io.write(...); end
	end

	function debug_flush()
		if DEBUG then io.flush(); end
	end

	local json = require("dashtx.json");
	local socket = require("socket");
	local http = require("socket.http");
	local base64 = require("dashtx.base64");
	local str_utils = require("dashtx.str_utils");

	http.TIMEOUT = 15;

	function getSocketIoT()
		local ts = math.ceil(socket.gettime()*1000);
		local str = "";
		local index = 0;
		while ts~=0 do
			local a = math.floor(ts-(256*math.floor(ts/256)));
			str = str..string.char(a);
			ts = math.floor(ts/math.pow(256,index+1));
		end
		str = str:reverse();
		local b64 = base64.encode(str);
		b64 = b64:gsub("%/","_");
		b64 = b64:gsub("%+","-");
		b64 = b64:gsub("%=","");
		debug_print("TS: ",b64);
		return b64;
	end

	--Get SID
	local response_body = {};
	local res, code, response_headers = http.request{
	    url = "http://"..base_url.."/socket.io/?EIO=3&transport=polling&t="..getSocketIoT(),
	    method = "GET", 
	    headers = 
	        {
	        	["Content-Length"] = 0;
	        	["Host"] = "insight.dash.org";
	        	["Origin"] = "http://localhost/";
	        },
	    source = ltn12.source.string(''),
	    sink = ltn12.sink.table(response_body),
	};

	debug_write("Response code="..tostring(code),'\n');
	debug_flush();

	debug_print("Set-Cookie", response_headers["set-cookie"]);

	local cookiesStr = "";
	if response_headers["set-cookie"] ~=nil then
		local arr1 = str_utils.split(response_headers["set-cookie"], ",");
		for i=1,#arr1,1 do
			if arr1[i]~=nil then
				local arr2 = str_utils.split(arr1[i], ";");
				cookiesStr = cookiesStr .. arr2[1] .. "; ";
			end
		end
	end

	local respBody = table.concat(response_body);

	if respBody==nil or #respBody==0 then
		debug_print("Response body nil or empty");
		return nil;
	end

	debug_print(respBody);

	respBody = respBody:sub(5,#respBody-4);

	local obj = json.decode(respBody);

	if obj==nil then
		debug_print("Cannot decode JSON object");
	end

	debug_print("SID: ",obj.sid);
	local sid = obj.sid;

	--Register events
	local toSend = "21:42[\"subscribe\",\"inv\"]";

	local response_body = {};
	local res, code, response_headers = http.request{
	    url = "http://"..base_url.."/socket.io/?EIO=3&transport=polling&t="..getSocketIoT().."&sid="..sid,
	    method = "POST", 
	    headers = 
	        {
	        	["Content-Length"] = #toSend;
	        	["Cookie"] = cookiesStr;
	        },
	    source = ltn12.source.string(toSend),
	    sink = ltn12.sink.table(response_body),
	};

	debug_write("Response code="..tostring(code),'\n');
	debug_flush();

	debug_print("Set-Cookie", response_headers["set-cookie"]);

	local cookiesStr = "";
	if response_headers["set-cookie"] ~=nil then
		local arr1 = str_utils.split(response_headers["set-cookie"], ",");
		for i=1,#arr1,1 do
			if arr1[i]~=nil then
				local arr2 = str_utils.split(arr1[i], ";");
				cookiesStr = cookiesStr .. arr2[1] .. "; ";
			end
		end
	end

	local respBody = table.concat(response_body);

	if respBody==nil or #respBody==0 then
		debug_print("Response body nil or empty");
		return nil;
	end

	debug_print(respBody);

	return sid, cookiesStr;

end

local function initializeWebsocket(uv, callback, on_recv, on_disconnect, timeout)

	--Obtain SID and register for events
	local httpInitWorker;
	httpInitWorker = uv.new_work(process_httpInit, function(sid, cookies)
		--Callback
		if sid==nil then
			callback(nil);
			return nil;
		end

		local startErr = nil;
		--Initialize WS
		local wsObject;
		wsObject = connect(uv, timeout, cookies, INSIGHT_API_BASE_URL, "/socket.io/?EIO=3&transport=websocket&sid="..url.escape(sid), 80,
			function(err)
				--OnConnect
				if err then
					callback(nil);
					return;
				end
				callback(wsObject);
				return;
			end,function()
				--OnDisconnect
				if on_disconnect~=nil then on_disconnect(); end
			end,function(msg)
				--OnMsgRecv
				if on_recv~=nil then on_recv(msg); end
			end
		);

	end);

	httpInitWorker:queue(module.DEBUG,INSIGHT_API_BASE_URL);

end

local function process_getTxDetails(debug, url, txId)

	DEBUG = debug;

	function debug_print(...)
		if DEBUG then print(...); end
	end

	function debug_write(...)
		if DEBUG then io.write(...); end
	end

	function debug_flush()
		if DEBUG then io.flush(); end
	end

	local json = require("dashtx.json");
	local http = require("ssl.https");

	http.TIMEOUT = 15;

	local response_body = {};
	local res, code, response_headers = http.request{
	    url = url..txId,
	    method = "GET", 
	    headers = 
	        {
	        	["Content-Length"] = 0;
	        },
	    source = ltn12.source.string(''),
	    sink = ltn12.sink.table(response_body),
	};

	debug_write("Response code="..tostring(code),'\n');
	debug_flush();

	if code~=200 then
		return nil;
	end

	local str = table.concat(response_body);

	debug_write("Response body="..tostring(str),'\n');
	debug_flush();

	if str==nil or #str==0 then
		return nil;
	end

	local obj = json.decode(str);

	if obj==nil then
		return nil;
	end

	return json.encode(obj);

end

local function getTxDetails(uv, txId, address, amountSats, callback)

	--Get tx details and get vout index
	local getTxDetailsWorker = uv.new_work(process_getTxDetails, function(jsonTx)
		--Callback
		if jsonTx==nil then
			callback(nil);
			return nil;
		end
		
		local obj = json.decode(jsonTx);
		
		if obj==nil then
			callback(nil);
			return nil;
		end
		if obj.vin==nil or obj.vin[1]==nil or obj.vin[1].addr==nil then
			callback(nil);
			return nil;
		end
		
		local sender = obj.vin[1].addr;

		--Search for the specific vout
		if obj.vout==nil then
			callback(nil);
			return nil;
		end

		local specVout = nil;

		for i=1,#obj.vout,1 do
			local value = math.floor( (tonumber(obj.vout[i].value)*100000000)+0.5 ); --in sats (round!)
			local index = obj.vout[i].n;
			debug_print("[CHECK TX] Comparing, "..tostring(value).." duffs, required: "..tostring(amountSats));
			if obj.vout[i].scriptPubKey~=nil and obj.vout[i].scriptPubKey.addresses~=nil and #obj.vout[i].scriptPubKey.addresses==1 then
				local address = obj.vout[i].scriptPubKey.addresses[1];
				local pubKeyScript = obj.vout[i].scriptPubKey.hex;

				if address==address and value==amountSats then
					--TX we are looking for!
					specVout = {
						index=index,
						pubKeyScript=pubKeyScript
					};
					break;
				end
			end
		end

		if specVout==nil then
			callback(nil);
			return nil;
		end

		callback({
			sender=sender,
			index=specVout.index,
			pubKeyScript=specVout.pubKeyScript
		});

	end);

	getTxDetailsWorker:queue(module.DEBUG, GET_TX_URL, txId);

end

local function process_sendRawTx(debug, url, rawTx)
	
	DEBUG = debug;

	function debug_print(...)
		if DEBUG then print(...); end
	end

	function debug_write(...)
		if DEBUG then io.write(...); end
	end

	function debug_flush()
		if DEBUG then io.flush(); end
	end

	local json = require("dashtx.json");
	local http = require("ssl.https");

	http.TIMEOUT = 15;

	local toSend = json.encode({
		rawtx=rawTx
	});

	local response_body = {};
	local res, code, response_headers = http.request{
	    url = url,
	    method = "POST", 
	    headers = 
	        {
	        	["Content-Length"] = #toSend;
	        	["Content-Type"] = "application/json"
	        },
	    source = ltn12.source.string(toSend),
	    sink = ltn12.sink.table(response_body),
	};

	debug_write("Response code="..tostring(code),'\n');
	debug_flush();

	debug_write("Response body="..table.concat(response_body),'\n');
	debug_flush();

	if code~=200 then
		return false;
	end

	return true;

end

local function sendRawTx(uv, rawTx, callback)
	
	local reqCounter = 0;
	local sendRawTxWorker;
	sendRawTxWorker = uv.new_work(process_sendRawTx, function(success)
		--Callback
		if not success then
			if reqCounter<SEND_TX_RETRY_COUNT then
				sendRawTxWorker:queue(module.DEBUG, SEND_TX_URL, rawTx);
				reqCounter = reqCounter+1;
			else
				callback(nil);
			end
		else
			callback(true);
		end
	end);

	sendRawTxWorker:queue(module.DEBUG, SEND_TX_URL, rawTx);

end

--[[
Params:
	uv - luv handle
	label - label of the transaction to incorporate in QR code
	amountEur - amount in euros to request
	timeout - timeout for receiving payment
	on_qr_generated - function called when qr code is generated
		called as on_qr_generated(qrCodeString), qrCodeString will be nil on failure
	on_tx_received - function called when payment is received
		called as on_tx_received(success) where success is a boolean signaling if transaction was successful (true) or timeout occured (false)
	on_tick - function called every second with how many seconds are left to receive the transaction
		called as on_tick(seconds_till_timeout) so you can display the time left to send transaction to customer
]]--
function module.startListeningToTransaction(uv, label, amountEur, timeout, on_qr_generated, on_tx_received, on_tick, ws_timeout)
	--Do request
	local secondsLeft = timeout;
	local timeout_t = nil;
	local wsObj;

	if ws_timeout==nil then
		ws_timeout = 5;
	end

	local cancelled = false;

	function cancel()
		if timeout_t~=nil then
			timeout_t:stop();
			timeout_t:close();
			timeout_t = nil;
		end
		if wsObj~=nil then
			wsObj.close();
		end
		cancelled = true;
	end

	getDashForEur(uv, amountEur, function(amountSats)
		if cancelled then
			return;
		end

		if amountSats==nil then
			if on_qr_generated~=nil then on_qr_generated(nil); end
			if on_tx_received~=nil then on_tx_received(false); end
			return;
		end

		local dashWalletAddr = dashwallet.getAddress();

		local qrCode = "dash:"..dashWalletAddr.."?amount="..string.format("%.8f",math.floor(amountSats+0.5)/100000000 ).."&label="..url.escape(label);

		--Return QR code just after successful connection to insight API
		initializeWebsocket(uv,
			function(wsObject)
				--Init callback
				if wsObject==nil or wsObject==false then
					--Failed
					if on_tx_received~=nil then on_tx_received(false); end
					return;
				end

				wsObj = wsObject;

				if cancelled then
					wsObject.close();
					return;
				end

				if on_qr_generated~=nil then on_qr_generated(qrCode); end

				--Start ticking
				timeout_t = uv.new_timer();
				timeout_t:start(1000,1000,function()
					secondsLeft = secondsLeft-1;
					if on_tick~=nil then on_tick(secondsLeft); end
					if secondsLeft<=0 then
						--Timed out
						cancelled = true;
						wsObject.close();
						timeout_t:stop();
						timeout_t:close();
						timeout_t = nil;
						if on_tx_received~=nil then on_tx_received(false); end
					end
				end);

			end, function(msg)
				--OnRecv, process
				if str_utils.starts_with(msg, "42") then
					msg = msg:sub(3,#msg)
					local obj = json.decode(msg);
					if obj~=nil and obj[1]~=nil and obj[2]~=nil then
						if obj[1]=="txlock" then
							debug_print("InstantSend TX: ", json.encode(obj[2]));
							if obj[2].txlock==true then

								if obj[2].vout~=nil then

									for e=1,#obj[2].vout,1 do

										local outTx = obj[2].vout[e];

										if outTx[dashWalletAddr]==amountSats then
											--Get more data about tx
											getTxDetails(uv, obj[2].txid, dashWalletAddr, amountSats, function(txObj)
												if txObj==nil or cancelled then
													return;
												end
												
												--Success
												wsObj.close();
												if timeout_t~=nil then
													timeout_t:stop();
													timeout_t:close();
													timeout_t = nil;
												end

												function refund()
													--Send DASH back
													local rawTx, txId = dashwallet.generateTx(obj[2].txid, txObj.index, txObj.pubKeyScript, txObj.sender, amountSats-module.NETWORK_FEE);
													sendRawTx(uv, rawTx, function(success)
														debug_print("Refund transaction success: ",success);
													end);
													debug_print("TXID: "..txId);
													return GET_CUSTOMER_TX_URL..txId:lower();
												end

												function accept()
													--Send DASH to main wallet
													local rawTx = dashwallet.generateTx(obj[2].txid, txObj.index, txObj.pubKeyScript, module.address, amountSats-module.NETWORK_FEE);
													sendRawTx(uv, rawTx, function(success)
														debug_print("Accept transaction success: ",success);
													end);
												end

												if on_tx_received~=nil then on_tx_received(true, accept, refund); end
											end);
											return;
										end
									end
								end
							end
						end
					end
				end
			end, function()
				--Disconnect, failed
				if on_tx_received~=nil then on_tx_received(false); end
				if timeout_t~=nil then
					timeout_t:stop();
					timeout_t:close();
					timeout_t = nil;
				end
			end
		, ws_timeout);
	end);

	return {
		cancel = cancel
	};
end

return module;